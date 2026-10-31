use crate::render::{FrozenPrompt, bytes, render_request, truncate_history};
use crate::service::{close_run, permissions, protocol_error, validate_environment};
use crate::*;
use chrono::Utc;
use jiabu_ai::*;
use jiabu_chat::{StreamEvent, *};
use jiabu_db::chat_runtime::{RunLease, RunRow, ToolCallRow};
use jiabu_db::{AppDb, Mode, OperationError, Principal, SpaceTx};
use jiabu_domain::{JoinEpoch, SpaceId};
use serde_json::{Value, json};
use sha2::{Digest, Sha256};
use std::{
    collections::{HashMap, HashSet},
    sync::Arc,
    time::{Duration, Instant},
};
use tokio::sync::{Mutex, Notify, watch};
#[async_trait::async_trait]
pub trait ImageLoader: Send + Sync {
    async fn original(&self, sha: &str) -> Result<String, OperationError>;
}
#[async_trait::async_trait]
pub trait FileLoader: Send + Sync {
    async fn pdf(&self, sha: &str) -> Result<String, OperationError>;
}
pub struct Runtime {
    pub db: AppDb,
    pub router: Arc<RouterStore>,
    pub tools: Arc<jiabu_tools::ToolRegistry>,
    pub templates: Arc<jiabu_tools::templates::TemplateStore>,
    pub hub: Arc<StreamHub>,
    pub observer: Arc<dyn CallObserver>,
    pub images: Option<Arc<dyn ImageLoader>>,
    pub files: Option<Arc<dyn FileLoader>>,
    pub budget: RunBudget,
    active: Mutex<HashMap<Uuid, Duration>>,
    owners: Mutex<HashSet<Uuid>>,
    wake: Notify,
}
impl Runtime {
    pub fn new(
        db: AppDb,
        router: Arc<RouterStore>,
        tools: Arc<jiabu_tools::ToolRegistry>,
        templates: Arc<jiabu_tools::templates::TemplateStore>,
        hub: Arc<StreamHub>,
        observer: Arc<dyn CallObserver>,
    ) -> Self {
        Self {
            db,
            router,
            tools,
            templates,
            hub,
            observer,
            images: None,
            files: None,
            budget: RunBudget::default(),
            active: Mutex::new(HashMap::new()),
            owners: Mutex::new(HashSet::new()),
            wake: Notify::new(),
        }
    }
    /// One iteration is also the deterministic integration-test entry point.
    pub async fn work_once(&self, owner: Uuid) -> Result<bool, OperationError> {
        self.owners.lock().await.insert(owner);
        for (space, user, epoch) in self.db.runnable_scopes().await? {
            let tx = match SpaceTx::begin(
                &self.db,
                user,
                &[(space, Some(JoinEpoch(epoch)))],
                Mode::Write,
            )
            .await
            {
                Ok(tx) => tx,
                Err(_) => continue,
            };
            let run = tx.claim_run(space, owner).await?;
            tx.commit().await?;
            if let Some(run) = run {
                let p = self.db.runtime_principal(user, run.id).await?;
                let lease = RunLease {
                    run_id: run.id,
                    owner,
                    epoch: run.lease_epoch,
                };
                let started = Instant::now();
                let result = self.drive(&p, &run, lease).await;
                *self.active.lock().await.entry(run.id).or_default() += started.elapsed();
                if let Err(error) = result {
                    // The failing stage is dropped. Close only from the durable
                    // checkpoint, never from its uncommitted in-memory fold.
                    let reason = error.code;
                    self.end_owned(&p, &run, lease, "failed", reason).await?;
                }
                // Keep elapsed time only while a run can yield and resume in
                // this process. Terminal runs must not accumulate in memory.
                match SpaceTx::begin(&self.db, p.user_id, &[(space, None)], Mode::Write).await {
                    Ok(tx) => {
                        let active = tx
                            .run_for_message(space, run.assistant_message_id)
                            .await?
                            .is_some_and(|r| service::is_active(&r.status));
                        tx.commit().await?;
                        if !active {
                            self.active.lock().await.remove(&run.id);
                        }
                    }
                    Err(_) => {
                        self.active.lock().await.remove(&run.id);
                    }
                }
                return Ok(true);
            }
        }
        Ok(false)
    }
    /// Renews the lease every `RENEW_SECS` until dropped. Holds the stage for
    /// the transaction so the tick branch never waits on it.
    async fn renew_while_streaming(
        &self,
        p: &Principal,
        run: &RunRow,
        lease: RunLease,
        stage: &Mutex<StagedStream>,
    ) -> Result<std::convert::Infallible, OperationError> {
        // The lease was just claimed or renewed; the first renewal is due one period later.
        let period = Duration::from_secs(RENEW_SECS);
        let mut renew = tokio::time::interval_at(tokio::time::Instant::now() + period, period);
        loop {
            renew.tick().await;
            let _stage = stage.lock().await;
            let tx = self.begin(p, run, lease).await?;
            tx.renew_run(SpaceId(run.space_id), lease).await?;
            tx.commit().await?;
        }
    }
    async fn begin(
        &self,
        p: &Principal,
        run: &RunRow,
        lease: RunLease,
    ) -> Result<SpaceTx, OperationError> {
        let space = SpaceId(run.space_id);
        let tx = SpaceTx::begin(
            &self.db,
            p.user_id,
            &[(space, Some(JoinEpoch(run.join_epoch)))],
            Mode::Write,
        )
        .await?;
        tx.guard_run(space, lease).await?;
        Ok(tx)
    }
    async fn end_owned(
        &self,
        p: &Principal,
        run: &RunRow,
        lease: RunLease,
        status: &str,
        reason: &str,
    ) -> Result<(), OperationError> {
        let tx = match self.begin(p, run, lease).await {
            Ok(tx) => tx,
            Err(_) => return Ok(()),
        };
        let batch = close_run(&tx, SpaceId(run.space_id), run, status, reason).await?;
        tx.commit().await?;
        jiabu_chat::publish(&self.hub, batch)
            .await
            .map_err(protocol_error)
    }
    async fn drive(
        &self,
        p: &Principal,
        run: &RunRow,
        lease: RunLease,
    ) -> Result<(), OperationError> {
        let space = SpaceId(run.space_id);
        let scope = ChatScope {
            space_id: space,
            member_id: jiabu_domain::MemberId(run.member_id),
            user_id: p.user_id,
        };
        let emitter = RunEmitter {
            lease,
            scope,
            hub: self.hub.clone(),
        };
        let tx = self.begin(p, run, lease).await?;
        let journal = tx.journal(space, run.id).await?;
        validate_environment(tx.member(space), &journal)?;
        let stored = tx
            .message(space, run.assistant_message_id)
            .await?
            .ok_or_else(OperationError::not_found)?;
        let mut prompt = if let Some(value) = journal
            .iter()
            .rev()
            .find(|i| i.kind == "note" && i.payload.get("frozen_prompt").is_some())
            .map(|i| i.payload["frozen_prompt"].clone())
        {
            serde_json::from_value::<FrozenPrompt>(value).map_err(protocol_error)?
        } else {
            let context = journal
                .iter()
                .find(|i| i.kind == "context")
                .ok_or_else(OperationError::internal)?;
            let input = journal
                .iter()
                .find(|i| i.kind == "input")
                .ok_or_else(OperationError::internal)?
                .payload
                .clone();
            let snapshot: PromptSnapshot =
                serde_json::from_value(context.payload["definitions"]["snapshot"].clone())
                    .map_err(protocol_error)?;
            let versions = context.payload["definitions"]["tool_versions"].clone();
            let budget = self
                .router
                .0
                .load()
                .config
                .models
                .iter()
                .filter(|m| m.enabled)
                .map(|m| m.context_tokens.unwrap_or(8192) as usize)
                .min()
                .unwrap_or(8192)
                .saturating_mul(2);
            let history =
                truncate_history(&tx.recent_history(space, run.input_entry_id).await?, budget);
            let frozen = tx.freeze_history(space, lease, json!(history)).await?;
            let prompt = FrozenPrompt {
                frozen_for: Some(run.id),
                drop_provider_blobs: false,
                snapshot,
                context: context.payload["space"].clone(),
                input,
                history: serde_json::from_value(frozen).map_err(protocol_error)?,
                permissions: permissions(tx.member(space)),
                tool_versions: versions,
            };
            tx.save_prompt_snapshot(
                space,
                lease,
                Sha256::digest(bytes(&json!(prompt.snapshot)).map_err(protocol_error)?).to_vec(),
                json!(prompt.snapshot),
            )
            .await?;
            tx.append_journal(
                space,
                lease,
                "note",
                None,
                json!({"frozen_prompt":prompt}),
                None,
            )
            .await?;
            prompt
        };
        // Explicit retry is a NEW run. Freeze current definitions once, retain
        // committed results, and turn incompatible pending calls into errors
        // for the model instead of guessing how to migrate their frozen args.
        if run.retry_of_run_id.is_some() && prompt.frozen_for != Some(run.id) {
            let mut tools = Vec::new();
            let mut versions = serde_json::Map::new();
            for tool in self.tools.agent_tools() {
                if tool.name() != "ask_user"
                    && jiabu_tools::authorize(tx.member(space), tool.module(), tool.action())
                        .is_err()
                {
                    continue;
                }
                tools.push(ToolDefinition {
                    name: tool.name().into(),
                    description: tool.description().into(),
                    parameters: tool.parameters().clone(),
                });
                versions.insert(tool.name().into(), json!(tool.schema_version()));
            }
            tools.sort_by(|a, b| a.name.cmp(&b.name));
            let old_calls = tx.calls(space, run.id).await?;
            for call in old_calls {
                if journal.iter().any(|i| {
                    i.kind == "tool_result" && i.call_id.as_deref() == Some(call.call_id.as_str())
                }) {
                    continue;
                }
                if self.tools.get(&call.tool).map_or(true, |t| {
                    t.schema_version() != call.tool_schema_version as u32
                }) {
                    tx.append_journal(space,lease,"tool_result",Some(&call.call_id),json!({"output":{"error":"tool_schema_changed","note":"Use current definitions; recorded successful operations already took effect."}}),None).await?;
                    tx.set_call_status(space, lease, &call.call_id, "failed")
                        .await?;
                }
            }
            prompt.snapshot.instructions =
                crate::render::static_instructions(&self.templates.snapshot().await.bytes);
            prompt.snapshot.tools = tools;
            prompt.tool_versions = Value::Object(versions);
            prompt.context = tx.space_context(space).await?;
            prompt.context["presets"] = json!(jiabu_domain::presets::PRESETS);
            prompt.frozen_for = Some(run.id);
            prompt.drop_provider_blobs = true;
            tx.save_prompt_snapshot(
                space,
                lease,
                Sha256::digest(bytes(&json!(prompt.snapshot)).map_err(protocol_error)?).to_vec(),
                json!(prompt.snapshot),
            )
            .await?;
            tx.append_journal(
                space,
                lease,
                "note",
                None,
                json!({"frozen_prompt":prompt}),
                None,
            )
            .await?;
        }
        // Validate both authorization and schema version before resuming work.
        for tool in &prompt.snapshot.tools {
            let current = self
                .tools
                .get(&tool.name)
                .map_err(|_| OperationError::new(409, "tool_schema_changed"))?;
            if prompt.tool_versions[&tool.name] != json!(current.schema_version()) {
                return Err(OperationError::new(409, "tool_schema_changed"));
            }
        }
        tx.commit().await?;
        let stage = Arc::new(Mutex::new(
            StagedStream::load(jiabu_chat::checkpoint(stored))
                .await
                .map_err(protocol_error)?,
        ));
        let started = Instant::now();
        let previous = self
            .active
            .lock()
            .await
            .get(&run.id)
            .copied()
            .unwrap_or_default();
        loop {
            let tx = self.begin(p, run, lease).await?;
            let current = tx.guard_run(space, lease).await?;
            tx.renew_run(space, lease).await?;
            let journal = tx.journal(space, run.id).await?;
            let calls = tx.calls(space, run.id).await?;
            validate_environment(tx.member(space), &journal)?;
            let action = next_action(&journal, &calls);
            if self.budget.exhausted(
                current.model_turns as u32,
                previous + started.elapsed(),
                action == NextAction::Model,
            ) {
                let batch = close_run(&tx, space, &current, "failed", "budget_exhausted").await?;
                tx.commit().await?;
                jiabu_chat::publish(&self.hub, batch)
                    .await
                    .map_err(protocol_error)?;
                return Ok(());
            }
            if action == NextAction::Model
                && let Some(tool) = corrections_exhausted(&journal, &calls)
            {
                tracing::warn!(
                    error_kind = "tool_corrections_exhausted",
                    tool = %tool,
                    "Model kept sending arguments the tool rejects"
                );
                let batch =
                    close_run(&tx, space, &current, "failed", "tool_arguments_rejected").await?;
                tx.commit().await?;
                jiabu_chat::publish(&self.hub, batch)
                    .await
                    .map_err(protocol_error)?;
                return Ok(());
            }
            let newly = if action == NextAction::Model {
                newly_unavailable_displays(&journal, &calls)
            } else {
                vec![]
            };
            if !newly.is_empty() {
                for tool in newly {
                    tracing::warn!(
                        error_kind = "display_fallback_text",
                        tool = %tool,
                        "Display tool kept failing; the model answers in text"
                    );
                    tx.append_journal(space, lease, "note", None, json!({"display_unavailable":tool,"text":format!("{tool} is unavailable for the rest of this reply. Do not call it again; answer briefly in text.")}), None).await?;
                }
                tx.commit().await?;
                continue;
            }
            tx.commit().await?;
            match action {
                NextAction::Complete => {
                    let tx = self.begin(p, run, lease).await?;
                    let mut s = stage.lock().await;
                    s.stream.finish().await.map_err(protocol_error)?;
                    let batch = s.batch().await.map_err(protocol_error)?;
                    emitter.persist(&tx, &batch).await.map_err(protocol_error)?;
                    tx.finish_run(space, run.id, "completed", None).await?;
                    tx.commit().await?;
                    jiabu_chat::publish(&self.hub, batch)
                        .await
                        .map_err(protocol_error)?;
                    return Ok(());
                }
                NextAction::InvalidJournal => {
                    return Err(OperationError::new(409, "invalid_journal"));
                }
                NextAction::Execute(id) => {
                    let call = calls
                        .iter()
                        .find(|c| c.call_id == id)
                        .ok_or_else(OperationError::internal)?;
                    let mut s = stage.lock().await;
                    let executor = ToolExecutor {
                        db: &self.db,
                        registry: self.tools.clone(),
                    };
                    if call.effect == "read" {
                        let order = journal
                            .iter()
                            .rev()
                            .find(|i| i.kind == "model_turn")
                            .and_then(|i| i.payload["calls"].as_array())
                            .ok_or_else(OperationError::internal)?;
                        let mut batch = Vec::new();
                        let mut found = false;
                        for proposal in order {
                            if proposal["call_id"] == id {
                                found = true;
                            }
                            if !found {
                                continue;
                            }
                            let Some(candidate) =
                                calls.iter().find(|c| proposal["call_id"] == c.call_id)
                            else {
                                continue;
                            };
                            if candidate.effect != "read" || candidate.tool == "ask_user" {
                                break;
                            }
                            if !journal.iter().any(|i| {
                                i.kind == "tool_result"
                                    && i.call_id.as_deref() == Some(candidate.call_id.as_str())
                            }) {
                                batch.push(candidate.clone());
                            }
                        }
                        executor
                            .execute_reads(p, run, lease, &batch, &mut s, &emitter)
                            .await?;
                    } else {
                        executor
                            .execute(p, run, lease, call, &mut s, &emitter)
                            .await?;
                    }
                }
                NextAction::Interrupt(id) => {
                    let call = calls
                        .iter()
                        .find(|c| c.call_id == id)
                        .ok_or_else(OperationError::internal)?;
                    self.pause(p, run, lease, call, &stage, &emitter).await?;
                    return Ok(());
                }
                NextAction::Model => {
                    let router = self.router.0.load_full();
                    let has_files = prompt.input["files"]
                        .as_array()
                        .is_some_and(|files| !files.is_empty());
                    let task = if has_files {
                        TaskKind::ChatFile
                    } else if prompt.input["images"]
                        .as_array()
                        .is_some_and(|a| !a.is_empty())
                    {
                        TaskKind::ChatVision
                    } else {
                        TaskKind::Chat
                    };
                    let mut request =
                        render_request(run.id, run.conversation_id.to_string(), &prompt, &journal)
                            .map_err(protocol_error)?;
                    let availability = if task == TaskKind::ChatFile {
                        router.request_availability(task, &request)
                    } else {
                        router.availability(task)
                    };
                    if !availability.available {
                        if availability.reason == "no_available_route" {
                            return Err(OperationError::new(503, "no_available_route"));
                        }
                        let tx = self.begin(p, run, lease).await?;
                        tx.wait_for_ai(space, lease).await?;
                        tx.commit().await?;
                        self.hub.publish(StreamEvent(json!({"protocolVersion":"0.1","type":"message.activity","messageId":run.assistant_message_id,"activity":{"phase":"degraded","label":"等待 AI / Waiting for AI"}}))).await.map_err(protocol_error)?;
                        return Ok(());
                    }
                    if has_files {
                        let tx = self.begin(p, run, lease).await?;
                        for item in &request.items {
                            if let RequestItem::Message { files, .. } = item {
                                for file in files {
                                    let hash = file.data.as_bytes();
                                    if hash.len() != 64 {
                                        return Err(OperationError::invalid());
                                    }
                                    let mut decoded = [0_u8; 32];
                                    for (index, pair) in hash.as_chunks::<2>().0.iter().enumerate()
                                    {
                                        let nibble = |byte| match byte {
                                            b'0'..=b'9' => Some(byte - b'0'),
                                            b'a'..=b'f' => Some(byte - b'a' + 10),
                                            _ => None,
                                        };
                                        decoded[index] = (nibble(pair[0])
                                            .ok_or_else(OperationError::invalid)?
                                            << 4)
                                            | nibble(pair[1])
                                                .ok_or_else(OperationError::invalid)?;
                                    }
                                    if tx.chat_file_metadata(space, &decoded).await?.is_none() {
                                        return Err(OperationError::not_found());
                                    }
                                }
                            }
                        }
                        tx.commit().await?;
                    }
                    for item in &mut request.items {
                        if let RequestItem::Message { images, files, .. } = item {
                            for image in images {
                                let loader = self
                                    .images
                                    .as_ref()
                                    .ok_or_else(|| OperationError::new(503, "image_unavailable"))?;
                                *image = loader.original(image).await?;
                            }
                            for file in files {
                                let loader = self
                                    .files
                                    .as_ref()
                                    .ok_or_else(|| OperationError::new(503, "file_unavailable"))?;
                                file.data = loader.pdf(&file.data).await?;
                            }
                        }
                    }
                    let tx = self.begin(p, run, lease).await?;
                    tx.begin_model_call(space, lease).await?;
                    tx.commit().await?;
                    let mut sink = Collector {
                        runtime: self,
                        p,
                        run,
                        lease,
                        stage: stage.clone(),
                        emitter: &emitter,
                        text: String::new(),
                        items: Vec::new(),
                        calls: Vec::new(),
                        rejected: Vec::new(),
                        messages_delimited: false,
                        block: None,
                        done: false,
                        allowed: &prompt.snapshot.tools,
                        unavailable: unavailable_displays(&journal),
                        last_event: Arc::new(Mutex::new(Instant::now())),
                    };
                    let last_event = sink.last_event.clone();
                    let mut cancellation = self
                        .hub
                        .subscribe(&run.assistant_message_id.to_string())
                        .await
                        .map_err(protocol_error)?;
                    let result = {
                        let future =
                            router.run_turn(task, &request, &mut sink, self.observer.as_ref());
                        tokio::pin!(future);
                        let mut ticks = tokio::time::interval(Duration::from_millis(50));
                        // Polled alongside the model so neither waits on a lock the
                        // other holds while suspended.
                        let renewal = self.renew_while_streaming(p, run, lease, &stage);
                        tokio::pin!(renewal);
                        let deadline = tokio::time::sleep(
                            self.budget.model_call.min(
                                self.budget
                                    .active
                                    .saturating_sub(previous + started.elapsed()),
                            ),
                        );
                        tokio::pin!(deadline);
                        loop {
                            tokio::select! {
                                r=&mut future=>break r,
                                notice=cancellation.recv()=>{
                                    match notice {
                                        Ok(Some(event)) if event.event_type()=="message.end"=>break Err(ProviderError::Sink),
                                        Err(_)=>break Err(ProviderError::Sink),
                                        _=>{},
                                    }
                                },
                                _=&mut deadline=>break Err(ProviderError::Timeout),
                                _=ticks.tick()=>{
                                    if last_event.lock().await.elapsed()>=self.budget.model_idle{break Err(ProviderError::Timeout);}
                                    // A busy stage means the model future holds it mid-write;
                                    // waiting here would stop polling that future and deadlock.
                                    if let Ok(mut s)=stage.try_lock(){
                                        s.stream.tick().await.map_err(protocol_error)?;
                                        flush(self,p,run,lease,&mut s,&emitter).await?;
                                    }
                                },
                                Err(e)=&mut renewal=>return Err(e),
                            }
                        }
                    };
                    if let Err(error) = result {
                        self.db.finish_abandoned_run_calls(run.id).await?;
                        let timeout = matches!(&error, ProviderError::Timeout)
                            || matches!(&error,ProviderError::PartialOutput{source} if matches!(source.as_ref(),ProviderError::Timeout));
                        if let ProviderError::Rejected {
                            code,
                            param,
                            message,
                        } = &error
                        {
                            // Not transient: waiting for AI would resend the same request.
                            // Only tool-schema messages are logged; others may echo input.
                            let schema_message = if param == "tools" {
                                message.as_str()
                            } else {
                                ""
                            };
                            tracing::warn!(
                                error_kind = "request_rejected",
                                upstream_code = %code,
                                upstream_param = %param,
                                upstream_message = %schema_message,
                                "AI request rejected by provider"
                            );
                            self.end_owned(
                                p,
                                run,
                                lease,
                                "failed",
                                &format!("request_rejected:{code}"),
                            )
                            .await?;
                        } else if timeout {
                            self.end_owned(p, run, lease, "failed", "model_timeout")
                                .await?;
                        } else if matches!(error, ProviderError::PartialOutput { .. })
                            || !sink.text.is_empty()
                        {
                            // Visible output is kept and never resent silently; a truncated
                            // stream still says why it ended.
                            let reason = match &error {
                                ProviderError::PartialOutput { source } => match source.as_ref() {
                                    ProviderError::Incomplete { reason } => {
                                        format!("incomplete:{reason}")
                                    }
                                    _ => "partial_output".into(),
                                },
                                _ => "partial_output".into(),
                            };
                            self.end_owned(p, run, lease, "interrupted", &reason)
                                .await?;
                        } else if matches!(error, ProviderError::Sink | ProviderError::Meter) {
                            return Err(OperationError::internal());
                        } else if let ProviderError::InvalidOutput
                        | ProviderError::Incomplete { .. } = &error
                        {
                            // Corrupt or truncated output was already retried once per route
                            // by the router; waiting for AI would only repeat it.
                            let reason = match &error {
                                ProviderError::Incomplete { reason } => {
                                    format!("incomplete:{reason}")
                                }
                                _ => "invalid_output".into(),
                            };
                            tracing::warn!(
                                error_kind = "stream_corrupt",
                                reason = %reason,
                                "AI output was unusable after a retry"
                            );
                            self.end_owned(p, run, lease, "failed", &reason).await?;
                        } else {
                            if let ProviderError::UpstreamFailed { code } = &error {
                                tracing::warn!(
                                    error_kind = "upstream_failed",
                                    upstream_code = %code,
                                    "AI provider reported a failure; waiting for AI"
                                );
                            }
                            let tx = self.begin(p, run, lease).await?;
                            tx.wait_for_ai(space, lease).await?;
                            tx.commit().await?;
                            self.hub.publish(StreamEvent(json!({"protocolVersion":"0.1","type":"message.activity","messageId":run.assistant_message_id,"activity":{"phase":"degraded"}}))).await.map_err(protocol_error)?;
                        }
                        return Ok(());
                    }
                    if !sink.done {
                        return Err(OperationError::new(502, "missing_completion"));
                    }
                    let mut s = stage.lock().await;
                    if let Some(block) = sink.block.take() {
                        block.finish().await.map_err(protocol_error)?;
                    }
                    let tx = self.begin(p, run, lease).await?;
                    validate_environment(tx.member(space), &journal)?;
                    // Providers that do not delimit messages replay their text first, as before.
                    if !sink.messages_delimited && !sink.text.is_empty() {
                        sink.items.insert(
                            0,
                            RequestItem::AssistantMessage {
                                text: sink.text.clone(),
                                phase: None,
                            },
                        );
                    }
                    let mut encrypted = Vec::new();
                    let mut items = Vec::new();
                    for item in &sink.items {
                        if matches!(item, RequestItem::ProviderBlob(_)) {
                            items.push(json!({"blob_index":encrypted.len()}));
                            encrypted.push(json!(item));
                        } else {
                            items.push(json!(item));
                        }
                    }
                    tx.append_journal(
                        space,
                        lease,
                        "model_turn",
                        None,
                        json!({"text":sink.text,"items":items,"calls":sink.calls}),
                        if encrypted.is_empty() {
                            None
                        } else {
                            Some(json!(encrypted))
                        },
                    )
                    .await?;
                    for call in &sink.calls {
                        tx.insert_call(
                            space,
                            lease,
                            call,
                            Sha256::digest(bytes(&call.args).map_err(protocol_error)?).to_vec(),
                        )
                        .await?;
                    }
                    // Rejected calls get their result in the same commit, so the next
                    // step is another model turn that sees what to correct.
                    for (call_id, output) in &sink.rejected {
                        let tool = sink
                            .calls
                            .iter()
                            .find(|c| &c.call_id == call_id)
                            .map_or("", |c| c.tool.as_str());
                        let rules = output["errors"]
                            .as_array()
                            .into_iter()
                            .flatten()
                            .filter_map(|e| e["rule"].as_str())
                            .collect::<Vec<_>>()
                            .join(",");
                        tracing::info!(
                            error_kind = "tool_arguments_rejected",
                            error_code = %output["error"].as_str().unwrap_or(""),
                            tool = %tool,
                            rules = %rules,
                            "Tool call arguments returned to the model"
                        );
                        tx.append_journal(
                            space,
                            lease,
                            "tool_result",
                            Some(call_id),
                            json!({"output":output}),
                            None,
                        )
                        .await?;
                    }
                    tx.model_turn_committed(space, lease).await?;
                    let final_turn = sink.calls.is_empty();
                    if final_turn {
                        s.stream.finish().await.map_err(protocol_error)?;
                    }
                    let batch = s.batch().await.map_err(protocol_error)?;
                    emitter.persist(&tx, &batch).await.map_err(protocol_error)?;
                    if final_turn {
                        tx.finish_run(space, run.id, "completed", None).await?;
                    }
                    tx.commit().await?;
                    jiabu_chat::publish(&self.hub, batch)
                        .await
                        .map_err(protocol_error)?;
                    if final_turn {
                        return Ok(());
                    }
                }
            }
        }
    }
    async fn pause(
        &self,
        p: &Principal,
        run: &RunRow,
        lease: RunLease,
        call: &ToolCallRow,
        stage: &Arc<Mutex<StagedStream>>,
        emitter: &RunEmitter,
    ) -> Result<(), OperationError> {
        let confirmation = call.tool != "ask_user";
        let expires = Utc::now() + chrono::Duration::days(if confirmation { 1 } else { 7 });
        let expires = expires.to_rfc3339_opts(chrono::SecondsFormat::Micros, true);
        let id = Uuid::now_v7().to_string();
        let (kind, mut data) = if confirmation {
            (
                "confirmation",
                json!({"title":"确认操作 / Confirm operation","severity":"normal","body":call.args.to_string(),"action":{"type":"confirmation.respond","target":"pending_operation.confirm","expiresAt":expires}}),
            )
        } else {
            let mut args: jiabu_tools::AskArgs =
                serde_json::from_value(call.args.clone()).map_err(protocol_error)?;
            args.check()?;
            if args.fields.is_empty() && args.options.is_empty() {
                args.fields.push(jiabu_tools::AskField {
                    key: "answer".into(),
                    label: args.prompt.clone(),
                    kind: "text".into(),
                    required: true,
                });
            }
            let action = json!({"type":if args.fields.is_empty(){"choice.select"}else{"form.submit"},"target":"clarification.answer","expiresAt":expires});
            if args.fields.is_empty() {
                (
                    "choice",
                    json!({"prompt":args.prompt,"options":if args.options.is_empty(){json!([{"id":"other","label":"输入其他内容 / Other input"}])}else{json!(args.options)},"action":action}),
                )
            } else {
                (
                    "form_intent",
                    json!({"title":args.prompt,"fields":args.fields,"action":action}),
                )
            }
        };
        data["state"] = json!({"status":"open"});
        let tx = self.begin(p, run, lease).await?;
        let mut s = stage.lock().await;
        let step = s
            .stream
            .start_step(if confirmation {
                "等待确认 / Confirmation"
            } else {
                "等待回答 / Question"
            })
            .await
            .map_err(protocol_error)?;
        let block = s
            .stream
            .start_block(kind, 1, "等待回答 / Waiting for input")
            .await
            .map_err(protocol_error)?;
        block
            .data(data, "等待回答 / Waiting for input", None)
            .await
            .map_err(protocol_error)?;
        block.finish().await.map_err(protocol_error)?;
        s.stream
            .pause(
                &step,
                &block,
                &id,
                if confirmation {
                    "confirmation"
                } else {
                    "input_required"
                },
                true,
            )
            .await
            .map_err(protocol_error)?;
        let batch = s.batch().await.map_err(protocol_error)?;
        emitter.persist(&tx, &batch).await.map_err(protocol_error)?;
        tx.pause_run(SpaceId(run.space_id),lease,json!({"id":id,"step_id":step.id,"block_id":block.id,"call_id":call.call_id,"expires_at":expires}),&call.call_id).await?;
        tx.commit().await?;
        jiabu_chat::publish(&self.hub, batch)
            .await
            .map_err(protocol_error)
    }
    pub async fn sweep(&self) -> Result<(), OperationError> {
        for (run, stored) in self.db.unavailable_run_messages().await? {
            let expected = stored.last_seq;
            let mut stage = StagedStream::load(jiabu_chat::checkpoint(stored))
                .await
                .map_err(protocol_error)?;
            stage.stream.stop().await.map_err(protocol_error)?;
            let batch = stage.batch().await.map_err(protocol_error)?;
            if self
                .db
                .cancel_unavailable_run(
                    &run,
                    expected,
                    batch.checkpoint.message.0.clone(),
                    batch.events.iter().map(|e| e.0.clone()).collect(),
                )
                .await?
            {
                self.db.finish_abandoned_run_calls(run.id).await?;
                jiabu_chat::publish(&self.hub, batch)
                    .await
                    .map_err(protocol_error)?;
            }
        }
        for (space, user, message, _) in self.db.sweep_candidates().await? {
            let tx = match SpaceTx::begin(&self.db, user, &[(space, None)], Mode::Write).await {
                Ok(tx) => tx,
                Err(_) => continue,
            };
            let Some(run) = tx.run_for_message(space, message).await? else {
                continue;
            };
            if !tx.sweep_still_due(space, run.id).await? {
                continue;
            }
            let (status, reason) = match run.status.as_str() {
                "paused" => ("expired", "interrupt_expired"),
                "waiting_ai" => ("failed", "waiting_ai_timeout"),
                _ => ("interrupted", "lease_expired"),
            };
            let batch = close_run(&tx, space, &run, status, reason).await?;
            tx.commit().await?;
            self.db.finish_abandoned_run_calls(run.id).await?;
            jiabu_chat::publish(&self.hub, batch)
                .await
                .map_err(protocol_error)?;
            self.active.lock().await.remove(&run.id);
        }
        Ok(())
    }
    pub fn spawn(self: Arc<Self>) -> RuntimeHandle {
        let (shutdown, rx) = watch::channel(false);
        let mut tasks = Vec::new();
        for _ in 0..WORKER_COUNT {
            let runtime = self.clone();
            let mut rx = rx.clone();
            tasks.push(tokio::spawn(async move {
                let owner = Uuid::now_v7();
                loop {
                    if *rx.borrow() {
                        break;
                    }
                    match runtime.work_once(owner).await {
                        Ok(true) => continue,
                        Ok(false) => {}
                        Err(_) => {
                            tracing::warn!(error_kind = "worker_failed", "Agent worker failed")
                        }
                    }
                    tokio::select! {
                        _ = tokio::time::sleep(Duration::from_secs(5)) => {}
                        _ = runtime.wake.notified() => {}
                        _ = rx.changed() => {}
                    }
                }
            }));
        }
        let runtime = self.clone();
        let mut rx = rx;
        tasks.push(tokio::spawn(async move {
            let mut tick = tokio::time::interval(Duration::from_secs(30));
            loop {
                tokio::select! {
                    _ = rx.changed() => break,
                    _ = tick.tick() => {
                        // Sweeping and log cleanup are independent; one failing must not skip the other.
                        if runtime.sweep().await.is_err() {
                            tracing::warn!(error_kind = "sweep_failed", "Agent sweep failed");
                        }
                        if runtime.db.cleanup_chat_logs().await.is_err() {
                            tracing::warn!(error_kind = "cleanup_failed", "Chat cleanup failed");
                        }
                    }
                }
            }
        }));
        RuntimeHandle {
            runtime: self,
            shutdown,
            tasks,
        }
    }
    pub async fn notifications(&self, url: &str) -> Result<(), OperationError> {
        let mut notifications = jiabu_db::chat_runtime::RunNotifications::connect(url)
            .await
            .map_err(|_| OperationError::internal())?;
        loop {
            notifications
                .recv()
                .await
                .map_err(|_| OperationError::internal())?;
            self.wake.notify_waiters();
        }
    }
}
pub struct RuntimeHandle {
    runtime: Arc<Runtime>,
    shutdown: watch::Sender<bool>,
    tasks: Vec<tokio::task::JoinHandle<()>>,
}
impl RuntimeHandle {
    pub fn stop_claiming(&self) {
        self.shutdown.send_replace(true);
    }
    pub fn stop_signal(&self) -> watch::Sender<bool> {
        self.shutdown.clone()
    }
    pub async fn shutdown(mut self) {
        self.shutdown.send_replace(true);
        let deadline = tokio::time::Instant::now() + Duration::from_secs(SHUTDOWN_GRACE_SECS);
        for task in &mut self.tasks {
            if tokio::time::timeout_at(deadline, &mut *task).await.is_err() {
                task.abort();
            }
        }
        // Aborted workers retain leases; revoke and close them now, never requeue.
        let owners: Vec<_> = self.runtime.owners.lock().await.iter().copied().collect();
        let Ok(candidates) = self.runtime.db.owned_running_messages(&owners).await else {
            return;
        };
        for (space, user, message) in candidates {
            if let Ok(tx) =
                SpaceTx::begin(&self.runtime.db, user, &[(space, None)], Mode::Write).await
                && let Ok(Some(run)) = tx.run_for_message(space, message).await
                && run.status == "running"
                && let Ok(batch) = close_run(&tx, space, &run, "interrupted", "shutdown").await
                && tx.commit().await.is_ok()
            {
                let _ = self.runtime.db.finish_abandoned_run_calls(run.id).await;
                let _ = jiabu_chat::publish(&self.runtime.hub, batch).await;
            }
        }
    }
}
async fn flush(
    runtime: &Runtime,
    p: &Principal,
    run: &RunRow,
    lease: RunLease,
    stage: &mut StagedStream,
    emitter: &RunEmitter,
) -> Result<(), OperationError> {
    let batch = stage.batch().await.map_err(protocol_error)?;
    if batch.events.is_empty() {
        return Ok(());
    }
    let tx = runtime.begin(p, run, lease).await?;
    emitter.commit(tx, batch).await.map_err(protocol_error)
}
struct Collector<'a> {
    runtime: &'a Runtime,
    p: &'a Principal,
    run: &'a RunRow,
    lease: RunLease,
    stage: Arc<Mutex<StagedStream>>,
    emitter: &'a RunEmitter,
    text: String,
    items: Vec<RequestItem>,
    calls: Vec<ToolCallRow>,
    /// Calls whose arguments were rejected, with the tool result the model will see.
    rejected: Vec<(String, Value)>,
    /// Whether the provider delimited its messages; otherwise text replays first.
    messages_delimited: bool,
    block: Option<BlockHandle>,
    done: bool,
    allowed: &'a [ToolDefinition],
    /// Display tools that kept failing in this run; further calls are refused.
    unavailable: Vec<String>,
    last_event: Arc<Mutex<Instant>>,
}
#[async_trait::async_trait]
impl TurnSink for Collector<'_> {
    async fn emit(&mut self, event: TurnEvent) -> Result<(), ProviderError> {
        *self.last_event.lock().await = Instant::now();
        match event {
            TurnEvent::TextDelta(text) => {
                self.text.push_str(&text);
                let mut stage = self.stage.lock().await;
                if self.block.is_none() {
                    self.block = Some(
                        stage
                            .stream
                            .start_block("markdown", 1, "")
                            .await
                            .map_err(|_| ProviderError::Sink)?,
                    );
                }
                if let Some(block) = &self.block {
                    block
                        .append_text(&text)
                        .await
                        .map_err(|_| ProviderError::Sink)?;
                }
                flush(
                    self.runtime,
                    self.p,
                    self.run,
                    self.lease,
                    &mut stage,
                    self.emitter,
                )
                .await
                .map_err(|_| ProviderError::Sink)?;
            }
            TurnEvent::ToolCall {
                call_id,
                name,
                args_raw,
            } => {
                // A repeated call id is a corrupt stream, not a correctable argument.
                if self.calls.iter().any(|c| c.call_id == call_id) {
                    return Err(ProviderError::InvalidOutput);
                }
                match check_call(
                    self.runtime,
                    self.allowed,
                    &self.unavailable,
                    &name,
                    &args_raw,
                ) {
                    Ok((tool, args, confirmation)) => self.calls.push(ToolCallRow {
                        call_id: call_id.clone(),
                        tool: name.clone(),
                        tool_schema_version: tool.schema_version() as i32,
                        args,
                        effect: if tool.effect() == jiabu_tools::Effect::Read {
                            "read"
                        } else {
                            "local_write"
                        }
                        .into(),
                        status: "proposed".into(),
                        idempotency_key: tool_idempotency_key(self.run.id, &call_id),
                        guard: Some(json!({"confirmation":confirmation})),
                    }),
                    // Fed back to the model as this call's result (ai-layer 5); nothing runs.
                    Err((version, args, output)) => {
                        self.calls.push(ToolCallRow {
                            call_id: call_id.clone(),
                            tool: name.clone(),
                            tool_schema_version: version,
                            args,
                            effect: "read".into(),
                            status: "rejected".into(),
                            idempotency_key: tool_idempotency_key(self.run.id, &call_id),
                            guard: Some(json!({"invalid_arguments":true})),
                        });
                        self.rejected.push((call_id.clone(), output));
                    }
                }
                self.items.push(RequestItem::ToolCall {
                    call_id,
                    name,
                    args_raw,
                });
            }
            TurnEvent::MessageDone { text, phase } => {
                self.messages_delimited = true;
                self.items
                    .push(RequestItem::AssistantMessage { text, phase });
            }
            TurnEvent::ProviderBlob(blob) => self.items.push(RequestItem::ProviderBlob(blob)),
            TurnEvent::Note(text) => {
                // Every write during a model call holds the stage; see the tick branch.
                let _stage = self.stage.lock().await;
                let tx = self
                    .runtime
                    .begin(self.p, self.run, self.lease)
                    .await
                    .map_err(|_| ProviderError::Sink)?;
                tx.append_journal(
                    SpaceId(self.run.space_id),
                    self.lease,
                    "note",
                    None,
                    json!({"text":text}),
                    None,
                )
                .await
                .map_err(|_| ProviderError::Sink)?;
                tx.commit().await.map_err(|_| ProviderError::Sink)?;
            }
            TurnEvent::Done { .. } => self.done = true,
        }
        Ok(())
    }
}
type CheckedCall<'a> = (&'a dyn jiabu_tools::AgentTool, Value, bool);
/// Accept a proposed call, or return `(schema_version, stored_args, tool_result)`
/// describing what the model must correct. Only schema-side names are reported.
fn check_call<'a>(
    runtime: &'a Runtime,
    allowed: &[ToolDefinition],
    unavailable: &[String],
    name: &str,
    args_raw: &str,
) -> Result<CheckedCall<'a>, (i32, Value, Value)> {
    let stored = |args: Option<&Value>| {
        args.cloned().unwrap_or_else(|| {
            // Unparseable arguments are kept for audit, bounded like other run data.
            Value::String(args_raw.chars().take(4096).collect())
        })
    };
    let tool = match runtime.tools.get(name) {
        Ok(tool)
            if allowed.iter().any(|t| t.name == name)
                && tool.exposure() != jiabu_tools::Exposure::ApiOnly =>
        {
            tool
        }
        _ => {
            let available: Vec<_> = allowed.iter().map(|t| t.name.as_str()).collect();
            return Err((
                0,
                stored(None),
                json!({"error":"unknown_tool","available":available,"note":"Call one of the available tools."}),
            ));
        }
    };
    let version = tool.schema_version() as i32;
    if unavailable.iter().any(|t| t == name) {
        return Err((
            version,
            stored(None),
            json!({"error":"display_unavailable","note":"Answer briefly in text without this tool."}),
        ));
    }
    let args: Value = match serde_json::from_str(args_raw) {
        Ok(args) => args,
        Err(_) => {
            let mut error = OperationError::new(422, "invalid_arguments");
            error.errors = Some(vec![jiabu_db::ValidationIssue {
                pointer: "/".into(),
                rule: "json_object".into(),
            }]);
            return Err((version, stored(None), tool_error_output(&error)));
        }
    };
    let rejected = |error: OperationError| {
        let mut error = error;
        if error.code == "validation_failed" {
            error.code = "invalid_arguments";
        }
        (version, args.clone(), tool_error_output(&error))
    };
    let validated = tool.validate(args.clone()).map_err(rejected)?;
    if name == "ask_user" {
        serde_json::from_value::<jiabu_tools::AskArgs>(args.clone())
            .map_err(|_| rejected(OperationError::invalid_at("/", "schema")))?
            .check()
            .map_err(rejected)?;
    }
    let confirmation = tool.requires_confirmation(validated.as_ref());
    Ok((tool, args, confirmation))
}
