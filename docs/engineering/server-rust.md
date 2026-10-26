# 家簿 · Rust 服务端技术规范

> 版本号取自 crates.io / GitHub（2026-10-25～26 核实）。服务端**从零开始实现**；AI 层细节见 [AI 层设计](ai-layer.md)，选型依据见 [调研摘要](../research/library-evaluation-2026-10.md)。

## 0. 结论先行

1. **主干：Rust + Tokio + Axum + PostgreSQL 18，数据库访问用 SeaORM 2.0。** Axum 由 tokio 官方组织维护，是 2026 年 Rust 后端资料最多的组合。SeaORM 原生异步、底层就是 sqlx 0.9；版本锁定，幂等、outbox、同步游标这类关键查询配集成测试，特殊查询可退回 sea-query 或原生 SQL。
2. **AI 层：自有领域 trait + `AiRouter`**。默认提供方是 ChatGPT 订阅（官方 “Sign in with ChatGPT”，基于 async-openai 的自写适配器），其他提供方经 genai 0.7 接入作为降级备选。业务代码只认领域 trait。
3. **登录**：Argon2id 密码哈希 + **不透明随机令牌**（Bearer，数据库只存 SHA-256），不用 JWT。
4. **其余全用业界常规零件**：tower-http（追踪、请求 ID、超时、压缩、请求体上限）、tracing、thiserror / anyhow、serde、validator、config、utoipa（导出 OpenAPI）、object_store（原图先存本地磁盘，以后可换 S3）、image（缩略图）。
5. **发布与部署**：打 tag 后由 GitHub Actions 在原生 x86_64 / aarch64 runner 上构建，产出 GitHub Releases 二进制 + GHCR 多架构镜像；用 docker compose（服务端 + PostgreSQL 18）或 systemd 部署，**部署机不编译**。日常开发测试在 x86 Linux 构建机上进行。

## 1. 技术栈总表

图例：✅ v1 使用　🔶 备选 / 以后　❌ 不采用

