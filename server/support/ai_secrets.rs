//! Shared by AI and management, without a business-crate dependency.
use chacha20poly1305::{
    KeyInit, XChaCha20Poly1305,
    aead::{Aead, Payload},
};
use jiabu_domain::ai::EncryptedSecret;
use secrecy::{ExposeSecret, SecretBox};
use zeroize::Zeroizing;
pub struct SecretKey {
    id: String,
    bytes: SecretBox<Vec<u8>>,
}
impl SecretKey {
    pub fn new(id: String, bytes: Vec<u8>) -> Result<Self, &'static str> {
        let bytes = Zeroizing::new(bytes);
        if bytes.len() != 32 || id.is_empty() {
            return Err("invalid master key");
        }
        Ok(Self {
            id,
            bytes: SecretBox::new(Box::new(bytes.to_vec())),
        })
    }
    pub fn from_environment() -> Result<Self, &'static str> {
        if let Ok(raw) = std::env::var("JIABU_SECRETS_KEY") {
            use base64::{Engine, engine::general_purpose::STANDARD};
            let raw = Zeroizing::new(raw);
            let bytes = STANDARD
                .decode(raw.as_bytes())
                .map_err(|_| "invalid base64 master key")?;
            return Self::new(
                std::env::var("JIABU_SECRETS_KEY_ID").unwrap_or_else(|_| "primary".into()),
                bytes,
            );
        }
        let path =
            std::env::var("JIABU_SECRETS_KEY_FILE").map_err(|_| "master key source required")?;
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            let metadata =
                std::fs::metadata(&path).map_err(|_| "cannot read master key metadata")?;
            if metadata.permissions().mode() & 0o777 != 0o600 {
                return Err("master key requires mode 600");
            }
        }
        let bytes = std::fs::read(path).map_err(|_| "cannot read master key")?;
        Self::new(
            std::env::var("JIABU_SECRETS_KEY_ID").unwrap_or_else(|_| "primary".into()),
            bytes,
        )
    }
    pub fn seal(
        &self,
        owner_kind: &str,
        owner_id: &str,
        field: &str,
        value: &[u8],
    ) -> Result<EncryptedSecret, &'static str> {
        let nonce: [u8; 24] = rand::random();
        let aad = aad(owner_kind, owner_id, field)?;
        let cipher = XChaCha20Poly1305::new_from_slice(self.bytes.expose_secret())
            .map_err(|_| "invalid master key")?;
        let ciphertext = cipher
            .encrypt(
                &nonce.into(),
                Payload {
                    msg: value,
                    aad: aad.as_bytes(),
                },
            )
            .map_err(|_| "encryption failed")?;
        // OAuth JSON never exposes a token suffix or account in management projections.
        let last4 = if field == "oauth" {
            String::new()
        } else {
            String::from_utf8_lossy(value)
                .chars()
                .rev()
                .take(4)
                .collect::<Vec<_>>()
                .into_iter()
                .rev()
                .collect()
        };
        Ok(EncryptedSecret {
            key_id: self.id.clone(),
            nonce: nonce.to_vec(),
            ciphertext,
            last4,
            revision: 0,
            usable: true,
        })
    }
    pub fn open(
        &self,
        owner_kind: &str,
        owner_id: &str,
        field: &str,
        secret: &EncryptedSecret,
    ) -> Result<Zeroizing<Vec<u8>>, &'static str> {
        if secret.key_id != self.id || secret.nonce.len() != 24 {
            return Err("invalid encrypted secret");
        }
        let aad = aad(owner_kind, owner_id, field)?;
        let cipher = XChaCha20Poly1305::new_from_slice(self.bytes.expose_secret())
            .map_err(|_| "invalid master key")?;
        let nonce: [u8; 24] = secret
            .nonce
            .as_slice()
            .try_into()
            .map_err(|_| "invalid nonce")?;
        cipher
            .decrypt(
                &nonce.into(),
                Payload {
                    msg: &secret.ciphertext,
                    aad: aad.as_bytes(),
                },
            )
            .map(Zeroizing::new)
            .map_err(|_| "secret authentication failed")
    }
}
fn aad(kind: &str, id: &str, field: &str) -> Result<String, &'static str> {
    if [kind, id, field]
        .iter()
        .any(|s| s.is_empty() || s.contains('/'))
    {
        return Err("invalid secret owner");
    }
    Ok(format!("{kind}/{id}/{field}"))
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn random_nonce_aad_owner_binding_and_tamper_rejection() {
        let key = SecretKey::new("test".into(), vec![7; 32]).unwrap();
        let a = key
            .seal("provider", "fake-a", "oauth", b"synthetic-value")
            .unwrap();
        let mut b = key
            .seal("provider", "fake-a", "oauth", b"synthetic-value")
            .unwrap();
        assert_ne!(a.nonce, b.nonce);
        assert_eq!(
            &*key.open("provider", "fake-a", "oauth", &a).unwrap(),
            b"synthetic-value"
        );
        assert!(key.open("provider", "fake-b", "oauth", &a).is_err());
        assert!(key.open("provider", "fake-a", "api_key", &a).is_err());
        b.ciphertext[0] ^= 1;
        assert!(key.open("provider", "fake-a", "oauth", &b).is_err());
    }
}
