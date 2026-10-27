//! Explicit HTTP response schemas; database rows are not the public API contract.
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use utoipa::ToSchema;
use uuid::Uuid;

#[derive(Deserialize, Serialize, ToSchema)]
pub(crate) struct SpaceMetadata {
    pub id: Uuid,
    pub name: String,
    pub accent_color: String,
    pub currency: String,
    pub timezone: String,
    pub is_default: bool,
    pub version: i32,
    pub change_seq: i64,
}
#[derive(Deserialize, Serialize, ToSchema)]
pub(crate) struct SpaceModules {
    pub ledger: String,
    pub documents: String,
}
#[derive(Deserialize, Serialize, ToSchema)]
pub(crate) struct SpaceMemberSummary {
    pub id: Uuid,
    pub display_name: String,
    pub role: String,
    pub status: String,
    pub version: i32,
}
#[derive(Deserialize, Serialize, ToSchema)]
pub(crate) struct SpaceSummary {
    pub id: Uuid,
    pub name: String,
    pub accent_color: String,
    pub currency: String,
    pub timezone: String,
    pub is_default: bool,
    pub version: i32,
    pub role: String,
    pub join_epoch: i32,
    pub member_id: Uuid,
    pub modules: SpaceModules,
    pub members: Vec<SpaceMemberSummary>,
}
#[derive(Deserialize, Serialize, ToSchema)]
pub(crate) struct SpacesResponse {
    pub spaces: Vec<SpaceSummary>,
}
#[derive(Deserialize, Serialize, ToSchema)]
pub(crate) struct SpaceMember {
    pub id: Uuid,
    pub display_name: String,
    pub role: String,
    pub status: String,
    pub join_epoch: i32,
    pub joined_at: DateTime<Utc>,
    pub left_at: Option<DateTime<Utc>>,
    pub left_reason: Option<String>,
    pub version: i32,
    pub change_seq: i64,
}
#[derive(Deserialize, Serialize, ToSchema)]
pub(crate) struct SpaceInvitationResponse {
    pub id: Uuid,
    pub space_id: Uuid,
    pub invitee_user_id: Uuid,
    pub invited_by_member_id: Uuid,
    pub status: String,
    pub created_at: DateTime<Utc>,
    pub decided_at: Option<DateTime<Utc>>,
}
#[derive(Deserialize, Serialize, ToSchema)]
pub(crate) struct SpaceInvitation {
    pub id: Uuid,
    pub status: String,
    pub invitee_username: String,
    pub invited_by_member_id: Uuid,
    pub created_at: DateTime<Utc>,
    pub decided_at: Option<DateTime<Utc>>,
}
#[derive(Deserialize, Serialize, ToSchema)]
pub(crate) struct SpaceInvitationsResponse {
    pub invitations: Vec<SpaceInvitation>,
}
#[derive(Deserialize, Serialize, ToSchema)]
pub(crate) struct ReceivedSpaceInvitation {
    pub id: Uuid,
    pub space_name: String,
    pub inviter_display_name: String,
}
#[derive(Deserialize, Serialize, ToSchema)]
pub(crate) struct ReceivedSpaceInvitationsResponse {
    pub invitations: Vec<ReceivedSpaceInvitation>,
}
#[derive(Deserialize, Serialize, ToSchema)]
pub(crate) struct SpaceActionResponse {
    pub status: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub member_id: Option<Uuid>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub join_epoch: Option<i32>,
}
#[derive(Deserialize, Serialize, ToSchema)]
pub(crate) struct TransferOwnershipResponse {
    pub owner_member_id: Uuid,
}
