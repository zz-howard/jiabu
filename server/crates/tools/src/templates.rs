//! Validated immutable template generations. Filesystem/signal IO lives in server.
use crate::ToolError;
use jiabu_db::{AppDb, SystemTx};
use jiabu_domain::templates::{self, Template};
use serde_json::json;
use sha2::{Digest, Sha256};
use std::{
    collections::{BTreeMap, BTreeSet},
    sync::Arc,
};
use tokio::sync::{Mutex, RwLock};
#[derive(Clone)]
pub struct TemplateFile {
    pub filename: String,
    pub body: String,
    pub official: bool,
    pub error: Option<&'static str>,
}
pub fn official_files() -> Vec<TemplateFile> {
    templates::OFFICIAL
        .iter()
        .map(|(name, body)| TemplateFile {
            filename: (*name).into(),
            body: (*body).into(),
            official: true,
            error: None,
        })
        .collect()
}
#[derive(Clone)]
pub struct TemplateCatalog {
    pub templates: BTreeMap<String, Template>,
    pub bytes: Vec<u8>,
    pub etag: String,
    sources: BTreeMap<String, (bool, String)>,
}
impl TemplateCatalog {
    fn new(
        templates: BTreeMap<String, Template>,
        sources: BTreeMap<String, (bool, String)>,
    ) -> Result<Self, ToolError> {
        let bytes =
            serde_json::to_vec(&json!({"templates":templates.values().collect::<Vec<_>>()}))
                .map_err(|_| ToolError::internal())?;
        let etag = format!(
            "\"{}\"",
            Sha256::digest(&bytes)
                .iter()
                .map(|b| format!("{b:02x}"))
                .collect::<String>()
        );
        Ok(Self {
            templates,
            sources,
            bytes,
            etag,
        })
    }
}
pub struct TemplateStore {
    current: RwLock<Arc<TemplateCatalog>>,
    reload: Mutex<()>,
    validator: jsonschema::Validator,
}
#[derive(Clone, Debug)]
pub struct RejectedTemplate {
    pub filename: String,
    pub category: &'static str,
}
#[derive(Default)]
pub struct ReloadReport {
    pub accepted: usize,
    pub rejected: Vec<RejectedTemplate>,
}
pub fn safe_filename(filename: &str) -> String {
    std::path::Path::new(filename)
        .file_name()
        .unwrap_or_default()
        .to_string_lossy()
        .chars()
        .filter(|c| !c.is_control())
        .collect()
}
pub fn log_rejection(filename: &str, category: &'static str) {
    tracing::error!(file=%safe_filename(filename),category,"template rejected");
}
impl TemplateStore {
    pub fn empty() -> Result<Self, ToolError> {
        let schema =
            serde_json::to_value(templates::schema()).map_err(|_| ToolError::internal())?;
        Ok(Self {
            current: RwLock::new(Arc::new(TemplateCatalog::new(
                BTreeMap::new(),
                BTreeMap::new(),
            )?)),
            reload: Mutex::new(()),
            validator: jsonschema::validator_for(&schema).map_err(|_| ToolError::internal())?,
        })
    }
    pub async fn snapshot(&self) -> Arc<TemplateCatalog> {
        self.current.read().await.clone()
    }
    pub fn parse(&self, file: &TemplateFile) -> Result<Template, &'static str> {
        if let Some(category) = file.error {
            return Err(category);
        }
        let raw: serde_json::Value = serde_json::from_str(&file.body).map_err(|_| "json")?;
        if !self.validator.is_valid(&raw) {
            return Err("schema");
        }
        let template: Template = serde_json::from_value(raw).map_err(|_| "schema")?;
        templates::validate(&template, file.official).map_err(|e| {
            if e.0 == "reserved_namespace" {
                "reserved_namespace"
            } else {
                "semantic"
            }
        })?;
        Ok(template)
    }
    /// Called by startup/background reload only; request paths never write snapshots.
    pub async fn reload(
        &self,
        db: &AppDb,
        files: Vec<TemplateFile>,
    ) -> Result<ReloadReport, ToolError> {
        let _reload = self.reload.lock().await;
        let previous = self.snapshot().await;
        let tx = SystemTx::begin(db).await?;
        let snapshots = tx.template_snapshots().await?;
        let mut report = ReloadReport::default();
        let mut parsed = Vec::new();
        let mut bad = BTreeSet::new();
        let mut counts = BTreeMap::new();
        for file in files {
            match self.parse(&file) {
                Ok(template) => {
                    *counts.entry(template.id.clone()).or_insert(0usize) += 1;
                    parsed.push((file, template));
                }
                Err(category) => {
                    bad.insert((file.official, file.filename.clone()));
                    report.rejected.push(RejectedTemplate {
                        filename: safe_filename(&file.filename),
                        category,
                    });
                }
            }
        }
        let mut templates = BTreeMap::new();
        let mut sources = BTreeMap::new();
        for (file, template) in parsed {
            let rejection = if counts.get(&template.id).copied().unwrap_or(0) > 1 {
                Some("duplicate_id")
            } else if snapshots
                .get(&template.id)
                .is_some_and(|old| !templates::compatible(old, &template))
            {
                Some("incompatible")
            } else {
                None
            };
            if let Some(category) = rejection {
                bad.insert((file.official, file.filename.clone()));
                report.rejected.push(RejectedTemplate {
                    filename: safe_filename(&file.filename),
                    category,
                });
                continue;
            }
            tx.save_template_snapshot(&template).await?;
            sources.insert(template.id.clone(), (file.official, file.filename));
            templates.insert(template.id.clone(), template);
            report.accepted += 1;
        }
        for (id, source) in &previous.sources {
            if bad.contains(source)
                && !templates.contains_key(id)
                && let Some(old) = previous.templates.get(id)
            {
                templates.insert(id.clone(), old.clone());
                sources.insert(id.clone(), source.clone());
            }
        }
        let next = Arc::new(TemplateCatalog::new(templates, sources)?);
        // Readers clone one whole generation. Commit and publication cannot interleave
        // with another reload or expose a generation whose snapshots rolled back.
        let mut publish = self.current.write().await;
        tx.commit().await?;
        *publish = next;
        for rejected in &report.rejected {
            log_rejection(&rejected.filename, rejected.category);
        }
        Ok(report)
    }
}
