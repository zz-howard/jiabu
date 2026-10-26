# 选型调研摘要：ORM、Rust LLM 库、ChatGPT 订阅接入、ARM CI、持久工作流（2026-10）

> 数据于 2026-10-25～26 核实：crates.io API（版本、日期、下载量、MSRV、依赖）、GitHub API（★、最近推送、贡献者、近 6 个月提交与合并 PR）、从 static.crates.io 下载的发布包源码（只读）、官方文档。“近 6 个月”指 2026-04-26 至 2026-10-26。没有编译，没有调用任何模型；源码中的 API 名称以 docs.rs 为准。最终决定见 [决策清单](../decisions/README.md)。

## 结论一览

| 问题 | 结论 | 决定 |
|---|---|---|
| ORM | SeaORM 2.0 与 SQLx 0.9 都可行；Diesel 的异步链（diesel-async）不成熟 | **SeaORM 2.0**，锁定版本，关键查询配集成测试，特殊查询用 sea-query / 原生 SQL |
| Rig | 已扩张成“库 + Bevy 编码 Agent + 记忆 / 回放 / 向量库”全家桶，近 6 个月 10 个破坏性小版本，多数是内部重构 | **不采用** |
| 比 genai 更好的多厂商库 | 没有；OpenAI、Anthropic 都没有官方 Rust SDK | **genai 0.7** 作为多厂商引擎 |
| ChatGPT 订阅（SIWC） | 没有成熟 Rust crate 实现官方流程；async-openai 有所需类型 | **async-openai 自写适配器**，作为默认提供方 |
| 免费 ARM CI | 公开仓库的标准 GitHub 托管 runner（含 `ubuntu-24.04-arm`）免费且不限量 | **GitHub Actions 原生构建 aarch64 / x86_64** |
| 持久的人在回路 | 两人规模用 Postgres 状态机就够；Temporal / Restate 过重 | **Postgres 状态表**（apalis 为以后的备选） |

## 1. ORM：SeaORM 2.0 vs SQLx 0.9 vs Diesel (+ diesel-async)

### 1.1 硬数据

| 项 | SQLx | SeaORM | Diesel | diesel-async | sea-query |
|---|---|---|---|---|---|
| 最新稳定版 | 0.9.0（2026-05-21） | 2.0.4（2026-09-27） | 2.3.14（2026-10-07） | 0.9.2（2026-06-19） | 1.0.2（2026-08-12） |
| 总下载 / 近 90 天 | 1.73 亿 / 5,000 万 | 2,780 万 / 541 万 | 4,204 万 / 1,028 万 | 1,578 万 / 554 万 | 3,903 万 / 636 万 |
| GitHub ★ | 17,596（仓库已迁至 transact-rs/sqlx） | 9,934 | 14,221 | 828 | 1,775 |
| 近 6 个月发布 | 1 次 | 10 次（rc 与 2.0.0–2.0.4） | 6 次补丁 | 3 次 | 4 次 |
| 大版本节奏 | pre-1.0，约每年一次破坏性升级 | 1.0（2024-08）→ 2.0（2026-07-19，此前 43 个 rc） | 2.x 遵守 semver | 10 个月 4 个破坏性小版本 | 1.0 于 2026-05-28 稳定 |
| MSRV | 1.94.0 | 1.94.0 | 1.86.0 | 1.84.0 | 1.88.0 |
| bus factor | 1–2 人；PR 持续合并 | 1 人为主 | 3 人活跃，最健康 | 1 人 | 同 SeaORM |

### 1.2 能力对照（结合本项目）

| 维度 | SQLx | SeaORM 2.0 | Diesel 2.3 + diesel-async 0.9 |
|---|---|---|---|
| async / Axum | 原生 async，`PgPool` 放进 Axum `State` | 原生 async（底层即 sqlx 0.9） | 本体同步；异步靠 diesel-async，事务写法有学习门槛 |
| uuid / timestamptz / jsonb | ✅ | ✅（`with-uuid` / `with-chrono` / `with-json`） | ✅ |
| 金额（`bigint` 分） | `i64` 直映射 | `i64` | `BigInt` ↔ `i64` |
| 幂等（`ON CONFLICT DO NOTHING RETURNING`） | 直接写 SQL | `OnConflict` builder；复杂情形用原生 SQL | DSL 支持，类型最严 |
| 任务表（`FOR UPDATE SKIP LOCKED`）、游标增量拉取 | 直接写 SQL | `lock_with_behavior(Update, SkipLocked)`；复杂情形回落原生 SQL | DSL 支持 |
| 嵌套事务 | SAVEPOINT | SAVEPOINT（已核 sqlx-core 0.9.0 / sea-orm 2.0.4 源码） | — |
| 编译期安全 | `query!` 对照真实库检查 SQL 与类型（需连库或离线数据） | 实体与列名有类型；SQL 合法性到运行时才知道 | 最强：DSL 对照 `schema.rs` 编译期检查 |
| 测试 | `#[sqlx::test]` 每测一个干净库 | 真库测试；`MockDatabase` 只校验生成的 SQL | 测试事务不提交 |
| 学习成本 | 低：会 SQL 就会用 | 中：Entity / ActiveModel / Relation，2.0 新宏 `#[sea_orm::model]`；部分 1.x 教程已过时 | 高：DSL 类型体操 + async 包装 |

