# server/ — Rust 服务端（尚未创建）

这里将放家簿的 Rust 服务端，采用 **Cargo workspace**（多个 crate 共用一份依赖版本表和一个 `Cargo.lock`）：

```
server/
  Cargo.toml                 # [workspace] + workspace.dependencies
  config/                    # base.toml / {env}.toml / ai.toml（密钥只来自环境变量）
  migrations/
  crates/
    domain/                  # 纯类型与规则，无 IO
    db/                      # SeaORM 实体与仓储
    ai/                      # ModelProvider trait、AiRouter、各提供方适配器
    storage/                 # 原图存储与图片处理
    api/                     # Axum 路由、提取器、中间件、OpenAPI
  bins/
    server/                  # HTTP 服务 + 后台任务
    admin/                   # 建用户、重置密码、提供方登录、导出 openapi.json
  tests/                     # 集成测试（真实 PostgreSQL 18）
  deploy/                    # docker compose 与 systemd 单元
```

服务端从零重写；API 契约将在开工时重新编写。开工前请先读：

- [Rust 服务端技术规范](../docs/engineering/server-rust.md)
- [AI 层设计](../docs/engineering/ai-layer.md)
- [产品需求](../docs/product/requirements.md)
