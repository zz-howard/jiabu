//! Live composition without server startup/recovery tasks. The credential source
//! permits ONLY CredentialManager's revision-CAS rotation/invalidation writes.
//! Ledger, journal and metering always belong to each scratch database. Never
//! log database URLs, credentials, upstream error bodies or model content.
use crate::fixture::Providers;
use anyhow::{Result, ensure};
use async_trait::async_trait;
use jiabu_ai::{
    credentials::{CredentialManager, RefreshGate, SecretKey, TokenRead, TokenStore},
    siwc::{
        SiwcProvider,
        oauth::{OAuthClient, OAuthCredentials},
    },
    *,
};
use jiabu_db::{AppDb, SystemTx};
use std::sync::Arc;
use zeroize::Zeroizing;
struct DatabaseTokens {
    db: AppDb,
    provider: String,
    key: Arc<SecretKey>,
}
#[async_trait]
impl TokenStore for DatabaseTokens {
    async fn load(&self) -> Result<TokenRead, ProviderError> {
        let secret = async {
            let tx = SystemTx::begin(&self.db).await?;
            let secret = tx.ai_secret(&self.provider).await?;
            tx.commit().await?;
            Ok::<_, anyhow::Error>(secret)
        }
        .await;
        let secret = match secret {
            Ok(Some(secret)) => secret,
            Ok(None) => return Err(ProviderError::Auth),
            Err(_) => return Ok(TokenRead::Unavailable),
        };
        // clear-secret erases ciphertext: inspect metadata before attempting decryption.
        if !secret.usable {
            return Ok(TokenRead::Cleared {
                revision: secret.revision,
            });
        }
        let bytes = self
            .key
            .open("provider", &self.provider, "oauth", &secret)
            .map_err(|_| ProviderError::Auth)?;
        let credentials = serde_json::from_slice(&bytes).map_err(|_| ProviderError::Auth)?;
        Ok(TokenRead::Present {
            revision: secret.revision,
            credentials,
        })
    }
    async fn compare_exchange(
        &self,
        expected: i64,
        next: &OAuthCredentials,
    ) -> Result<bool, ProviderError> {
        let bytes = Zeroizing::new(serde_json::to_vec(next).map_err(|_| ProviderError::Transport)?);
        let secret = self
            .key
            .seal("provider", &self.provider, "oauth", &bytes)
            .map_err(|_| ProviderError::Transport)?;
        let tx = SystemTx::begin(&self.db)
            .await
            .map_err(|_| ProviderError::Transport)?;
        let changed = tx
            .rotate_ai_secret(&self.provider, expected, &secret, next.expires_at)
            .await
            .map_err(|_| ProviderError::Transport)?;
        tx.commit().await.map_err(|_| ProviderError::Transport)?;
        Ok(changed)
    }
    async fn invalidate(&self, expected: i64) -> Result<bool, ProviderError> {
        let tx = SystemTx::begin(&self.db)
            .await
            .map_err(|_| ProviderError::Auth)?;
        let changed = tx
            .invalidate_ai_secret(&self.provider, expected)
            .await
            .map_err(|_| ProviderError::Auth)?;
        tx.commit().await.map_err(|_| ProviderError::Auth)?;
        Ok(changed)
    }
}

