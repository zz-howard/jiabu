use jiabu_domain::ai::Billing;
pub fn allowed(billing: Billing, allow_paid_fallback: bool) -> bool {
    billing != Billing::Paid || allow_paid_fallback
}
