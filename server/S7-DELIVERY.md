# S7 / PR ①：AI 与配置

实现依据：`~/zylos/workspace/jiabu-s7/go1.md`。仅在当前工作树改文件，未提交、未编译、未安装工具链、未联网。构建、数据库测试、格式化、依赖许可审查和生成文件都等待构建机验证；本文不代表这些检查已通过。

## 本 PR 内容

- `domain::ai`：提供方、模型、路由、策略、加密凭据 DTO；没有 IO。
- `ai`：对象安全的 provider / sink / observer 接口，冻结模型参数，按模型配置路由，默认禁止付费备选，提供方级熔断（3 次 / 60 秒 / 单半开探测），配置替换共享原熔断状态；Mock 支持文字、工具、错误、延迟、barrier、超时脚本。
- SIWC：固定官方 Responses 端点；namespace 工具、JPEG data URL、完整历史、会话缓存键与请求头；请求字段白名单。SDK 类型只验证请求，实际通过 reqwest 发送原始白名单 JSON，避免 SDK 默认字段、隐式重试与实际调用计量不一致。SSE 支持分片 / CRLF；文字 delta 用于显示，完成项按 output_index 收集；不重复追加完成项文字；工具和 opaque reasoning 在 completed 后发布。额度、认证、限流、传输、超时、缺 completed 有独立错误。blob 拒绝只去除重试一次，sink 收到需要落 journal 的 Note。
- OAuth：PKCE S256、state、nonce、回环回调校验，粘贴回调，刷新轮换。CLI 登录后访问官方 `/v1/models` 校验直接 API 权限并列出可配置模型。登录默认加密存库；file 来源使用带 revision 的 JSON envelope、进程间文件锁、0600 临时文件、sync + 同目录 rename。
- 凭据：XChaCha20-Poly1305、随机 24 字节 nonce、AAD=`owner_kind/owner_id/field`；主密钥由 `secrecy` 包装、临时明文用 `zeroize` 清理。主密钥文件是原始 32 字节 / 权限 0600；也接受 `JIABU_SECRETS_KEY` 的 base64 值。密钥 ID 默认 primary，可用 `JIABU_SECRETS_KEY_ID` 指定。数据库只存密文；OAuth 不显示令牌末四位。
- `db`：单条 SQL 的一致配置快照、密文读取 / 窄 CAS、封装的通知订阅；模型请求前独立提交计量登记，结束时独立完成，调用价格在登记时固定。所有金额在 PostgreSQL numeric 中计算；记录缓存读写；没有价格仍执行并告警、成本为 NULL。单进程启动时把遗留 started 行标为 lost，token 为 NULL。
- `db-admin` / `admin` / CLI：提供方与模型 add/update/enable/disable/list，提供方 status/set-secret/clear-secret/login，route show/set/clear，price list/add，settings show/set。配置写入与 CLI 审计同事务；触发器更新 config_version 并在提交时通知。没有管理 API、物理删除或价格覆盖。admin 不依赖 AI / 公共 DB / chat / agent / storage / api；仅管理二进制组合登录。
- 服务端：先订阅再首次加载，NOTIFY + 60 秒兜底，ArcSwap 热替换；外部文件 / 环境凭据在兜底时重新检查。`GET /v1/status` 精确查询 `availability(Chat)`；只读 key 可以查询，不发模型请求。
- 0008 仅新增上述配置 / OAuth 元数据、密文 revision / usable、调用完成标记与函数。运行表、会话表、动作、journal 保留期均留给 PR ②。

## 文档没写清、我是这么做的