pub async fn load(database_url: &str) -> Result<Providers> {
    let db = AppDb::connect(database_url).await?;
    let config = db.ai_configuration().await?;
    let prices = db.evaluation_prices().await?;
    let key = Arc::new(SecretKey::from_environment().map_err(anyhow::Error::msg)?);
    let mut providers: Vec<Arc<dyn ModelProvider>> = Vec::new();
    for p in &config.providers {
        if !p.enabled || p.kind != "siwc" {
            continue;
        }
        ensure!(
            matches!(p.secret_source.as_deref(), None | Some("db")),
            "live evaluation requires database SIWC credentials"
        );
        let tokens = Arc::new(DatabaseTokens {
            db: db.clone(),
            provider: p.id.clone(),
            key: key.clone(),
        });
        // One manager/gate per source is shared across the entire suite. Reuse
        // the existing refresh implementation, including revision-CAS writes.
        let manager = Arc::new(
            CredentialManager::with_gate(
                tokens,
                OAuthClient::official()?,
                Arc::new(RefreshGate::default()),
            )
            .await,
        );
        providers.push(Arc::new(SiwcProvider::new(
            p.id.clone(),
            Capabilities {
                structured: StructuredMode::ToolCall,
                vision: true,
                max_images: 8,
                context_tokens: 0,
            },
            manager,
        )?));
    }
    ensure!(!providers.is_empty(), "no enabled SIWC provider");
    Ok(Providers {
        config,
        providers,
        prices,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use jiabu_db_admin::ai_configuration::ConfigWrite;
    /// Offline: no model/OAuth request. Source reads leave all run/meter tables
    /// empty; only explicit credential CAS may change the source database.
    #[tokio::test]
    async fn database_tokens_read_and_revision_cas_are_the_only_source_writes() -> Result<()> {
        let test = crate::support::TestDb::new().await?;
        let admin = test.admin().await?;
        admin
            .ai_write(
                ConfigWrite::Provider {
                    config: ProviderConfig {
                        id: "synthetic".into(),
                        kind: "siwc".into(),
                        base_url: None,
                        billing: Billing::Subscription,
                        secret_source: Some("db".into()),
                        enabled: true,
                        version: 1,
                    },
                    create: true,
                },
                "eval-test",
            )
            .await?;
        let key = Arc::new(
            SecretKey::new("synthetic-key".into(), vec![7; 32]).map_err(anyhow::Error::msg)?,
        );
        let credentials = OAuthCredentials {
            access_token: "synthetic-access".into(),
            refresh_token: "synthetic-refresh".into(),
            client_id: "oaiapp_synthetic".into(),
            account_id: "synthetic-account".into(),
            expires_at: chrono::Utc::now().timestamp() + 7200,
            host_id: uuid::Uuid::nil(),
        };
        let bytes = Zeroizing::new(serde_json::to_vec(&credentials)?);
        let secret = key
            .seal("provider", "synthetic", "oauth", &bytes)
            .map_err(anyhow::Error::msg)?;
        admin
            .ai_save_oauth(
                "synthetic",
                &secret,
                &credentials.client_id,
                credentials.expires_at,
                "eval-test",
            )
            .await?;
        let db = AppDb::connect(&test.app_url).await?;
        let tokens = Arc::new(DatabaseTokens {
            db: db.clone(),
            provider: "synthetic".into(),
            key,
        });
        let owner = test.owner().await?;
        let before: serde_json::Value =
            sqlx::query_scalar("select to_jsonb(s) from secrets s where owner_id='synthetic'")
                .fetch_one(&owner)
                .await?;
        let TokenRead::Present { revision, .. } = tokens.load().await? else {
            anyhow::bail!("missing synthetic token")
        };
        let manager = CredentialManager::with_gate(
            tokens.clone(),
            OAuthClient::at("http://127.0.0.1:1")?,
            Arc::new(RefreshGate::default()),
        )
        .await;
        // Far-future expiry ensures access() cannot contact the deliberately
        // unreachable OAuth endpoint. No new login path is introduced.
        let loaded = manager.access().await?;
        assert_eq!(loaded.access_token, "synthetic-access");
        let after: serde_json::Value =
            sqlx::query_scalar("select to_jsonb(s) from secrets s where owner_id='synthetic'")
                .fetch_one(&owner)
                .await?;
        assert_eq!(before, after);
        let mut rotated = credentials;
        rotated.access_token = "synthetic-next-access".into();
        rotated.refresh_token = "synthetic-next-refresh".into();
        let (a, b) = tokio::join!(
            tokens.compare_exchange(revision, &rotated),
            tokens.compare_exchange(revision, &rotated)
        );
        assert_ne!(a?, b?);
        let TokenRead::Present {
            revision: next,
            credentials: current,
        } = tokens.load().await?
        else {
            anyhow::bail!("missing rotation")
        };
        assert!(next > revision);
        assert_eq!(current.refresh_token, "synthetic-next-refresh");
        for table in ["records", "agent_runs", "agent_run_items", "ai_calls"] {
            let count: i64 =
                sqlx::query_scalar(sqlx::AssertSqlSafe(format!("select count(*) from {table}")))
                    .fetch_one(&owner)
                    .await?;
            assert_eq!(count, 0);
        }
        // Scratch evaluation and metering are independent of the credential DB.
        let entry =
            crate::dataset::parse(include_str!("../../../eval/entries/zh-single-001.yaml"))?;
        let scratch = std::env::var("DATABASE_URL")?;
        let scenario =
            crate::fixture::Scenario::new(&entry, &crate::dataset_root(), &scratch, None, None)
                .await?;
        let result = scenario.evaluate(&entry).await?;
        assert!(!result.calls.is_empty());
        let count: i64 = sqlx::query_scalar("select count(*) from ai_calls")
            .fetch_one(&owner)
            .await?;
        assert_eq!(count, 0);
        Ok(())
    }
}
