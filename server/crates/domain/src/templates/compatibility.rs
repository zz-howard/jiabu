use super::*;
fn lower(old: Option<f64>, new: Option<f64>) -> bool {
    match (old, new) {
        (_, None) => true,
        (Some(a), Some(b)) => b <= a,
        (None, Some(_)) => false,
    }
}
fn upper(old: Option<f64>, new: Option<f64>) -> bool {
    match (old, new) {
        (_, None) => true,
        (Some(a), Some(b)) => b >= a,
        (None, Some(_)) => false,
    }
}
fn limit(old: Option<u32>, new: Option<u32>) -> bool {
    match (old, new) {
        (_, None) => true,
        (Some(a), Some(b)) => b >= a,
        (None, Some(_)) => false,
    }
}
fn field(old: &Field, new: &Field) -> bool {
    old.kind == new.kind
        && old.metric == new.metric
        && old.metric_columns == new.metric_columns
        && lower(old.min, new.min)
        && upper(old.max, new.max)
        && limit(old.max_length, new.max_length)
        && (old.kind != ValueType::Image
            || new.max_items.unwrap_or(10) >= old.max_items.unwrap_or(10))
        && match (&old.units, &new.units) {
            (_, None) => true,
            (Some(a), Some(b)) => a.iter().all(|x| b.contains(x)),
            (None, Some(_)) => false,
        }
        && old
            .options
            .iter()
            .flatten()
            .all(|o| new.options.iter().flatten().any(|n| n.id == o.id))
        && old.columns.iter().flatten().all(|o| {
            new.columns
                .iter()
                .flatten()
                .any(|n| n.key == o.key && field(&o.field(), &n.field()))
        })
}
/// Compare acceptance/metric identity, never translated labels or AI prose.
pub fn compatible(old: &Template, new: &Template) -> bool {
    old.id == new.id
        && new.version >= old.version
        && old.protocol == new.protocol
        && old.event_date_field == new.event_date_field
        && old
            .fields
            .iter()
            .all(|o| new.fields.iter().any(|n| n.key == o.key && field(o, n)))
        && new
            .subjects
            .iter()
            .all(|n| match old.subjects.iter().find(|o| o.kind == n.kind) {
                Some(o) => {
                    n.min <= o.min
                        && match (o.max, n.max) {
                            (_, None) => true,
                            (Some(a), Some(b)) => b >= a,
                            (None, Some(_)) => false,
                        }
                }
                None => n.min == 0,
            })
        && old
            .subjects
            .iter()
            .all(|o| new.subjects.iter().any(|n| n.kind == o.kind) || o.max == Some(0))
}