1. 按 go1，id_token 只接受直接 TLS 令牌端点响应，检查 iss / aud / exp / nonce，不做 JWKS 签名验证，不引入 openidconnect。OAuth 传输关闭重定向；生产仅使用官方 issuer。loopback HTTP override 仅用于合成契约测试。
2. 动态客户端首次使用 `dynamic_agent_client`；令牌响应有 client_id 时按它核对 audience，否则要求直接令牌响应的 audience 是单个 `oaiapp_…` 应用 ID，保存后用于后续登录和刷新。真实 SIWC 响应形状需由 luna.coco 的在线测试验证。scope 在令牌响应中存在时逐项检查；省略时沿用本次申请范围，并用 `/v1/models` 再验证访问。
3. 主机 ID 存在 ai_settings 的单例行中，适用于 v1 单主机部署，不是每次进程启动生成。首次 `provider login chatgpt` 可创建订阅 SIWC 提供方；模型与路由由管理员从返回的账号模型列表配置。
4. 管理配置 add/update 和 price/settings set 使用 `--file <JSON>`，提供方 / 模型 update 是完整替换元数据。模型 add 缺 id 时生成 UUIDv7；provider.version 默认 1，但更新版本只由数据库递增。secret 只接受 `--stdin` / `--file`，不接受 argv 明文。价格为十进制字符串；`cache_write` 的费率值也用字符串，`long_context` 的阈值用整数、费率用字符串。
5. 文件凭据结构是 `{revision, usable, credentials: {access_token, refresh_token, client_id, account_id, expires_at, host_id}}`。env 来源是其中 credentials 本体 JSON，只适合外部负责更新令牌的场景；CAS 永远失败，自动刷新后的令牌只用于本次调用，不会保存。建议使用数据库或文件实现自动轮换。file/env 来源不由本 CLI 覆盖。
6. 缓存写入用量目前没有 TTL：价格表存在 default 时使用 default；只有一个 TTL 费率时使用该费率；多个 TTL 且无 default 时，不猜测费率，成本保持 NULL。长上下文按 input_tokens 阈值选价。价格缺失不阻止调用，历史价格不重算。
7. 配置一次管理操作可以触发多次版本递增；约定是单调递增，不保证正好 +1。所有正常配置写入与 OAuth 函数先锁 settings 行，避免密钥行 / 提供方行之间的锁反转。刷新 CAS 只允许当前启用的 SIWC 数据库 OAuth 行，刷新失败的失效写入也绑定 revision；旧请求的认证失败不撤销已经轮换的新令牌。单进程内还按 provider ID 跨配置代共享刷新锁，避免热替换期间两个适配器同时使用旧 refresh token。
8. 运行等待退避的 5 秒初值 / 60 秒上限 / 600 秒硬上限在本 PR 提供可配置字段；实际等待状态机留 PR ②。路由的 5 分钟总调用超时和 SIWC 的 60 秒流空闲超时已经接入。
9. ProviderBlob 作为有序 RequestItem 保留在模型输出原位置，限提供方 / 模型 / 账号完全匹配才发送；无关 scope 就地跳过，其余条目顺序不变。被拒后重试一次，移除全部 ProviderBlob 条目并保留其余历史顺序。PR ② 负责消费 Note、原子落 model_turn / journal、保存前缀计量上下文；本 PR 不建立任何 agent worker。
10. 非 SIWC 的真实付费适配器按范围不实现。配置能力与付费开关已存在，Mock 覆盖付费降级。ChatWeave 依赖、dispatcher 授权接线与通用后续项均在 PR ② 处理。

11. 凭据规则：每次调用在共享刷新锁内读存储，不缓存凭据；闸门按 `(provider_id, source_identity)` 跨配置代常驻共享，只含锁与 `usable`。墓碑 / 损坏返回 Auth 并标记不可用，临时读取故障返回 Transport、不改可用性，退避由路由熔断处理。访问令牌 60 秒内到期或收到 401 / invalid_token 时，有 refresh token 就刷新；并发被拒请求若读到令牌已变，直接复用。成功后 CAS 保存新令牌，CAS 冲突或存储错误只记日志，本次仍用刷新结果；下次以存储为准。令牌端点明确拒绝则按 revision invalidate、标记不可用并要求重新登录；网络 / 5xx / 429 失败时沿用尚未过期的访问令牌，过期则返回 Transport，不保留失败状态。`available()` 只读 `usable`。模型认证失败最多刷新后重试一次，已有可见输出不重试；403 不改凭据。clear-secret 保留递增 revision 的墓碑，重新登录继续递增，下一次读库立即生效。
12. router 跟踪已送往 sink 的非空文字、工具调用及 Note；已部分输出后的失败返回带原始错误的 PartialOutput，停止同一 sink 上的透明重试和降级，PR ② 据此保留已有文字并另起一块。
13. 半开探测由 RAII 许可持有，提前返回或取消均按失败释放；包含重试及 observer / sink 等待的单提供方调用总时限为 300 秒，过期探测在额外冷却后可回收，许可代次隔离过期探测的迟到收尾。

