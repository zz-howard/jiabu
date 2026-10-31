use crate::*;
use chrono::Utc;
use jiabu_chat::{RunEmitter, StagedStream};
use jiabu_db::chat_runtime::{RunLease, RunRow, ToolCallRow};
use jiabu_db::{AppDb, Mode, OperationError, Principal, SpaceTx};
use jiabu_domain::{JoinEpoch, SpaceId};
use jiabu_tools::{Effect, Invocation, ToolCtx};
use serde_json::json;
use std::sync::Arc;
pub struct ToolExecutor<'a> {
    pub db: &'a AppDb,
    pub registry: Arc<jiabu_tools::ToolRegistry>,
}
impl ToolExecutor<'_> {
    pub async fn execute(
        &self,
        p: &Principal,
        run: &RunRow,
        lease: RunLease,
        call: &ToolCallRow,
        stage: &mut StagedStream,
        emitter: &RunEmitter,
    ) -> Result<(), OperationError> {
        // Validation happens before acquiring the transaction's space write lock.
        let prepared = self.registry.prepare_agent(&call.tool, call.args.clone())?;
        let tool = self.registry.get(&call.tool)?;
        if tool.schema_version() != call.tool_schema_version as u32 {
            return Err(OperationError::new(409, "tool_schema_changed"));
        }
        let space = SpaceId(run.space_id);
        let mut tx = SpaceTx::begin(
            self.db,
            p.user_id,
            &[(space, Some(JoinEpoch(run.join_epoch)))],
            Mode::Write,
        )
        .await?;
        tx.guard_run(space, lease).await?;
        service::validate_environment(tx.member(space), &tx.journal(space, run.id).await?)?;
        let stored = tx.calls(space, run.id).await?;
        if !stored
            .iter()
            .any(|c| c == call && matches!(c.status.as_str(), "proposed" | "approved"))
        {
            return Err(OperationError::new(409, "tool_call_changed"));
        }
        if tx
            .journal(space, run.id)
            .await?
            .iter()
            .any(|i| i.kind == "tool_result" && i.call_id.as_deref() == Some(call.call_id.as_str()))
        {
            tx.commit().await?;
            return Ok(());
        }
        let context = ToolCtx::for_transaction(
            self.db,
            p.clone(),
            &tx,
            space,
            JoinEpoch(run.join_epoch),
            tool.effect(),
            Invocation {
                idempotency_key: Some(call.idempotency_key),
                replay_key: Some(format!("agent:{}", call.idempotency_key)),
                run_id: Some(run.id),
                request_id: run.id,
                now: Utc::now(),
            },
        )?
        .bind_run_lease(lease)?;
        tx.set_call_status(space, lease, &call.call_id, "executing")
            .await?;
        let step = stage
            .stream
            .start_step(
                tool.step_label(
                    self.registry
                        .get(&call.tool)?
                        .validate(call.args.clone())?
                        .as_ref(),
                    &context,
                )
                .0,
            )
            .await
            .map_err(service::protocol_error)?;
        let result = tokio::time::timeout(
            std::time::Duration::from_secs(TOOL_TIMEOUT_SECS),
            self.registry.invoke_in_tx(prepared, &context, &mut tx),
        )
        .await;
        // Timeout cancels a query/transaction future: abandon the entire outer
        // transaction. No SAVEPOINT recovery is attempted after cancellation.
        let result = match result {
            Ok(Ok(value)) => Ok(value),
            Ok(Err(e)) if e.status < 500 => Err(e),
            _ => return Err(OperationError::new(500, "tool_failed")),
        };
        let (output, status) = match result {
            Ok(value) => {
                let shows_component = tool.effect() == Effect::LocalWrite;
                if shows_component
                    && let Some((kind, data, fallback)) =
                        jiabu_chat::map_tool_result(&call.tool, &call.args, &value)
                            .map_err(service::protocol_error)?
                {
                    stage
                        .component(kind, data, &fallback)
                        .await
                        .map_err(service::protocol_error)?;
                }
                (value, "succeeded")
            }
            Err(error) => (crate::tool_error_output(&error), "failed"),
        };
        tx.append_journal(
            space,
            lease,
            "tool_result",
            Some(&call.call_id),
            json!({"output":output}),
            None,
        )
        .await?;
        tx.set_call_status(space, lease, &call.call_id, status)
            .await?;
        step.finish(status, None)
            .await
            .map_err(service::protocol_error)?;
        let batch = stage.batch().await.map_err(service::protocol_error)?;
        emitter
            .persist(&tx, &batch)
            .await
            .map_err(service::protocol_error)?;
        // The original lease may have expired while a tool held its row lock.
        tx.guard_run(space, lease).await?;
        service::validate_environment(tx.member(space), &tx.journal(space, run.id).await?)?;
        tx.commit().await?;
        jiabu_chat::publish(&emitter.hub, batch)
            .await
            .map_err(service::protocol_error)
    }
}
impl ToolExecutor<'_> {
    pub async fn execute_reads(
        &self,
        p: &Principal,
        run: &RunRow,
        lease: RunLease,
        calls: &[ToolCallRow],
        stage: &mut StagedStream,
        emitter: &RunEmitter,
    ) -> Result<(), OperationError> {
        let mut prepared = Vec::new();
        for call in calls {
            prepared.push(self.registry.prepare_agent(&call.tool, call.args.clone())?);
        }
        let space = SpaceId(run.space_id);
        let tx = SpaceTx::begin(
            self.db,
            p.user_id,
            &[(space, Some(JoinEpoch(run.join_epoch)))],
            Mode::Write,
        )
        .await?;
        tx.guard_run(space, lease).await?;
        let journal = tx.journal(space, run.id).await?;
        service::validate_environment(tx.member(space), &journal)?;
        let stored = tx.calls(space, run.id).await?;
        let mut contexts = Vec::new();
        for call in calls {
            if !stored
                .iter()
                .any(|c| c == call && matches!(c.status.as_str(), "proposed" | "approved"))
            {
                return Err(OperationError::new(409, "tool_call_changed"));
            }
            if self.registry.get(&call.tool)?.schema_version() != call.tool_schema_version as u32 {
                return Err(OperationError::new(409, "tool_schema_changed"));
            }
            contexts.push(
                ToolCtx::for_transaction(
                    self.db,
                    p.clone(),
                    &tx,
                    space,
                    JoinEpoch(run.join_epoch),
                    Effect::Read,
                    Invocation {
                        idempotency_key: Some(call.idempotency_key),
                        replay_key: None,
                        run_id: Some(run.id),
                        request_id: run.id,
                        now: Utc::now(),
                    },
                )?
                .bind_run_lease(lease)?,
            );
        }
        let mut steps = Vec::new();
        for (call, ctx) in calls.iter().zip(&contexts) {
            let label = if jiabu_tools::is_display_tool(&call.tool) {
                let tool = self.registry.get(&call.tool)?;
                tool.step_label(tool.validate(call.args.clone())?.as_ref(), ctx)
                    .0
            } else {
                "查询 / Query"
            };
            steps.push(
                stage
                    .stream
                    .start_step(label)
                    .await
                    .map_err(service::protocol_error)?,
            );
        }
        let futures = prepared
            .into_iter()
            .zip(&contexts)
            .map(|(prepared, ctx)| self.registry.invoke_read_in_tx(prepared, ctx, &tx));
        let results = tokio::time::timeout(
            std::time::Duration::from_secs(TOOL_TIMEOUT_SECS),
            futures_util::future::join_all(futures),
        )
        .await
        .map_err(|_| OperationError::new(500, "tool_timeout"))?;
        // join_all preserves input order; journals and blocks never depend on
        // scheduling or query completion order.
        for ((call, result), step) in calls.iter().zip(results).zip(steps) {
            let (output, status) = match result {
                Ok(v) => (v, "succeeded"),
                Err(e) if e.status < 500 => (crate::tool_error_output(&e), "failed"),
                Err(e) => return Err(e),
            };
            if status == "succeeded"
                && let Some((kind, data, fallback)) =
                    jiabu_chat::map_tool_result(&call.tool, &call.args, &output)
                        .map_err(service::protocol_error)?
                && !stage
                    .component(kind, data, &fallback)
                    .await
                    .map_err(service::protocol_error)?
                && jiabu_tools::is_display_tool(&call.tool)
            {
                // Our bug, not the model's: show the complete text instead, no retry.
                tracing::error!(
                    error_kind = "display_block_invalid",
                    tool = %call.tool,
                    block = kind,
                    "Display block failed protocol validation; sent as text"
                );
                stage
                    .markdown(&fallback)
                    .await
                    .map_err(service::protocol_error)?;
            }
            if jiabu_tools::is_display_tool(&call.tool) {
                display_telemetry(&journal, &stored, call, &output);
            }
            tx.append_journal(
                space,
                lease,
                "tool_result",
                Some(&call.call_id),
                json!({"output":output}),
                None,
            )
            .await?;
            tx.set_call_status(space, lease, &call.call_id, status)
                .await?;
            step.finish(status, None)
                .await
                .map_err(service::protocol_error)?;
        }
        let batch = stage.batch().await.map_err(service::protocol_error)?;
        emitter
            .persist(&tx, &batch)
            .await
            .map_err(service::protocol_error)?;
        tx.guard_run(space, lease).await?;
        tx.commit().await?;
        jiabu_chat::publish(&emitter.hub, batch)
            .await
            .map_err(service::protocol_error)
    }
}

