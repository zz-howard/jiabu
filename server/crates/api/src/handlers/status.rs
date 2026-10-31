use axum::{Json, extract::State};
use serde::Serialize;
#[derive(Serialize, utoipa::ToSchema)]
pub struct Status {
    ai_available: bool,
    ai_reason: &'static str,
    file_ai_available: bool,
    file_ai_reason: &'static str,
}
#[utoipa::path(get,path="/v1/status",security(("bearer"=[])),responses((status=200,body=Status,description="Availability of the configured chat routes",example=json!({"ai_available":false,"ai_reason":"unavailable","file_ai_available":false,"file_ai_reason":"unavailable"}))))]
pub(crate) async fn get(
    _principal: crate::Principal,
    State(state): State<crate::AppState>,
) -> Json<Status> {
    let router = state.ai.0.load();
    let availability = router.availability(jiabu_ai::TaskKind::Chat);
    let file_availability = router.availability(jiabu_ai::TaskKind::ChatFile);
    Json(Status {
        ai_available: availability.available,
        ai_reason: availability.reason,
        file_ai_available: file_availability.available,
        file_ai_reason: file_availability.reason,
    })
}