## CLI 输入例子（全部虚构）

`admin provider add --file provider.json`：

```json
{"id":"chatgpt","kind":"siwc","billing":"subscription","base_url":null,"secret_source":"db"}
```

`admin model add --file model.json`（model 替换为登录后账号列表中的名称）：

```json
{"provider_id":"chatgpt","model":"synthetic-model","structured":"tool_call","vision":true,"context_tokens":32000}
```

随后用 `admin model list` 得到模型 UUID，再 `admin route set chat <UUID>` 与 `admin route set chat_vision <UUID>`。`admin route clear chat_vision` 清空该链。`admin settings set --file settings.json` 的输入：

```json
{"allow_paid_fallback":false,"breaker":{"failures":3,"cool_down_secs":60},"retry_initial_secs":5,"retry_max_secs":60,"waiting_timeout_secs":600}
```

## 已编写、等待构建机运行的验收

- `ai/tests/siwc.rs`：请求体 inline insta 快照、禁用字段、会话头 / 缓存键、namespace / 图片、完整参数原样回放、output_item.done / delta 去重、completed 空 output、缺 completed、两类流中额度错误、逐字节 CRLF SSE、scope 过滤、wiremock blob 拒绝后的两次独立调用。
- `ai/tests/oauth.rs`：PKCE challenge 与真实提交 verifier 对应、state / 重复参数 / 错误回调、iss / aud / exp / nonce、刷新令牌轮换、并发访问及配置代之间共享单次刷新、旧认证失败不撤销新令牌、刷新失败后路由不可用。
- `ai/tests/router.rs`：付费默认关闭且付费 Mock 调用数为零、明确启用后可降级、仅 chat 路由、热替换保留打开熔断器、半开单探测、blob 只重试一次、每次尝试独立 observer 记录。
- `support/ai_secrets.rs`：随机 nonce、AAD 跨 owner / field 失败、密文篡改拒绝；敏感类型不提供 Debug。生产错误不包含上游原文。
- `db/src/tests/ai.rs`：真实 PG18 并发 OAuth CAS 只有一个胜者、应用没有 secrets 普通写权限、PUBLIC 无函数执行权、固定 search_path、角色分离、配置审计 / 通知 / 版本 / 回滚、价格只追加、独立登记、固定历史价格、缓存读写 / numeric 金额、未知成本 NULL、失败 / lost、完成标记不可重复写。
- `api/src/tests.rs`：通过真实路由和认证检查 `/status`，只看 chat、受付费策略影响、session 和只读 key 均可查询，且 agent_runs / ai_calls 不增加。
- `bins/server/src/ai_runtime.rs`：真实 PG18 NOTIFY 热替换、文件凭据失效后不可用、计量 trait 接线；不调用真实提供方。
- CLI：参数解析验证不接受 argv secret 或设备码登录；admin 十进制费率验证。

### PR ① 负对照（构建机临时修改，不提交）

| 故意改坏 | 必须失败的测试 |
|---|---|
| 删除 router 的 billing::allowed 过滤 | paid_fallback_disabled_never_calls_paid_mock_and_meters_each_actual_attempt |
| `/status` 查询任何路由 / 改查 chat_vision | status_uses_chat_availability_with_session_or_key_and_never_creates_runs |
| 请求加回 temperature 等禁用字段 | request_snapshot_is_allowlisted_with_namespace_image_and_no_forbidden_fields |
| ai_refresh_oauth 去掉 revision 条件 | refresh_cas_two_concurrent_rotations_have_exactly_one_winner_and_narrow_grants |
| encryption open/seal 都改为空 AAD | random_nonce_aad_owner_binding_and_tamper_rejection |

