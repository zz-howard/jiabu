use serde::{Deserialize, Serialize};
use uuid::Uuid;
macro_rules! id {
    ($($name:ident),+ $(,)?) => {$ (
        #[derive(Clone, Copy, Debug, Eq, PartialEq, Ord, PartialOrd, Hash, Serialize, Deserialize)]
        #[serde(transparent)]
        pub struct $name(pub Uuid);
        impl From<Uuid> for $name { fn from(value: Uuid) -> Self { Self(value) } }
        impl std::fmt::Display for $name {
            fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result { std::fmt::Display::fmt(&self.0, f) }
        }
    )+};
}
id!(
    UserId, SpaceId, MemberId, SessionId, RunId, RecordId, AccountId, TagId, DocumentId, SubjectId
);
#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(transparent)]
pub struct JoinEpoch(pub i32);
