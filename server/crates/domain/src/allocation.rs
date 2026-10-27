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
}
