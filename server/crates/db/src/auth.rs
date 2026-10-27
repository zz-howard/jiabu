//! Account/session persistence; token material is always a digest at this boundary.
use crate::AppDb;
use chrono::{DateTime, Utc};
use jiabu_domain::{SessionId, UserId};
use sea_orm::{ConnectionTrait, DbBackend, DbErr, Statement, TransactionTrait};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Clone, Serialize, Deserialize)]
pub struct User {
    pub id: Uuid,
    pub username: String,
    pub locale: String,
}
#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SessionKind {
    Full,
    PasswordChange,
}
impl SessionKind {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Full => "full",
            Self::PasswordChange => "password_change",
        }
    }
}
pub struct Candidate {
    pub id: UserId,
    pub password_hash: String,
}
pub struct Authenticated {
    pub user: User,
    pub session_id: SessionId,
    pub kind: SessionKind,
}
pub struct Login {
    pub user: User,
    pub kind: SessionKind,
    pub admin_reset_at: Option<DateTime<Utc>>,
}
#[derive(Debug, thiserror::Error)]
pub enum AuthError {
    #[error("unauthenticated")]
    Unauthenticated,
    #[error("account_disabled")]
    Disabled,
    #[error(transparent)]
    Database(#[from] DbErr),
}
fn user(row: &sea_orm::QueryResult) -> Result<User, DbErr> {
    Ok(User {
        id: row.try_get("", "id")?,
        username: row.try_get("", "username")?,
        locale: row.try_get("", "locale")?,
    })
}
impl AppDb {
    pub async fn login_candidate(&self, username: &str) -> Result<Option<Candidate>, DbErr> {
        self.connection
            .query_one_raw(Statement::from_sql_and_values(
                DbBackend::Postgres,
                "select id,password_hash from users where lower(username)=lower($1)",
                [username.into()],
            ))
            .await?
            .map(|r| {
                Ok(Candidate {
                    id: UserId(r.try_get("", "id")?),
                    password_hash: r.try_get("", "password_hash")?,
                })
            })
            .transpose()
    }
    pub async fn finish_login(
        &self,
        candidate: &Candidate,
        digest: Vec<u8>,
        device: Option<String>,
    ) -> Result<Login, AuthError> {
        let tx = self.connection.begin().await?;
        let r = tx.query_one_raw(Statement::from_sql_and_values(DbBackend::Postgres,
            "select id,username,locale,password_hash,must_change_password,disabled_at,admin_reset_at,admin_reset_notice_pending from users where id=$1 for update",
            [candidate.id.0.into()])).await?.ok_or(AuthError::Unauthenticated)?;
        if r.try_get::<String>("", "password_hash")? != candidate.password_hash {
            return Err(AuthError::Unauthenticated);
        }
        // Login failure deliberately does not reveal account existence/disabled state.
        if r.try_get::<Option<DateTime<Utc>>>("", "disabled_at")?
            .is_some()
        {
            return Err(AuthError::Unauthenticated);
        }
        let kind = if r.try_get::<bool>("", "must_change_password")? {
            SessionKind::PasswordChange
        } else {
            SessionKind::Full
        };
        let notice = if r.try_get::<bool>("", "admin_reset_notice_pending")? {
            r.try_get("", "admin_reset_at")?
        } else {
            None
        };
        tx.execute_raw(Statement::from_sql_and_values(DbBackend::Postgres,
            "insert into sessions(token_hash,user_id,kind,device_name,expires_at) values($1,$2,$3,$4,now()+case when $3='full' then interval '180 days' else interval '15 minutes' end)",
            [digest.into(), candidate.id.0.into(), kind.as_str().into(), device.into()])).await?;
        tx.execute_raw(Statement::from_sql_and_values(
            DbBackend::Postgres,
            "update users set admin_reset_notice_pending=false where id=$1",
            [candidate.id.0.into()],
        ))
        .await?;
        let result = Login {
            user: user(&r)?,
            kind,
            admin_reset_at: notice,
        };
        tx.commit().await?;
        Ok(result)
    }
    pub async fn authenticate(&self, digest: Vec<u8>) -> Result<Authenticated, AuthError> {
        let r = self.connection.query_one_raw(Statement::from_sql_and_values(DbBackend::Postgres,
            "select u.id,u.username,u.locale,u.disabled_at,s.id session_id,s.kind from sessions s join users u on u.id=s.user_id where s.token_hash=$1 and s.expires_at>now()",
            [digest.into()])).await?.ok_or(AuthError::Unauthenticated)?;
        if r.try_get::<Option<DateTime<Utc>>>("", "disabled_at")?
            .is_some()
        {
            return Err(AuthError::Disabled);
        }
        let session_id = SessionId(r.try_get("", "session_id")?);
        let kind = if r.try_get::<String>("", "kind")? == "full" {
            SessionKind::Full
        } else {
            SessionKind::PasswordChange
        };
        if kind == SessionKind::Full {
            self.connection.execute_raw(Statement::from_sql_and_values(DbBackend::Postgres,
                "update sessions set last_seen_at=now(),expires_at=now()+interval '180 days' where id=$1 and last_seen_at<now()-interval '1 day'",
                [session_id.0.into()])).await?;
        }
        Ok(Authenticated {
            user: user(&r)?,
            session_id,
            kind,
        })
    }
    pub async fn logout(&self, session: SessionId) -> Result<(), DbErr> {
        self.connection
            .execute_raw(Statement::from_sql_and_values(
                DbBackend::Postgres,
                "delete from sessions where id=$1",
                [session.0.into()],
            ))
            .await?;
        Ok(())
    }
    pub async fn set_locale(&self, id: UserId, locale: &str) -> Result<User, DbErr> {
        let r = self
            .connection
            .query_one_raw(Statement::from_sql_and_values(
                DbBackend::Postgres,
                "update users set locale=$2 where id=$1 returning id,username,locale",
                [id.0.into(), locale.into()],
            ))
            .await?
            .ok_or_else(|| DbErr::Custom("user no longer exists".into()))?;
        user(&r)
    }
    pub async fn change_password(
        &self,
        id: UserId,
        session: SessionId,
        old_hash: &str,
        new_hash: String,
    ) -> Result<(), AuthError> {
        let tx = self.connection.begin().await?;
        let r = tx
            .query_one_raw(Statement::from_sql_and_values(
                DbBackend::Postgres,
                "select password_hash,disabled_at from users where id=$1 for update",
                [id.0.into()],
            ))
            .await?
            .ok_or(AuthError::Unauthenticated)?;
        if r.try_get::<String>("", "password_hash")? != old_hash
            || r.try_get::<Option<DateTime<Utc>>>("", "disabled_at")?
                .is_some()
        {
            return Err(AuthError::Unauthenticated);
        }
        let alive = tx
            .query_one_raw(Statement::from_sql_and_values(
                DbBackend::Postgres,
                "select id from sessions where id=$1 and user_id=$2 and expires_at>now()",
                [session.0.into(), id.0.into()],
            ))
            .await?;
        if alive.is_none() {
            return Err(AuthError::Unauthenticated);
        }
        tx.execute_raw(Statement::from_sql_and_values(DbBackend::Postgres,
            "update users set password_hash=$2,must_change_password=false,password_changed_at=now() where id=$1", [id.0.into(), new_hash.into()])).await?;
        tx.execute_raw(Statement::from_sql_and_values(
            DbBackend::Postgres,
            "delete from sessions where user_id=$1 and id<>$2",
            [id.0.into(), session.0.into()],
        ))
        .await?;
        tx.execute_raw(Statement::from_sql_and_values(DbBackend::Postgres,
            "update sessions set kind='full',last_seen_at=now(),expires_at=now()+interval '180 days' where id=$1", [session.0.into()])).await?;
        tx.commit().await?;
        Ok(())
    }
    pub async fn minimum_builds(&self) -> Result<(i32, i32), DbErr> {
        let r = self.connection.query_one_raw(Statement::from_string(DbBackend::Postgres,
            "select coalesce(max(build) filter(where channel='stable'),0)::int stable,coalesce(max(build) filter(where channel='beta'),0)::int beta from app_releases where security_force and status='available'".to_owned())).await?
            .ok_or_else(|| DbErr::Custom("missing aggregate".into()))?;
        Ok((r.try_get("", "stable")?, r.try_get("", "beta")?))
    }
    /// Used by S2 creation; this is the same primitive used by account creation.
    pub async fn initialize_space(
        &self,
        plan: &jiabu_domain::space_init::SpaceInit,
    ) -> Result<jiabu_domain::MemberId, DbErr> {
        let tx = self.connection.begin().await?;
        let seeds =
            serde_json::to_value(&plan.presets).map_err(|e| DbErr::Custom(e.to_string()))?;
        let r = tx
            .query_one_raw(Statement::from_sql_and_values(
                DbBackend::Postgres,
                "select initialize_space($1,$2,$3,$4,$5,$6,$7,$8,$9) as id",
                [
                    plan.space_id.0.into(),
                    plan.user_id.0.into(),
                    plan.name.clone().into(),
                    plan.accent.clone().into(),
                    plan.currency.clone().into(),
                    plan.timezone.clone().into(),
                    plan.is_default.into(),
                    plan.display_name.clone().into(),
                    seeds.into(),
                ],
            ))
            .await?
            .ok_or_else(|| DbErr::Custom("missing initialized member".into()))?;
        let id = jiabu_domain::MemberId(r.try_get("", "id")?);
        tx.commit().await?;
        Ok(id)
    }
}