## 构建机需要生成 / 验证

1. 先解析并构建最小接线：最可能出错的是 async-openai 0.42 的 `responses` feature / `types::responses::CreateResponse` / namespace serde 形状，以及 reqwest 对齐版本和 feature 名。已按评审版本放入 manifest，reqwest 0.13 的版本对齐标 TODO(luna)。PKCE 使用 oauth2 5，HTTP 直接由 reqwest 发送；没有引入 openidconnect / genai。
2. 更新 Cargo.lock；不手造锁文件校验和。检查许可证与 cargo deny / audit。
3. 运行 `tool/check-entities.sh --write`（可丢弃 PG18 集群），重生成实体。预期涉及 ai_providers、ai_settings、secrets、ai_calls；本机没有手改 generated 文件。
4. 在构建机运行 `cargo fmt --all`，再运行 AGENTS 指定的 fmt check、clippy、nextest、deny、audit 与四个 tool/check 脚本。本机没有 rustfmt，因此源文件尚未经过 rustfmt。
5. `cargo run --bin admin -- openapi export --out openapi`；审查 public 与 admin 两份 JSON。①只改 public `/status` 描述，未新增管理 HTTP 接口。
6. `chacha20poly1305 0.11` 的 KeyInit / nonce 转换、secrecy 的 SecretBox<Vec<u8>>、sqlx 0.9 / SeaORM 2.0.4 的 bind / query_raw 与 PgListener 需要首次编译核对。把错误贴回后继续修；未将未运行的验证标记为通过。
7. 最终真实登录、缓存命中与真实模型冒烟由 luna.coco 执行；本轮未联网。

## 本机静态检查

已通过：全部 Cargo.toml 的 Python tomllib 解析、`tool/check-rules.sh`、`git diff --check`。未运行编译、测试、fmt、clippy、cargo tree、deny、audit、实体生成或 OpenAPI 导出。

## 改动文件清单

- `server/Cargo.toml`
- `server/S7-DELIVERY.md`
- `server/bins/admin/Cargo.toml`
- `server/bins/admin/src/ai_commands.rs`
- `server/bins/admin/src/main.rs`
- `server/bins/server/Cargo.toml`
- `server/bins/server/src/ai_runtime.rs`
- `server/bins/server/src/main.rs`
- `server/crates/admin/Cargo.toml`
- `server/crates/admin/src/ai.rs`
- `server/crates/admin/src/lib.rs`
- `server/crates/ai/Cargo.toml`
- `server/crates/ai/src/billing.rs`
- `server/crates/ai/src/breaker.rs`
- `server/crates/ai/src/credentials.rs`
- `server/crates/ai/src/lib.rs`
- `server/crates/ai/src/mock.rs`
- `server/crates/ai/src/provider.rs`
- `server/crates/ai/src/router.rs`
- `server/crates/ai/src/siwc/mod.rs`
- `server/crates/ai/src/siwc/oauth.rs`
- `server/crates/ai/src/siwc/request.rs`
- `server/crates/ai/src/siwc/stream.rs`
- `server/crates/ai/src/types.rs`
- `server/crates/ai/tests/oauth.rs`
- `server/crates/ai/tests/router.rs`
- `server/crates/ai/tests/siwc.rs`
- `server/crates/ai/tests/support/mod.rs`
- `server/crates/api/Cargo.toml`
- `server/crates/api/src/handlers/status.rs`
- `server/crates/api/src/state.rs`
- `server/crates/api/src/tests.rs`
- `server/crates/db-admin/src/ai_configuration.rs`
- `server/crates/db-admin/src/lib.rs`
- `server/crates/db-admin/src/provider_secrets.rs`
- `server/crates/db/Cargo.toml`
- `server/crates/db/src/ai_config.rs`
- `server/crates/db/src/ai_metering.rs`
- `server/crates/db/src/lib.rs`
- `server/crates/db/src/tests.rs`
- `server/crates/db/src/tests/ai.rs`
- `server/crates/domain/src/ai.rs`
- `server/crates/domain/src/lib.rs`
- `server/migrations/0008_s7_ai.sql`
- `server/support/ai_secrets.rs`

