use crate::{SpaceId, UserId};
use serde::Serialize;
use uuid::Uuid;
/// Fixed keys in design-spec section 1.2, in palette order.
pub const SPACE_ACCENT_KEYS: &[&str] = &[
    "terracotta",
    "indigo",
    "pine",
    "plum",
    "teal",
    "amber",
    "rouge",
    "wisteria",
];
pub const DEFAULT_ACCENT: &str = SPACE_ACCENT_KEYS[0];
#[derive(Clone, Debug, Serialize)]
pub struct PresetSeed {
    pub id: Uuid,
    pub preset_key: String,
}
#[derive(Clone, Debug)]
pub struct SpaceInit {
    pub space_id: SpaceId,
    pub user_id: UserId,
    pub name: String,
    pub accent: String,
    pub currency: String,
    pub timezone: String,
    pub is_default: bool,
    pub display_name: String,
    pub presets: Vec<PresetSeed>,
}
