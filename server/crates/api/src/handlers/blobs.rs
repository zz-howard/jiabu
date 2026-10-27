use crate::{ApiError, AppState, Principal, services::blobs};
use axum::{
    body::{Body, to_bytes},
    extract::{
        Path, Query, Request, State,
        rejection::{PathRejection, QueryRejection},
    },
    http::{StatusCode, header},
    response::{IntoResponse, Response},
};
use jiabu_domain::{JoinEpoch, SpaceId};
use jiabu_storage::{BlobHash, Variant, prepare_jpeg};
use serde::Deserialize;
use uuid::Uuid;
#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
pub(crate) struct UploadQuery {
    module: String,
}
#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
pub(crate) struct DownloadQuery {
    #[serde(default = "display")]
    variant: String,
}
fn display() -> String {
    "display".into()
}

#[utoipa::path(put,path="/v1/spaces/{space_id}/blobs/{sha256}",security(("bearer"=[])),params(("space_id"=Uuid,Path),("sha256"=String,Path),("module"=String,Query,description="ledger | documents | chat"),("X-Jiabu-Join-Epoch"=i32,Header)),request_body(content=String,content_type="image/jpeg",description="Complete JPEG bytes, including on repeated uploads"),responses((status=204,description="Stored; empty response for both new and existing content"),(status=400,body=crate::Problem),(status=401,body=crate::Problem),(status=403,body=crate::Problem),(status=429,body=crate::Problem,headers(("Retry-After"=u64,description="Seconds until retry"))),(status=500,body=crate::Problem),(status=503,body=crate::Problem,headers(("Retry-After"=u64,description="Upload slots busy; retry in seconds"))),(status=404,body=crate::Problem,example=json!({"type":"urn:jiabu:error:not_found","title":"not_found","status":404,"code":"not_found","request_id":"00000000-0000-7000-8000-000000000001"})),(status=409,body=crate::Problem),(status=413,body=crate::Problem),(status=415,body=crate::Problem),(status=422,body=crate::Problem)))]
pub(crate) async fn upload(
    State(state): State<AppState>,
    principal: Principal,
    path: Result<Path<(Uuid, String)>, PathRejection>,
    request: Request,
) -> Result<StatusCode, ApiError> {
    let Path((space, sha)) = path.map_err(|_| ApiError::bad_request())?;
    let epoch = request
        .headers()
        .get("x-jiabu-join-epoch")
        .and_then(|v| v.to_str().ok())
        .and_then(|v| v.parse::<i32>().ok())
        .filter(|v| *v > 0)
        .map(JoinEpoch)
        .ok_or_else(ApiError::bad_request)?;
    let Query(query) =
        Query::<UploadQuery>::try_from_uri(request.uri()).map_err(|_| ApiError::bad_request())?;
    let space = SpaceId(space);
    blobs::upload_preflight(&state, &principal, space, epoch, &query.module).await?;
    let hash = BlobHash::parse(&sha).map_err(blobs::storage_error)?;
    // Membership/epoch, key scope and module authorization above always precede
    // resource admission, so unavailable spaces keep their identical 404s even
    // at capacity. The slot bounds reading, buffering, CPU queues and persistence.
    let upload_slot =
        state
            .upload_slots
            .clone()
            .try_acquire_owned()
            .map_err(|error| match error {
                tokio::sync::TryAcquireError::NoPermits => {
                    let mut error = ApiError::new(StatusCode::SERVICE_UNAVAILABLE, "upload_busy");
                    error.retry_after = Some(1);
                    error
                }
                tokio::sync::TryAcquireError::Closed => ApiError::internal(),
            })?;
    let bytes = to_bytes(request.into_body(), state.image_limits.max_upload_bytes)
        .await
        .map_err(|_| ApiError::new(StatusCode::PAYLOAD_TOO_LARGE, "payload_too_large"))?;
    // Slow networks do not occupy CPU permits. Acquire only after the complete,
    // size-bounded body is buffered; cancellation cannot release running CPU work.
    let permit = state
        .image_work
        .clone()
        .acquire_owned()
        .await
        .map_err(|_| ApiError::internal())?;
    let limits = state.image_limits.clone();
    let (image, _permit, _upload_slot) = tokio::task::spawn_blocking(move || {
        (prepare_jpeg(bytes, hash, &limits), permit, upload_slot)
    })
    .await
    .map_err(|_| ApiError::internal())?;
    let image = image.map_err(blobs::storage_error)?;
    #[cfg(test)]
    if let Some((entered, release)) = &state.upload_gate {
        entered.notify_one();
        release.notified().await;
    }
    blobs::finish_upload(&state, &principal, space, epoch, &query.module, &image).await?;
    Ok(StatusCode::NO_CONTENT)
}
#[utoipa::path(get,path="/v1/spaces/{space_id}/blobs/{sha256}",security(("bearer"=[])),params(("space_id"=Uuid,Path),("sha256"=String,Path),("variant"=Option<String>,Query,description="thumb | display | original; defaults to display")),responses((status=200,content_type="image/jpeg",body=String,description="Streaming JPEG bytes"),(status=400,body=crate::Problem),(status=401,body=crate::Problem),(status=403,body=crate::Problem),(status=429,body=crate::Problem,headers(("Retry-After"=u64,description="Seconds until retry"))),(status=500,body=crate::Problem),(status=503,body=crate::Problem),(status=404,body=crate::Problem,example=json!({"type":"urn:jiabu:error:not_found","title":"not_found","status":404,"code":"not_found","request_id":"00000000-0000-7000-8000-000000000001"}))))]
pub(crate) async fn get(
    State(state): State<AppState>,
    principal: Principal,
    path: Result<Path<(Uuid, String)>, PathRejection>,
    query: Result<Query<DownloadQuery>, QueryRejection>,
) -> Result<Response, ApiError> {
    let Path((space, sha)) = path.map_err(|_| ApiError::bad_request())?;
    let hash = BlobHash::parse(&sha).map_err(|_| ApiError::not_found())?;
    blobs::authorize_download(&state, &principal, SpaceId(space), hash).await?;
    let Query(query) = query.map_err(|_| ApiError::bad_request())?;
    let variant = match query.variant.as_str() {
        "original" => Variant::Original,
        "display" => Variant::Display,
        "thumb" => Variant::Thumb,
        _ => return Err(ApiError::bad_request()),
    };
    let object = state
        .blobs
        .get_stream(hash, variant)
        .await
        .map_err(blobs::storage_error)?;
    Ok((
        [
            (header::CONTENT_TYPE, "image/jpeg".to_owned()),
            (header::CONTENT_LENGTH, object.bytes.to_string()),
        ],
        Body::from_stream(object.stream),
    )
        .into_response())
}