### 1.3 评价与决定

- **Diesel**：本体最成熟、semver 最守规矩，但“成熟”的是同步 Diesel；异步要靠仍是 0.x、基本一人维护的 diesel-async。不选。
- **SQLx**：最透明，下载量是另外两者的 4–6 倍，生态大量绑定 sqlx 0.9；隐忧是发版很慢、核心维护者少。
- **SeaORM 2.0**：原生 async，下载量与 Diesel 同一量级，基于 sqlx 0.9 继承其驱动；2.0 刚稳定、提交约 80% 来自一人。
- **决定：SeaORM 2.0**。理由：实体类型减少 CRUD 样板；嵌套事务语义与 SQLx 相同；关键 SQL（幂等、SKIP LOCKED、游标同步）可以用 sea-query 或原生 SQL 写，不被 ORM 束缚。风险对策：锁定版本、升级走独立 PR、关键查询全部配真实 PostgreSQL 集成测试。

## 2. Rig（rig-core）

- 版本：0.45.0（2026-10-19），0.46.0-rc.1（2026-10-23）；380 万下载、约 9.0k★；MSRV 1.97.1。
- **定位已变**：README 首段为“Rust library for building LLM applications, and `rig`, a terminal coding agent … extend with Bevy plugins”。工作区包含 rig-agent、rig-memory、rig-cassette、rig-tools（read / write / shell 等编码工具）、rig-ecs、rig-tui 及十几个向量库集成——本项目只需要 completion、streaming、tool、structured_output 和少数 provider。
- **规模**：rig-core 0.46.0-rc.1 约 13.8 万行 Rust（不含 rig-agent）；genai 0.7.1 约 3.6 万行。
- **稳定性**：近 6 个月 0.36 → 0.46-rc.1，pre-1.0 每个小版本都可破坏，共 10 个破坏性小版本；`MIGRATING.md` 长达 6,266 行。按版本归类，绝大多数是内部重构（构造方式在 0.36、0.41、0.43 改了三次；`agent.prompt()` 返回类型在 0.43、0.44 连改两次），上游 API 驱动的只占少数。**0.44 让旧格式的持久化 `AgentRun` 无法加载**——对“等待用户澄清”这类持久状态是硬伤。
- **鉴权**：普通 OpenAI 配置只收静态 key；0.45 起新增 `SignedInModel` + 可自行实现的 `CredentialSource`，理论上可按请求刷新令牌，但它在新的 serve / effect 层，且是刚引入的 API。
- **SIWC**：内置 `chatgpt` provider 走 `chatgpt.com/backend-api/codex`（非官方路径，与官方文档“不要指向 backend-api”相悖）；Responses wire 层没有 namespace 工具类型。
- **结论：不采用**。若一两年后到 1.0 且 API 稳定，可再评估；领域 trait 已把库隔离开。

## 3. Rust 多厂商 LLM 库现状

