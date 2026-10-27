use crate::{
    AccountSession, ApiError, AppState, api_key_token, credentials, services::spaces::operation,
};
use axum::{
    Json,
    extract::{Path, State, rejection::JsonRejection},
    http::{HeaderMap, StatusCode},
};
use chrono::{DateTime, Utc};
use jiabu_db::api_keys::{KeyChange, NewKey};
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use uuid::Uuid;

#[derive(Default)]
pub(crate) enum Expiry {
    #[default]
    Default,
    Never,
    At(DateTime<Utc>),
}
fn expiry<'de, D: serde::Deserializer<'de>>(deserializer: D) -> Result<Expiry, D::Error> {
    Ok(Option::<DateTime<Utc>>::deserialize(deserializer)?.map_or(Expiry::Never, Expiry::At))
}
#[derive(Deserialize, Serialize, utoipa::ToSchema)]
#[serde(rename_all = "snake_case")]
pub(crate) enum Scope {
    Read,
    ReadWrite,
}
#[derive(Deserialize, utoipa::ToSchema)]
#[serde(deny_unknown_fields)]
pub(crate) struct CreateKey {
    name: String,
    scope: Scope,
    #[serde(default, deserialize_with = "expiry")]
    #[schema(value_type=Option<DateTime<Utc>>)]
    expires_at: Expiry,
}
#[derive(Deserialize, Serialize, utoipa::ToSchema)]
#[serde(deny_unknown_fields)]
pub(crate) struct RenameKey {
    name: String,
}
#[derive(Serialize, utoipa::ToSchema)]
pub struct KeyView {
    id: Uuid,
    name: String,
    display_prefix: String,
    scope: Scope,
    expires_at: Option<DateTime<Utc>>,
    created_at: DateTime<Utc>,
    last_used_at: Option<DateTime<Utc>>,
    revoked_at: Option<DateTime<Utc>>,
    revoked_by: Option<String>,
    status: String,
}
#[derive(Serialize, utoipa::ToSchema)]
pub struct KeyList {
    api_keys: Vec<KeyView>,
}
#[derive(Serialize, utoipa::ToSchema)]
pub struct CreatedKey {
    id: Uuid,
    key: String,
    created: bool,
    plaintext_available: bool,
}
#[derive(Serialize, utoipa::ToSchema)]
pub struct KeyReplay {
    id: Uuid,
    created: bool,
    plaintext_available: bool,
}
fn name(value: &str) -> Result<String, ApiError> {
    let value = value.trim();
    if !(1..=40).contains(&value.chars().count()) {
        return Err(ApiError::invalid());
    }
    Ok(value.to_owned())
}

