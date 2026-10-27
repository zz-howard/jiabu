use serde::{Deserialize, Serialize};
#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(transparent)]
pub struct Money(pub i64);
impl Money {
    pub fn checked_add(self, other: Self) -> Option<Self> {
        self.0.checked_add(other.0).map(Self)
    }
}
#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize)]
pub struct Currency {
    pub code: &'static str,
    pub decimals: u8,
}
pub const CURRENCIES: &[Currency] = &[
    Currency {
        code: "CNY",
        decimals: 2,
    },
    Currency {
        code: "HKD",
        decimals: 2,
    },
    Currency {
        code: "USD",
        decimals: 2,
    },
    Currency {
        code: "EUR",
        decimals: 2,
    },
    Currency {
        code: "GBP",
        decimals: 2,
    },
    Currency {
        code: "JPY",
        decimals: 0,
    },
];
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn money_only_accepts_integers() {
        assert!(serde_json::from_str::<Money>("1.5").is_err());
        assert_eq!(Money(i64::MAX).checked_add(Money(1)), None);
        assert_eq!(CURRENCIES.len(), 6);
        assert_eq!(CURRENCIES[5].decimals, 0);
    }
}
