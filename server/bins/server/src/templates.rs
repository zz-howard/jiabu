//! Startup and SIGHUP filesystem orchestration. No request handler enters here.
use jiabu_db::AppDb;
use jiabu_tools::{
    ToolError,
    templates::{TemplateFile, TemplateStore, log_rejection, official_files},
};
use std::{path::Path, sync::Arc};
pub async fn load(db: &AppDb, store: &TemplateStore, data_dir: &Path) -> Result<(), ToolError> {
    let directory = data_dir.join("templates");
    let mut files = official_files();
    match tokio::fs::read_dir(&directory).await {
        Ok(mut entries) => loop {
            let entry = match entries.next_entry().await {
                Ok(Some(e)) => e,
                Ok(None) => break,
                Err(_) => {
                    log_rejection("templates", "io");
                    return Ok(());
                }
            };
            let path = entry.path();
            if path.extension().is_none_or(|e| e != "json") {
                continue;
            }
            let filename = entry.file_name().to_string_lossy().into_owned();
            let (body, error) = match tokio::fs::read(&path).await {
                Ok(bytes) => match String::from_utf8(bytes) {
                    Ok(body) => (body, None),
                    Err(_) => (String::new(), Some("json")),
                },
                Err(_) => (String::new(), Some("io")),
            };
            files.push(TemplateFile {
                filename,
                body,
                official: false,
                error,
            });
        },
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => {}
        Err(_) => {
            log_rejection("templates", "io");
            return Ok(());
        }
    }
    store.reload(db, files).await?;
    Ok(())
}
#[cfg(unix)]
pub fn start(
    db: AppDb,
    store: Arc<TemplateStore>,
    data_dir: std::path::PathBuf,
) -> Result<tokio::task::JoinHandle<()>, std::io::Error> {
    // Register before reporting the HTTP listener ready; a test/operator may HUP immediately.
    let mut signal = tokio::signal::unix::signal(tokio::signal::unix::SignalKind::hangup())?;
    Ok(tokio::spawn(async move {
        while signal.recv().await.is_some() {
            if load(&db, &store, &data_dir).await.is_err() {
                log_rejection("templates", "database");
            }
        }
    }))
}
