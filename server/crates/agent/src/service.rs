use crate::*;
use chrono::{DateTime, Utc};
use jiabu_chat::{StagedStream, StreamConfig, StreamHub};
use jiabu_db::chat_runtime::RunRow;
use jiabu_db::{AppDb, Mode, OperationError, Principal, SpaceTx};
use jiabu_domain::{JoinEpoch, SpaceId};
use serde_json::{Value, json};
use sha2::{Digest, Sha256};
use std::sync::Arc;
/// A request binds its space and epoch explicitly; neither is inferred from a
/// message UUID. HTTP binds it after checking membership and request headers.
pub struct ScopedRuns {
    pub db: AppDb,
    pub space: SpaceId,
    pub epoch: JoinEpoch,
    pub hub: Arc<StreamHub>,
    pub tools: Arc<jiabu_tools::ToolRegistry>,
    pub templates: Arc<jiabu_tools::templates::TemplateStore>,
}
impl RunService {
    pub fn scoped(
        &self,
        db: AppDb,
        space: SpaceId,
        epoch: JoinEpoch,
        hub: Arc<StreamHub>,
        tools: Arc<jiabu_tools::ToolRegistry>,
        templates: Arc<jiabu_tools::templates::TemplateStore>,
    ) -> ScopedRuns {
        ScopedRuns {
            db,
            space,
            epoch,
            hub,
            tools,
            templates,
        }
    }
}
pub(crate) fn protocol_error(_: impl std::fmt::Display) -> OperationError {
    OperationError::new(409, "runtime_conflict")
}
fn protocol_error_at(reason: &'static str, error: impl std::fmt::Display) -> OperationError {
    // Static context only: protocol errors can contain private field values.
    tracing::warn!(reason, "chat protocol conflict");
    protocol_error(error)
}
impl ScopedRuns {
    async fn begin(&self, p: &Principal) -> Result<SpaceTx, OperationError> {
        p.require_ai_session()?;
        if matches!(
            p.via,
            jiabu_db::Via::Session {
                kind: jiabu_db::auth::SessionKind::PasswordChange,
                ..
            }
        ) {
            return Err(OperationError::new(403, "password_change_required"));
        }
        Ok(SpaceTx::begin(
            &self.db,
            p.user_id,
            &[(self.space, Some(self.epoch))],
            Mode::Write,
        )
        .await?)
    }
    pub async fn start(
        &self,
        p: &Principal,
        input: StartMessage,
    ) -> Result<StartResponse, OperationError> {
        self.start_at(p, input, Utc::now()).await
    }
    /// Trusted non-HTTP entry point for reproducible evaluations. Only the frozen
    /// submission timestamp changes; leases and interrupt expiry use wall time.
    pub async fn start_at(
        &self,
        p: &Principal,
        input: StartMessage,
        submitted_at: DateTime<Utc>,
    ) -> Result<StartResponse, OperationError> {
        let tx = self.begin(p).await?;
        if input.text.as_deref().unwrap_or_default().trim().is_empty() && input.images.is_empty() {
            return Err(OperationError::invalid());
        }
        if input.text.as_ref().is_some_and(|s| s.len() > 32000) || input.images.len() > 8 {
            return Err(OperationError::invalid());
        }
        // Image references must already be verified original blob IDs. Never
        // fetch caller URLs; no network or thumbnail/re-encoding in the runtime.
        for image in &input.images {
            tx.require_chat_image(self.space, image).await?;
        }
        if let Some(existing) = tx.message(self.space, input.id).await? {
            let expected = json!({"text":input.text,"images":input.images});
            if existing.message["metadata"]["input"] != expected {
                return Err(OperationError::new(409, "idempotency_conflict"));
            }
            let response = tx
                .reply_for_input(self.space, input.id)
                .await?
                .ok_or_else(OperationError::internal)?;
            if tx
                .run_for_message(self.space, response)
                .await?
                .is_none_or(|r| r.join_epoch != self.epoch.0)
            {
                return Err(OperationError::new(409, "membership_changed"));
            }
            tx.commit().await?;
            return Ok(StartResponse {
                user_message_id: input.id,
                message_id: response,
            });
        }
        let mut closing = Vec::new();
        for run in tx.active_runs(self.space).await? {
            if run.status == "paused" {
                closing.push(close_run(&tx, self.space, &run, "cancelled", "stopped").await?);
            }
        }
        let conversation = tx.conversation(self.space).await?;
        let run = Uuid::now_v7();
        let message = Uuid::now_v7();
        let now = submitted_at.to_rfc3339();
        let text = input.text.clone().unwrap_or_default();
        let user = json!({"protocolVersion":"0.1","id":input.id,"conversationId":conversation,"role":"user","status":"complete","rev":1,"createdAt":now,"fallbackText":text,"blocks":[],"metadata":{"input":{"text":input.text,"images":input.images},"locale":p.user.locale}});
        tx.insert_message(self.space, conversation, None, None, user, 0)
            .await?;
        let mut config = StreamConfig::new(message.to_string());
        config.conversation_id = Some(conversation.to_string());
        let mut stage = StagedStream::start(config).await.map_err(protocol_error)?;
        let batch = stage.batch().await.map_err(protocol_error)?;
        tx.insert_message(
            self.space,
            conversation,
            Some(run),
            Some(input.id),
            batch.checkpoint.message.0.clone(),
            0,
        )
        .await?;
        jiabu_chat::persist(&tx, self.space, &batch)
            .await
            .map_err(protocol_error)?;
        tx.enqueue_run(self.space, conversation, input.id, message, run, None)
            .await?;
        // Context/input are frozen at submission; history waits until first claim.
        let mut context = tx.space_context(self.space).await?;
        context["presets"] = json!(jiabu_domain::presets::PRESETS);
        let mut tools = Vec::new();
        let mut versions = serde_json::Map::new();
        for tool in self.tools.agent_tools() {
            if tool.name() != "ask_user"
                && jiabu_tools::authorize(tx.member(self.space), tool.module(), tool.action())
                    .is_err()
            {
                continue;
            }
            tools.push(jiabu_ai::ToolDefinition {
                name: tool.name().into(),
                description: tool.description().into(),
                parameters: tool.parameters().clone(),
            });
            versions.insert(tool.name().into(), json!(tool.schema_version()));
        }
        tools.sort_by(|a, b| a.name.cmp(&b.name));
        let templates = self.templates.snapshot().await;
        let snapshot = jiabu_ai::PromptSnapshot {
            instructions: crate::render::static_instructions(&templates.bytes),
            tools,
            model: String::new(),
            parameters: jiabu_ai::ModelParameters::default(),
        };
        tx.seed_run_context(self.space,run,context,json!({"text":text,"images":user_images(&input.images),"locale":p.user.locale,"submitted_at":now}),json!({"snapshot":snapshot,"tool_versions":versions})).await?;
        tx.commit().await?;
        for b in closing {
            jiabu_chat::publish(&self.hub, b)
                .await
                .map_err(protocol_error)?;
        }
        jiabu_chat::publish(&self.hub, batch)
            .await
            .map_err(protocol_error)?;
        Ok(StartResponse {
            user_message_id: input.id,
            message_id: message,
        })
    }
    pub async fn stop(&self, p: &Principal, message: Uuid) -> Result<(), OperationError> {
        let tx = self.begin(p).await?;
        let run = tx
            .run_for_message(self.space, message)
            .await?
            .ok_or_else(OperationError::not_found)?;
        if !is_active(&run.status) {
            tx.commit().await?;
            return Ok(());
        }
        let batch = close_run(&tx, self.space, &run, "cancelled", "stopped").await?;
        tx.commit().await?;
        jiabu_chat::publish(&self.hub, batch)
            .await
            .map_err(protocol_error)
    }
    pub async fn retry(
        &self,
        p: &Principal,
        message: Uuid,
    ) -> Result<StartResponse, OperationError> {
        let tx = self.begin(p).await?;
        let old = tx
            .run_for_message(self.space, message)
            .await?
            .ok_or_else(OperationError::not_found)?;
        if old.join_epoch != self.epoch.0
            || old.last_error.as_deref() == Some("permission_changed")
            || old.journal_compacted_at.is_some()
            || !matches!(
                old.status.as_str(),
                "interrupted" | "failed" | "expired" | "cancelled"
            )
        {
            return Err(OperationError::new(409, "retry_unavailable"));
        }
        // Permission validation precedes even a previously accepted retry replay.
        let journal = tx.journal(self.space, old.id).await?;
        validate_environment(tx.member(self.space), &journal)?;
        if let Some(child) = tx.retry_child(self.space, old.id).await? {
            tx.commit().await?;
            return Ok(StartResponse {
                user_message_id: old.input_entry_id,
                message_id: child.assistant_message_id,
            });
        }
        let run = Uuid::now_v7();
        let message = Uuid::now_v7();
        let mut config = StreamConfig::new(message.to_string());
        config.conversation_id = Some(old.conversation_id.to_string());
        let mut stage = StagedStream::start(config).await.map_err(protocol_error)?;
        let batch = stage.batch().await.map_err(protocol_error)?;
        tx.insert_message(
            self.space,
            old.conversation_id,
            Some(run),
            Some(old.input_entry_id),
            batch.checkpoint.message.0.clone(),
            0,
        )
        .await?;
        jiabu_chat::persist(&tx, self.space, &batch)
            .await
            .map_err(protocol_error)?;
        tx.enqueue_run(
            self.space,
            old.conversation_id,
            old.input_entry_id,
            message,
            run,
            Some(old.id),
        )
        .await?;
        tx.retry_copy(self.space, &old, run).await?;
        tx.commit().await?;
        jiabu_chat::publish(&self.hub, batch)
            .await
            .map_err(protocol_error)?;
        Ok(StartResponse {
            user_message_id: old.input_entry_id,
            message_id: message,
        })
    }
    pub async fn answer(
        &self,
        p: &Principal,
        request: Value,
        registry: &jiabu_tools::ToolRegistry,
    ) -> Result<Value, OperationError> {
        self.answer_inner(p, request, registry, None).await
    }
    /// HTTP identity binding is checked after persisted-block authorization.
    pub async fn answer_with_key(
        &self,
        p: &Principal,
        request: Value,
        registry: &jiabu_tools::ToolRegistry,
        key: Uuid,
    ) -> Result<Value, OperationError> {
        self.answer_inner(p, request, registry, Some(key)).await
    }
    async fn answer_inner(
        &self,
        p: &Principal,
        request: Value,
        registry: &jiabu_tools::ToolRegistry,
        key: Option<Uuid>,
    ) -> Result<Value, OperationError> {
        let tx = self.begin(p).await?;
        let parse_id = |v: &Value| {
            v.as_str()
                .and_then(|s| s.parse::<Uuid>().ok())
                .ok_or_else(OperationError::invalid)
        };
        let message = parse_id(&request["context"]["messageId"])?;
        let action = parse_id(&request["id"])?;
        let block_id = request["context"]["blockId"]
            .as_str()
            .ok_or_else(OperationError::invalid)?
            .to_owned();
        let run = tx
            .run_for_message(self.space, message)
            .await?
            .ok_or_else(OperationError::not_found)?;
        if run.join_epoch != self.epoch.0 {
            return Err(OperationError::not_found());
        }
        if request["context"]["conversationId"] != run.conversation_id.to_string() {
            return Err(OperationError::not_found());
        }
        let stored = tx
            .message(self.space, message)
            .await?
            .ok_or_else(OperationError::not_found)?;
        let block = stored.message["blocks"]
            .as_array()
            .and_then(|a| a.iter().find(|b| b["id"] == block_id))
            .ok_or_else(OperationError::not_found)?;
        // Recover the originating tool from durable interrupts, including after
        // resolution. Authorization runs before receipt lookup on EVERY replay.
        let journal = tx.journal(self.space, run.id).await?;
        let interrupt = journal
            .iter()
            .rev()
            .filter(|i| i.kind == "interrupt")
            .find(|i| i.payload["block_id"] == block_id)
            .map(|i| i.payload.clone())
            .ok_or_else(OperationError::not_found)?;
        let calls = tx.calls(self.space, run.id).await?;
        let call = calls
            .iter()
            .find(|c| Some(c.call_id.as_str()) == interrupt["call_id"].as_str())
            .ok_or_else(OperationError::not_found)?;
        if validate_environment(tx.member(self.space), &journal).is_err() {
            // The frozen permissions no longer hold, so this reply can never
            // resume; close it now instead of leaving it paused until expiry.
            if run.status == "paused" {
                let batch =
                    close_run(&tx, self.space, &run, "failed", "permission_changed").await?;
                tx.commit().await?;
                jiabu_chat::publish(&self.hub, batch)
                    .await
                    .map_err(protocol_error)?;
            }
            return Err(OperationError::not_found());
        }
        let tool = registry.get(&call.tool)?;
        if call.tool != "ask_user" {
            jiabu_tools::authorize(tx.member(self.space), tool.module(), tool.action())
                .map_err(|_| OperationError::not_found())?;
        }
        if key.is_some_and(|key| key != action) {
            return Err(OperationError::new(400, "idempotency_key_mismatch"));
        }
        let fingerprint =
            Sha256::digest(crate::render::bytes(&request).map_err(protocol_error)?).to_vec();
        if let Some(result) = tx
            .action_receipt(self.space, action, fingerprint.clone())
            .await?
        {
            tx.commit().await?;
            return Ok(result);
        }
        if run.status != "paused"
            || run.open_interrupt.as_ref().and_then(|v| v.get("id")) != interrupt.get("id")
        {
            return Err(OperationError::new(409, "interrupt_resolved"));
        }
        let expires = interrupt["expires_at"]
            .as_str()
            .and_then(|s| DateTime::parse_from_rfc3339(s).ok())
            .ok_or_else(OperationError::internal)?;
        if expires <= Utc::now() {
            return Err(OperationError::new(409, "interrupt_expired"));
        }
        let payload = &request["payload"];
        validate_answer(block, &request)?;
        let approved = call.tool != "ask_user"
            && payload["outcome"] == "confirm"
            && payload.get("freeText").is_none();
        let mut stage = StagedStream::load(jiabu_chat::checkpoint(stored))
            .await
            .map_err(protocol_error)?;
        stage
            .stream
            .resume(jiabu_chat::RecordedAnswer {
                interrupt_id: interrupt["id"]
                    .as_str()
                    .ok_or_else(OperationError::internal)?
                    .into(),
                payload: payload.clone(),
                resolved_at: Utc::now().to_rfc3339(),
                resolved_by: Some(tx.member(self.space).id().to_string()),
            })
            .await
            .map_err(protocol_error)?;
        // Finish the resumed question step; waiting time is excluded by CW clocks.
        if let Some(step) = interrupt["step_id"].as_str() {
            stage
                .stream
                .step_handle(step)
                .await
                .map_err(protocol_error)?
                .finish("succeeded", None)
                .await
                .map_err(protocol_error)?;
        }
        let batch = stage.batch().await.map_err(protocol_error)?;
        tx.resolve_interrupt(self.space,run.id,&interrupt,json!({"interrupt_id":interrupt["id"],"outcome":if approved{"confirm"}else if call.tool=="ask_user"{"answer"}else{"cancel"},"payload":payload}),approved).await?;
        jiabu_chat::persist(&tx, self.space, &batch)
            .await
            .map_err(protocol_error)?;
        let result = json!({"status":"accepted","resume":{"messageId":message}});
        tx.remember_action(
            self.space,
            action,
            message,
            &block_id,
            request,
            fingerprint,
            result.clone(),
        )
        .await?;
        tx.commit().await?;
        jiabu_chat::publish(&self.hub, batch)
            .await
            .map_err(protocol_error)?;
        Ok(result)
    }
}
fn user_images(images: &[String]) -> Value {
    json!(images)
}
pub(crate) fn is_active(status: &str) -> bool {
    matches!(status, "queued" | "running" | "paused" | "waiting_ai")
}
pub(crate) fn permissions(member: &jiabu_db::ActiveMember) -> Value {
    json!({"ledger":format!("{:?}",member.ledger_grant()),"documents":format!("{:?}",member.documents_grant())})
}
pub(crate) fn validate_environment(
    member: &jiabu_db::ActiveMember,
    journal: &[jiabu_db::chat_runtime::JournalItem],
) -> Result<(), OperationError> {
    if let Some(context) = journal.iter().find(|i| i.kind == "context")
        && context
            .payload
            .get("permissions")
            .is_some_and(|v| v != &permissions(member))
    {
        return Err(OperationError::new(409, "permission_changed"));
    }
    Ok(())
}
pub(crate) async fn close_run(
    tx: &SpaceTx,
    space: SpaceId,
    run: &RunRow,
    status: &str,
    reason: &str,
) -> Result<jiabu_chat::EmissionBatch, OperationError> {
    let stored = tx
        .message(space, run.assistant_message_id)
        .await?
        .ok_or_else(OperationError::not_found)?;
    let initial = jiabu_chat::checkpoint(stored);
    let mut stage = StagedStream::load(initial.clone())
        .await
        .map_err(|error| protocol_error_at("close_run: load checkpoint", error))?;
    let calls = tx.calls(space, run.id).await?;
    let count = calls
        .iter()
        .filter(|c| c.effect == "local_write" && c.status == "succeeded")
        .count();
    let current = stage
        .stream
        .message()
        .await
        .map_err(|error| protocol_error_at("close_run: read stream status", error))?;
    let open_markdown = current.0["blocks"].as_array().is_some_and(|blocks| {
        blocks
            .iter()
            .any(|block| block["type"] == "markdown" && block["status"] == "pending")
    });
    // CW permits one open markdown block. Its terminator closes any persisted
    // model block; terminal_summary still reports counts when we skip this block.
    if current.status() == "streaming" && reason == "stopped" && !open_markdown {
        stage
            .markdown(&format!(
                "已停止，已保存 {count} 项 / Stopped; {count} operations saved."
            ))
            .await
            .map_err(|error| protocol_error_at("close_run: append stop text", error))?;
    }
    // A paused stream must be closed through its interrupt-aware CW terminator.
    match reason {
        "stopped" => stage
            .stream
            .stop()
            .await
            .map_err(|error| protocol_error_at("close_run: stop stream", error))?,
        "interrupt_expired" => stage
            .stream
            .expire_interrupt()
            .await
            .map_err(|error| protocol_error_at("close_run: expire interrupt", error))?,
        // ChatWeave only closes a paused stream through stop / expiry.
        _ if current.status() == "paused" => stage
            .stream
            .stop()
            .await
            .map_err(|error| protocol_error_at("close_run: stop paused stream", error))?,
        _ => {
            if stage
                .stream
                .message()
                .await
                .map_err(|error| protocol_error_at("close_run: read fallback text", error))?
                .0["fallbackText"]
                .as_str()
                .is_none_or(|s| s.trim().is_empty())
                && !open_markdown
            {
                stage
                    .markdown("运行未完成，请重试 / Run did not finish; retry.")
                    .await
                    .map_err(|error| protocol_error_at("close_run: append failure text", error))?;
            }
            stage.stream.fail(&format!("运行未完成，请重试 / Run did not finish; retry. 已保存 {count} 项 / {count} operations saved.")).await.map_err(|error| protocol_error_at("close_run: fail stream", error))?;
        }
    }
    let mut batch = stage
        .batch()
        .await
        .map_err(|error| protocol_error_at("close_run: collect terminal batch", error))?;
    if reason == "stopped" {
        let unfinished = calls.iter().filter(|c| c.status != "succeeded").count();
        batch=jiabu_chat::terminal_summary(&initial,batch,&format!("已停止；已保存 {count} 项，未完成 {unfinished} 项 / Stopped; {count} operations saved, {unfinished} unfinished.")).map_err(|error| protocol_error_at("close_run: fold terminal summary", error))?;
    }
    tx.record_interrupt_close(space, run, status).await?;
    jiabu_chat::persist(tx, space, &batch)
        .await
        .map_err(|error| protocol_error_at("close_run: persist terminal batch", error))?;
    tx.finish_run(space, run.id, status, Some(reason)).await?;
    Ok(batch)
}
fn validate_answer(block: &Value, request: &Value) -> Result<(), OperationError> {
    jiabu_chat::validate_action_request(request).map_err(protocol_error)?;
    let data = &block["data"];
    let payload = &request["payload"];
    if !payload.is_object()
        || request["target"] != data["action"]["target"]
        || request["type"] != data["action"]["type"]
    {
        return Err(OperationError::invalid());
    }
    if let Some(text) = payload.get("freeText") {
        if !text.is_string()
            || text
                .as_str()
                .is_none_or(|s| s.trim().is_empty() || s.chars().count() > 500)
        {
            return Err(OperationError::invalid());
        }
        return Ok(());
    }
    match block["type"].as_str() {
        Some("choice") => {
            let selected = payload["selected"]
                .as_array()
                .filter(|a| !a.is_empty())
                .ok_or_else(OperationError::invalid)?;
            let options = data["options"]
                .as_array()
                .ok_or_else(OperationError::invalid)?;
            if selected
                .iter()
                .any(|s| !s.is_string() || !options.iter().any(|o| o["id"] == *s))
            {
                return Err(OperationError::invalid());
            }
        }
        Some("confirmation") => {
            if !matches!(payload["outcome"].as_str(), Some("confirm" | "cancel")) {
                return Err(OperationError::invalid());
            }
        }
        Some("form_intent") => {
            let values = payload["values"]
                .as_object()
                .ok_or_else(OperationError::invalid)?;
            let fields = data["fields"]
                .as_array()
                .ok_or_else(OperationError::invalid)?;
            if values
                .keys()
                .any(|k| !fields.iter().any(|f| f["key"] == k.as_str()))
            {
                return Err(OperationError::invalid());
            }
            for field in fields {
                let key = field["key"].as_str().ok_or_else(OperationError::invalid)?;
                let Some(value) = values.get(key) else {
                    if field["required"] == true {
                        return Err(OperationError::invalid());
                    }
                    continue;
                };
                if !match field["type"].as_str() {
                    Some("number") => value.is_number(),
                    Some("boolean") => value.is_boolean(),
                    Some("date") => value
                        .as_str()
                        .is_some_and(|s| chrono::NaiveDate::parse_from_str(s, "%Y-%m-%d").is_ok()),
                    _ => value.is_string(),
                } {
                    return Err(OperationError::invalid());
                }
            }
        }
        _ => return Err(OperationError::invalid()),
    }
    Ok(())
}
