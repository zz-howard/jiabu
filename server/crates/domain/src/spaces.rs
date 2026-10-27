//! S2 commands. Space/member versions are optimistic; grants only have change_seq.
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Clone, Debug, Serialize, Deserialize)]
pub enum Change {
    Rename {
        name: Option<String>,
        accent_color: Option<String>,
        expected_version: i32,
    },
    Delete {
        name: String,
    },
    Invite {
        username: String,
    },
    Cancel {
        invitation: Uuid,
    },
    Remove {
        member: Uuid,
    },
    Leave,
    Transfer {
        member: Uuid,
    },
    DisplayName {
        display_name: String,
        expected_version: i32,
    },
}
impl Change {
    pub fn requires_owner(&self) -> bool {
        matches!(
            self,
            Self::Rename { .. } | Self::Delete { .. } | Self::Remove { .. } | Self::Transfer { .. }
        )
    }
}
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct CreateSpace {
    pub id: Uuid,
    pub name: String,
    pub accent_color: String,
    pub currency: String,
    pub timezone: String,
}
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum Decision {
    Accept,
    Decline,
}
impl Decision {
    pub fn status(self) -> &'static str {
        match self {
            Self::Accept => "accepted",
            Self::Decline => "declined",
        }
    }
}
pub fn valid_name(value: &str, maximum: usize) -> bool {
    !value.trim().is_empty() && value.chars().count() <= maximum
}
