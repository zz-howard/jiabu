use axum::Json;
use serde::Serialize;
#[derive(Serialize, utoipa::ToSchema)]
pub struct Status {
    ai_available: bool,
    ai_reason: &'static str,
}
#[utoipa::path(get,path="/v1/status",security(("bearer"=[])),responses((status=200,body=Status,description="AI availability; S7 connects the runtime",example=json!({"ai_available":false,"ai_reason":"unavailable"}))))]
pub(crate) async fn get(_principal: crate::Principal) -> Json<Status> {
    Json(Status {
        ai_available: false,
        ai_reason: "unavailable",
    })
}
