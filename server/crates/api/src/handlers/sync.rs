use crate::{
    ApiError, AppState, Principal, RequestAudit,
    services::sync::{self, PullRequest, PushRequest, PushResponse},
};
use axum::{
    Extension, Json,
    extract::{State, rejection::JsonRejection},
};
use serde_json::Value;

#[utoipa::path(post,path="/v1/sync/push",security(("bearer"=[])),request_body(content=PushRequest,example=json!({"ops":[{"op_id":"00000000-0000-7000-8000-000000000001","space_id":"00000000-0000-7000-8000-000000000002","join_epoch":1,"request_id":"00000000-0000-7000-8000-000000000003","tool":"create_tag","args":{"name":"示例标签"}}]})),responses((status=200,body=PushResponse,example=json!({"results":[{"op_id":"00000000-0000-7000-8000-000000000001","status":"ok","result":{"version":1}}]})),(status=400,body=crate::Problem),(status=401,body=crate::Problem),(status=403,body=crate::Problem),(status=429,body=crate::Problem,headers(("Retry-After"=u64,description="Seconds until retry"))),(status=500,body=crate::Problem),(status=503,body=crate::Problem),(status=413,body=crate::Problem)))]
pub(crate) async fn push(
    State(state): State<AppState>,
    principal: Principal,
    Extension(audit): Extension<RequestAudit>,
    body: Result<Json<PushRequest>, JsonRejection>,
) -> Result<Json<PushResponse>, ApiError> {
    Ok(Json(
        sync::push(&state, &principal, &audit, super::input(body)?).await?,
    ))
}
#[utoipa::path(post,path="/v1/sync/pull",security(("bearer"=[])),request_body(content=PullRequest,example=json!({"spaces":{"00000000-0000-7000-8000-000000000002":0},"limit":500})),responses((status=200,body=Value,example=json!({"spaces":[{"space_id":"00000000-0000-7000-8000-000000000002","cursor":1,"has_more":false,"changes":[{"entity":"tag","data":{"change_seq":1}}]}],"unavailable":[]})),(status=400,body=crate::Problem),(status=401,body=crate::Problem),(status=403,body=crate::Problem),(status=429,body=crate::Problem,headers(("Retry-After"=u64,description="Seconds until retry"))),(status=500,body=crate::Problem),(status=503,body=crate::Problem)))]
pub(crate) async fn pull(
    State(state): State<AppState>,
    principal: Principal,
    body: Result<Json<PullRequest>, JsonRejection>,
) -> Result<Json<Value>, ApiError> {
    Ok(Json(
        sync::pull(&state, &principal, super::input(body)?).await?,
    ))
}