第二轮独立评审修复：

- 每次尝试传入总时限的剩余预算（含登记耗时），只对提供方调用套超时；捕获 Timeout 后独立执行 `observer.finish()`，router 返回前 `ai_calls` 已完成（`outcome=failed`、`error_kind=timeout`、`completed_at` 非空），重试共用剩余预算。
- 模型请求 401 或流中 `invalid_api_key` / `invalid_token` / `token_expired` 在尚无可见输出时，经共享刷新锁重新读取并强制刷新（并发请求已轮换则复用新令牌），仅重试一次；凭据失效仅由令牌端点明确的 `invalid_grant` / `invalid_client` / `unauthorized_client` 触发。403 保留 quota 码 → `QuotaExhausted`、`rate_limit_exceeded` → `RateLimited`、加密内容拒绝码 → `BlobRejected`；`permission_denied` / `insufficient_permissions` / `model_not_found` / `model_access_denied` 及未知或访问令牌类 403 → `Unsupported("permission denied")`，均不刷新、不修改凭据；已输出内容的流失败不透明重试。


第三轮独立评审修复：

- SIWC 认证恢复的两次物理模型请求分别经过 observer begin/finish，第一次记录 auth、第二次记录 success 或自身错误，共用剩余超时预算；补充 401 / 流中认证错误的逐次计量断言。
- 需要 DB 主密钥时读取失败使 reload 返回错误并保留旧 router 与版本，首次失败保留 version=-1 的不可用 router，60 秒兜底按未加载版本重试；新增密钥恢复后同配置重新加载及可用性断言（本轮均未编译或运行测试）。


第四轮独立评审修复：

- 完成项 refusal 文本与 output_text 一样发送给 sink，response.refusal.delta 复用文字增量与完成项前缀去重规则；补充无增量、部分增量和完整增量拒答流测试。
- response.completed 的 usage 在发布其他事件前同步交给 AttemptSink 计量，后续 ToolCall sink 失败仍独立 finish；补充 observer 与 ai_calls token、成本、失败结果断言（本轮未编译或运行测试，未联网）。


凭据简化回归覆盖：到期前刷新并 CAS 保存新 refresh token、并发到期只刷新一次、401 单次重试及并发 401 共用刷新、明确拒绝后不可用及重新登录恢复、503 后下一次调用恢复、真实 db-admin clear-secret 路径阻止下一次请求发送旧令牌、临时读取故障恢复。本轮仅做静态核对，未编译、未运行 Rust / 数据库测试、未联网、未提交。

## 已知限制

- 刷新成功但写库失败时，新 refresh token 只用于本次调用；若上游已作废旧 refresh token，需要重新登录。
- 调用截止时间取消刷新时，可能丢失上游已轮换的新 refresh token，需要重新登录。

## PR ②：持久运行与聊天接口

实现依据：`~/zylos/workspace/jiabu-s7/go2.md`，以末尾“补充：控制复杂度”为最高口径。

### 本 PR 内容

