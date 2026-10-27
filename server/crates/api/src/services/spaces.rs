use crate::{ApiError, AppState, Principal, middleware};
use axum::http::{HeaderMap, StatusCode};
use jiabu_db::{
    Mode, SpaceTx,
    spaces::{Idempotency, Reply},
};
use jiabu_domain::{JoinEpoch, SpaceId, spaces::Change};
use serde_json::Value;
use sha2::{Digest, Sha256};

pub(crate) fn operation(
    headers: &HeaderMap,
    method: &str,
    path: &str,
    body: Value,
) -> Result<Idempotency, ApiError> {
    let key = headers
        .get("idempotency-key")
        .ok_or_else(|| ApiError::new(StatusCode::BAD_REQUEST, "idempotency_key_required"))?
        .to_str()
        .map_err(|_| ApiError::bad_request())?;
    if key.is_empty() || key.len() > 200 {
        return Err(ApiError::bad_request());
    }
    // serde_json's map is sorted (preserve_order is not enabled). Parsing the typed
    // body first gives stable field order and ignores irrelevant JSON whitespace.
    let canonical = serde_json::to_vec(&(method, path, body)).map_err(|_| ApiError::internal())?;
    Ok(Idempotency {
        key: key.to_owned(),
        hash: Sha256::digest(canonical).to_vec(),
    })
}
pub(crate) fn epoch(headers: &HeaderMap) -> Result<JoinEpoch, ApiError> {
    headers
        .get("x-jiabu-join-epoch")
        .and_then(|v| v.to_str().ok())
        .and_then(|s| s.parse::<i32>().ok())
        .filter(|n| *n > 0)
        .map(JoinEpoch)
        .ok_or_else(ApiError::bad_request)
}
pub(crate) async fn change(
    state: &AppState,
    principal: &Principal,
    space: SpaceId,
    epoch: JoinEpoch,
    change: Change,
    operation: Idempotency,
) -> Result<Reply, ApiError> {
    let tx = SpaceTx::begin(
        &state.db,
        principal.user_id,
        &[(space, Some(epoch))],
        Mode::Write,
    )
    .await?;
    tx.authorize_change(space, &change).await?;
    if let Some(reply) = tx.replay(principal.user_id, &operation).await? {
        tx.commit().await?;
        return Ok(reply);
    }
    let deleting = matches!(change, Change::Delete { .. });
    let reply = tx
        .apply_change(space, change, middleware::request_id())
        .await?;
    tx.remember(principal.user_id, &operation, &reply).await?;
    tx.commit().await?;
    if deleting {
        state.purge_signal().notify_one();
    }
    Ok(reply)
}