| 类别 | crate / 工具 | 版本（发布日） | v1 | 说明 |
|---|---|---|---|---|
| 语言 | Rust stable | **1.99.1**（2026-10-13），edition 2024 | ✅ | |
| 异步运行时 | tokio | **1.54.1** | ✅ | 事实标准 |
| Web 框架 | axum / axum-extra | **0.8.9** / 0.12.6 | ✅ | tokio-rs 维护；复用 tower 中间件生态；官方 50+ 示例 |
| 中间件 | tower 0.5.3 / tower-http **0.7.1** | | ✅ | trace / request-id / timeout / compression / limit / catch-panic / sensitive-headers |
| 数据库 | PostgreSQL | **18.6**（18 支持到 2030-11） | ✅ | PG18 自带 `uuidv7()` |
| DB 访问 | **SeaORM**（sqlx-postgres、runtime-tokio-rustls、macros、with-uuid、with-chrono、with-json） | **2.0.4**（2026-09-27），锁定版本 | ✅ | 原生 async，基于 sqlx 0.9；MSRV 1.94 |
| 特殊查询 | sea-query（SeaORM 内置）/ 原生 SQL（`Statement`） | sea-query 1.0.2 | ✅ | `ON CONFLICT`、`FOR UPDATE SKIP LOCKED`、游标同步等 |
| 密码哈希 | argon2 | **0.6.0** | ✅ | Argon2id，OWASP 推荐 |
| 会话 | 自有 `sessions` 表 + 随机令牌（`rand` 0.10 + `sha2` 0.11） | — | ✅ | 见 3.1 |
| 登录限流 | tower_governor | 0.8.0 | ✅ | 防暴力破解 |
| 序列化 | serde 1.0.229 / serde_json 1.0.154 | | ✅ | |
| 校验 | validator | **0.21.0** | ✅ | `#[derive(Validate)]` |
| 错误 | thiserror 2 / anyhow 1 | | ✅ | 领域用 thiserror，入口与脚本用 anyhow |
| 配置 | config + secrecy | **0.15.27** / 0.10 | ✅ | 密钥只来自环境变量 / 文件，`secrecy` 防打印 |
| 日志追踪 | tracing 0.1.44 / tracing-subscriber 0.3.23 | | ✅ | JSON 日志 + 请求 ID，见第 6 节 |
| OpenAPI | utoipa **6.0.0** + utoipa-axum 0.3.0 + utoipa-scalar 0.4.0 | | ✅ | 代码即文档，导出 `openapi.json` 给客户端做契约测试 |
| ID / 时间 / 金额 | uuid 1.29（v7）· chrono 0.4.45 · 金额 `i64` 分 | | ✅ | 客户端生成 UUIDv7 当记录 ID 兼幂等键 |
| AI 层 | genai `=0.7.1` · async-openai 0.42 · oauth2 5 · schemars 1.2 · jsonschema 0.60 | | ✅ | 见 [AI 层设计](ai-layer.md) |
| 后台任务 | Postgres 任务表 + `FOR UPDATE SKIP LOCKED` + `LISTEN/NOTIFY`（同进程 tokio 任务） | | ✅ | 入库与入队同一事务 |
| 后台任务（备选） | apalis 1.0.0 + apalis-postgres 1.0.0 | 2026-10-12 刚发 1.0 | 🔶 | 任务种类变多时再评估 |
| 对象存储 | object_store | **0.14.2** | ✅ | `LocalFileSystem` ↔ `AmazonS3` 同一 trait |
| 图片 | image 0.25.10 · infer 0.22.0 · kamadak-exif 0.6.1 | | ✅ | 缩略图、真实 MIME 嗅探、方向；不支持 HEIC（客户端统一转 JPEG） |
| 测试 | axum-test 21.1.0 · testcontainers 0.28.0 · cargo-nextest 0.9.149 · wiremock 0.6 · insta 1.49 | | ✅ | 见第 7 节 |
| 质量 | rustfmt · clippy · cargo-deny 0.20.2 · cargo-audit 0.22.2 | | ✅ | |
| JWT | jsonwebtoken 11.1.0 | | ❌ | 无状态令牌难吊销；两人规模用不上 |
| 会话框架 | tower-sessions / axum-login | | ❌ | 版本链停在 tower-sessions 0.14 / sqlx 0.8，且以 Cookie 为中心 |
| S3 服务 | MinIO | | ❌ | 社区仓库已于 2026-04 归档 |

## 2. 工程结构（Cargo workspace）

```
server/
├─ Cargo.toml                # [workspace]，workspace.dependencies 统一版本
├─ Cargo.lock                # 提交
├─ config/ base.toml, local.toml, production.toml, ai.toml
├─ migrations/
├─ crates/
│  ├─ domain/                # 纯类型与规则：Record, Scope, Money, RecordEvent；无 IO
│  ├─ db/                    # SeaORM 实体与仓储：records, accounts, sessions, idempotency, sync, ai_jobs
│  ├─ ai/                    # ModelProvider trait、AiRouter、各适配器、校验
│  ├─ storage/               # object_store 封装 + 图片处理
│  └─ api/                   # axum 路由、提取器、中间件、utoipa、AppError
├─ bins/
│  ├─ server/ main.rs        # 启动 HTTP + 后台 worker
│  └─ admin/  main.rs        # 建用户、重置密码、提供方登录、导出 openapi.json、迁移
├─ tests/                    # 集成测试（真实 PostgreSQL 18 + axum-test）
└─ deploy/                   # docker-compose.yml、Dockerfile、jiabu.service（systemd）
```

依赖方向：`api → {db, ai, storage} → domain`。`domain` 不依赖任何 IO 库；`ai` 不暴露第三方库类型。

### 2.1 workspace.dependencies 草案

