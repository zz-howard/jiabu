use super::*;
use crate::templates::{OFFICIAL, Template};
use serde_json::json;
fn content(items: Value) -> Content {
    serde_json::from_value(json!({"v":1,"items":items})).unwrap()
}
#[test]
fn no_template_seven_types_and_missing_required_are_supported() {
    let mut data = content(json!([
        {"key":"text","type":"text","label":"文字","value":"虚构文字"},
        {"key":"number","type":"number","label":"数字","value":null},
        {"key":"date","type":"date","label":"日期","value":"2026-10-12"},
        {"key":"image","type":"image","label":"原图","value":[]},
        {"key":"one","type":"single_select","label":"单选","value":{"id":"yes","label":"是"}},
        {"key":"many","type":"multi_select","label":"多选","value":[{"id":"a","label":"甲"}]},
        {"key":"table","type":"table","label":"表格","value":{"columns":[{"key":"n","label":"数值","type":"number","unit":"kg"}],"rows":[{"n":2.5}]}}
    ]));
    normalize_content(&mut data, None).unwrap();
    let t: Template = serde_json::from_str(OFFICIAL[0].1).unwrap();
    normalize_content(&mut content(json!([])), Some(&t)).unwrap();
}
#[test]
fn content_rejects_unknown_fields_types_options_units_and_limits() {
    let t: Template = serde_json::from_str(OFFICIAL[0].1).unwrap();
    let cases = vec![
        json!([{"key":"absent","type":"text","label":"未知","value":"x"}]),
        json!([{"key":"weight","type":"text","label":"错类型","value":"61"}]),
        json!([{"key":"heart_rate","type":"number","label":"心率","value":70,"unit":"wrong"}]),
        json!([{"key":"fasting","type":"single_select","label":"空腹","value":{"id":"absent","label":"未知"}}]),
        json!([{"key":"exam_date","type":"date","label":"日期","value":"2026-02-30"}]),
        json!([{"key":"report_images","type":"image","label":"原图","value":vec![json!({"blob":"ab".repeat(32)});21]}]),
        json!([{"key":"conclusion","type":"text","label":"结论","value":"x".repeat(2001)}]),
    ];
    for items in cases {
        assert!(normalize_content(&mut content(items), Some(&t)).is_err());
    }
    let items = (0..201)
        .map(|n| json!({"key":format!("k{n}"),"type":"text","label":"虚构","value":"x"}))
        .collect::<Vec<_>>();
    assert!(normalize_content(&mut content(json!(items)), None).is_err());
    let rows = vec![json!({"n":1}); 201];
    let mut table = content(
        json!([{"key":"t","type":"table","label":"表格","value":{"columns":[{"key":"n","type":"number","label":"值"}],"rows":rows}}]),
    );
    assert!(normalize_content(&mut table, None).is_err());
    assert!(
        normalize_content(
            &mut content(
                json!([{"key":"big","type":"text","label":"大","value":"字".repeat(100000)}])
            ),
            None
        )
        .is_err()
    );
    let mut forged =
        content(json!([{"key":"n","type":"number","label":"值","value":1,"metric":"body.weight"}]));
    assert!(normalize_content(&mut forged, None).is_err());
}
#[test]
fn defaults_uncertain_unicode_and_title_are_pure_and_preserve_snapshots() {
    let t: Template = serde_json::from_str(OFFICIAL[0].1).unwrap();
    let mut data = content(json!([{"key":"weight","type":"number","label":"旧标签","value":999}]));
    normalize_content(&mut data, Some(&t)).unwrap();
    assert_eq!(data.items[0].unit.as_deref(), Some("kg"));
    assert_eq!(data.items[0].metric.as_deref(), Some("body.weight"));
    assert_eq!(data.items[0].uncertain, Some(true));
    assert_eq!(data.items[0].label, "旧标签");
    assert_eq!(normalize_name("　Ａｌｉｃｅ　"), "Alice");
    assert!(subject_rules(Some(&t), &[SubjectKind::FamilyMember]));
    assert!(!subject_rules(
        Some(&t),
        &[SubjectKind::FamilyMember, SubjectKind::Pet]
    ));
    assert_eq!(
        render_title(&t, &data, "{exam_date}", "en").unwrap(),
        "{exam_date} check-up"
    );
}
#[test]
fn item_row_image_and_byte_limits_accept_the_boundary() {
    let items = (0..200)
        .map(|n| json!({"key":format!("k{n}"),"type":"text","label":"值","value":"x"}))
        .collect::<Vec<_>>();
    normalize_content(&mut content(json!(items)), None).unwrap();
    let mut table = content(
        json!([{"key":"t","type":"table","label":"表格","value":{"columns":[{"key":"n","type":"number","label":"值"}],"rows":vec![json!({"n":1});200]}}]),
    );
    normalize_content(&mut table, None).unwrap();
    let mut images = content(
        json!([{"key":"images","type":"image","label":"原图","value":vec![json!({"blob":"ab".repeat(32)});10]}]),
    );
    assert_eq!(normalize_content(&mut images, None).unwrap().len(), 10);
    images.items[0]
        .value
        .as_array_mut()
        .unwrap()
        .push(json!({"blob":"ab".repeat(32)}));
    assert!(normalize_content(&mut images, None).is_err());
    let mut bytes = content(json!([{"key":"text","type":"text","label":"文字","value":""}]));
    let overhead = serde_json::to_vec(&bytes).unwrap().len();
    bytes.items[0].value = json!("x".repeat(256 * 1024 - overhead));
    assert_eq!(serde_json::to_vec(&bytes).unwrap().len(), 256 * 1024);
    normalize_content(&mut bytes, None).unwrap();
    let mut text = bytes.items[0].value.as_str().unwrap().to_owned();
    text.push('x');
    bytes.items[0].value = json!(text);
    assert!(normalize_content(&mut bytes, None).is_err());
}
