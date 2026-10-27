//! The single module authorization entry point.
use jiabu_db::{ActiveMember, GrantLevel};
use jiabu_domain::NotFound;
#[derive(Clone, Copy)]
pub enum Module {
    Ledger,
    Documents,
}
#[derive(Clone, Copy)]
pub enum Action {
    Read,
    Write,
    Manage,
}
fn permits(level: GrantLevel, action: Action) -> Result<(), NotFound> {
    let required = match action {
        Action::Read => GrantLevel::Read,
        Action::Write => GrantLevel::Write,
        Action::Manage => GrantLevel::Manage,
    };
    if level >= required {
        Ok(())
    } else {
        Err(NotFound)
    }
}
pub fn authorize(member: &ActiveMember, module: Module, action: Action) -> Result<(), NotFound> {
    permits(
        match module {
            Module::Ledger => member.ledger_grant(),
            Module::Documents => member.documents_grant(),
        },
        action,
    )
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn authorization_matrix() {
        for (i, level) in [
            GrantLevel::None,
            GrantLevel::Read,
            GrantLevel::Write,
            GrantLevel::Manage,
        ]
        .into_iter()
        .enumerate()
        {
            for (j, action) in [Action::Read, Action::Write, Action::Manage]
                .into_iter()
                .enumerate()
            {
                assert_eq!(permits(level, action).is_ok(), i > j);
            }
        }
    }
}
