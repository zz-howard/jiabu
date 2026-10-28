use axum::{Json, extract::State};
use serde::Serialize;
#[derive(Serialize, utoipa::ToSchema)]
pub struct Status {
    ai_available: bool,
    ai_reason: &'static str,
}
#[utoipa::path(get,path="/v1/status",security(("bearer"=[])),responses((status=200,body=Status,description="Availability of the configured chat route",example=json!({"ai_available":false,"ai_reason":"unavailable"}))))]
pub(crate) async fn get(
    _principal: crate::Principal,
    State(state): State<crate::AppState>,
) -> Json<Status> {
    let availability = state.ai.0.load().availability(jiabu_ai::TaskKind::Chat);
    Json(Status {
        ai_available: availability.available,
        ai_reason: availability.reason,
    })
}