#[utoipa::path(get,path="/v1/me/api-keys",security(("bearer"=[])),responses((status=200,body=KeyList,description="Personal keys; never includes token hashes",example=json!({"api_keys":[]})),(status=401,body=crate::Problem,description="Unauthenticated"),(status=403,body=crate::Problem,description="Account session required")))]
pub(crate) async fn list(
    State(state): State<AppState>,
    AccountSession(principal): AccountSession,
) -> Result<Json<Value>, ApiError> {
    Ok(Json(state.db.api_keys(principal.user_id).await?))
}
#[utoipa::path(post,path="/v1/me/api-keys",security(("bearer"=[])),params(("Idempotency-Key"=String,Header)),request_body(content=CreateKey,example=json!({"name":"示例脚本","scope":"read"})),responses((status=201,body=CreatedKey,description="Secret is returned once",example=json!({"id":"019a0000-0000-7000-8000-000000000001","key":"<personal-key-shown-once>","created":true,"plaintext_available":true})),(status=200,body=KeyReplay,description="Already created; plaintext unavailable",example=json!({"id":"019a0000-0000-7000-8000-000000000001","created":true,"plaintext_available":false})),(status=400,body=crate::Problem,description="Invalid request or missing idempotency key"),(status=401,body=crate::Problem,description="Unauthenticated"),(status=403,body=crate::Problem,description="Account session required"),(status=422,body=crate::Problem,description="Invalid input, key limit reached or idempotency key reused")))]
pub(crate) async fn create(
    State(state): State<AppState>,
    AccountSession(principal): AccountSession,
    headers: HeaderMap,
    body: Result<Json<CreateKey>, JsonRejection>,
) -> Result<(StatusCode, Json<Value>), ApiError> {
    let input = super::input(body)?;
    let name = name(&input.name)?;
    let now = Utc::now();
    let (expires_at, expiry_hash) = match input.expires_at {
        Expiry::Default => (
            Some(now + chrono::Duration::days(90)),
            json!("default_90_days"),
        ),
        Expiry::Never => (None, Value::Null),
        Expiry::At(at) => (Some(at), json!(at)),
    };
    // Hash the requested policy, not a freshly computed relative timestamp.
    let operation = operation(
        &headers,
        "POST",
        "/v1/me/api-keys",
        json!({"name":name,"scope":input.scope,"expires_at":expiry_hash}),
    )?;
    let token = api_key_token::generate();
    let reply = state
        .db
        .create_api_key(
            principal.user_id,
            NewKey {
                name,
                scope: match input.scope {
                    Scope::Read => "read",
                    Scope::ReadWrite => "read_write",
                }
                .into(),
                digest: credentials::token_hash(&token),
                display_prefix: api_key_token::display_prefix(&token),
                expires_at,
            },
            &operation,
        )
        .await?;
    let mut body = reply.body;
    if reply.status == 201 {
        body["key"] = json!(token);
        body["created"] = json!(true);
        body["plaintext_available"] = json!(true);
    }
    Ok((
        StatusCode::from_u16(reply.status).map_err(|_| ApiError::internal())?,
        Json(body),
    ))
}
#[utoipa::path(patch,path="/v1/me/api-keys/{id}",security(("bearer"=[])),params(("id"=Uuid,Path),("Idempotency-Key"=String,Header)),request_body(content=RenameKey,example=json!({"name":"改名后的示例脚本"})),responses((status=200,body=KeyView,description="Renamed key",example=json!({"id":"019a0000-0000-7000-8000-000000000001","name":"示例脚本","scope":"read","status":"active"})),(status=400,body=crate::Problem,description="Invalid request or missing idempotency key"),(status=401,body=crate::Problem,description="Unauthenticated"),(status=403,body=crate::Problem,description="Account session required"),(status=404,body=crate::Problem,description="Not found"),(status=422,body=crate::Problem,description="Validation failed or idempotency key reused")))]
pub(crate) async fn rename(
    State(state): State<AppState>,
    AccountSession(principal): AccountSession,
    Path(id): Path<Uuid>,
    headers: HeaderMap,
    body: Result<Json<RenameKey>, JsonRejection>,
) -> Result<Json<Value>, ApiError> {
    let input = super::input(body)?;
    let name = name(&input.name)?;
    let operation = operation(
        &headers,
        "PATCH",
        &format!("/v1/me/api-keys/{id}"),
        json!({"name":name}),
    )?;
    Ok(Json(
        state
            .db
            .change_api_key(principal.user_id, id, KeyChange::Rename(name), &operation)
            .await?
            .body,
    ))
}
#[utoipa::path(post,path="/v1/me/api-keys/{id}/revoke",security(("bearer"=[])),params(("id"=Uuid,Path),("Idempotency-Key"=String,Header)),responses((status=200,body=KeyView,description="Revoked key; row retained",example=json!({"id":"019a0000-0000-7000-8000-000000000001","status":"revoked","revoked_by":"user"})),(status=400,body=crate::Problem,description="Missing idempotency key"),(status=401,body=crate::Problem,description="Unauthenticated"),(status=403,body=crate::Problem,description="Account session required"),(status=404,body=crate::Problem,description="Not found"),(status=422,body=crate::Problem,description="Idempotency key reused")))]
pub(crate) async fn revoke(
    State(state): State<AppState>,
    AccountSession(principal): AccountSession,
    Path(id): Path<Uuid>,
    headers: HeaderMap,
) -> Result<Json<Value>, ApiError> {
    let operation = operation(
        &headers,
        "POST",
        &format!("/v1/me/api-keys/{id}/revoke"),
        Value::Null,
    )?;
    Ok(Json(
        state
            .db
            .change_api_key(principal.user_id, id, KeyChange::Revoke, &operation)
            .await?
            .body,
    ))
}