/// One log line per display result. Counting by tool, outcome and rule happens in
/// log aggregation; rule names and pointers only, never argument values.
fn display_telemetry(
    journal: &[jiabu_db::chat_runtime::JournalItem],
    calls: &[ToolCallRow],
    call: &ToolCallRow,
    output: &serde_json::Value,
) {
    let earlier_failures = journal
        .iter()
        .filter(|i| i.kind == "tool_result" && crate::counts_as_failure(&i.payload["output"]))
        .filter(|i| {
            calls
                .iter()
                .any(|c| i.call_id.as_deref() == Some(c.call_id.as_str()) && c.tool == call.tool)
        })
        .count();
    let outcome = match (output["error"].as_str(), output["status"].as_str()) {
        (Some(_), _) => "rejected",
        (None, Some("no_data")) => "no_data",
        _ if earlier_failures > 0 => "shown_after_correction",
        _ => "shown",
    };
    let rules = output["errors"]
        .as_array()
        .into_iter()
        .flatten()
        .filter_map(|e| e["rule"].as_str())
        .collect::<Vec<_>>()
        .join(",");
    tracing::info!(
        display_tool = %call.tool,
        display_outcome = outcome,
        error_code = %output["error"].as_str().unwrap_or(""),
        rules = %rules,
        attempt = earlier_failures + 1,
        "Display tool result"
    );
}
