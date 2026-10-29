//! Validate every delivered ToolCall before forwarding to the runtime. Invalid
//! calls may be rejected before journal commit; keep counts, never raw content.
use async_trait::async_trait;
use jiabu_ai::*;
use std::{sync::{Arc, atomic::{AtomicUsize,Ordering}},time::Duration};
#[derive(Default)]
pub struct ToolAudit { pub total: AtomicUsize, pub valid: AtomicUsize }
pub struct AuditedProvider {
    pub inner: Arc<dyn ModelProvider>,
    pub registry: Arc<jiabu_tools::ToolRegistry>,
    pub audit: Arc<ToolAudit>,
}
struct Sink<'a> { inner: &'a mut dyn TurnSink, registry: &'a jiabu_tools::ToolRegistry, audit: &'a ToolAudit }
#[async_trait]
impl TurnSink for Sink<'_> {
    fn record_usage(&mut self,usage:&Usage) {self.inner.record_usage(usage);}
    async fn emit(&mut self,event:TurnEvent)->Result<(),ProviderError> {
        if let TurnEvent::ToolCall{name,args_raw,..}=&event {
            self.audit.total.fetch_add(1,Ordering::Relaxed);
            let valid=(|| {
                let tool=self.registry.get(name).ok()?;
                if tool.exposure()==jiabu_tools::Exposure::ApiOnly {return None;}
                let args:serde_json::Value=serde_json::from_str(args_raw).ok()?;
                tool.validate(args.clone()).ok()?;
                if name=="ask_user" {serde_json::from_value::<jiabu_tools::AskArgs>(args).ok()?.check().ok()?;}
                Some(())
            })().is_some();
            if valid {self.audit.valid.fetch_add(1,Ordering::Relaxed);}
        }
        self.inner.emit(event).await
    }
}
#[async_trait]
impl ModelProvider for AuditedProvider {
    fn id(&self)->&str {self.inner.id()}
    fn capabilities(&self)->&Capabilities {self.inner.capabilities()}
    fn credentials_available(&self)->bool {self.inner.credentials_available()}
    async fn run_turn(&self,req:&TurnRequest,sink:&mut dyn TurnSink)->Result<(),ProviderError> {
        self.inner.run_turn(req,&mut Sink{inner:sink,registry:&self.registry,audit:&self.audit}).await
    }
    async fn run_turn_observed(&self,task:TaskKind,req:&TurnRequest,sink:&mut dyn TurnSink,observer:&dyn CallObserver,budget:Duration)->Result<(),ProviderError> {
        // Delegate the observed method so SIWC refresh retries retain independent metering.
        self.inner.run_turn_observed(task,req,&mut Sink{inner:sink,registry:&self.registry,audit:&self.audit},observer,budget).await
    }
}