| 库 | 最新版（日期） | 下载 / ★ | 近 6 个月发布 | 性质 | 评价 |
|---|---|---|---|---|---|
| **genai** | 0.7.1（10-23） | 52.5 万 / 918★ | 45（稳定线破坏性升级 2 次） | 多厂商客户端 | **最贴合**：35 种 AdapterKind，原生 Anthropic / Gemini，国内厂商齐全，异步 `AuthResolver`；缺点是单人维护、pre-1.0、无 OpenTelemetry GenAI 语义约定 |
| rig-core | 0.45.0；0.46.0-rc.1 | 380.7 万 / 8,977★ | 13（10 个破坏性） | 框架 | 采用量最高但 API 不稳定，重心偏向编码 Agent |
| async-openai | 0.42.2（10-10） | 981 万 / 2,021★ | 17 | 只覆盖 OpenAI 形状 | 有 `NamespaceToolParam`、自实现 `Config` trait 可动态取令牌；用于 SIWC 适配器 |
| langchain-rust | 7.0.0 | 16.1 万 / 1,351★ | 5 | 链式框架 | 面向 RAG，不合适 |
| swiftide | 0.33.0 | 8.6 万 / 795★ | 1 | RAG 索引 + Agent | 不合适 |
| llm（graniet） | 1.3.8（2026-04-19） | 13.1 万 / 366★ | 0 | 多厂商 | 已停更 |
| aisdk | 0.5.2（2026-02-25） | 9.1 万 / 253★ | 0 | 多厂商 | 停更 |
| adk-rust（非 Google 官方） | 2.3.0 | 3.7 万 / 721★ | 13 | Agent 框架 | 2025-11 才创建，太新 |
| mistralrs | 0.8.1 | 23.1 万 / 7,774★ | 0 | 本地推理引擎 | 不同类别 |
| 官方 SDK | — | — | — | — | OpenAI、Anthropic 均无官方 Rust SDK；Google 的 google-cloud-rust 是 Vertex 底层客户端 |

**关于将来的主 Agent / 子 Agent / 人在回路**：需要的 Agent 循环很小（调用模型 → 执行工具 → 回填 → 循环；遇到 `ask_user` 挂起），在 genai 之上自写约 300–600 行；真正难的持久化挂起与恢复本来就要放在自己的 Postgres 里并经服务端权限校验。子 Agent 就是另一套 prompt + 工具的同一个循环，作为工具挂进主 Agent 即可。

## 4. ChatGPT 订阅（官方 SIWC）

- **官方流程**：OAuth 访问令牌作为 `Authorization: Bearer` 调用 `POST https://api.openai.com/v1/responses`；每个请求 `store: false`、`stream: true`；不要指向 ChatGPT `backend-api`。
- **预览期限制**：须省略 `background`、`conversation`、`max_output_tokens`、`max_tool_calls`、`metadata`、`moderation`、`multi_agent`、`prompt`、`prompt_cache_retention`、`safety_identifier`、`temperature`、`top_logprobs`、`top_p`、`truncation`、`user`；function / custom 工具须放进 namespace 或经 `additional_tools` 提供；不支持图片生成、file search、Code Interpreter、native computer use、托管 MCP、`tool_search`；文本、图片、文件仅在模型接受时可用；应用须自行刷新令牌；**`text.format` 结构化输出未被提及**。
- **资格**：官方措辞为开源项目、本地运行的个人项目和少数私有应用可用；付费或远程托管应用需填 interest form / 加入候补。官方页面无日期戳。
- **各库支持**：

| 库 | 官方 SIWC | 说明 |
|---|---|---|
| genai 0.7.1 | ❌ | 无 namespace 工具类型；`extra_body` 理论上可塞但未验证；默认会发送须省略的字段 |
| rig-core 0.45 / 0.46-rc.1 | ❌ | `chatgpt` provider 走 Codex 后端（非官方 SIWC） |
| async-openai 0.42.2 | 🔶 有现成类型，需自写流程 | `NamespaceToolParam`、`Tool::Namespace(..)`；自实现 `Config` trait 动态取令牌 |
| 其他 crate | ❌ | 只有零星新 crate（下载量个位到两位数），无成熟库 |

- 已知有开源项目（非 Rust）在使用这条官方路径；DevKit 只有 TypeScript 包。
- crates.io 上第三方发布的 codex 协议 crate 并非 OpenAI 官方，不使用。

## 5. GitHub Actions 托管 arm64 runner

- 官方文档原文：“Use of the standard GitHub-hosted runners is free and unlimited on public repositories.” 标签含 `ubuntu-24.04-arm`、`ubuntu-22.04-arm`。公开仓库规格 4 CPU / 16 GB RAM / 14 GB SSD；私有仓库 2 CPU / 8 GB。
- 计费文档：公开仓库使用标准托管 runner 免费；**larger runner 始终收费**，所以只用标准 arm64 runner。私有仓库的 Linux 2 核 arm64 按分钟计费（扣完免费额度后）。
- 时间线：2025-01-16 公开仓库 public preview → **2025-08-07 GA** → 2026-01-29 私有仓库可用。
- 含义：公开仓库可以在原生 aarch64 与 x86_64 runner 上分别构建，无需交叉编译。