```toml
[workspace.dependencies]
tokio = { version = "1.54", features = ["full"] }
axum = { version = "0.8.9", features = ["macros", "multipart"] }
axum-extra = { version = "0.12", features = ["typed-header"] }
tower = "0.5"
tower-http = { version = "0.7", features = ["trace", "request-id", "timeout", "compression-gzip", "limit", "catch-panic", "sensitive-headers", "util"] }
sea-orm = { version = "=2.0.4", default-features = false, features = ["sqlx-postgres", "runtime-tokio-rustls", "macros", "with-uuid", "with-chrono", "with-json"] }
serde = { version = "1", features = ["derive"] }
serde_json = "1"
uuid = { version = "1.29", features = ["v7", "serde"] }
chrono = { version = "0.4", features = ["serde"] }
argon2 = "0.6"
sha2 = "0.11"
rand = "0.10"
thiserror = "2"
anyhow = "1"
validator = { version = "0.21", features = ["derive"] }
config = "0.15"
secrecy = { version = "0.10", features = ["serde"] }
tracing = "0.1"
tracing-subscriber = { version = "0.3", features = ["env-filter", "json"] }
utoipa = { version = "6", features = ["axum_extras", "uuid", "chrono"] }
utoipa-axum = "0.3"
object_store = "0.14"
image = "0.25"
infer = "0.22"
tower_governor = "0.8"
# AI 层依赖见 ai-layer.md
```

feature 组合以首次编译为准。SeaORM 升级是独立的 PR，必须跑完全部集成测试。

## 3. 认证与授权

### 3.1 登录与会话

- **密码**：`argon2` 0.6 的 Argon2id + PHC 字符串。
- **会话**：登录成功 → 生成 32 字节随机令牌 → 返回给 App（客户端用 flutter_secure_storage 保存，底层是 Android Keystore 加密）→ 数据库只存 `sha256(token)`、`user_id`、`device`、`expires_at`、`last_seen_at`。请求带 `Authorization: Bearer <token>`。登出 / 改密 = 删行。这是“有状态会话”的标准实现，所用加密原语都来自成熟 crate。
- **为什么不用 JWT**：吊销要另建黑名单；两人规模没有横向扩展需求。
- 首版预建两个账号，由 `admin` 命令创建和重置密码；无公开注册。
- 登录接口用 tower_governor 限流。

### 3.2 授权（家庭 / 私人）

- 自定义 Axum 提取器 `CurrentUser`（从令牌解析出内部用户 ID 和所属家庭）。
- 所有查询带范围过滤：`(scope = 'family' AND family_id = $fam) OR (scope = 'private' AND owner_id = $uid)`；仓储层提供唯一的“带范围查询”入口，禁止绕过。
- 写入前服务端**再次校验** scope，不信任客户端状态。
- 同步接口同样经过范围过滤。
- PostgreSQL 行级安全（RLS）可作为第二道防线（待定）。

## 4. API 原则

> **API 契约尚未定稿，将在服务端开工时重新编写**，由 utoipa 从代码生成 `openapi.json` 并提交进仓库。以下是契约必须遵守的原则。

- **幂等写入**：客户端为每条记录生成 UUIDv7 作 `id`，每个改动请求带 `Idempotency-Key` 头（与 IETF httpapi 草案同名）。服务端在同一事务内：`INSERT INTO idempotency (user_id, key, request_hash) … ON CONFLICT DO NOTHING`；已存在且有保存的响应则直接回放；请求体哈希不同则返回 422。`records` 用 `INSERT … ON CONFLICT (id) DO NOTHING`。
- **outbox 同步**：客户端把离线期间的改动按顺序推送；`POST /sync/push` 批量提交（每条带幂等键），逐条返回结果。
- **change_seq 游标**：每次改动写入全局递增的 `change_seq`（PostgreSQL sequence）；`GET /sync?since=<cursor>` 返回 seq 更大的记录（含已作废的“墓碑”）和新游标。
- **乐观并发**：更新带 `expected_version`，版本不符返回 409，客户端拉取最新版本后提示用户。
- **请求 ID**：每个请求带 `X-Request-Id`（UUIDv7，客户端生成，离线重发沿用同一个）；服务端校验格式后沿用，没有才自己生成，并在响应头回传。
- **统一错误格式**：RFC 9457 风格 `application/problem+json`：`{type, title, status, detail, request_id}`；内部错误只记日志不外泄细节。
- **AI 解析异步化**：提交原话 / 图片后立即返回“待 AI 处理”状态；结果（记录草稿、追问、非记账回复）通过同步接口拉取。
- **其他**：`/healthz` 健康检查；`/client-logs` 接收客户端日志；所有路径对反向代理子路径透明（服务端不感知前缀）。
- Axum 默认请求体上限 2 MB（`DefaultBodyLimit`），图片上传路由单独调大（例如 20 MB）；手机 App 不需要 CORS。

