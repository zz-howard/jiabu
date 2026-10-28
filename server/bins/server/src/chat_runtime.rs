//! Process lifecycle and original image IO; no HTTP routing lives here.
use base64::Engine;
use futures_util::StreamExt;
use jiabu_agent::{ImageLoader, Runtime, RuntimeMeter};
use jiabu_db::OperationError;
use jiabu_storage::{BlobHash, BlobStore, Variant};
use std::sync::Arc;
struct Originals(Arc<BlobStore>);
#[async_trait::async_trait]
impl ImageLoader for Originals {
    async fn original(&self, sha: &str) -> Result<String, OperationError> {
        let hash = BlobHash::parse(sha).map_err(|_| OperationError::invalid())?;
        let mut blob = self
            .0
            .get_stream(hash, Variant::Original)
            .await
            .map_err(|_| OperationError::not_found())?;
        let mut bytes = Vec::new();
        while let Some(chunk) = blob.stream.next().await {
            bytes.extend_from_slice(&chunk.map_err(|_| OperationError::internal())?);
        }
        Ok(format!(
            "data:image/jpeg;base64,{}",
            base64::engine::general_purpose::STANDARD.encode(bytes)
        ))
    }
}
pub fn runtime(state: &jiabu_api::AppState, hub: Arc<jiabu_chat::StreamHub>) -> Arc<Runtime> {
    let mut runtime = Runtime::new(
        state.db.clone(),
        state.ai.clone(),
        state.tools.clone(),
        state.templates.clone(),
        hub,
        Arc::new(RuntimeMeter {
            db: state.db.clone(),
            token: uuid::Uuid::now_v7(),
        }),
    );
    runtime.images = Some(Arc::new(Originals(state.blobs.clone())));
    Arc::new(runtime)
}
pub async fn shutdown_signal() {
    #[cfg(unix)]
    {
        if let Ok(mut term) =
            tokio::signal::unix::signal(tokio::signal::unix::SignalKind::terminate())
        {
            tokio::select! {_=tokio::signal::ctrl_c()=>{},_=term.recv()=>{}}
        } else {
            let _ = tokio::signal::ctrl_c().await;
        }
    }
    #[cfg(not(unix))]
    {
        let _ = tokio::signal::ctrl_c().await;
    }
}