- 迁移 0009：运行状态增加 `interrupted`，增加 `waiting_ai_since`、`journal_compacted_at`、动作 SHA-256 请求指纹；FIFO 索引 `(conversation_id, created_at, id)`；保留期函数 `retain_agent_journals(int)`（终态 7 天清 provider_blob、30 天压缩 journal 与工具原始参数并标不可重试），由 jiabu_owner 持有、固定 search_path、撤销 PUBLIC EXECUTE、仅授予 jiabu_app。0010 只为 ChatWeave 检查点保存私有 `step_work_ms`。
- `db::chat_runtime`：全部运行 SQL。worker 写入前的 guard 同时检查运行、空间、成员、join_epoch、lease_owner、lease_epoch、租约有效期与 cancel_requested。领取按 `(created_at, id)` FIFO，同会话有 running / paused 或更早的 queued / waiting_ai 时不领取后面的运行。
- `tools`：HTTP 与 Agent 共用执行核心，Agent 不能绕过注册表；ApiOnly 不对 Agent 开放，AgentOnly 的 `ask_user` 只由运行时解释为中断，没有公开路由。执行、审计、幂等占位用 SAVEPOINT 包围，业务失败整体回滚到保存点；工具调用幂等键 `uuidv5(run_id, call_id)`，重试复制原键。
- `chat`：复用 ChatWeave MessageStream / FoldState / ResumeService / SSE。事件先进暂存批次，连同 journal、工具状态、检查点在一个受租约保护的 SpaceTx 内提交，提交后才广播。记录卡 / 文档卡只含 ID 与版本；统计、余额、明细等卡片从工具结构化结果映射，不从模型文字提取。暂停 / 回答 rev=0，最终 rev=1，最终后修订增加 rev 与 change_seq。事件日志 10 分钟清理，清理后按能力协商返回快照。
- `agent`：固定两个 worker，NOTIFY 唤醒加 5 秒轮询；租约 60 秒、20 秒续租；30 秒清扫器。六段 renderer 递归规范化对象键、保留数组次序与原 args_raw，`s7-renderer` 子命令供两个独立进程比对字节。运行开始时冻结空间上下文、工具定义、时间与 locale，历史按上下文字节预算无状态截断。动作处理先查身份 / epoch / 会话 / 持久块 / 原工具权限 / 冻结环境，再查绑定指纹的回执。
- 接口：提交消息、SSE、动作、停止、重试、活跃回复六条路由。key 双重拒绝（路由 SessionOnly + 服务层 `require_ai_session()`，错误码 `api_key_ai_not_allowed`）。SSE 先查成员与消息归属，Last-Event-ID 优先于 `after`，15 秒心跳、5 分钟空闲期限（ping 不续期）。路由与 worker 共用同一个 StreamHub。`/sync/push` 伪装的聊天提交不产生运行。

### 有意简化（覆盖原计划）

1. 租约过期、优雅停机超时（约 20 秒）、模型 PartialOutput 一律把运行标 `interrupted`，收尾已持久的消息并发 `message.end`，只由用户显式重试。不自动重排、不续跑模型流、停机不释放回队列。暂停后回答是正常的持久中断流程，不受影响。
2. 不加 queue_seq，同时间戳以 UUIDv7 id 排序。
3. 不加活跃时间累计检查点，活跃预算只在进程内计。
4. 不加会话历史整理状态，运行开始时按预算截取最近完整历史，运行内不重排。
5. 不引入 proptest，`next_action()` 用表驱动单元测试；前缀稳定只验收“两个独立进程渲染同一 journal 字节相同”。
6. 预算：20 轮、活跃 10 分钟、waiting_ai 10 分钟、单次模型调用 5 分钟、模型流空闲 60 秒、工具 10 秒。超限标 `failed`，用确定性服务端文案收尾，不再调模型。
7. 原运行遇到工具 schema 变化安全失败；显式重试的新运行使用当前定义，已提交结果保留且不重复执行。
8. worker 只依赖 AiRouter，不接触凭据内部状态。

### 文档没写清、我是这么做的

- 既有 `chat_actions` 行的请求指纹为 NULL，不编造旧哈希；这类旧回执的回放按指纹不符拒绝。
- 压缩后的 journal 保留 kind / call_id / created_at 与工具名 / 状态，删除 payload 原文；`history_item` 是单独保留的聊天历史，不按 journal 规则删除。`journal_compacted_at` 是拒绝重试的依据。
- 停止时若模型 markdown 块尚未关闭，由库终结它，数量说明进 terminal_summary，避免出现第二个打开的 markdown 块。
- 流式输出期间，所有空间事务都在持有暂存锁时进行；50ms 刷新 tick 只 `try_lock`，续租与模型调用并行轮询。否则 tick 或续租在 `select!` 分支里等锁时，持锁的模型 future 不再被轮询，回复会永久卡住（第一轮评审发现）。

