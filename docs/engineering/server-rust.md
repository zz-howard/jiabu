# 家簿 · Rust 服务端技术规范

> 文档版本 v0.2（2026-10-27）：按[技术方案](technical-design.md) v0.3 第 13 节同步；表结构、接口清单、同步协议以技术方案为准。版本号取自 crates.io / GitHub（2026-10-25～26 核实）。服务端**从零开始实现**；AI 层细节见 [AI 层设计](ai-layer.md)，选型依据见 [调研摘要](../research/library-evaluation-2026-10.md)。

## 0. 结论先行

1. **主干：Rust + Tokio + Axum + PostgreSQL 18，数据库访问用 SeaORM 2.0。** Axum 由 tokio 官方组织维护，是 2026 年 Rust 后端资料最多的组合。SeaORM 原生异步、底层就是 sqlx 0.9；版本锁定，幂等、outbox、同步游标这类关键查询配集成测试，特殊查询可退回 sea-query 或原生 SQL。
2. **AI 层：自有领域 trait + `AiRouter`**。默认提供方是 ChatGPT 订阅（官方 “Sign in with ChatGPT”，基于 async-openai 的自写适配器），其他提供方经 genai 0.7 接入作为降级备选。业务代码只认领域 trait。
3. **登录**：Argon2id 密码哈希 + **不透明随机令牌**（Bearer，数据库只存 SHA-256），不用 JWT。
4. **数据按“空间”隔离**：空间是独立账本（自己的资金账户、用途账户、记录、资料、聊天与 AI 对话）。所有业务行带 `space_id`，每个请求都先解析出当前用户在该空间的**活跃成员**身份，否则一律按“不存在”（404）处理；同步按空间分别维护游标。
5. **其余全用业界常规零件**：tower-http（追踪、请求 ID、超时、压缩、请求体上限）、tracing、thiserror / anyhow、serde、validator、config、utoipa（导出 OpenAPI）、object_store（原图先存本地磁盘，以后可换 S3）、image（缩略图）。
6. **发布与部署**：打 tag 后由 GitHub Actions 在原生 x86_64 / aarch64 runner 上构建，产出 GitHub Releases 二进制 + GHCR 多架构镜像；用 docker compose（服务端 + PostgreSQL 18）或 systemd 部署，**部署机不编译**。日常开发测试在 x86 Linux 构建机上进行。
7. **聊天回复用 ChatWeave 协议（草案）**：服务端把 AI 结果确定性地映射成语义块（文字、记录卡、指标、表格、选项……），经 SSE 流式下发、`chat_entries` 持久化并同步；UI 动作经 ChatWeave 的 Action Registry，再由统一的 `authorize()` 把关。ChatWeave 是独立开源库，不含任何家簿概念（见 4.2）。
8. **AI 运行可以暂停几天**：持久执行自写在 PostgreSQL 里（运行行 + 只追加的步骤日志），不引入 Temporal 等引擎；暂停时没有线程在等，崩溃后从日志接着做，会改数据的工具与日志同一事务、恰好一次（见 [AI 层第 14 节](ai-layer.md#14-持久执行暂停恢复与崩溃)）。
9. **管理能力单独一个入口，碰不到内容**：带版本号的管理 API（`/admin/v1`）只在本机 Unix 套接字上监听，用 `admin` 命令创建的管理服务令牌访问；只管账号、AI 提供方 / 模型 / 价格和用量计量。能看到空间名称（用来把用量和空间对上号），但**没有任何返回账本、资料、聊天或运行日志内容的接口**，由 crate 依赖边界、独立的数据库角色（列级授权）和测试三层保证。自己部署的人用 `admin` 命令完成同样的事（同一套服务层）。图形化的管理控制台是单独的服务，不在本仓库，本仓库也不依赖它（第 9 节）。
10. **个人 API key**：用户在 App 里创建，以本人身份调用公开 API；权限 = 本人权限 ∩ key 的范围（只读 / 读写）；key 不单独选空间，本人当前在册的空间它都能用（P51）。只存 SHA-256，固定前缀 `jiabu_pat_` 便于密钥扫描，按 key 限流，所有操作标注“通过 API key”（3.3）。**key 不能使用 AI 对话**，也不能触发任何 AI 运行；key 进不了管理 API。
11. **AI 的工具同时是公开 API**：每个工具只定义一次（`crates/tools`），同一份定义既注册进 Agent 循环，也是手机和 key 写入空间内容的唯一途径（经 `POST /sync/push` 或工具路由，没有单独的记录 REST 写接口），并由注册表自动生成 `POST /spaces/{space_id}/tools/{tool_name}` 路由和 OpenAPI；参数校验、空间绑定、权限检查、业务校验和执行走同一个函数。AI 要做需要确认的写入时先弹确认卡，key 调用写入类工具则直接执行（4.3）。

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
| 登录 / API key 限流 | tower_governor（底层 governor 0.10） | 0.8.0 | ✅ | 登录防暴力破解；API key 按 key 限流（3.3） |
| 密钥加密 | chacha20poly1305（XChaCha20-Poly1305） + zeroize | **0.11.0** / 1.9.1 | ✅ | 管理 API 写入的提供方 API key 等密钥落库前加密，主密钥来自文件（9.6） |
| 令牌校验位 | crc32fast | 1.5.3 | ✅ | API key / 管理令牌末尾的校验位：密钥扫描工具可离线校验格式，减少误报 |
| 序列化 | serde 1.0.229 / serde_json 1.0.154 | | ✅ | |
| 校验 | validator | **0.21.0** | ✅ | `#[derive(Validate)]` |
| 错误 | thiserror 2 / anyhow 1 | | ✅ | 领域用 thiserror，入口与脚本用 anyhow |
| 配置 | config + secrecy | **0.15.27** / 0.10 | ✅ | 密钥只来自环境变量 / 文件，`secrecy` 防打印 |
| 日志追踪 | tracing 0.1.44 / tracing-subscriber 0.3.23 | | ✅ | JSON 日志 + 请求 ID，见第 6 节 |
| OpenAPI | utoipa **6.0.0** + utoipa-axum 0.3.0 + utoipa-scalar 0.4.0 | | ✅ | 代码即文档，导出 `openapi.json` 给客户端做契约测试 |
| ID / 时间 / 金额 | uuid 1.29（v7）· chrono 0.4.45 · 金额 `i64` 分 | | ✅ | 客户端生成 UUIDv7 当记录 ID 兼幂等键 |
| AI 层 | genai `=0.7.1` · async-openai 0.42 · oauth2 5 · schemars 1.2 · jsonschema 0.60 | | ✅ | 见 [AI 层设计](ai-layer.md) |
| 聊天协议 | [ChatWeave](https://github.com/zz-howard/chatweave) 的 `chatweave-protocol`（块与事件类型、Schema 校验、限制）+ `chatweave-server`（流生成器、SSE 辅助、Action Registry） | 未发布；开发期 `[patch]` 路径依赖 | ✅ | 见 4.2 |
| 后台任务 | AI 运行表 `agent_runs` 本身就是队列：`FOR UPDATE SKIP LOCKED` + 租约 + 防护令牌 + `LISTEN/NOTIFY`（同进程 tokio 任务，每 5 秒轮询兜底） | | ✅ | 入库与入队同一事务；持久执行（暂停 / 恢复 / 崩溃）见 [AI 层第 14 节](ai-layer.md#14-持久执行暂停恢复与崩溃) |
| 后台任务（备选） | apalis 1.0.0 + apalis-postgres 1.0.0 | 2026-10-12 刚发 1.0 | 🔶 | 任务种类变多时可替代领取 / 重试部分；“暂停”和防护令牌仍需自写，v1 不引入 |
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
├─ migrations/              # 纯 SQL 迁移，唯一来源（技术方案 10.1）
├─ templates/official/      # 官方资料模板 JSON（编译进二进制）
├─ openapi/                 # openapi.json · openapi-admin.json（CI 检查与代码一致）
├─ crates/
│  ├─ domain/                # 纯类型与规则：Money、记录种类与余额规则、拨入日期、预置分类、资料模板协议、错误代码；无 IO
│  ├─ db/                    # SeaORM 实体（从迁移后的库生成）与仓储：SpaceTx / SystemTx、按空间的仓储函数、同步查询、幂等表
│  ├─ ai/                    # ModelProvider trait、AiRouter、各适配器、校验
│  ├─ tools/                 # AI 的工具：AgentTool 实现 + ToolRegistry（Agent 循环与工具 API 共用，4.3）
│  ├─ chat/                  # ChatWeave 接入：工具结果 → 语义块映射、x-jiabu.* 块 Schema、PostgreSQL 事件日志、消息存储、进程内广播、SSE 辅助
│  ├─ agent/                 # 运行的生命周期：RunService（开始 / 停止 / 重试 / 回答）、worker、journal、清扫器、ChatWeave 动作处理器
│  ├─ storage/               # object_store 封装 + 图片处理
│  ├─ api/                   # 公开 API（/v1，App 与个人 API key）：axum 路由、提取器、中间件、同步、工具路由生成、utoipa、AppError
│  ├─ db-admin/              # 管理侧专用的 SeaORM 实体：只覆盖允许管理侧访问的表和列（9.2）
│  ├─ admin/                 # 管理服务层：账号、提供方 / 模型 / 路由 / 价格、用量查询、管理审计、管理令牌
│  └─ admin-api/             # 管理 API（/admin/v1）的 axum 路由与 utoipa；只依赖 admin
├─ bins/
│  ├─ server/ main.rs        # 启动公开 HTTP、管理 API 监听器（Unix 套接字）+ 后台 worker
│  └─ admin/  main.rs        # 管理命令：账号、提供方（含 ChatGPT 订阅登录）、价格、用量、管理令牌、导出 OpenAPI、迁移（9.8）
├─ tests/                    # 集成测试（真实 PostgreSQL 18 + axum-test）
└─ deploy/                   # docker-compose.yml、Dockerfile、jiabu.service（systemd）
```

依赖方向：`api → agent → {chat, tools, ai} → {db, storage} → domain`，`tools → {db, storage, domain}`（`api` 也可直接用 `chat` / `tools` / `db` / `storage`：工具 API 的路由由 `api` 从 `ToolRegistry` 生成）。`tools` 不依赖 `ai` 和 ChatWeave：工具本身不知道调用它的是模型还是 HTTP 请求。`domain` 不依赖任何 IO 库；`ai` 不暴露第三方库类型；只有 `chat`、`agent`、`api` 依赖 ChatWeave 的 crate（`agent` 实现 ChatWeave 的 `ActionHandler`）。另有一条 CI 检查：`crates/api` 里不得出现 `SystemTx`（技术方案 4.3）。

管理侧单独一条线：`admin-api → admin → {db-admin, domain}`；`bins/admin` 也只调用 `admin`（另加 `ai` 的 SIWC 登录流程）。`admin`、`admin-api` **不得**依赖 `db`、`chat`、`agent`、`storage`、`api`：CI 用 `cargo tree -p jiabu-admin -p jiabu-admin-api -e normal` 检查，出现这几个 crate 就失败。`db-admin` 里没有记录、资料、聊天、运行日志这些实体，管理侧代码想读也没有类型可用（9.2）。

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
chatweave-protocol = { git = "https://github.com/zz-howard/chatweave", rev = "<提交>" }   # 发布后改版本号
chatweave-server = { git = "https://github.com/zz-howard/chatweave", rev = "<提交>", features = ["axum"] }
# AI 层依赖见 ai-layer.md

# 开发期本机覆盖（写在开发者本机的 .cargo/config.toml，不入库）：
# [patch."https://github.com/zz-howard/chatweave"]
# chatweave-protocol = { path = "../../chatweave/rust/crates/chatweave-protocol" }
# chatweave-server   = { path = "../../chatweave/rust/crates/chatweave-server" }
```

feature 组合以首次编译为准。SeaORM 升级是独立的 PR，必须跑完全部集成测试。

## 3. 认证与授权

### 3.1 登录与会话

- **密码**：`argon2` 0.6 的 Argon2id + PHC 字符串。
- **会话**：登录成功 → 生成 32 字节随机令牌 → 返回给 App（客户端用 flutter_secure_storage 保存，底层是 Android Keystore 加密）→ 数据库只存 `sha256(token)` 和会话元数据（`sessions` 主键是 `id`，便于按会话删除；表结构见[技术方案 3.2](technical-design.md#32-账号会话api-key)）。请求带 `Authorization: Bearer <token>`。登出 / 改密 = 删行。这是“有状态会话”的标准实现，所用加密原语都来自成熟 crate。
- **为什么不用 JWT**：吊销要另建黑名单；两人规模没有横向扩展需求。
- 首版预建两个账号，由 `admin` 命令或管理 API 创建（9.4）；无公开注册。创建账号时在同一事务内为其建好**默认个人空间**（`is_default = true`，本人为 owner）。
- **停用与临时密码**：`users.disabled_at` 非空的账号登录被拒，令牌和 API key 鉴权时一并检查（停用时同一事务删除全部会话）。管理员重置密码 = 生成一次性临时密码（只显示一次）+ `must_change_password = true` + 删除全部会话；带此标记登录时只返回受限令牌，只能调用改密码接口，改完才是正常会话。服务端记下最近一次管理员重置密码的时间，本人下次登录时随登录响应返回，App 显示一次“你的密码在……被管理员重置”（P49）。
- 登录接口用 tower_governor 限流。
- 令牌（会话令牌、个人 API key、管理令牌）都只存 SHA-256，按哈希的唯一索引查找；三者在不同的表、不同的前缀（会话令牌无前缀，`jiabu_pat_`，`jiabu_adm_`），公开 API 不接受管理令牌，管理 API 只接受管理令牌。

### 3.2 授权（空间成员）

- **账号与空间成员是两个实体**：`users` 是登录身份；加入某个空间会生成一行 `space_members`（每个空间内的显示名、角色 owner / member、状态 active / left）。业务数据的创建者引用 `space_members.id`（`created_by_member_id`），不直接引用 `user_id`。
- 自定义 Axum 提取器 `CurrentUser`（从令牌解析出内部用户 ID）；凡是路径或请求体涉及空间的接口，再经提取器 `SpaceMember` 按 `(space_id, user_id, status = 'active')` 解析成员身份。查不到一律返回 **404**（不是 403），让非成员无法判断某个空间是否存在。
- 所有业务查询必须带 `space_id`，并与活跃成员关系联查；仓储层只提供“带空间成员校验的查询”入口，禁止绕过。`GET /spaces` 只返回当前用户为活跃成员的空间，不返回其他空间的名称、数量或任何动态。
- 写入前服务端**再次校验**成员身份，并校验引用的账户、标签、资料都属于同一空间；不信任客户端状态。
- 同步接口同样只返回活跃成员所在空间的数据（见第 4 节）。
- **成员管理**：创建空间（创建者成为 owner）、改名、邀请已有账号（v1 没有公开注册，只能邀请预建账号；对方接受后才成为成员，P62）、owner 移除成员、成员自行退出、转让 owner、删除空间。默认个人空间拒绝邀请他人，也不能退出和删除。最后一位 owner 不能直接退出，须先转让 owner 或删除空间（P18）。**转让**：owner 可以转给任何一位活跃成员（P57）。**删除**：只在空间里只剩请求者一人时允许，请求须带上空间名作确认，删除不可恢复（P57）；删除后的数据清理见[技术方案 3.10](technical-design.md#310-数据库角色rls-与删除空间)。
- **邀请的状态转换**（[技术方案 3.3](technical-design.md#33-空间与成员)）：接受 / 拒绝 / 撤回都在空间锁里做条件写入 `WHERE status = 'pending'`，并发时只有一个生效；接受时校验请求者是被邀请人、空间未删除、邀请人仍是活跃成员；邀请人退出或被移出、删除空间时，同一事务里把待处理的邀请改为 `cancelled`（P64）。
- **退出 / 被移除**：该行 `status = 'left'`、写 `left_at` 和 `left_reason`；该成员在这个空间里未结束的运行同一事务取消；之后对该空间的所有请求立即 404（会话本身不失效，只是空间校验不通过）。其创建的记录保留，界面仍显示其显示名并标注“已退出”。
- **重新加入**：复用同一行 `space_members`（改回 `active`、`join_epoch + 1`、更新 `joined_at`、清空 `left_at`），旧记录自动重新关联；每次加入 / 退出都追加一条审计事件。
- **模块与按模块授权（扩展预留）**：空间内容分模块（v1：`ledger` 账本、`documents` 资料；以后加 `memories` 等）。所有内容表带 `module` 列；`space_member_grants (member_id, module, level)` 记录每位成员对每个模块的级别（`none` / `read` / `write` / `manage`）。v1 加入空间时为每个模块写入 `manage`（owner）或 `write`（member），不提供授权界面。
- **统一授权入口**：所有业务读写只经一个函数 `authorize(member, module, action)`（由 `SpaceMember` 提取器之后的仓储层调用），禁止在 handler 里写“是成员就放行”。无权模块与非成员同样返回 404；同步、AI 上下文组装、导出都调用同一函数。
- **单条可见范围（预留）**：内容表预留可空的 `visibility jsonb`（例如指定可见成员列表），v1 恒为空、不读取。
- 不区分成人 / 未成年账号类型，差异由按模块授权表达。
- PostgreSQL 行级安全（RLS，以空间成员关系与模块授权为条件）可作为第二道防线（待定）。

### 3.3 个人 API key

产品规则见[需求 · 个人 API key](../product/requirements.md#个人-api-key)。

**格式**：`jiabu_pat_` + 40 位 base62 随机字符（`rand` 的系统随机源，约 238 位熵）+ 6 位 base62 的 CRC32 校验位，共 56 个字符。固定前缀加校验位，让密钥扫描工具能可靠识别（以后可向代码托管平台登记该格式）。列表里显示的是 `display_prefix` = `jiabu_pat_` + 随机部分的前 6 位。

**创建与保存**：`POST /me/api-keys` 只接受**会话令牌**（key 不能创建 key）。服务端生成 key、在响应里返回一次明文，库里只存 `sha256(key)`；明文不进日志、不进幂等响应缓存（该接口的幂等记录只存 key 的 ID，重放时返回“已创建，明文不再显示”）。每个账号最多 20 个有效 key。

**鉴权**：`Authorization: Bearer jiabu_pat_…`。提取器先看前缀和校验位（格式不对直接 401，不查库），再按哈希查 `api_keys`：未撤销、未过期、账号未停用。得到 `Principal { user_id, via: Session(session_id) | ApiKey { id, name, scope } }`，后面的提取器和仓储层都拿它。key 没有自己的空间范围（P51、S24）：能访问哪些空间，完全由本人**当前**的活跃成员身份决定，包括以后新加入的空间；退出后立即 404，重新加入后自动恢复。

**授权 = 本人权限 ∩ key 的范围**，都在统一的授权入口里判断，不在 handler 里写：

| 检查 | 不满足时 |
|---|---|
| 空间成员身份（与会话相同，3.2） | 404 |
| `authorize(member, module, action)`（与会话相同） | 404 |
| 只读 key 只允许读类动作、只能调用 `effect = read` 的工具 | 403 `api_key_read_only`（空间对它是存在的，不泄露信息） |
| 接口不在 key 的允许范围（下表） | 403 `api_key_not_allowed`；AI 相关的为 403 `api_key_ai_not_allowed` |

| 接口类别 | 会话 | API key |
|---|---|---|
| 空间列表、同步（`/sync/push` 的每条是一次工具调用）、原图上传下载 | ✅ | ✅（列表返回本人在册的全部空间；写入需要读写 key） |
| 工具 API：`GET /spaces/{space_id}/tools`、`POST /spaces/{space_id}/tools/{tool_name}`（4.3） | ✅ | ✅（只读 key 只能调用只读工具；写入类工具直接执行，不弹确认） |
| 聊天与一切 AI：提交消息、SSE 流、动作（回答追问 / 确认）、停止；会让 AI 运行的提交 | ✅ | ❌ `api_key_ai_not_allowed` |
| `/me/api-keys` 的增、改、撤销；改密码；会话管理 | ✅ | ❌ |
| 新建空间；空间成员管理：邀请、移除、退出、删除空间、转让所有权（P41、P61） | ✅ | ❌ |
| 管理 API | ❌ | ❌（不同的监听器，第 9 节） |

**key 不能使用 AI**（P31）：key 发起不了任何 AI 运行，判断只放在两处、都不靠 handler 自觉：

- 路由层：聊天的全部接口（4.2）用提取器 `SessionOnly`，key 请求直接 403 `api_key_ai_not_allowed`；
- 服务层：创建运行的入口 `RunService::start` / `retry` 要求 `Principal.via = Session`，否则返回同样的错误。聊天消息只经 `POST /spaces/{space_id}/chat/messages`，不进 `/sync/push`，所以 push 里没有会触发 AI 的条目。

所以运行一定来自手机上的本人：`agent_runs`、`conversations`、`chat_actions`、`ai_calls` 都没有 key 的归属列，key 也不产生 AI 用量。key 要查数、记账，就调用工具 API（4.3）或经 `/sync/push` 提交工具调用，自己给出结构化的参数。

**写入直接执行**：确认卡是 AI 对话里的中断（AI 层 14.4 C），key 没有对话，所以 key 经工具 API 或 `/sync/push` 的写入**不确认、直接执行**——调用方是用户自己授权、并为之负责的脚本或 agent。补偿手段是：写入必须带 `Idempotency-Key`（缺少时 400 `idempotency_key_required`，重试不会记成两笔）；改已有记录必须带 `expected_version`（不符 409）；每次写入都有“通过 API key”标注和审计（下文），用户可以在 App 里照常撤销。以后如果要求 key 的写入先在手机上确认，可以在这一层加（待定问题 27）。

**撤销与过期**：鉴权每次查库（v1 不加缓存），撤销、过期、账号停用、退出空间之后的下一个请求立即被拒；已经通过鉴权、正在执行的单个请求照常完成（它在一个事务里）。

**限流**（`config` 可调）：按 key 的令牌桶，读类请求与只读工具 60 次 / 分钟，写入类工具（含 `/sync/push` 里的每一条）20 次 / 分钟。超限返回 429 + `Retry-After`。格式正确但查不到的 key 按来源 IP 限流，防止猜测。

**最近使用时间**：`last_used_at` 最多每 60 秒写一次（条件更新 `WHERE last_used_at < now() - interval '60 seconds'`），不为每个请求写库。不记录调用方 IP。

**标注与审计**：`entity_events`（[技术方案 3.6](technical-design.md#36-变更记录审计)）带 `via_api_key_id` 和 `via_api_key_name`（操作当时的名称快照），随同步下发，客户端在记录卡、变更记录和历史里显示“通过 API key：名称”，同一空间的其他成员也能看到。另外每次 key 的工具调用和写入请求追加一行只追加的 `api_key_audit`（时间、key、用户、空间、操作名如 `tool:query_stats` / `push:update_record`、`effect`、结果或错误类别、请求 ID、幂等键），**不记参数和结果**（它们是内容），保留 180 天，供排查和以后在 App 里显示“这个 key 最近做了什么”。

**接口**：`GET /me/api-keys`（列表：名称、`display_prefix`、权限、到期、最近使用、状态）· `POST /me/api-keys`（创建，返回一次明文）· `PATCH /me/api-keys/{id}`（只能改名称）· `POST /me/api-keys/{id}/revoke`。撤销立即生效（鉴权每次查库，v1 不加缓存）。key 行永不物理删除，撤销或过期的保留，以便历史标注和审计能找到名字。

### 3.4 管理身份

管理员不是 `users` 里的账号：公开 API 上没有任何管理能力，管理 API 只认管理令牌，二者在不同的监听器上。人的登录（包括第二因子）由使用管理 API 的控制台负责，服务端只认服务令牌。设计与理由见第 9 节。

## 4. API 原则

> **API 契约尚未定稿，将在服务端开工时重新编写**，由 utoipa 从代码生成 `openapi.json` 并提交进仓库。以下是契约必须遵守的原则。

- **幂等写入**：客户端为每条记录生成 UUIDv7 作 `id`，每个改动请求带 `Idempotency-Key` 头（与 IETF httpapi 草案同名），幂等键仍按用户维度存储。服务端在同一事务内，**在身份、空间成员、`join_epoch` 和授权检查都通过之后**（幂等结果不是授权缓存，[技术方案 5.3](technical-design.md#53-post-syncpush)）：`INSERT INTO idempotency (user_id, key, request_hash) … ON CONFLICT DO NOTHING`；已存在且有保存的响应则直接回放；请求体哈希不同则返回 422。`records` 用 `INSERT … ON CONFLICT (id) DO NOTHING`。
- **outbox 同步**（[技术方案 5.2、5.3](technical-design.md#52-outbox-条目)）：空间内容的写入**只经工具**（S25）：`POST /sync/push` 的每条是一次工具调用 `{op_id, space_id, join_epoch, tool, args}`，服务端逐条、每条一个事务处理（成员与 `join_epoch` → 授权 → 幂等 → `ToolRegistry::invoke`），逐条返回结果；客户端同一实体同一时间只有一条在途；目标空间已不可用（例如已退出）的条目返回“空间不可用”；客户端按 P52 处理：退出或被移出的空间，本机内容（含未上传的条目）一律清除，不保留。
- **change_seq 游标（按空间分别维护）**：每次改动写入全局递增的 `change_seq`（PostgreSQL sequence），每行带 `space_id`。客户端**每个空间保存一个游标**；`POST /sync/pull` 提交 `{space_id: cursor}` 映射，服务端只返回当前用户为活跃成员的空间中 seq 大于对应游标的行（含已作废的“墓碑”）和各空间的新游标；不可用或不存在的空间统一标为“不可用”，不区分两种情况。分页（[技术方案 5.4](technical-design.md#54-post-syncpull-与变更序号)，S36）：每个同步行各取一个 `change_seq`；行过滤（模块、聊天归属）写在查询里，不在序列化时丢行；新游标 = 返回的最后一行；`has_more` 按每表 `limit + 1` 判断；一个空间的拉取在一个 `REPEATABLE READ` 只读事务里完成，同一空间的写事务由咨询锁串行。
  - 客户端靠 `GET /spaces`（成员关系列表）知道有哪些空间：某空间从列表消失（退出 / 被移除）→ 清除本机该空间的数据和游标；新加入或重新加入 → 游标从 0 开始，完整回填该空间。
  - **为什么不用单一的全局游标再按成员关系过滤**：新加入空间的历史行 seq 都小于全局游标，会被跳过，需要另写回填逻辑和边界处理，容易出错；按空间分游标时“新加入 = 游标 0”自然完成回填，退出时也只需丢掉一个游标。两种方式都不泄露其他空间的信息，按空间分游标更简单。
- **乐观并发**：更新带 `expected_version`，版本不符返回 409，客户端拉取最新版本后提示用户。
- **请求 ID**：每个请求带 `X-Request-Id`（UUIDv7，客户端生成，离线重发沿用同一个）；服务端校验格式后沿用，没有才自己生成，并在响应头回传。
- **统一错误格式**：RFC 9457 风格 `application/problem+json`：`{type, title, status, detail, request_id}`；内部错误只记日志不外泄细节。
- **AI 解析异步化 + 流式回复**：经 `POST /spaces/{space_id}/chat/messages` 发出原话 / 图片后立即返回 `{userMessageId, messageId}`（这次回复的助手消息 ID）；客户端可订阅该消息的 SSE 流逐步显示；生成结束后最终消息写入 `chat_entries`，照常通过同步接口下发（**以同步版本为准**）。见 4.2。
- **成员世代**：空间内容的写请求都带成员世代：`/sync/push` 每条带 `join_epoch`，原图上传、聊天的发消息 / 回答 / 重试 / 停止、工具 API 带请求头 `X-Jiabu-Join-Epoch`（工具 API 给 key 用时可省略）；不一致返回 409 `membership_changed`，检查在幂等回放之前（[技术方案 5.6](technical-design.md#56-退出被移出离线期间被移出又加回待定问题-30)）。
- **其他**：`/healthz` 健康检查；`/client-logs` 接收客户端日志；所有路径对反向代理子路径透明（服务端不感知前缀）。
- Axum 默认请求体上限 2 MB（`DefaultBodyLimit`），图片上传路由单独调大（例如 20 MB）；手机 App 不需要 CORS。

### 4.1 路由骨架（示意）

```rust
// 完整接口清单见技术方案 6.3；公开 API 挂在 /v1 下
let api = OpenApiRouter::new()
    .routes(routes!(auth::login, auth::logout))
    .routes(routes!(spaces::list, spaces::create, spaces::rename))
    .routes(routes!(invitations::create, invitations::list, invitations::cancel, members::remove, members::leave))
    .routes(routes!(sync::pull, sync::push))                       // 空间内容的写入只经工具（push 或下面的工具路由），没有记录 REST 写接口
    .routes(routes!(chat::send, chat::stream, chat::actions, chat::stop, chat::retry, chat::active_messages))   // 4.2；stream 路由不套 TimeoutLayer
    .routes(routes!(blobs::upload, blobs::get))
    .routes(routes!(me::api_keys_list, me::api_keys_create, me::api_keys_rename, me::api_keys_revoke))   // 3.3，只接受会话
    .routes(routes!(tools::list));                                // GET /spaces/{space_id}/tools（4.3）
let api = tool_registry.mount_api(api);   // 为每个开放给 API 的工具注册 POST /spaces/{space_id}/tools/{name}，schema 进 OpenAPI（4.3）
let (router, openapi) = api.split_for_parts();
// 管理 API 是另一个 Router（crates/admin-api），绑在另一个监听器上（第 9 节）；公开 Router 里没有任何 /admin 路由
let app = router
    .layer(TraceLayer::new_for_http())
    .layer(PropagateRequestIdLayer::x_request_id())
    .layer(SetRequestIdLayer::x_request_id(AcceptOrMakeRequestId)) // 自定义 MakeRequestId：优先沿用客户端的值
    .layer(TimeoutLayer::new(Duration::from_secs(30)))
    .layer(CompressionLayer::new())
    .with_state(state);
```

### 4.2 聊天流式接口与 UI 动作（ChatWeave，草案）

聊天回复的格式是 ChatWeave 协议：一条消息 = 有序的语义块（文字、记录卡、指标、表格、选项……）+ 纯文本兜底。协议、事件和续传规则见 [ChatWeave 文档](https://github.com/zz-howard/chatweave)；这里只写家簿怎么接。

| 接口 | 说明 |
|---|---|
| `POST /spaces/{space_id}/chat/messages` | 发消息：`{id, text?, images?}` → ChatWeave `startResponse`，返回 `{userMessageId, messageId}`（同一个 `id` 重放返回同一个 `messageId`）；不进 `/sync/push`，key 不能调用（`SessionOnly`）。请求头 `ChatWeave-Capabilities` 声明客户端能渲染的块类型，存进 `agent_runs.client_capabilities` 供映射时参考 |
| `GET /spaces/{space_id}/chat/messages/{message_id}/stream` | SSE 流（`text/event-stream`）。用 `chatweave-server` 的 Axum 辅助实现：`Last-Event-ID` 续传、15 秒心跳、无法重放时发快照。消息已完成时只发快照后关闭 |
| `POST /spaces/{space_id}/chat/actions` | UI 动作（选项、确认、表单）。`Idempotency-Key` = 动作 ID；交给 ChatWeave 的 `ActionRegistry::dispatch()` |
| `POST /spaces/{space_id}/chat/messages/{message_id}/stop` | 停止生成（ChatWeave 的命名）：消息以 `interrupted` 结束，已产出的部分保留；也用于“改为手动填写”取消排队中的运行 |
| `POST /spaces/{space_id}/chat/messages/{message_id}/retry` | 对“没有完成”的回复重试：开一次新运行（新的一条回复），接着原运行的 journal 做，已执行的工具调用不再执行（[技术方案 7.3](technical-design.md#73-运行种类与同一会话的排队)，P64）；一次运行只能被重试一次；`permission_changed` 与 journal 已压缩的返回 409 `retry_unavailable` |
| `GET /spaces/{space_id}/chat/active-messages` | 本人会话里还没结束的回复（含排队中、暂停中），App 被杀后找回用 |

**授权**：聊天接口都先经 `SpaceMember` 提取器，非成员一律 404；写类接口（发消息、动作、停止、重试）再比对 `X-Jiabu-Join-Epoch`；对话是一对一的，消息所属会话必须属于请求者本人（`conversations.member_id`），同一空间的其他成员访问别人的流、动作、停止、重试也一律 404；续传请求同样每次鉴权（`Last-Event-ID` 只是序号）。动作处理器的 `authorize` 调用统一的 `authorize(member, module, action)`（例如回答记账追问需要 `ledger` 的写权限），无权与不存在同样返回 404 等价的 `not_found`。ChatWeave 的宿主上下文 `Ctx` = `{ member, space_id, request_id }`；`ActionStore::load_block` 只按 `(space_id, message_id)` 加载，保证不能跨空间引用块。动作的处理顺序：加载块（同时确认活跃成员、`join_epoch`、消息属于本人会话）→ 宿主 `authorize` → **最后**才查动作的幂等结果并回放（S34；ChatWeave `protocol.md` 5.2 已按此修改）。

**v1 动作处理器**（在 `crates/agent` 中实现、注册进 ChatWeave 的 `ActionRegistry`）：

| target | 动作类型 | 做什么 | 破坏性 |
|---|---|---|---|
| `clarification.answer` | `choice.select`（点选项 `selected`，或点“输入其他内容”后打字 `freeText`）/ `form.submit`（`values` 或 `freeText`） | 追问是一次中断（首次设置补齐账户信息也是它）：条件写入确认中断仍开着、未过期后，把回答作为这次中断的结果写进运行 journal（不写成聊天消息），运行改回 `queued`；返回 `accepted` 和 `resume.messageId`（**同一条回复**继续，不是新回复）。实现见 AI 层 14.4 A | 否 |
| `pending_operation.confirm` | `confirmation.respond`（`outcome`，或点“输入其他内容”后的 `freeText`） | 中断的确认：确认则由 worker 按冻结的参数执行（执行前再校验记录版本，变了就不写、交给 Agent 说明），取消或写了别的话则不执行，结果交回 Agent 在同一条回复里继续；返回 `accepted` + `resume.messageId`（v1 预留，基本不用；日常记账靠撤销而不是确认，P2） | 是 |

记录卡上的“编辑 / 撤销”不是 ChatWeave 动作，是工具调用（`update_record` / `void_record`，经 `/sync/push`）。

**中断（回复暂停与继续）**：追问和需要确认的操作让回复暂停（ChatWeave `message.paused`）。暂停时在同一事务里写 journal、把暂停中的回复（`stream_status = paused`）写进 `chat_entries`、运行置 `paused` 并释放租约，然后关闭这条流；回答经上表的动作处理器记录后，运行重新排队，worker 在**同一条回复**里继续，事件序号接着往下数。暂停中停止或过期（改记录类确认 24 小时、澄清 7 天）时结束这条回复（“已停止 / 已过期”）。等待回答时客户端锁定输入框，所以正常情况下不会有新消息；离线排队的新消息到达时若恰好有暂停中的回复，提交接口先按停止处理它，再开始新的一轮；有排队 / 运行中的回复时，新运行排在后面，同一会话先进先出（[技术方案 7.3](technical-design.md#73-运行种类与同一会话的排队)）。暂停中的回复也出现在“活动消息”查询里。运行的保存、恢复与崩溃处理见 [AI 层第 14 节](ai-layer.md#14-持久执行暂停恢复与崩溃)。

**运行步骤**（回复顶部的“过程”条）：AI worker 在工具调用和 `ask_user` 前后用流生成器发 ChatWeave 的步骤事件（每个工具的步骤说明见 [AI 层 13.5](ai-layer.md#135-运行步骤过程条)）。步骤事件和块事件一样写 `chat_stream_events`、续传重放；回复结束时精简的步骤记录随消息存进 `chat_entries.message` 的 `steps` 字段，不新增表或列。工具名、参数、原始结果和模型的推理文字不进事件、不进 `chat_entries`。

**SSE 与部署**：反向代理必须关闭对该路由的响应缓冲（Caddy 的 `reverse_proxy` 对 `text/event-stream` 响应默认即时刷新，以其文档为准；其他代理需显式配置），超时不短于心跳间隔；该路由不套用 30 秒的 `TimeoutLayer`，改用“空闲超时”。

### 4.3 工具 API：AI 能用的工具，key 也能直接调用

产品规则见[需求 · 个人 API key](../product/requirements.md#个人-api-key)；工具的定义见 [AI 层 13.5、13.6](ai-layer.md#135-运行步骤过程条)。

**一份定义，两个入口**。每个工具只在 `crates/tools` 里实现一次（`AgentTool`）：参数和结果的类型（schemars 生成 JSON Schema）、说明、所属模块与动作、`effect`、业务校验和执行。`ToolRegistry` 在启动时把同一批工具挂到两处：

- **Agent 循环**：把工具的名称、说明和参数 schema 按固定顺序渲染进提示词快照的工具清单（AI 层 15.2）；
- **公开 Router**：遍历注册表，为每个开放给 API 的工具注册一条**具体**路由 `POST /spaces/{space_id}/tools/{tool_name}`（例如 `/spaces/{space_id}/tools/query_stats`），并用同一份 schema 写进 `openapi.json`：每个工具一个 operation（`operationId = tool_<name>`），请求体就是工具参数的类型，响应体就是工具结果的类型。不手写 handler。

两个入口都调用同一个函数 `ToolRegistry::invoke(name, args_raw, &ToolCtx)`，校验与执行的每一步只写一次：

1. 按 schema 反序列化 + JSON Schema 校验 + `validator`；不合法返回结构化错误；
2. 空间绑定：空间来自 `ToolCtx`（运行的 `space_id` 或请求路径），工具参数里**没有** `space_id`，调用方无法指定或切换空间；
3. 身份范围：`ToolCtx.principal` 是 key 时，再检查空间在 key 的范围内、只读 key 只能调 `effect = read` 的工具（3.3）；
4. `authorize(member, tool.module(), tool.action())`（3.2），无权与不存在同样处理；
5. 业务校验与执行：写入类工具在一个事务里写业务数据和 `entity_events`（带 `ToolCtx` 里的 `via_api_key_*`），新记录 ID 由 `ToolCtx.idempotency_key` 派生。

入口各自只做外层的事：

| | Agent 循环 | 工具 API |
|---|---|---|
| 身份 | 运行的发起成员（只能是会话，3.3） | 请求的 `Principal`（会话或 key）+ 路径里的空间 |
| 写入前 | 工具声明需要确认的写入先发起中断（确认卡，AI 层 14.4 C），确认后执行冻结的参数；日常记一笔仍直接入账（P2） | **不确认、直接执行** |
| 幂等 | `ToolCtx.idempotency_key = uuidv5(run_id, call_id)`，结果记进 journal | 写入类必须带 `Idempotency-Key`（第 4 节的 `idempotency` 表）；`ToolCtx.idempotency_key = uuidv5(user_id, Idempotency-Key)`；只读工具不要求 |
| 记录 | `agent_tool_calls`、journal、步骤事件、`ai_step_meters` | key 调用时写 `api_key_audit`（3.3）；**不写** `ai_calls` / `ai_step_meters`——没有模型调用，也就没有可计量的 AI 用量 |
| 过程条说明 | `step_label` / `step_summary`（AI 层 13.5） | 不用 |
| 错误 | 作为工具结果回填给模型，由模型说明 | problem+json：422 参数不合法、404 无权或不存在、403 `api_key_read_only`、409 版本冲突、429 限流 |
| 结果的展示 | 按 AI 层 13.2 映射成语义块（记录卡、指标……） | 直接返回工具的结构化结果（与回填给模型的是同一个类型），不返回语义块 |

**开放范围**（`exposure`）：`AgentAndApi` 两边都有；`ApiOnly` 开放给手机和 key、但不放进模型的工具清单（例如 `delete_tag`、`delete_subject`，技术方案 6.4）；`AgentOnly` 的工具不注册路由、不进 `openapi.json`、不出现在工具清单里——`ask_user`（只在对话里有意义）和以后子 Agent 的委派。记账就是模型调用 `create_record`，没有单独的“解析”调用；key 要记账就调用写入类工具，自己给出结构化字段。

**`GET /spaces/{space_id}/tools`**：列出当前身份在这个空间能调用的工具（名称、说明、`effect`、参数与结果的 JSON Schema、`schema_version`）；只读 key 只看到只读工具。外部 agent 可以直接把它当工具清单用。

**为什么是“每个工具一条具体路由”**，而不是另外两种做法：

- **一条通用路由**（`POST /tools/{tool_name}`，工具名是路径参数）：路由最少，但 OpenAPI 里只能写成一个 `oneOf` 的大接口，生成的客户端没有类型，文档也看不出每个工具要什么参数；
- **为每个工具手写 REST 资源接口**（例如 `GET /spaces/{id}/stats?…`）：查询类工具本来就是动作（“按这些条件统计”），硬套成资源会和现有的记录接口重复；每个工具都要手写一个 handler 和一份 DTO，迟早会和 Agent 用的那份定义走样；
- **选定的做法**：路由由注册表生成，handler 只有一个泛型实现；每个工具在 OpenAPI 里有自己的类型；工具与接口一一对应，加一个工具（`exposure` 允许时）就自动多一个接口，改参数时 `openapi.json` 的 CI 检查会把变化摆出来。统一用 POST：参数是结构化的 JSON（筛选条件、期间、多个账户），放进查询串表达不了；只读工具的 POST 不改任何数据，也不要求 `Idempotency-Key`。

**版本**：工具带 `schema_version`；同一工具名只做向后兼容的改动（新增可选参数、结果新增字段）；不兼容时起新名字（如 `query_stats_v2`），旧的至少保留一个发布周期。注意工具的说明和 schema 同时是提示词的一部分：改它们要按 AI 层 14.10 升 `agent_def_version`。

**测试**：每个开放的工具至少一条集成测试，分别经 Agent 循环（`MockProvider` 发出工具调用）和工具 API 调用同样的参数，断言写入结果、`entity_events`、权限拒绝完全一致；只读 key 调写入类工具 403；没勾选的空间 404；写入缺少 `Idempotency-Key` 400、重放返回第一次的结果；`openapi.json` 里没有 `AgentOnly` 工具。

## 5. 数据模型与关键模式

### 5.1 表结构草案（PostgreSQL 18）

账号、会话、空间、成员、邀请、账本、资料、变更记录（`entity_events`）、原图引用、会话、安装包的完整建表在[技术方案第 3 节](technical-design.md#3-数据模型)；这里只列技术方案沿用、没有重抄的几张表。

```sql
create table space_member_grants (member_id uuid not null references space_members,
  module text not null,                             -- 'ledger' | 'documents'（以后 'memories' …）
  level text not null check (level in ('none','read','write','manage')),
  change_seq bigint not null, primary key (member_id, module));
create sequence change_seq;                         -- 全局；每个同步行各取一个（技术方案 5.4）
create table space_events (id bigint generated always as identity primary key, space_id uuid not null,
  actor_member_id uuid references space_members, subject_member_id uuid references space_members,
  request_id uuid, kind text not null,   -- create|rename|invite|join|leave|remove|rejoin|transfer|delete
  at timestamptz not null default now());
create table blobs (sha256 bytea primary key, mime text not null check (mime = 'image/jpeg'), bytes bigint not null,
  width int, height int, created_at timestamptz not null default now());
-- 之后加的列：unreferenced_at（S4 的保留计时）、stored_bytes（原图 + 两个派生尺寸的字节数，照片占用用，技术方案 3.7.1）
-- blob_refs：代理主键 + 两条部分唯一索引（chat 每位成员一条、业务模块每个空间每张图一条），见技术方案 3.7
-- 聊天表都不带 module / visibility（聊天是本人的记录，不按模块过滤）；三张表都有 space_id 和会话所属成员 member_id
create table chat_entries (id uuid primary key, space_id uuid not null references spaces,
  member_id uuid not null references space_members,       -- 会话所属成员（冗余 conversations.member_id，给 RLS 和同步过滤用）
  conversation_id uuid not null references conversations, role text not null check (role in ('user','assistant','system')),
  reply_to_id uuid,                                       -- 助手消息回答的是哪条用户消息（重试用）
  agent_run_id uuid,                                      -- 产生这条助手回复的运行
  protocol_version text not null,                         -- ChatWeave 协议版本，如 '0.1'
  message jsonb not null,                                 -- ChatWeave 消息（块列表、状态）；入库前经 Schema 校验
  fallback_text text not null,                            -- 纯文本兜底：通知、搜索、旧客户端
  stream_status text not null check (stream_status in ('streaming','paused','complete','interrupted','error')),
  rev int not null default 0,                             -- 完成时 1，之后每次块状态变化 +1
  last_seq int not null default 0,                        -- 最后一个流事件序号（快照需要）
  change_seq bigint not null, created_at timestamptz not null, updated_at timestamptz not null);
create table chat_stream_events (message_id uuid not null, seq int not null,
  space_id uuid not null, member_id uuid not null,        -- RLS 与授权用
  event jsonb not null, created_at timestamptz not null default now(),
  primary key (message_id, seq));                         -- 续传用的短期事件日志
create table chat_actions (id uuid primary key,             -- = 动作 ID = 幂等键
  space_id uuid not null, member_id uuid not null, message_id uuid not null, block_id text not null,
  action_type text not null, target text not null, payload jsonb not null,
  status text not null, result jsonb not null,
  actor_member_id uuid not null references space_members, request_id uuid,
  created_at timestamptz not null default now());          -- 只追加，兼作审计
-- 个人 API key（3.3）
create table api_keys (id uuid primary key default uuidv7(), user_id uuid not null references users,
  name text not null, token_hash bytea unique not null,   -- sha256(明文)；明文只在创建响应里出现一次
  display_prefix text not null,                           -- 'jiabu_pat_' + 随机部分前 6 位
  scope text not null check (scope in ('read','read_write')),
  expires_at timestamptz,                                 -- 空 = 永不过期
  created_at timestamptz not null default now(), last_used_at timestamptz,
  revoked_at timestamptz, revoked_by text check (revoked_by in ('user','admin')));   -- 行不物理删除
-- key 不单独选空间，可访问的空间 = 本人当前的活跃成员关系（P51、S24）
-- key 的工具调用与写入请求的审计（3.3）：只追加，不记参数和结果
create table api_key_audit (id bigint generated always as identity primary key,
  at timestamptz not null default now(), api_key_id uuid not null references api_keys,
  user_id uuid not null, space_id uuid,
  operation text not null,                -- 'tool:query_stats'、'tool:create_record'、'push:update_record' …
  effect text not null check (effect in ('read','local_write')),
  outcome text not null,                  -- 'ok' 或错误类别（'read_only'、'not_found'、'conflict'、'invalid' …）
  request_id uuid, idempotency_key text);   -- 保留 180 天
-- 管理侧的表（admin_tokens、admin_audit、ai_providers、ai_models、ai_routes、ai_settings、ai_prices、secrets、ai_step_meters）见 9.5；app_releases 见技术方案 3.9
-- agent_runs / agent_run_items / agent_tool_calls / agent_prompt_snapshots 见 ai-layer.md 14.2（v1 的改动见技术方案 3.8）；ai_calls 见 ai-layer.md 第 8 节
```

金额一律 `bigint` 存空间币种的最小单位（`*_minor` 列，人民币即“分”），不用浮点；主键用 UUIDv7。

**迁移**：全部业务表、AI 运行的一组表（`agent_runs`、`agent_run_items`、`agent_tool_calls`、`agent_prompt_snapshots`、`ai_calls`）以及管理侧的表和数据库角色授权（9.5）都在首批迁移里建好，`chat_entries.stream_status` 从一开始就包含 `paused`。已发布的迁移只追加、不修改；步骤日志的格式变化靠行上的 `schema_version` 加读取时升级，不改历史行。迁移是纯 SQL 文件、`sqlx::migrate!` 执行、SeaORM 实体从库生成（[技术方案 10.1](technical-design.md#101-迁移待定问题-2)）。

**账户属于空间**：资金账户和用途账户都挂在某个空间下。同一张真实银行卡可以在两个空间各建一次，各自只记本空间的流水、显示本空间推导出的余额；系统不尝试合并成整张卡的余额，App 内整卡余额对不上是已接受的取舍。

### 5.2 关键模式

1. **幂等写入**：见第 4 节。
2. **AI 运行（队列 + 持久执行）**：用户消息入库时同事务插入 `agent_runs(kind = 'chat', status = 'queued')` 并 `NOTIFY`（运行种类只有 `chat`，A16）。同进程固定 2 个 worker（tokio 任务）被 `LISTEN/NOTIFY` 唤醒，另每 5 秒轮询兜底：
   - **领取**：同一会话先进先出（本会话没有更早的未结束运行才领取，技术方案 7.3）；`UPDATE … SET status = 'running', lease_owner, lease_until = now() + 60s, lease_epoch = lease_epoch + 1 WHERE id = (SELECT … FOR UPDATE SKIP LOCKED LIMIT 1)`；每 20 秒续租；之后的每一次写入都带 `lease_epoch` 条件（防护令牌），影响 0 行就放弃。
   - **执行**：读运行行和步骤日志，跑到下一个停顿点：中断（暂停并释放租约）、最终回答（完成）、全部提供方失败（`waiting_ai`，按 `run_after` 指数退避）。会改数据的工具在同一个事务里写业务表和步骤结果。
   - **清扫器**：每 30 秒把租约过期的运行放回队列（崩溃重试最多 2 次，超过则以“没有完成、可重试”结束）；每分钟把过期的中断关闭（改记录类确认 24 小时、澄清 7 天）。
   - **优雅停机**：停止领取，进行中的调用最多等约 20 秒，否则把运行放回队列，重启后马上接上。
   - 细节（表结构、状态机、恢复算法、恰好一次、崩溃处理、预算）见 [AI 层第 14 节](ai-layer.md#14-持久执行暂停恢复与崩溃)。
3. **追加式审计 / 撤销**：`entity_events(space_id, entity_kind, entity_id, kind[create|update|void|restore|archive|unarchive|delete], before, after, actor_member_id, via_api_key_*, run_id, request_id, at, change_seq)`（账户、计划、标签、资料、对象的修改也在这里，技术方案 3.6）与 `space_events` 只 INSERT（应用数据库角色对该表无 UPDATE / DELETE 权限）。撤销 = 追加一条 `void` 事件并更新实体当前态，绝不删除历史。
4. **余额**：余额由记录推导（开户余额 + 关联记录），一笔支出同时影响真实账户和用途账户、只计一次消费；月度拨入和逻辑调拨是独立记录类型，不算收入或消费。**退款不变量**（S39）：“一笔支出的有效退款之和 ≤ 它的金额，退款只挂在有效支出上”在建退款、改金额、恢复退款、撤销支出这些写入里于空间锁内检查；有有效退款的支出不能直接撤销（422 `has_refunds`，P64）。
5. **空间隔离**：每行带 `space_id`；任何查询、统计、提示都不跨空间，不在一个空间里透露其他空间的数量、合计或线索。聊天记录与 AI 上下文按空间隔离，其他空间的内容绝不进入模型请求。账号级事件（登录、改密）只记 `user_id`，空间内事件记 `actor_member_id`。
6. ~~跨空间移动记录~~：v1 不做（[决策 P63](../decisions/README.md)）；记错空间时在原空间撤销、到正确的空间重新记。
7. **聊天回复的流式与持久化**（ChatWeave）：AI worker 用 `chatweave-server` 的流生成器产生事件，每个事件**先写 `chat_stream_events` 再广播**给在线订阅者（进程内 `tokio::sync::broadcast`，慢订阅者被断开后自行续传）；`message.end` 时在**同一事务**里写入 `chat_entries` 最终消息（`rev = 1`，分配 `change_seq`）并更新 `agent_runs` 状态。事件日志在消息结束（或暂停）10 分钟后由清理任务删除；暂停中的回复以 `chat_entries` 里的暂停版本为准，日志清理不影响它继续。进程崩溃后，租约过期的运行由清扫器放回队列，在**同一条回复**里接着做（已显示的文字保留，新文字另起一块，最多重试 2 次）；超过上限才用库的折叠函数从事件日志恢复消息、标 `interrupted` 并持久化，用户可以重试。块状态变化（追问被回答）= 更新 `chat_entries.message`、`rev + 1`、新的 `change_seq`，经同步下发到会话所属成员的设备。**聊天条目只同步给会话所属成员**：同步接口按 `member_id = 请求者`（`conversations.member_id`，`chat_entries` 冗余同一列）过滤，同一空间的其他成员拿不到别人的对话。

### 5.3 原图存储

- v1：`object_store::local::LocalFileSystem` 存原图到 `<data_dir>/blobs/{sha256 前 2 位}/{sha256}.{orig|1600|512}.jpg`（内容寻址，物理文件只存一份），数据库存元数据（大小、MIME、宽高）以及逻辑引用 `blob_refs`（按模块 `ledger` / `documents` / `chat`；聊天的图每位成员各一条、只有本人能读，业务模块每个空间每张图一条，[技术方案 3.7](technical-design.md#37-原图)）。上传总是要求完整内容，响应对新图和已有的图完全相同（技术方案 5.8）。以后换 S3 兼容服务只换构造函数。
- 处理：`infer` 嗅探真实类型（不信任客户端 Content-Type）；`image` 生成 1600px 显示版和 512px 缩略图；按 EXIF 方向转正；派生尺寸重新编码、不带 EXIF；原图写盘前去掉 GPS、XMP / APP13 和图像结束标记之后的附加内容（“实况照片”视频、MPF），画质不动（P70，技术方案 3.7）。原图供 AI 和核对。
- 下载：本空间要有一条请求者能读的引用（`ledger` / `documents` 按模块读权限，`chat` 要求本人的引用），否则 404；之后流式返回（`tokio_util::io::ReaderStream`），不开放静态目录。

### 5.4 中间件、配置、错误、校验

- tower-http：`trace`、`request-id`、`timeout`、`compression-gzip` / `-zstd`、`limit`、`catch-panic`、`sensitive-headers`（日志隐藏 Authorization）。
- 配置：`config` 读取 `config/base.toml` + `config/{env}.toml` + 环境变量覆盖；密钥只来自环境变量 / 文件，用 `secrecy` 包装。
- 错误：领域错误 `enum AppError`（thiserror）实现 `IntoResponse`，统一输出 problem+json。
- 校验：`validator` 派生（金额 > 0、备注长度等），业务规则在 domain 层。

## 6. 日志与可追踪性

目标：拿到一个 ID，就能把“手机上点了什么 → 服务器收到什么 → AI 任务怎么跑的 → 数据库改了什么”串成一条线。

- **一个请求 ID 贯穿全程**：客户端每个用户动作生成 `X-Request-Id`，离线重发沿用（与幂等键一起存在 outbox 里）；服务器优先接收客户端的值并校验格式。
- **每行日志带上下文**：`tracing` 请求 span 带 `request_id`、内部 `user_id`、`space_id`（如有）、路由、耗时、状态码。输出 JSON，一行一条，便于 `grep` / `jq` 过滤。
- **跨进 AI 运行**：`agent_runs` 存 `origin_request_id`；worker 开新 span，带 `run_id`、`lease_epoch`、`origin_request_id`、`provider_id`、模型名、重试次数、降级原因、耗时、token 用量（含缓存读取 / 写入 token）。
- **跨进审计**：`entity_events.request_id` 可反查“这笔账是哪次操作改的”。
- **错误回执带 ID**：错误响应带 `request_id`，App 错误提示和客户端日志也显示 / 记录它；用户截个图就能定位服务器日志。
- **聊天流**：每个 SSE 连接一个 span，带 `request_id`、`space_id`、`message_id`、续传起点 seq、持续时间、断开原因；不记事件内容。动作请求带 `X-Request-Id`，写入 `chat_actions.request_id`。
- **客户端日志同一套 ID**：`/client-logs` 每条带 `request_id`、App 版本、设备型号、系统版本。
- **不记敏感内容**：只记 ID、元数据、耗时和错误类型；不记密码、令牌、API key、提供方密钥、记账原话、图片和模型完整回复。需要看原话时到库里按 ID 查。
- **鉴权方式进 span**：请求 span 带 `auth_kind`（`session` / `api_key`）和 `api_key_id`（如有），工具 API 另带 `tool`（工具名）；管理 API 的请求 span 带 `admin_token_id` 和控制台传来的 `X-Admin-Actor`，并且一律不记请求体。
- **保留与查看**：日志按天滚动，保留 30 天；v1 用文件 + `jq`。以后要可视化再接 OpenTelemetry（`tracing-opentelemetry`），span 代码不用改。

## 7. 测试与质量

- `cargo nextest run`；集成测试连**真实 PostgreSQL 18**（本地用 testcontainers 0.28，CI 用 service 容器），每个测试使用独立的临时数据库并自动跑迁移。
- **关键查询必须有集成测试**：幂等（重复提交、哈希不同 422、响应回放）、`ON CONFLICT`、`FOR UPDATE SKIP LOCKED` 并发取任务、change_seq 游标增量与墓碑、空间隔离（非成员对空间的任何请求都得 404；列表、同步、统计不含他人空间；退出后立即不可访问、重新加入复用同一成员行、`join_epoch + 1`）、授权先于幂等回放（退出后或退出又加回后重放旧的 `op_id` 拿不到当时的结果）、拉取分页（同一事务写多行、页边界不漏行）、退款不变量、嵌套事务（SeaORM 与 SQLx 一样用 SAVEPOINT 实现）。
- 聊天流与动作：中途断开后带 `Last-Event-ID` 续传的结果与不断开一致；事件日志清理后得到快照；非成员 / 已退出成员对流、动作、停止、重试接口一律 404；SSE 先订阅再读日志的交接在“读日志与订阅之间插入写入”时不漏事件，同一空间的其他成员访问别人的会话同样 404、同步也拿不到；越权动作（无模块权限、指向其他空间的消息、选项不在块里、重复动作 ID）全部被拒或回放。
- AI 运行（持久执行）：多个 worker 并发领取不重复；租约过期被别的 worker 接手后，旧 worker 的写入因 `lease_epoch` 不符失败；本地写入工具在事务回滚时不留痕、提交后恢复不重做；两台设备同时回答只有一个成功；回答与过期 / 停止竞态只有一个成功；离线排队的新消息先结束暂停中的回复；同一会话先进先出；`one_active_run_per_conversation`（只管 `running` / `paused`）与 `one_retry_per_run` 生效；重试复用原运行已有结果的工具调用、不重复执行。
- 个人 API key：key 不能创建 / 撤销 key、不能改密码和管理成员；只读 key 的任何写入被拒；非成员空间与不存在的空间返回完全相同的 404；退出空间、账号停用、撤销、过期后立即失效，重新加入后同一个 key 自动恢复、新加入的空间无需新建 key；key 不能新建空间；限流返回 429；`entity_events` 的标注随同步下发。key 调用聊天的任何接口一律 403 `api_key_ai_not_allowed`，并断言没有创建任何 `agent_runs`、没有写任何 `ai_calls`。
- 工具 API（4.3）：同一工具经 Agent 循环和经工具 API 调用的结果、权限拒绝、`entity_events` 一致；只读 key 调写入类工具 403；写入缺 `Idempotency-Key` 400、重放返回第一次的结果；`AgentOnly` 工具（`ask_user`）没有路由、不在 `openapi.json` 里。
- 管理 API（9.2 的三层）：① `cargo tree` 依赖检查；② 用 `jiabu_admin` 数据库角色连接后，对 `records`、`documents`、`chat_entries`、`agent_run_items`、`agent_tool_calls`、`blobs` 等表的 `SELECT` 必须报权限错误（`spaces` 只能读 9.2 表里列出的列，`spaces.name` 可读）；③ 导出的 `openapi-admin.json` 做字段快照（每个 schema 的字段名与类型），任何新增字段都会让快照变化，必须在评审里说明它不是内容。管理令牌访问公开 API、会话令牌和 API key 访问管理 API 一律 401。
- HTTP 级测试用 `axum-test`；SeaORM 的 `MockDatabase` 只用于快照生成的 SQL，不替代真库测试。
- AI 适配器：wiremock 回放 + insta 请求体快照，见 [AI 层设计](ai-layer.md#9-测试策略)。
- 静态检查：`cargo fmt --check`、`cargo clippy --all-targets -- -D warnings`、`cargo deny check`（许可证 + 漏洞库）、`cargo audit`。

### 7.1 给 AI 编程代理的规则

`server/AGENTS.md` 写明项目规则，例如：

- 所有改动请求必须带幂等键；空间数据只在 `SpaceTx` 里读写（`crates/api` 里不得出现 `SystemTx`），不得手写不带 `space_id` 的业务查询；禁止会话级 `SET jiabu.` / `set_config(…, false)`（技术方案 4.3、14 节 E2）。
- 空间内容的写入只经工具（`ToolRegistry::invoke`），不新增记录 REST 写接口。
- 请求路径上禁止 `unwrap` / `expect`。
- 新接口必须有 utoipa 注解和集成测试。
- 金额只用 `i64` 分；时间一律 `timestamptz`。
- 日志不得出现令牌、密码、原话。
- 聊天块只能由 `crates/chat` 的映射函数生成并经 Schema 校验；不得从模型文本里抽取组件；动作处理器必须实现 `authorize` 并有越权测试。

可参考 microsoft/rust-guidelines（MIT，含给 AI 的合并版 `src/agents/all.txt`）、rust-lang/api-guidelines、leonardomso/rust-skills（MIT，挑选规则拷贝）。**不安装**带钩子脚本的第三方 skills 插件（有的插件注册了几乎匹配所有提问的 UserPromptSubmit 钩子并执行 shell 脚本），只阅读参考。clippy 严格模式本身就是最好的“AI 规则”。

## 8. CI、发布与部署

### 8.1 CI（每个 PR）

GitHub Actions `ubuntu-24.04`：fmt → clippy → nextest（PostgreSQL 18 service 容器）→ cargo-deny / cargo-audit → 管理侧 crate 依赖检查（2 节）→ “`crates/api` 不得出现 `SystemTx`”与“禁止会话级 `SET jiabu.`”两条 grep 规则 → 迁移后重新生成 SeaORM 实体并 `git diff --exit-code` → 导出 `openapi.json` 与 `openapi-admin.json` 并检查与仓库中一致。

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
- 密钥（数据库密码、提供方凭据、密钥加密主密钥）只通过环境变量或权限 600 的文件注入，绝不进镜像或仓库。
- 管理 API 的 Unix 套接字放在数据目录下（如 `<data_dir>/run/admin.sock`），反向代理**不得**转发到它；docker compose 部署时用命名卷把套接字目录共享给同一台机器上的管理控制台容器（如有）。数据库里要有两个登录角色：`jiabu_app`（公开 API 与 worker）和 `jiabu_admin`（管理 API 与 `admin` 命令），角色由部署脚本创建（`admin db init-roles`，需要数据库超级用户一次），授权由迁移维护（9.5）。

## 9. 管理能力与管理 API

产品规则见[需求 · 管理员](../product/requirements.md#管理员管得了服务看不到内容)。

### 9.1 边界：本仓库提供什么

- **本仓库（开源）只提供基础能力**：用量计量（每次模型调用的 token 与按官方价格折算的成本）、提供方与模型配置（提供方、模型、密钥 / 订阅登录状态、每类任务的默认模型与降级顺序、带来源和日期的官方价格表）、账号管理（新建、停用 / 启用、重置密码、查看成员关系、撤销 API key、登出所有设备）。这些能力通过两种方式使用，二者调用**同一套服务层**（`crates/admin`）：
  - `admin` 命令（9.8）：自己部署的人在服务器上直接用，不需要任何控制台；
  - **管理 API**（`/admin/v1`，9.3、9.4）：带版本号、有 OpenAPI 描述（`openapi-admin.json`），任何控制台都可以基于它来做。
- **图形化的管理控制台不在本仓库**：网页界面、报表等放在单独的服务里，部署在同一台机器上，只通过管理 API 与服务端交互。本仓库不依赖它，没有它也能完整使用。

### 9.2 管理侧看不到内容：三层保证

“管理功能里看不到账本和聊天内容”不是靠约定，而是管理侧代码根本拿不到这些数据。边界要说清楚（P49）：这三层保证的是**管理功能**；能直接登录服务器、读数据库凭据或原图目录的人在技术上能读到数据，软件防不住（首版不做端到端加密）；管理员重置密码会被本人察觉（3.1）。

1. **接口层**：管理 API 没有任何返回记录、账户、余额、标签、资料、原图、聊天消息、AI 的输入输出、运行日志（journal）或工具参数的接口。运行明细（9.4）只返回：每次模型调用的提供方、模型、token、成本、耗时、结果，以及每一步的**操作类别**（来自固定目录，例如“查询统计”“查询余额”“搜索记录”“询问用户”），**不**返回过程条上渲染好的步骤说明（那里面可能带账户名、标签名）。空间返回 ID、**名称**、类型（默认个人 / 共享）、创建者用户名、成员数和创建时间：没有名称，管理员无法把用量、账号和具体的空间对上号（P30）；名称以外的空间内容（账户、记录、资料、聊天、空间的点缀色等界面设置）一律不返回。
2. **代码层**：`admin` / `admin-api` 只依赖 `db-admin`，后者只定义允许管理侧访问的表和列的实体；CI 检查依赖图（第 2 节）。
3. **数据库层**：管理 API 和 `admin` 命令用独立的连接池，登录角色 `jiabu_admin`，只有下列授权（迁移里维护）；其余表一律无权限，即使管理侧代码写了原生 SQL 也读不到：

| 表 | `jiabu_admin` 的权限 |
|---|---|
| `users` | `SELECT (id, username, must_change_password, admin_reset_at, disabled_at, password_changed_at, created_at)`；`INSERT`；`UPDATE (password_hash, must_change_password, admin_reset_at, admin_reset_notice_pending, disabled_at, password_changed_at)` |
| `sessions` | `SELECT (id, user_id, kind, device_name, created_at, expires_at, last_seen_at)`；`DELETE` |
| `spaces` | `SELECT (id, name, is_default, created_by_user_id, created_at, deleted_at)`；`INSERT`（建账号时建默认个人空间） |
| `space_members` | `SELECT (id, space_id, user_id, role, status, left_reason, joined_at, left_at)`；`INSERT` |
| `space_member_grants` | `INSERT` |
| `api_keys` | `SELECT`（除 `token_hash`）；`UPDATE (revoked_at, revoked_by)` |
| `agent_runs` | `SELECT (id, space_id, member_id, kind, status, provider_id, model, model_turns, active_ms, attempt, created_at, ended_at)` |
| `ai_calls`、`ai_step_meters` | `SELECT` |
| `space_storage_daily`、`storage_daily_totals` | `SELECT`（只有空间 ID、日期、张数和字节数，技术方案 3.7.1） |
| `app_releases` | 读写（安装包不含内容，技术方案 3.9） |
| `ai_providers`、`ai_models`、`ai_routes`、`ai_settings`、`ai_prices`、`secrets`、`admin_tokens`、`admin_audit` | 读写（`admin_audit` 只有 `INSERT` / `SELECT`） |
| `records`、`entity_events`、`accounts`、`allocation_plans`、`tags`、`subjects`、`documents`、`space_invitations`、`blobs`、`blob_refs`、`conversations`、`chat_entries`、`chat_stream_events`、`chat_actions`、`agent_run_items`、`agent_tool_calls`、`agent_prompt_snapshots`、`idempotency`、`api_key_audit` | **无** |

公开 API 与 worker 用 `jiabu_app` 角色（迁移用第三个角色 `jiabu_owner`，技术方案 3.10），对管理侧的表只有业务需要的权限：读 `app_releases`、`ai_*` 配置和 `secrets`（只有密文，解密在进程内用主密钥做，9.6），写 `ai_calls`、`ai_step_meters`；不能读写 `admin_tokens`、`admin_audit`。

### 9.3 监听与认证

**监听**：管理 API 不挂在公开端口上。`server` 进程另起一个监听器：

- 默认且推荐：**Unix 套接字** `<data_dir>/run/admin.sock`，文件权限 `0660`，属组为专用的 `jiabu-admin` 组；只有同一台机器上、在这个组里的进程（`admin` 命令、管理控制台）能连上。连接时用 `SO_PEERCRED` 取对端的 uid，配置了 `admin.allowed_uids` 时不在列表里的直接断开（第二道检查）。axum 0.8 的 `serve` 支持 `UnixListener`（以编译为准）。
- 备选：`127.0.0.1:<端口>`（例如容器之间不方便共享套接字时）。配置成非回环地址时服务端**拒绝启动**。
- 两个 Router 完全分开：公开 Router 没有任何 `/admin` 路由，管理 Router 没有任何公开接口；各自导出各自的 OpenAPI（`openapi.json` / `openapi-admin.json`）。

**认证：管理服务令牌**。管理 API 只认 `Authorization: Bearer jiabu_adm_…`：

- 只能在服务器上用 `admin token create --name <名称> --scope read|write [--expires 365d]` 创建，明文只显示一次，库里只存 SHA-256；`admin token list / revoke` 管理。**管理 API 本身不能创建管理令牌**，所以拿到一个令牌的控制台没法给自己“续命”或扩权。
- `read` 只能查询（用量、配置、账号列表、审计）；`write` 还能改配置、录入密钥、管理账号。控制台可以给“只看报表”的人用 `read` 令牌。
- 格式与 API key 相同（固定前缀 + 随机部分 + 校验位），不同前缀。会话令牌、个人 API key 访问管理 API 一律 401；管理令牌访问公开 API 同样 401。
- 每个请求可带 `X-Admin-Actor: <控制台里的管理员标识>`，原样写进审计（只用于“是谁点的”，不参与授权）。

**人的登录和第二因子由控制台负责**。服务端不保存管理员的用户名、密码或 TOTP，也不提供网页登录：

- 自己部署、只用 `admin` 命令时：能在服务器上执行命令（并能读数据库凭据）本身就是管理员身份，不需要额外登录；
- 用管理控制台时：人在控制台登录（控制台必须要求第二因子，例如 TOTP），控制台再用自己保管的管理令牌（权限 600 的文件）经本机套接字调用管理 API。

这样分工的理由：① 服务端不需要实现网页会话、CSRF、第二因子、找回这些与家簿本身无关的东西，攻击面小；② 管理 API 只在本机可达，令牌被偷走也得先进到这台机器；③ 换控制台、写自己的脚本都不用改服务端；④ 本仓库不依赖任何控制台。

### 9.4 接口清单（`/admin/v1`）

所有写请求带 `Idempotency-Key`；错误格式与公开 API 相同（problem+json）；时间一律 UTC 的 RFC 3339，按日 / 月分组时由请求参数 `tz` 指定时区。金额以美元计、保留 6 位小数（与价格表一致）。

| 分组 | 接口 | 权限 | 说明 |
|---|---|---|---|
| 元信息 | `GET /meta` | read | 服务端版本、管理 API 版本、支持的分组维度和任务类型；worker 状态（排队数、最老一条排队的等待时间、`waiting_ai` 数）、最近一次安装包拉取结果、最近一次备份时间（技术方案 10.7） |
| 用量 | `GET /usage/summary` | read | 参数：`from`、`to`、`tz`、`group_by`（`space` / `user` / `member` / `provider` / `model` / `task_kind` / `day` / `month`，可组合两个）、过滤条件。返回每组的调用次数、各类 token、成本、缓存省下的金额、失败次数；价格缺失的调用单独计数 |
| | `GET /usage/runs` | read | 运行列表（分页）：运行 ID、空间 ID 与名称、成员、任务类型、状态、模型调用次数、token 合计、成本、活跃时长、开始 / 结束时间 |
| | `GET /usage/runs/{run_id}` | read | 运行明细：每次模型调用（序号、调用种类 first / continue / resume / retry、提供方、模型、各类 token、成本、缓存省下的金额、耗时、结果、错误类别）+ 每一步（序号、操作类别、状态、耗时）。**不含**任何文字内容 |
| | `GET /usage/calls` | read | 调用明细（分页），字段同上，用于导出 |
| 空间（只有元数据） | `GET /spaces` | read | ID、名称、类型、创建者用户名、成员数、创建时间；不含任何空间内容 |
| 照片占用 | `GET /storage` | read | 参数 `from`、`to`、可选 `space_id`：每个空间每天的照片张数与字节数（`space_storage_daily`，带空间名称）和每天的全服务器实际占用（`storage_daily_totals`）；不含任何照片或引用（P68，技术方案 3.7.1） |
| 提供方 | `GET /providers`、`POST /providers`、`PATCH /providers/{id}` | read / write | 提供方：种类（`siwc` / genai 的各家 / `ollama` …）、`base_url`、计费类别（`subscription` / `local` / `paid`）、是否启用 |
| | `PUT /providers/{id}/secret`、`DELETE /providers/{id}/secret` | write | 录入 / 删除 API key（只写不读，9.6）。也可以不录入，而是继续用环境变量或文件（`secret_source = env:NAME` / `file:PATH`） |
| | `GET /providers/{id}/status` | read | 是否已配置凭据（只给“已设置 · 末 4 位”）、熔断器状态、最近一次成功 / 失败及错误类别；ChatGPT 订阅另给登录状态、令牌到期时间、最近一次刷新、`ext_agent_host_id`（9.7） |
| | `POST /providers/{id}/test` | write | 用固定的测试提示发一次最小调用，返回是否成功、延迟、token；计入用量（`task_kind = probe`，不归属任何空间） |
| 模型 | `GET /models`、`POST /models`、`PATCH /models/{id}` | read / write | 某提供方下的一个模型：模型名、能力（视觉、结构化输出方式、上下文长度）、是否启用 |
| 路由 | `GET /routes`、`PUT /routes/{task_kind}` | read / write | 每类任务（`chat`、`chat_vision`）的有序模型列表：第一个是默认，其余按顺序降级 |
| 策略 | `GET /settings`、`PATCH /settings` | read / write | `allow_paid_fallback`、熔断参数 |
| 价格 | `GET /prices`、`POST /prices` | read / write | 价格行只追加、不修改：模型、各类 token 的单价（每百万 token，美元）、缓存写入按有效期的单价、长上下文加价、`source`（官方价格页 URL）、`as_of`（核对日期）、`effective_from`。改价 = 新增一行；历史调用的成本不重算 |
| 账号 | `GET /users`、`POST /users`、`GET /users/{id}` | read / write | 列表与详情：用户名、状态、创建时间、最近活跃（取自会话）、空间数、有效 API key 数。新建账号同时建默认个人空间，返回一次性临时密码 |
| | `POST /users/{id}/disable`、`POST /users/{id}/enable` | write | 停用（同一事务删除全部会话）/ 启用 |
| | `POST /users/{id}/reset-password` | write | 生成一次性临时密码（只在响应里出现一次）、要求下次登录改密、删除全部会话 |
| | `GET /users/{id}/memberships` | read | 所在空间：空间 ID、名称、类型、角色、状态、加入 / 退出时间 |
| | `GET /users/{id}/sessions`、`DELETE /users/{id}/sessions` | read / write | 设备名、到期、最近活跃；“在所有设备上退出” |
| | `GET /users/{id}/api-keys`、`POST /users/{id}/api-keys/{key_id}/revoke` | read / write | key 的名称、`display_prefix`、权限、到期、最近使用、状态；撤销（`revoked_by = 'admin'`）。不能创建 |
| 安装包 | `GET /app-releases` | read | 已拉取 / 上传的安装包：构建号、版本、渠道、状态、拒绝原因、拉取时间（技术方案 10.5） |
| | `POST /app-releases/check` | write | 立即检查一次 GitHub Releases |
| | `POST /app-releases` | write | 手动上传安装包和 `release.json`，与自动拉取同样校验 SHA-256 与签名证书指纹 |
| | `POST /app-releases/{build}/withdraw` | write | 撤回一个版本（`status = 'withdrawn'`） |
| 审计 | `GET /audit` | read | 管理审计（9.5），按时间、令牌、对象过滤 |

不提供：删除账号（数据归属复杂，首版不做）、修改空间或成员关系、任何读取内容的接口、创建管理令牌。

### 9.5 表结构（管理侧，草案）

```sql
-- 管理服务令牌（9.3）：只能由 admin 命令创建
create table admin_tokens (id uuid primary key default uuidv7(), name text not null,
  token_hash bytea unique not null, display_prefix text not null,
  scope text not null check (scope in ('read','write')),
  expires_at timestamptz, created_at timestamptz not null default now(), created_by text not null,  -- 执行 admin 命令的系统用户
  last_used_at timestamptz, revoked_at timestamptz);
-- 管理审计：只追加（jiabu_admin 无 UPDATE / DELETE）
create table admin_audit (id bigint generated always as identity primary key,
  at timestamptz not null default now(),
  actor_kind text not null check (actor_kind in ('cli','token')),
  actor_token_id uuid references admin_tokens, actor_label text,   -- X-Admin-Actor 或命令行的系统用户
  action text not null,                     -- 如 'user.disable'、'provider.secret.set'、'price.add'、'route.update'
  target_kind text, target_id text, request_id uuid,
  detail jsonb);                            -- 改动摘要；绝不含密码、令牌、密钥明文
-- AI 配置（取代 config/ai.toml 作为事实来源；AI 层第 7 节）
create table ai_providers (id text primary key,                     -- 'chatgpt'、'gemini' …
  kind text not null, base_url text,
  billing text not null check (billing in ('subscription','local','paid')),
  secret_source text,                       -- 'stored' | 'env:NAME' | 'file:PATH' | 空（不需要凭据）
  enabled boolean not null default true, version int not null default 1,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now());
create table ai_models (id uuid primary key default uuidv7(), provider_id text not null references ai_providers,
  model text not null, structured text not null, vision boolean not null, context_tokens int,
  enabled boolean not null default true, unique (provider_id, model));
create table ai_routes (task_kind text not null, position smallint not null,
  model_id uuid not null references ai_models, primary key (task_kind, position));
create table ai_settings (id boolean primary key default true check (id),   -- 单行
  allow_paid_fallback boolean not null default false, breaker jsonb not null, config_version bigint not null default 1);
create table ai_prices (id uuid primary key default uuidv7(),
  provider_kind text not null, model text not null,         -- 按“官方模型名”定价；订阅提供方用该模型的官方 API 标价
  currency text not null default 'USD',
  input numeric(12,6) not null, cached_input numeric(12,6), output numeric(12,6) not null,
  cache_write jsonb,                        -- {"5m": …, "1h": …} / {"30m": …}，按有效期
  long_context jsonb,                       -- {above_tokens, input, cached_input, output}
  source text not null, as_of date not null, effective_from timestamptz not null,
  created_at timestamptz not null default now());          -- 只追加；同一模型取 effective_from 不晚于调用时间的最新一行
-- 加密保存的密钥（9.6）
create table secrets (id uuid primary key default uuidv7(), owner_kind text not null, owner_id text not null,
  field text not null, key_id text not null, nonce bytea not null, ciphertext bytea not null,
  last4 text not null, updated_at timestamptz not null default now(), unique (owner_kind, owner_id, field));
-- ai_calls（扩展后）与 ai_step_meters 见 AI 层第 8 节
```

迁移最后一步是一段 `GRANT` / `REVOKE`，按 9.2 的表给 `jiabu_admin` 和 `jiabu_app` 授权；集成测试用两个角色分别连接验证。`config/ai.toml` 不再是运行时的事实来源，只作为首次导入的格式（`admin ai import config/ai.toml`），也可以导出当前配置备份（`admin ai export`，不含密钥）。

### 9.6 密钥加密

- 管理 API 录入的提供方 API key 用 **XChaCha20-Poly1305**（`chacha20poly1305` crate）加密后存进 `secrets`：每次加密随机 24 字节 nonce；附加数据（AAD）= `owner_kind/owner_id/field`，密文被挪到别的提供方名下会解密失败。
- **主密钥**：32 字节随机数，放在权限 600 的文件里（`JIABU_SECRETS_KEY_FILE`，`admin secrets init-key` 生成），或环境变量；用 `secrecy` 包装、用完 `zeroize`。不进数据库、不进镜像，与数据库**分开备份**（数据库备份被偷，密文也解不开；主密钥丢了，只能重新录入密钥）。
- **轮换**：`key_id` 标明用的是哪把主密钥；`admin secrets rotate --new-key-file …` 用新主密钥重新加密全部行后停用旧的。
- **只写不读**：管理 API 和 `admin` 命令都不返回明文，只返回“已设置 · 末 4 位 · 更新时间”。明文只在 `AiRouter` 构造提供方客户端时在进程内解密。
- 以前的方式继续可用：`secret_source = env:NAME` 或 `file:PATH` 时服务端从环境变量 / 文件读取，管理 API 只显示来源，不显示值。

### 9.7 ChatGPT 订阅的登录只在命令行

SIWC 只有“浏览器 + 本机回环地址回调”一种登录方式（AI 层 4.1、4.3）：登录发起方在本机临时监听一个端口，浏览器在同一台机器上完成授权后跳回 `http://localhost:<端口>/…`。管理控制台运行在服务器上，而管理员的浏览器在自己的电脑上，回调到的是**管理员电脑**的 localhost，控制台收不到；动态注册的客户端也只允许回环地址作为回调，不能改成控制台的网址。另外官方说明远程托管的应用需要另外申请。所以：

- 登录用 `admin provider login chatgpt`，在服务器上执行：命令打印授权链接，管理员在自己电脑的浏览器里登录并同意，再把跳转后（打不开的）`127.0.0.1` 网址粘回命令行完成（“粘贴回调网址”，2026-10-27 实测，AI 层 4.3）；凭据只在服务器上生成。经 SSH 转移凭据文件或端口转发仍可作退路；
- 管理 API 只给状态：是否已登录、访问令牌到期时间、最近一次刷新及结果、额度不足的最近时间、`ext_agent_host_id`；需要重新登录时控制台显示应在服务器上执行的命令；
- 令牌刷新仍由服务端负责（原子替换凭据文件），刷新失败计入提供方状态并告警。

### 9.8 `admin` 命令

`admin` 命令直接调用 `crates/admin`（与管理 API 同一套服务层、同样写审计，`actor_kind = 'cli'`、`actor_label` = 系统用户名），用 `jiabu_admin` 角色连接数据库：

```
admin user create|list|show|disable|enable|reset-password|memberships|sessions|logout-all
admin user api-keys <用户> [--revoke <key_id>]
admin provider list|add|update|enable|disable|status|test|set-secret|clear-secret
admin provider login chatgpt              # SIWC 浏览器登录（9.7）
admin model list|add|update|enable|disable
admin route show|set <task_kind> <模型…>
admin price list|add                      # 只追加
admin usage summary --from … --to … --group-by space,model [--tz …] [--json]
admin usage run <run_id>
admin storage summary [--from …] [--to …] [--space <id>] [--json]   # 照片占用（P68）
admin token create|list|revoke            # 管理服务令牌（只能在这里创建）
admin secrets init-key|rotate
admin ai import <ai.toml> | export
admin release list|check|upload <apk> <release.json>|withdraw <build>
admin audit [--since …]
admin db init-roles | migrate
admin openapi export [--admin]
```

`set-secret` 从标准输入或文件读取密钥，不接受命令行参数（避免进 shell 历史）。所有命令支持 `--json` 输出，便于脚本使用。

### 9.9 版本与兼容

- 路径带主版本 `/admin/v1`。同一主版本内只做**向后兼容**的改动（新增接口、新增可选参数、响应新增字段）；客户端必须忽略不认识的字段。
- 不兼容的改动开 `/admin/v2`，至少与 v1 并存一个发布周期，`GET /meta` 列出支持的版本。
- `openapi-admin.json` 与代码一起提交，CI 检查一致；它也是控制台生成客户端代码的依据。

## 10. 风险

| # | 事项 | 对策 |
|---|---|---|
| 1 | SeaORM 2.0 刚于 2026-07 稳定，提交主要来自一位维护者 | 锁定版本；关键查询集成测试；必要时退回 sea-query / 原生 SQL |
| 2 | sqlx（SeaORM 底层）发版慢、核心维护者少 | 生态大量绑定 sqlx 0.9，短期风险低；持续关注 |
| 3 | 默认 AI 提供方的合规与额度 | 见 [AI 层设计 · 风险](ai-layer.md#11-风险) |
| 4 | 手机上传 HEIC | 客户端统一转 JPEG 再上传 |
| 5 | 以上代码片段未编译 | 以首次编译和 docs.rs 为准 |
| 6 | 漏写空间过滤导致跨空间泄露 | 仓储层唯一入口 + 集成测试 + `AGENTS.md` 规则；RLS 作为可选第二道防线（待定） |
| 7 | ChatWeave 尚在设计阶段、与家簿同步开发 | 开发期固定提交 + 本机 `[patch]`；家簿需要的能力以通用形式进库；家簿侧集成测试守住接口 |
| 8 | SSE 被反向代理缓冲或切断 | 关闭缓冲、心跳、续传；最差情况由同步拿最终版本 |
| 9 | 以后给管理 API 加接口时不小心带出内容 | 9.2 的三层保证：crate 依赖检查、`jiabu_admin` 角色的列级授权、`openapi-admin.json` 字段快照；新增管理接口必须在评审里说明“为什么这不是内容” |
| 10 | API key 泄露 | 默认 90 天过期；可识别前缀便于扫描；只存哈希；按 key 限流（写入更严）；最近使用时间可见；本人和管理员都能随时撤销；key 不能用 AI，泄露后也不会消耗 AI 额度 |
| 12 | key 的写入不经确认、直接执行 | 必须带幂等键和（改已有记录时）版本号；读写 key 需要用户主动选择；每次写入都有标注和 `api_key_audit`，可在 App 里撤销；以后可改为需要手机确认（待定问题 27） |
| 13 | 工具 API 与 Agent 用的工具定义走样 | 只有一份定义和一个 `invoke()`；路由由注册表生成；两个入口的同参数集成测试；`openapi.json` 的 CI 检查 |
| 11 | 密钥加密主密钥丢失 | 库里加密保存的提供方密钥全部无法解密，需要重新录入；主密钥文件与数据库分开备份（9.6） |