## 6. 持久的人在回路（等待用户澄清）

| 方案 | 现状（2026-10-26） | 对两人应用 |
|---|---|---|
| **Postgres 状态机（手写）** | `ai_jobs` 表：`status ∈ {queued, running, waiting_user, waiting_ai, done, failed}` + `attempt`、`run_after`、`locked_until`、`conversation jsonb`、`pending_question`；`FOR UPDATE SKIP LOCKED` 取任务，`LISTEN/NOTIFY` 唤醒 | **推荐**：只多一张表，没有新进程，与幂等键 / outbox 模式一致 |
| apalis 1.0.0 + apalis-postgres 1.0.0 | 2026-10-12 发 1.0（此前 alpha / beta / rc 约 13 个月）；基于 sqlx 0.9；137 万下载 / 1,471★；一人为主 | 可选：替代取任务、重试、调度；“等待用户”状态仍需自己建模 |
| graphile_worker（Rust 移植） | 0.14.1；sqlx 0.9；87★ | 小众，不推荐 |
| underway | 0.2.0（2025-07-16）；依赖 sqlx 0.8 | 不兼容，❌ |
| Temporal Rust SDK | 1.0.0 于 2026-09-04 GA；原生 signal / update 等待外部输入 | 过重：需额外运行 Temporal Server 和 worker，还要学 workflow 确定性约束 |
| Restate Rust SDK | 0.12.1；restate-server v1.8.1 | 比 Temporal 轻，但仍多一个有状态服务；SDK 仍是 0.x |

建议：v1 用手写 Postgres 状态机，把 `NeedsFollowUp` 落库为 `waiting_user`；任务种类变多再引入 apalis；Temporal / Restate 只在出现跨服务长事务编排需求时考虑。

## 7. 未能核实

1. SIWC 文档无日期戳，无法严格证明某日之后未改动；SIWC 下 `text.format` 是否可用官方未写。
2. genai 用 `extra_body` 发 SIWC 请求（namespace 工具、省略默认参数）未验证。
3. Rig `SignedInModel` + 自定义 `CredentialSource` 用于 api.openai.com 的可行性未编译验证。
4. Rig 背后公司的融资与背景未找到可靠来源。
5. `ubuntu-26.04-arm` 是否为 preview 只来自搜索摘要。
6. 所有代码与 API 名称均未编译。

## 来源

- crates.io API：`https://crates.io/api/v1/crates/<name>`（sqlx、sea-orm、sea-orm-migration、sea-query、sea-query-sqlx、diesel、diesel-async、diesel_migrations、rig-core、genai、async-openai、llm、langchain-rust、swiftide、aisdk、adk-rust、mistralrs、apalis、apalis-postgres、graphile_worker、underway、temporalio-sdk、restate-sdk 等）及 `/<crate>/<version>/dependencies`
- GitHub：transact-rs/sqlx、SeaQL/sea-orm、SeaQL/sea-query、diesel-rs/diesel、diesel-rs/diesel_async、0xPlaygrounds/rig、jeremychone/rust-genai、64bit/async-openai、graniet/llm、apalis-dev/apalis、temporalio/sdk-rust、restatedev/sdk-rust、restatedev/restate
- Rig：https://github.com/0xPlaygrounds/rig/blob/main/README.md 、/CHANGELOG.md 、/MIGRATING.md
- OpenAI SIWC：https://developers.openai.com/siwc/ 、https://developers.openai.com/siwc/token-sharing-open-source 、https://developers.openai.com/siwc/token-sharing-open-source/models-and-inference 、https://developers.openai.com/siwc/token-sharing-open-source/preview-limitations 、https://developers.openai.com/cookbook/articles/sign-in-with-chatgpt
- GitHub Actions：https://docs.github.com/en/actions/reference/runners/github-hosted-runners 、https://docs.github.com/en/billing/concepts/product-billing/github-actions 、https://github.blog/changelog/2025-01-16-linux-arm64-hosted-runners-now-available-for-free-in-public-repositories-public-preview/ 、https://github.blog/changelog/2025-08-07-arm64-hosted-runners-for-public-repositories-are-now-generally-available/ 、https://github.blog/changelog/2026-01-29-arm64-standard-runners-are-now-available-in-private-repositories
- SeaORM：https://www.sea-ql.org/SeaORM/docs/introduction/whats-new/ 、https://www.sea-ql.org/blog/2026-07-27-sea-orm-2.0/
- Temporal：https://github.com/temporalio/sdk-rust/releases/tag/v1.0.0
