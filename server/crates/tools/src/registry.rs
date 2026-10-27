use crate::{
    AgentTool, Effect, Exposure, ToolCtx, ToolError, TypedTool, authorize, tool::TypedAdapter,
};
use jiabu_db::{Idempotency, Mode, OperationReply, SpaceTx, Via};
use serde_json::{Value, json};
use sha2::{Digest, Sha256};

pub struct ToolRegistry {
    tools: Vec<Box<dyn AgentTool>>,
}
impl ToolRegistry {
    pub fn ledger() -> Result<Self, ToolError> {
        let mut registry = Self { tools: Vec::new() };
        crate::ledger::register(&mut registry)?;
        registry.register(crate::ask_user::AskUser)?;
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
        // Transfer ownership first so every return path rolls back/releases the
        // already-open transaction, including invalid arguments and placeholders.
        let tx = ctx.tx.lock().await.take().ok_or_else(ToolError::internal)?;
        let tool = self.get(name)?;
        // This declaration proves exposure filtering. S7 will intercept ask_user.
        if tool.exposure() == Exposure::AgentOnly {
            return Err(ToolError::new(503, "unavailable"));
        }
        // 1. Schema + typed deserialization + validator, once for both entrances.
        let call = tool.validate(args_raw.clone())?;
        // 2. Space binding and the live member originate only from SpaceTx::begin.
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
        let member = tx.member(ctx.space_id);
        if member.user_id() != ctx.principal.user_id
            || member.id() != ctx.member.id()
            || member.space_id() != ctx.member.space_id()
        {
            return Err(ToolError::not_found());
        }
        // 3. S5 implements key scope/read-only checks and authentication. Fail closed in S3.
        if matches!(ctx.principal.via, Via::ApiKey { .. })
            || ctx.via_api_key_id.is_some()
            || ctx.via_api_key_name.is_some()
        {
            return Err(ToolError::new(403, "api_key_not_allowed"));
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
        // 5. Replay, business validation, write + append-only audit, response, commit.
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
            let canonical =
                serde_json::to_vec(&("POST", path, args_raw)).map_err(|_| ToolError::internal())?;
            let operation = Idempotency {
                key,
                hash: Sha256::digest(canonical).to_vec(),
            };
            if let Some(reply) = tx.replay(ctx.principal.user_id, &operation).await? {
                tx.commit().await?;
                return Ok(reply.body);
            }
            Some(operation)
        } else {
            None
        };
        let result = call.execute(ctx, &tx).await?;
        if let Some(operation) = operation {
            tx.remember(
                ctx.principal.user_id,
                &operation,
                &OperationReply::ok(result.clone()),
            )
            .await?;
        }
        tx.commit().await?;
        Ok(result)
    }
    pub async fn available(&self, ctx: &ToolCtx) -> Result<Value, ToolError> {
        if matches!(ctx.principal.via, Via::ApiKey { .. }) {
            return Err(ToolError::new(403, "api_key_not_allowed"));
        }
        let tx = ctx.tx.lock().await.take().ok_or_else(ToolError::internal)?;
        let member = tx.member(ctx.bound_space);
        if ctx.space_id != ctx.bound_space || member.user_id() != ctx.principal.user_id {
            return Err(ToolError::not_found());
        }
        let tools:Vec<Value>=self.tools().filter(|tool|tool.exposure()!=Exposure::AgentOnly && authorize(member,tool.module(),tool.action()).is_ok()).map(|tool|json!({"name":tool.name(),"description":tool.description(),"effect":tool.effect(),"parameters":tool.parameters(),"output_schema":tool.output_schema(),"schema_version":tool.schema_version()})).collect();
        tx.commit().await?;
        Ok(json!({"tools":tools}))
    }
}