### 4.1 路由骨架（示意）

```rust
let api = OpenApiRouter::new()
    .routes(routes!(auth::login, auth::logout))
    .routes(routes!(records::create, records::list))
    .routes(routes!(records::update, records::void))
    .routes(routes!(sync::pull, sync::push))
    .routes(routes!(blobs::upload, blobs::get));
let (router, openapi) = api.split_for_parts();
let app = router
    .layer(TraceLayer::new_for_http())
    .layer(PropagateRequestIdLayer::x_request_id())
    .layer(SetRequestIdLayer::x_request_id(AcceptOrMakeRequestId)) // 自定义 MakeRequestId：优先沿用客户端的值
    .layer(TimeoutLayer::new(Duration::from_secs(30)))
    .layer(CompressionLayer::new())
    .with_state(state);
```

## 5. 数据模型与关键模式

### 5.1 表结构草案（PostgreSQL 18）

```sql
create table users (id uuid primary key default uuidv7(), username text unique not null,
  password_hash text not null, family_id uuid not null, created_at timestamptz not null default now());
create table sessions (token_hash bytea primary key, user_id uuid not null references users,
  device text, expires_at timestamptz not null, last_seen_at timestamptz not null default now());
create table accounts (id uuid primary key, family_id uuid not null, owner_id uuid not null references users,
  scope text not null check (scope in ('family','private')), kind text not null check (kind in ('real','purpose')),
  name text not null, opening_balance_minor bigint not null default 0,
  monthly_allocation_minor bigint, allocation_day smallint default 1, auto_allocate boolean not null default false,
  archived_at timestamptz, change_seq bigint not null, version int not null default 1);
create table records (id uuid primary key, family_id uuid not null, owner_id uuid not null references users,
  scope text not null check (scope in ('family','private')), kind text not null,
  amount_minor bigint, account_id uuid, purpose_id uuid, tags text[] not null default '{}',
  content jsonb not null default '{}', status text not null, version int not null default 1,
  change_seq bigint not null, voided boolean not null default false,
  created_at timestamptz not null, updated_at timestamptz not null);
create sequence change_seq;
create table record_events (id bigint generated always as identity primary key, record_id uuid not null,
  actor_id uuid not null, request_id uuid, kind text not null, before jsonb, after jsonb,
  at timestamptz not null default now());
create table idempotency (user_id uuid not null, key text not null, request_hash bytea not null,
  response_status smallint, response_body jsonb, created_at timestamptz not null default now(),
  primary key (user_id, key));
create table blobs (sha256 bytea primary key, mime text not null, bytes bigint not null,
  width int, height int, uploaded_by uuid not null, scope text not null, created_at timestamptz not null default now());
-- ai_jobs / ai_calls 见 ai-layer.md
```

金额一律 `bigint` 存“分”（`*_minor` 列），不用浮点；主键用 UUIDv7。

### 5.2 关键模式

