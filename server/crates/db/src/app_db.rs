use sea_orm::{
    ConnectOptions, ConnectionTrait, Database, DatabaseConnection, DbBackend, DbErr, Statement,
};
#[derive(Clone)]
pub struct AppDb {
    pub(crate) connection: DatabaseConnection,
}
impl AppDb {
    pub async fn connect(url: &str) -> Result<Self, DbErr> {
        let mut options = ConnectOptions::new(url.to_owned());
        options.sqlx_logging(false);
        let connection = Database::connect(options).await?;
        let row = connection
            .query_one_raw(Statement::from_string(
                DbBackend::Postgres,
                "select current_user::text as role".to_owned(),
            ))
            .await?
            .ok_or_else(|| DbErr::Custom("missing database role".into()))?;
        if row.try_get::<String>("", "role")? != "jiabu_app" {
            return Err(DbErr::Custom(
                "Application connection requires jiabu_app".into(),
            ));
        }
        Ok(Self { connection })
    }
    pub async fn close(self) -> Result<(), DbErr> {
        self.connection.close().await
    }
}
