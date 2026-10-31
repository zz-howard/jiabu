use crate::{
    AgentTool, Effect, Exposure, ToolCtx, ToolError, TypedTool, ValidatedCall, authorize,
    tool::TypedAdapter,
};
use jiabu_db::{Idempotency, Mode, OperationReply, SpaceTx, Via};
use serde_json::{Value, json};
use sha2::{Digest, Sha256};

/// Only ToolRegistry can construct prepared calls. Prepare before taking a write lock.
pub struct PreparedToolCall {
    name: String,
    args_raw: Value,
    call: Box<dyn ValidatedCall>,
}

pub struct ToolRegistry {
    tools: Vec<Box<dyn AgentTool>>,
    pub api_keys: std::sync::Arc<crate::api_key::ApiKeyLimiter>,
}
impl ToolRegistry {
    pub fn ledger() -> Result<Self, ToolError> {
        let mut registry = Self {
            tools: Vec::new(),
            api_keys: std::sync::Arc::new(crate::api_key::ApiKeyLimiter::default()),
        };
        crate::ledger::register(&mut registry)?;
        registry.register(crate::ask_user::AskUser)?;
        crate::display::register(&mut registry)?;
        Ok(registry)
    }
    pub fn with_templates(
        templates: std::sync::Arc<crate::templates::TemplateStore>,
    ) -> Result<Self, ToolError> {
        let mut registry = Self::ledger()?;
        crate::documents::register(&mut registry, templates)?;
        Ok(registry)
    }
    pub fn register<T: TypedTool>(&mut self, tool: T) -> Result<(), ToolError> {
        if !tool
            .name()
            .bytes()
            .all(|b| b.is_ascii_lowercase() || b == b'_' || b.is_ascii_digit())
            || tool.name().is_empty()
            || self.tools.iter().any(|t| t.name() == tool.name())
        {
            return Err(ToolError::internal());
        }
        self.tools.push(Box::new(TypedAdapter::new(tool)?));
        Ok(())
    }
    pub fn tools(&self) -> impl Iterator<Item = &dyn AgentTool> {
        self.tools.iter().map(Box::as_ref)
    }
    pub fn get(&self, name: &str) -> Result<&dyn AgentTool, ToolError> {
        self.tools()
            .find(|t| t.name() == name)
            .ok_or_else(ToolError::not_found)
    }
    pub fn agent_tools(&self) -> impl Iterator<Item = &dyn AgentTool> {
        self.tools().filter(|t| t.exposure() != Exposure::ApiOnly)
    }
    pub async fn invoke(
        &self,
        name: &str,
        args_raw: Value,
        ctx: &ToolCtx,
    ) -> Result<Value, ToolError> {
        let result = self.invoke_inner(name, args_raw, ctx).await;
        let operation = if self.get(name).is_ok() {
            name
        } else {
            "unknown"
        };
        if let Err(error) = &result
            && error.status != 429
            && let Some(audit) = ctx.key_audit(operation, error.code)
        {
            ctx.db.append_api_key_audit(&audit).await?;
            ctx.audit_done();
        }
        result
    }
    async fn invoke_inner(
        &self,
        name: &str,
        args_raw: Value,
        ctx: &ToolCtx,
    ) -> Result<Value, ToolError> {
        // Transfer ownership first so every return path rolls back/releases the
        // already-open transaction, including invalid arguments and placeholders.
        let tx = ctx.tx.lock().await.take().ok_or_else(ToolError::internal)?;
        let prepared = self.prepare(name, args_raw, false)?;
        let tool = self.get(name)?;
        if ctx.space_id != ctx.bound_space || tool.effect() != ctx.bound_effect {
            return Err(ToolError::new(400, "bad_request"));
        }
        let tx = if tool.effect() == Effect::LocalWrite {
            // No parameter validation occurs under the space write lock. Do not
            // reuse the preflight membership/grants for authorization or replay.
            tx.rollback().await?;
            SpaceTx::begin(
                &ctx.db,
                ctx.principal.user_id,
                &[(ctx.bound_space, ctx.epoch)],
                Mode::Write,
            )
            .await?
        } else {
            tx
        };
        let mut tx = tx;
        let result = self.execute_in_tx(prepared, ctx, &mut tx).await?;
        tx.commit().await?;
        ctx.audit_done();
        Ok(result)
    }
    fn prepare(
        &self,
        name: &str,
        args_raw: Value,
        agent: bool,
    ) -> Result<PreparedToolCall, ToolError> {
        let tool = self.get(name)?;
        if (agent && tool.exposure() == Exposure::ApiOnly)
            || (!agent && tool.exposure() == Exposure::AgentOnly)
        {
            return Err(ToolError::not_found());
        }
        // ask_user is a typed interrupt intent, never an executable business tool.
        if tool.exposure() == Exposure::AgentOnly && !crate::is_display_tool(name) {
            tool.validate(args_raw)?;
            return Err(ToolError::new(409, "agent_interrupt_required"));
        }
        let call = tool.validate(args_raw.clone())?;
        Ok(PreparedToolCall {
            name: name.to_owned(),
            args_raw,
            call,
        })
    }
    pub fn prepare_agent(
        &self,
        name: &str,
        args_raw: Value,
    ) -> Result<PreparedToolCall, ToolError> {
        self.prepare(name, args_raw, true)
    }
    /// Never commits, reopens, or broadcasts. The Agent must check its lease epoch
    /// in this transaction before entry, then append tool_result before committing.
    pub async fn invoke_in_tx(
        &self,
        prepared: PreparedToolCall,
        ctx: &ToolCtx,
        tx: &mut SpaceTx,
    ) -> Result<Value, ToolError> {
        ctx.principal.require_ai_session()?;
        let lease = ctx.run_lease.ok_or_else(ToolError::not_found)?;
        if ctx.run_id != Some(lease.run_id) {
            return Err(ToolError::not_found());
        }
        tx.guard_run(ctx.space_id, lease).await?;
        let tool = self.get(&prepared.name)?;
        if tool.exposure() != Exposure::AgentAndApi || ctx.run_id.is_none() {
            return Err(ToolError::not_found());
        }
        self.execute_in_tx(prepared, ctx, tx).await
    }
    /// Read-only Agent fan-out shares the guarded transaction. This path uses
    /// the same prepared typed calls and authorization as invoke_in_tx; it has
    /// no idempotency/audit writes and therefore needs no SAVEPOINT.
    pub async fn invoke_read_in_tx(
        &self,
        prepared: PreparedToolCall,
        ctx: &ToolCtx,
        tx: &SpaceTx,
    ) -> Result<Value, ToolError> {
        ctx.principal.require_ai_session()?;
        if matches!(
            ctx.principal.via,
            Via::Session {
                kind: jiabu_db::auth::SessionKind::PasswordChange,
                ..
            }
        ) {
            return Err(ToolError::new(403, "password_change_required"));
        }
        let lease = ctx.run_lease.ok_or_else(ToolError::not_found)?;
        tx.guard_run(ctx.space_id, lease).await?;
        let tool = self.get(&prepared.name)?;
        if tool.effect() != Effect::Read
            || (tool.exposure() != Exposure::AgentAndApi && !crate::is_display_tool(tool.name()))
            || ctx.bound_effect != Effect::Read
            || ctx.run_id != Some(lease.run_id)
        {
            return Err(ToolError::not_found());
        }
        let member = tx.tool_member(ctx.bound_space, ctx.principal.user_id, ctx.epoch, false)?;
        if ctx.space_id != ctx.bound_space || member.id() != ctx.member.id() {
            return Err(ToolError::not_found());
        }
        authorize(member, tool.module(), tool.action()).map_err(|_| ToolError::not_found())?;
        prepared.call.execute(ctx, tx).await
    }
    async fn execute_in_tx(
        &self,
        prepared: PreparedToolCall,
        ctx: &ToolCtx,
        tx: &mut SpaceTx,
    ) -> Result<Value, ToolError> {
        let PreparedToolCall {
            name,
            args_raw,
            call,
        } = prepared;
        let tool = self.get(&name)?;
        if ctx.space_id != ctx.bound_space || tool.effect() != ctx.bound_effect {
            return Err(ToolError::new(400, "bad_request"));
        }
        let member = tx.tool_member(
            ctx.bound_space,
            ctx.principal.user_id,
            ctx.epoch,
            tool.effect() == Effect::LocalWrite,
        )?;
        if member.user_id() != ctx.principal.user_id
            || member.id() != ctx.member.id()
            || member.space_id() != ctx.member.space_id()
        {
            return Err(ToolError::not_found());
        }
        // 3. Membership is already live; scope must precede module authorization.
        if tool.effect() != Effect::Read {
            ctx.principal.require_read_write()?;
        }
        let (key_id, key_name) = match &ctx.principal.via {
            Via::ApiKey { id, name, .. } => (Some(*id), Some(name.as_str())),
            _ => (None, None),
        };
        if ctx.via_api_key_id != key_id || ctx.via_api_key_name.as_deref() != key_name {
            return Err(ToolError::new(400, "bad_request"));
        }
        if matches!(
            ctx.principal.via,
            Via::Session {
                kind: jiabu_db::auth::SessionKind::PasswordChange,
                ..
            }
        ) {
            return Err(ToolError::new(403, "password_change_required"));
        }
        // 4. Authorization always precedes replay. No handler repeats this decision.
        authorize(member, tool.module(), tool.action()).map_err(|_| ToolError::not_found())?;
        // HTTP admission already charged once, before entering any tool transaction.
        // Batch callers must use the shared request budget for each item.
        // 5. Replay, business validation, write + append-only audit, response, commit.
        tx.begin_tool_savepoint().await?;
        let outcome = async {
            let operation = if tool.effect() == Effect::LocalWrite {
                let id = ctx
                    .idempotency_key
                    .ok_or_else(|| ToolError::new(400, "idempotency_key_required"))?;
                let key = ctx
                    .replay_key
                    .clone()
                    .unwrap_or_else(|| format!("tool:{id}"));
                if key.is_empty() || key.len() > 200 {
                    return Err(ToolError::new(400, "bad_request"));
                }
                let path = format!("/v1/spaces/{}/tools/{name}", ctx.space_id);
                let canonical = serde_json::to_vec(&("POST", path, args_raw))
                    .map_err(|_| ToolError::internal())?;
                let operation = Idempotency {
                    key,
                    hash: Sha256::digest(canonical).to_vec(),
                };
                if let Some(reply) = tx.replay(ctx.principal.user_id, &operation).await? {
                    if let Some(audit) = ctx.key_audit(&name, "ok") {
                        tx.append_api_key_audit(&audit).await?;
                    }
                    return Ok(reply.body);
                }
                Some(operation)
            } else {
                None
            };
            let result = call.execute(ctx, tx).await?;
            if let Some(operation) = operation {
                tx.remember(
                    ctx.principal.user_id,
                    &operation,
                    &OperationReply::ok(result.clone()),
                )
                .await?;
            }
            if let Some(audit) = ctx.key_audit(&name, "ok") {
                tx.append_api_key_audit(&audit).await?;
            }
            Ok::<Value, ToolError>(result)
        }
        .await;
        match outcome {
            Ok(result) => {
                tx.release_tool_savepoint().await?;
                Ok(result)
            }
            Err(error) => {
                // A business failure leaves no partial business/audit/idempotency
                // writes; caller may journal that failure in the outer transaction.
                tx.rollback_tool_savepoint().await?;
                Err(error)
            }
        }
    }
    pub async fn available(&self, ctx: &ToolCtx) -> Result<Value, ToolError> {
        let tx = ctx.tx.lock().await.take().ok_or_else(ToolError::internal)?;
        let member = tx.member(ctx.bound_space);
        if ctx.space_id != ctx.bound_space || member.user_id() != ctx.principal.user_id {
            return Err(ToolError::not_found());
        }
        let tools:Vec<Value>=self.tools().filter(|tool|tool.exposure()!=Exposure::AgentOnly && (tool.effect()==Effect::Read || ctx.principal.require_read_write().is_ok()) && authorize(member,tool.module(),tool.action()).is_ok()).map(|tool|json!({"name":tool.name(),"description":tool.description(),"effect":tool.effect(),"parameters":tool.parameters(),"output_schema":tool.output_schema(),"schema_version":tool.schema_version()})).collect();
        tx.commit().await?;
        Ok(json!({"tools":tools}))
    }
}