1. **幂等写入**：见第 4 节。
2. **AI 解析任务**：原话 / 图片入库时同事务插入 `ai_jobs(status = 'queued')`；后台 worker `SELECT … FOR UPDATE SKIP LOCKED LIMIT 1` 取任务 → 调 `AiRouter` → 结果经校验后写 `records` → 任务置 `done`；失败指数退避；需要追问则置 `waiting_user`。细节见 [AI 层设计](ai-layer.md#6-任务与追问状态)。
3. **追加式审计 / 撤销**：`record_events(record_id, actor_id, request_id, kind[create|update|void|restore], before, after, at)` 只 INSERT（应用数据库角色对该表无 UPDATE / DELETE 权限）。撤销 = 追加一条反向事件并更新 `records` 当前态，绝不删除历史。
4. **余额**：余额由记录推导（开户余额 + 关联记录），一笔支出同时影响真实账户和用途账户、只计一次消费；月度拨入和逻辑调拨是独立记录类型，不算收入或消费。
5. **家庭 / 私人隔离**：每行带 `scope`、`owner_id`、`family_id`；聊天会话按内部用户 ID 隔离，私人上下文绝不进入另一人的模型请求。

### 5.3 原图存储

- v1：`object_store::local::LocalFileSystem` 存原图到 `<data_dir>/blobs/{sha256 前 2 位}/{sha256}`（内容寻址，天然去重），数据库存元数据（大小、MIME、宽高、上传者、scope）。以后换 S3 兼容服务只换构造函数。
- 处理：`infer` 嗅探真实类型（不信任客户端 Content-Type）；`image` 生成 512px 缩略图；按 EXIF 方向转正；对外下发的图片重新编码以去掉 GPS 等 EXIF（原图保留供 AI 和核对）。
- 下载：经鉴权后流式返回（`tokio_util::io::ReaderStream`），不开放静态目录。

### 5.4 中间件、配置、错误、校验

- tower-http：`trace`、`request-id`、`timeout`、`compression-gzip` / `-zstd`、`limit`、`catch-panic`、`sensitive-headers`（日志隐藏 Authorization）。
- 配置：`config` 读取 `config/base.toml` + `config/{env}.toml` + 环境变量覆盖；密钥只来自环境变量 / 文件，用 `secrecy` 包装。
- 错误：领域错误 `enum AppError`（thiserror）实现 `IntoResponse`，统一输出 problem+json。
- 校验：`validator` 派生（金额 > 0、备注长度等），业务规则在 domain 层。

## 6. 日志与可追踪性

目标：拿到一个 ID，就能把“手机上点了什么 → 服务器收到什么 → AI 任务怎么跑的 → 数据库改了什么”串成一条线。

- **一个请求 ID 贯穿全程**：客户端每个用户动作生成 `X-Request-Id`，离线重发沿用（与幂等键一起存在 outbox 里）；服务器优先接收客户端的值并校验格式。
- **每行日志带上下文**：`tracing` 请求 span 带 `request_id`、内部 `user_id`、路由、耗时、状态码。输出 JSON，一行一条，便于 `grep` / `jq` 过滤。
- **跨进 AI 任务**：`ai_jobs` 存 `origin_request_id`；worker 开新 span，带 `job_id`、`origin_request_id`、`provider_id`、模型名、重试次数、降级原因、耗时、token 用量。
- **跨进审计**：`record_events.request_id` 可反查“这笔账是哪次操作改的”。
- **错误回执带 ID**：错误响应带 `request_id`，App 错误提示和客户端日志也显示 / 记录它；用户截个图就能定位服务器日志。
- **客户端日志同一套 ID**：`/client-logs` 每条带 `request_id`、App 版本、设备型号、系统版本。
- **不记敏感内容**：只记 ID、元数据、耗时和错误类型；不记密码、令牌、记账原话、图片和模型完整回复。需要看原话时到库里按 ID 查。
- **保留与查看**：日志按天滚动，保留 30 天；v1 用文件 + `jq`。以后要可视化再接 OpenTelemetry（`tracing-opentelemetry`），span 代码不用改。

## 7. 测试与质量

- `cargo nextest run`；集成测试连**真实 PostgreSQL 18**（本地用 testcontainers 0.28，CI 用 service 容器），每个测试使用独立的临时数据库并自动跑迁移。
- **关键查询必须有集成测试**：幂等（重复提交、哈希不同 422、响应回放）、`ON CONFLICT`、`FOR UPDATE SKIP LOCKED` 并发取任务、change_seq 游标增量与墓碑、范围过滤（私人记录对另一用户不可见）、嵌套事务（SeaORM 与 SQLx 一样用 SAVEPOINT 实现）。
- HTTP 级测试用 `axum-test`；SeaORM 的 `MockDatabase` 只用于快照生成的 SQL，不替代真库测试。
- AI 适配器：wiremock 回放 + insta 请求体快照，见 [AI 层设计](ai-layer.md#9-测试策略)。
- 静态检查：`cargo fmt --check`、`cargo clippy --all-targets -- -D warnings`、`cargo deny check`（许可证 + 漏洞库）、`cargo audit`。

### 7.1 给 AI 编程代理的规则

`server/AGENTS.md` 写明项目规则，例如：

- 所有改动请求必须带幂等键；所有查询必须经范围过滤入口。
- 请求路径上禁止 `unwrap` / `expect`。
- 新接口必须有 utoipa 注解和集成测试。
- 金额只用 `i64` 分；时间一律 `timestamptz`。
- 日志不得出现令牌、密码、原话。

可参考 microsoft/rust-guidelines（MIT，含给 AI 的合并版 `src/agents/all.txt`）、rust-lang/api-guidelines、leonardomso/rust-skills（MIT，挑选规则拷贝）。**不安装**带钩子脚本的第三方 skills 插件（有的插件注册了几乎匹配所有提问的 UserPromptSubmit 钩子并执行 shell 脚本），只阅读参考。clippy 严格模式本身就是最好的“AI 规则”。

## 8. CI、发布与部署

### 8.1 CI（每个 PR）

GitHub Actions `ubuntu-24.04`：fmt → clippy → nextest（PostgreSQL 18 service 容器）→ cargo-deny / cargo-audit → 导出 `openapi.json` 并检查与仓库中一致。

### 8.2 发布（打 tag）

- 在**原生 runner** 上分别构建，不交叉编译：`ubuntu-24.04`（x86_64）与 `ubuntu-24.04-arm`（aarch64）。公开仓库使用标准 GitHub 托管 runner 免费且不限量（arm64 公开仓库规格 4 核 / 16 GB）。
- `[profile.release] lto = "thin"`。
- 产物：
  - GitHub Releases：`jiabu-server-<version>-<target>.tar.gz`（含 `server`、`admin` 二进制、示例配置、systemd 单元）+ SHA-256 校验文件；
  - GHCR 多架构镜像 `ghcr.io/<owner>/jiabu-server:<version>`（linux/amd64 + linux/arm64；各架构原生构建后按 digest 推送，再合并成 manifest list）。

### 8.3 部署

两种方式，部署机都**不编译**：

- **docker compose**：`deploy/docker-compose.yml` 包含服务端镜像 + `postgres:18`（命名卷、只在内部网络暴露）。
- **systemd**：从 Releases 下载对应架构的二进制，`deploy/jiabu.service` 管理进程；PostgreSQL 18 可用系统包或容器。

通用约定：

- 迁移在启动时执行，或部署脚本中执行 `admin migrate`。
- 反向代理（如 Caddy）剥掉子路径前缀后转发，后端不感知子路径；OpenAPI `servers` 填完整前缀。示例：

  ```
  <域名> {
      handle_path /<子路径>/* {
          reverse_proxy localhost:<端口>
      }
  }
  ```

- 反向代理默认不限请求体大小，限制交给后端。
- 每日 `pg_dump` 备份到独立的备份目录；原图目录一并备份。
- 密钥（数据库密码、提供方凭据）只通过环境变量或权限 600 的文件注入，绝不进镜像或仓库。

## 9. 风险

| # | 事项 | 对策 |
|---|---|---|
| 1 | SeaORM 2.0 刚于 2026-07 稳定，提交主要来自一位维护者 | 锁定版本；关键查询集成测试；必要时退回 sea-query / 原生 SQL |
| 2 | sqlx（SeaORM 底层）发版慢、核心维护者少 | 生态大量绑定 sqlx 0.9，短期风险低；持续关注 |
| 3 | 默认 AI 提供方的合规与额度 | 见 [AI 层设计 · 风险](ai-layer.md#11-风险) |
| 4 | 手机上传 HEIC | 客户端统一转 JPEG 再上传 |
| 5 | 以上代码片段未编译 | 以首次编译和 docs.rs 为准 |
