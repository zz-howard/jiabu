use super::*;
use serde_json::{Value, json};
fn checkup() -> Template {
    serde_json::from_str(OFFICIAL[0].1).unwrap()
}
#[test]
fn committed_schema_matches_generated_schema() {
    let committed: Value =
        serde_json::from_str(include_str!("../../../../templates/template-1.schema.json")).unwrap();
    assert_eq!(
        committed,
        serde_json::to_value(schema()).unwrap(),
        "Regenerate using export_template_schema on the build host"
    );
}
#[test]
fn official_templates_match_protocol_and_spec_without_id_collisions() {
    let validator = jsonschema::validator_for(&serde_json::to_value(schema()).unwrap()).unwrap();
    let committed: Value =
        serde_json::from_str(include_str!("../../../../templates/template-1.schema.json")).unwrap();
    let committed = jsonschema::validator_for(&committed).unwrap();
    let mut ids = std::collections::BTreeSet::new();
    for (_, body) in OFFICIAL {
        let raw: Value = serde_json::from_str(body).unwrap();
        assert!(validator.is_valid(&raw));
        assert!(committed.is_valid(&raw));
        fn bilingual(v: &Value) {
            match v {
                Value::Object(o) => {
                    if o.contains_key("zh-Hans") {
                        assert!(o.get("en").is_some_and(Value::is_string));
                    }
                    for child in o.values() {
                        bilingual(child);
                    }
                }
                Value::Array(a) => {
                    for child in a {
                        bilingual(child);
                    }
                }
                _ => (),
            }
        }
        bilingual(&raw);
        let template: Template = serde_json::from_value(raw.clone()).unwrap();
        validate(&template, true).unwrap();
        assert!(ids.insert(template.id));
        assert!(raw["name"]["en"].is_string());
        assert_eq!(
            raw["subjects"],
            json!([{"kind":"family_member","min":1,"max":1}])
        );
    }
    let spec = include_str!("../../../../../docs/engineering/technical-design.md");
    let example = spec
        .split("### 8.7 完整示例：体检（官方模板）")
        .nth(1)
        .unwrap()
        .split("```json\n")
        .nth(1)
        .unwrap()
        .split("\n```")
        .next()
        .unwrap();
    let example: Value = serde_json::from_str(example).unwrap();
    assert_eq!(
        serde_json::from_str::<Value>(OFFICIAL[0].1).unwrap(),
        example
    );
    assert!(
        OFFICIAL[1..]
            .iter()
            .all(|(_, s)| serde_json::from_str::<Value>(s).unwrap()["id"] != example["id"])
    );
}
#[test]
fn semantic_rejections_cover_all_references_and_limits() {
    let base = serde_json::to_value(checkup()).unwrap();
    let cases = [
        ("/id", json!("Bad.id")),
        ("/version", json!(0)),
        ("/event_date_field", json!("weight")),
        ("/title/zh-Hans", json!("{absent}")),
        ("/layout/0/fields/0", json!("absent")),
        ("/layout/0/fields/1", json!("exam_date")),
        ("/fields/0/key", json!("weight")),
        ("/fields/0/key", json!("Bad")),
        ("/fields/9/metric_columns/item", json!("result")),
        ("/fields/9/metric_columns/value", json!("item")),
        ("/fields/9/columns/0/options/1/id", json!("wbc")),
        ("/ai/hints", json!("字".repeat(2001))),
        ("/name", json!({"en":"Only English"})),
    ];
    for (pointer, value) in cases {
        let mut raw = base.clone();
        *raw.pointer_mut(pointer).unwrap() = value;
        assert!(
            serde_json::from_value::<Template>(raw)
                .map(|t| validate(&t, true).is_err())
                .unwrap_or(true),
            "{pointer}"
        );
    }
    assert_eq!(
        validate(&checkup(), false).unwrap_err().0,
        "reserved_namespace"
    );
    let mut raw = base;
    raw["fields"][9]["columns"][0]["type"] = json!("image");
    assert!(serde_json::from_value::<Template>(raw).is_err());
}
#[test]
fn compatibility_accepts_only_relaxations_and_stable_metric_identity() {
    let old = checkup();
    let mut new = old.clone();
    new.version += 1;
    new.fields.push(new.fields[1].clone());
    new.fields.last_mut().unwrap().key = "extra".into();
    new.name.insert("en".into(), "New label".into());
    new.fields[2].min = Some(1.0);
    new.fields[2].max = Some(300.0);
    new.fields[8].options.as_mut().unwrap().push(SelectOption {
        id: "unknown".into(),
        label: old.name.clone(),
    });
    assert!(compatible(&old, &new));
    for mutation in 0..7 {
        let mut bad = old.clone();
        match mutation {
            0 => {
                bad.fields.remove(0);
            }
            1 => bad.fields[2].kind = ValueType::Text,
            2 => bad.fields[2].metric = Some("other".into()),
            3 => bad.version = 0,
            4 => bad.fields[2].min = Some(100.0),
            5 => {
                bad.fields[8].options.as_mut().unwrap().remove(0);
            }
            _ => bad.fields[9].metric_columns.as_mut().unwrap().unit = None,
        }
        assert!(!compatible(&old, &bad), "mutation {mutation}");
    }
}
