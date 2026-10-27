//! Canonicalize known SQL timestamp columns without touching user JSON payloads.
use crate::DbErr;
use chrono::{DateTime, Utc};
use serde_json::Value;

pub(crate) fn normalize_fields(mut value: Value, fields: &[&str]) -> Result<Value, DbErr> {
    for field in fields {
        if let Some(timestamp) = value.get_mut(*field).filter(|v| !v.is_null()) {
            let instant: DateTime<Utc> = serde_json::from_value(timestamp.clone())
                .map_err(|_| DbErr::Custom("invalid persisted timestamp".into()))?;
            *timestamp = serde_json::to_value(instant)
                .map_err(|_| DbErr::Custom("invalid persisted timestamp".into()))?;
        }
    }
    Ok(value)
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn timestamps_use_domain_utc_serialization_and_preserve_user_json() -> Result<(), DbErr> {
        let input = json!({
            "created_at": "2026-10-28T08:00:00.1234+08:00",
            "updated_at": "2026-10-28T00:00:00+00:00",
            "deleted_at": null,
            "occurred_on": "2026-10-28",
            "content": {"created_at": "2026-10-28T08:00:00+08:00"}
        });
        let output = normalize_fields(input.clone(), &["created_at", "updated_at", "deleted_at"])?;
        assert_eq!(output["created_at"], "2026-10-28T00:00:00.123400Z");
        assert_eq!(output["updated_at"], "2026-10-28T00:00:00Z");
        assert_eq!(output["deleted_at"], Value::Null);
        assert_eq!(output["occurred_on"], input["occurred_on"]);
        assert_eq!(output["content"], input["content"]);
        assert_eq!(
            normalize_fields(output.clone(), &["created_at", "updated_at"])?,
            output
        );
        Ok(())
    }
}
