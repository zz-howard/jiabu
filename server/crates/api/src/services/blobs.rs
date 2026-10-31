use crate::{ApiError, AppState, Principal};
use axum::http::StatusCode;
use jiabu_db::{Mode, SpaceTx};
use jiabu_domain::{JoinEpoch, SpaceId};
use jiabu_storage::{BlobHash, PreparedFile, PreparedJpeg, StorageError};
use jiabu_tools::{Action, Module, authorize};

pub fn storage_error(error: StorageError) -> ApiError {
    match error {
        StorageError::NotJpeg | StorageError::NotPdf => {
            ApiError::new(StatusCode::UNSUPPORTED_MEDIA_TYPE, "unsupported_media_type")
        }
        StorageError::TooLarge => ApiError::new(StatusCode::PAYLOAD_TOO_LARGE, "payload_too_large"),
        StorageError::Invalid => ApiError::invalid(),
        StorageError::NotFound => ApiError::not_found(),
        StorageError::Internal => ApiError::internal(),
    }
}
pub async fn file_upload_preflight(
    state: &AppState,
    principal: &Principal,
    space: SpaceId,
    epoch: JoinEpoch,
) -> Result<(), ApiError> {
    upload_preflight(state, principal, space, epoch, "chat_file").await
}
pub fn authorize_upload(tx: &SpaceTx, space: SpaceId, module: &str) -> Result<(), ApiError> {
    let member = tx.member(space);
    match module {
        "ledger" => {
            authorize(member, Module::Ledger, Action::Write).map_err(|_| ApiError::not_found())
        }
        "documents" => {
            authorize(member, Module::Documents, Action::Write).map_err(|_| ApiError::not_found())
        }
        "chat" | "chat_file" => Ok(()),
        _ => Err(ApiError::bad_request()),
    }
}
pub async fn finish_file_upload(
    state: &AppState,
    principal: &Principal,
    space: SpaceId,
    epoch: JoinEpoch,
    file: &PreparedFile,
) -> Result<(), ApiError> {
    let tx = SpaceTx::begin(
        &state.db,
        principal.user_id,
        &[(space, Some(epoch))],
        Mode::Write,
    )
    .await?;
    principal.require_read_write()?;
    authorize_upload(&tx, space, "chat_file")?;
    tx.lock_blobs().await?;
    let bytes = i64::try_from(file.bytes.len()).map_err(|_| ApiError::invalid())?;
    tx.save_file(space, &file.hash.bytes(), bytes, state.clock.now())
        .await?;
    state
        .blobs
        .put_file_if_absent(file)
        .await
        .map_err(storage_error)?;
    tx.add_blob_ref(space, "chat_file", &file.hash.bytes(), state.clock.now())
        .await?;
    tx.commit().await?;
    Ok(())
}
pub async fn authorize_file_download(
    state: &AppState,
    principal: &Principal,
    space: SpaceId,
    hash: BlobHash,
) -> Result<(), ApiError> {
    let tx = SpaceTx::begin(&state.db, principal.user_id, &[(space, None)], Mode::Read).await?;
    if tx.chat_file_metadata(space, &hash.bytes()).await?.is_none() {
        return Err(ApiError::not_found());
    }
    tx.commit().await?;
    Ok(())
}
pub async fn upload_preflight(
    state: &AppState,
    principal: &Principal,
    space: SpaceId,
    epoch: JoinEpoch,
    module: &str,
) -> Result<(), ApiError> {
    let tx = SpaceTx::begin(
        &state.db,
        principal.user_id,
        &[(space, Some(epoch))],
        Mode::Read,
    )
    .await?;
    principal.require_read_write()?;
    authorize_upload(&tx, space, module)?;
    tx.commit().await?;
    Ok(())
}
pub async fn finish_upload(
    state: &AppState,
    principal: &Principal,
    space: SpaceId,
    epoch: JoinEpoch,
    module: &str,
    image: &PreparedJpeg,
) -> Result<(), ApiError> {
    let tx = SpaceTx::begin(
        &state.db,
        principal.user_id,
        &[(space, Some(epoch))],
        Mode::Write,
    )
    .await?;
    // Recheck after reading and CPU work: exit/rejoin or grant changes during that
    // work must win, even if these exact objects already exist globally.
    principal.require_read_write()?;
    authorize_upload(&tx, space, module)?;
    // Fixed order: space write lock -> blob lifecycle lock. Decode/resize/hash
    // have already completed outside this short final storage critical section.
    tx.lock_blobs().await?;
    let bytes = i64::try_from(image.original.len()).map_err(|_| ApiError::invalid())?;
    let dimensions = (
        i32::try_from(image.width).map_err(|_| ApiError::invalid())?,
        i32::try_from(image.height).map_err(|_| ApiError::invalid())?,
    );
    tx.save_blob(
        space,
        &image.hash.bytes(),
        bytes,
        dimensions,
        state.clock.now(),
    )
    .await?;
    state
        .blobs
        .put_if_absent(image)
        .await
        .map_err(storage_error)?;
    tx.add_blob_ref(space, module, &image.hash.bytes(), state.clock.now())
        .await?;
    tx.commit().await?;
    Ok(())
}
pub async fn authorize_download(
    state: &AppState,
    principal: &Principal,
    space: SpaceId,
    hash: BlobHash,
) -> Result<(), ApiError> {
    let tx = SpaceTx::begin(&state.db, principal.user_id, &[(space, None)], Mode::Read).await?;
    let modules = tx.blob_ref_modules(space, &hash.bytes()).await?;
    let member = tx.member(space);
    let readable = modules.iter().any(|module| match module.as_str() {
        "ledger" => authorize(member, Module::Ledger, Action::Read).is_ok(),
        "documents" => authorize(member, Module::Documents, Action::Read).is_ok(),
        "chat" => true,
        _ => false,
    });
    if !readable {
        return Err(ApiError::not_found());
    }
    tx.commit().await?;
    Ok(())
}
