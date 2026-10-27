//! Calendar rules only. The caller supplies the space-local date.
use chrono::{Datelike, NaiveDate};

pub fn due_in_month(year: i32, month: u32, day: u32) -> Option<NaiveDate> {
    if !(1..=31).contains(&day) {
        return None;
    }
    let (y, m) = if month == 12 {
        (year.checked_add(1)?, 1)
    } else {
        (year, month.checked_add(1)?)
    };
    let last = NaiveDate::from_ymd_opt(y, m, 1)?.pred_opt()?;
    NaiveDate::from_ymd_opt(year, month, day.min(last.day()))
}
pub fn next_month(date: NaiveDate, day: u32) -> Option<NaiveDate> {
    if date.month() == 12 {
        due_in_month(date.year().checked_add(1)?, 1, day)
    } else {
        due_in_month(date.year(), date.month() + 1, day)
    }
}
pub fn month_key(date: NaiveDate) -> String {
    date.format("%Y-%m").to_string()
}
pub fn first_run(today: NaiveDate, day: u32, last: Option<&str>) -> Option<NaiveDate> {
    let mut due = due_in_month(today.year(), today.month(), day)?;
    if due <= today || last == Some(month_key(due).as_str()) {
        due = next_month(due, day)?;
    }
    if last == Some(month_key(due).as_str()) {
        due = next_month(due, day)?;
    }
    Some(due)
}
/// An enabled plan being edited must still run once in this calendar month.
/// A past/current due date is intentionally returned so the caller immediately
/// executes the new settings, unless the month was already allocated.
pub fn continued_run(today: NaiveDate, day: u32, last: Option<&str>) -> Option<NaiveDate> {
    let due = due_in_month(today.year(), today.month(), day)?;
    if last == Some(month_key(today).as_str()) {
        next_month(due, day)
    } else {
        Some(due)
    }
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn strictly_future_and_month_end() {
        for day in 29..=31 {
            let today = NaiveDate::from_ymd_opt(2025, 1, 31).unwrap();
            assert_eq!(
                first_run(today, day, None).unwrap().to_string(),
                "2025-02-28"
            );
            assert_eq!(
                due_in_month(2024, 2, day).unwrap().to_string(),
                "2024-02-29"
            );
        }
        let today = NaiveDate::from_ymd_opt(2026, 3, 1).unwrap();
        assert_eq!(
            first_run(today, 15, Some("2026-03")).unwrap().to_string(),
            "2026-04-15"
        );
        assert_eq!(first_run(today, 1, None).unwrap().to_string(), "2026-04-01");
    }
    #[test]
    fn continued_plan_keeps_unpaid_month_even_if_new_day_has_passed() {
        let today = NaiveDate::from_ymd_opt(2026, 10, 20).unwrap();
        for (day, last, expected) in [
            (15, Some("2026-09"), "2026-10-15"),
            (20, Some("2026-09"), "2026-10-20"),
            (25, Some("2026-09"), "2026-10-25"),
            (15, Some("2026-10"), "2026-11-15"),
        ] {
            assert_eq!(
                continued_run(today, day, last).unwrap().to_string(),
                expected
            );
        }
        let february = NaiveDate::from_ymd_opt(2027, 2, 28).unwrap();
        assert_eq!(
            continued_run(february, 31, Some("2027-01")).unwrap(),
            february
        );
        // Re-enabling and first setup deliberately retain the strictly-future rule.
        assert_eq!(
            first_run(today, 15, Some("2026-09")).unwrap().to_string(),
            "2026-11-15"
        );
        assert_eq!(
            first_run(today, 20, None).unwrap().to_string(),
            "2026-11-20"
        );
    }
}