- 工具结果映射出的卡片超过协议上限（如 13 个账户余额超过 metric_group 的 12 项，或累计超过 256 KiB 消息上限）时不显示该卡片（在当前流的副本上试发判断），完整 tool_result 照常给模型，由模型用文字回答，不让整个回复失败。
- 暂停期间成员权限变化（如转让空间所有权）后回答追问：拒绝（404，仍在查回执之前），同时把该回复收尾为 `failed(permission_changed)`，不让它挂到 7 天过期；用户另发新消息即可。ChatWeave 只能用 stop / 过期终结暂停中的流，`close_run` 对暂停流的其他原因统一走 stop。
- 优雅停机时，排队 / waiting_ai / 暂停回复的 SSE 不会自己结束；HTTP 排空最多等 worker 宽限加 5 秒（约 25 秒）后退出，客户端重连续传。

### 应以通用形式进库（ChatWeave）

- `action/dispatch.rs::dispatch()` 在 `handler.authorize` 前调用 `find_result`。家簿在同事务里先授权再查回执；建议库提供“授权后读取回执”的严格顺序。
- `stream.rs` 的存检查点、append、publish 是分开的存储调用。家簿用暂存批次加一个受 epoch 保护的事务提交，提交后广播；建议库提供宿主原子提交批次的接口。

### 已知限制

- 运行中断后由用户点重试，不自动恢复；重试会重新调用模型（已提交的工具结果不重复执行）。
- 进程崩溃时，正在进行的回复要等租约过期（最多约 60 秒）加下一次清扫（最多 30 秒）才显示为中断。

### 验证

构建机：fmt、clippy `-D warnings`、nextest 全部、cargo deny、cargo audit、四个检查脚本、OpenAPI 导出。

负对照（构建机临时改坏、跑对应测试、撤回，不提交损坏实现）：

| 改坏 | 结果 |
|---|---|
| worker guard 去掉 lease_epoch 条件 | `reclaimed_run_rejects_writes_from_the_same_owners_earlier_epoch` 失败。原 `stale_lease_epoch_*` 测试因清扫后状态已非 running 抓不到，补了这条同一 owner 只差 epoch 的测试 |
| 领取去掉“更早的 queued / waiting_ai 阻塞” | `later_message_waits_behind_earlier_run_backing_off_for_ai` 失败（同上，原并发测试抓不到，已补） |
| 领取不再被 paused 阻塞（B/A 先后） | `queued_b_remains_blocked_when_running_a_later_pauses` 失败 |
| 新消息不关闭暂停中的 A | `new_c_closes_paused_a_but_does_not_overtake_queued_b` 失败 |
| 重试复制工具调用时重新生成幂等键 | `retry_lunch_50_parking_10_*` 失败 |
| 服务层去掉 `require_ai_session()` | `service_layer_key_rejected_without_runs_or_model_calls` 失败 |
| 重试把已成功调用改回 proposed | 测试仍通过：执行器以 journal 中的 tool_result 为准跳过，状态复制是第二道 |
| 动作去掉工具模块授权 | 测试仍通过：权限变化先被冻结环境校验以 404 拒绝（同样在查回执之前），模块授权是第二道 |
| 恢复 SQL 去掉 paused / interrupt ID 条件 | 测试仍通过：服务层在行锁内已检查同样条件，SQL 条件是第二道 |
| RunEmitter::commit 改为先广播后提交 | **未被抓到**：`sse_commit_before_broadcast_survives_crash` 只验证“已提交未广播可重放”，没走 `commit()`；确定性地让提交在广播后失败需要故障注入，未做。顺序由 `commit()` 三行代码保证 |
