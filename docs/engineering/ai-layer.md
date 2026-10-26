# 家簿 · AI 层设计

> 库版本与官方文档于 2026-10-25～26 核实。服务端整体规范见 [server-rust.md](server-rust.md)，选型依据见 [调研摘要](../research/library-evaluation-2026-10.md)。文中代码均为设计草图，未编译；genai 0.7 的确切方法签名以 docs.rs 为准。

## 0. 结论先行

1. **我们自己定义领域级 `ModelProvider` trait**（`parse_entry(文本, 图片) → 记录草稿 | 追问 | 非记账回复`），所有模型服务商都是它的适配器；上面一层 **`AiRouter`** 按配置选择提供方并做降级（fallback）。业务代码、任务队列、测试只认这个 trait，不认任何第三方库类型——库换掉不伤业务。
2. **默认提供方 = ChatGPT 订阅**，走官方 **Sign in with ChatGPT（下称 SIWC）**：OAuth 令牌调用公开的 `https://api.openai.com/v1/responses`，按 ChatGPT 订阅额度计费。genai 不支持 SIWC 的特殊要求，所以用 **async-openai 0.42** 自写 `SiwcProvider`。
3. **其他提供方经 genai 0.7（锁定 `=0.7.1`）接入，作为降级备选**：OpenAI API key、Anthropic、Gemini、DeepSeek、通义千问、Kimi、智谱、Ollama 本地模型等，用一个 `GenaiProvider` 按配置覆盖。
4. **结构化输出不信任库，信任服务端校验**：能用原生 JSON Schema 就用 → 否则工具调用 → 否则 JSON 模式 + 提示词里给 schema；结果一律经 serde 反序列化 + JSON Schema 校验 + 业务校验，失败带错误信息重试一次，再失败降级到下一个提供方。
5. **计费红线**：不把按量付费的 API key 作为默认，也不在订阅额度耗尽或接入失败时自动切到付费提供方；付费备选只有显式开启才会被使用。全部失败时任务进入 `waiting_ai`，稍后重试，绝不丢数据。
6. **Rig 不采用**：框架面太大、近 6 个月 10 个破坏性小版本、普通 OpenAI 配置只收静态 key、没有 namespace 工具，其内置 `chatgpt` provider 走的是非官方的 ChatGPT `backend-api`。
7. **回复 = 语义块，流式下发（草案）**：模型的文字输出逐步流给客户端；结构化部分（记录草稿、追问、问数）由服务端**确定性地映射**成 [ChatWeave](https://github.com/zz-howard/chatweave) 语义块，数字来自服务端的真实查询而不是模型。v1 没有 UI Agent。见第 13 节。

## 1. 设计原则

- **AI 只“提议”，服务端“执行”**：模型输出的是记录草稿或工具调用参数；真正写库前由服务端校验空间成员身份和业务规则。提供方失败不能绕过权限。
- **一个任务只属于一个空间**：每个 AI 任务和聊天会话都带 `space_id`；上下文只从该空间组装（该空间的账户、标签、成员、资料和聊天记录），AI 只往当前空间记账，不推断、不建议其他空间，也看不到其他空间的任何内容。各空间的聊天记录和 AI 上下文互相隔离。
- **上下文先过滤再调用**：用户共享一份订阅凭据，所以每次调用前必须先按空间（并校验发起者是该空间的活跃成员）筛选上下文；其他空间的内容绝不进入请求。记错空间的记录由用户手工移动，AI 不参与。
- **可替换**：领域 trait 隔离第三方库；即使 genai 停更，手写适配器的退路成本可控（估 1,000–1,500 行）。
- **可观测**：每次调用记账（提供方、模型、模式、耗时、token、结果），日志与用户的原始请求 ID 串起来。
- **可测试**：无网络的单元测试覆盖全部状态机与降级；适配器用录制回放 + 请求体快照守住库升级。

## 2. 领域接口

```rust
// crates/ai —— 领域级接口，不暴露任何第三方库类型
pub struct ParseEntryRequest {
    pub request_id: Uuid,            // = ai_jobs.id，日志 / 重放用
    pub text: String,                // 用户原话
    pub images: Vec<ImageInput>,     // { mime, bytes }，已在服务端压缩到 ≤1600px JPEG
    pub today: NaiveDate, pub tz: Tz,
    pub context: ParseContext,       // 只含当前空间的账户 / 标签 / 成员（由 ai_jobs.space_id 决定）
    pub history: Vec<Turn>,          // 追问来回
}
pub enum ParseOutcome {
    Draft(RecordDraft),                                      // 信息明确，可直接入账
    NeedsFollowUp { partial: RecordDraft, question: String, options: Vec<String> },
    NotARecord { reply: String },                            // 闲聊、问数等
}
pub struct Capabilities { pub structured: StructuredMode, pub vision: bool, pub max_images: u8 }
pub enum StructuredMode { JsonSchema, ToolCall, JsonObject, PromptOnly }

#[async_trait::async_trait]   // 需要 dyn，故用 async-trait 或手动 Box<dyn Future>
pub trait ModelProvider: Send + Sync {
    fn id(&self) -> &str;
    fn capabilities(&self) -> &Capabilities;
    async fn parse_entry(&self, req: &ParseEntryRequest) -> Result<ParseOutcome, ProviderError>;
}
/// 流式一轮（草案）：用于需要逐字显示的回复。适配器把提供方的流事件翻译成 TurnEvent；
/// 不支持流式的提供方在结束时一次性发出全部文字（自动降级，功能不变）。
pub enum TurnEvent {
    TextDelta(String),                                  // 给用户看的文字片段
    ToolCall { name: String, arguments: serde_json::Value },   // 参数完整后才发出
    Done { usage: Usage },
}
// ModelProvider 增加（草案）：
// async fn run_turn(&self, req: &TurnRequest, sink: &mut dyn TurnSink) -> Result<(), ProviderError>;

pub enum ProviderError {
    RateLimited { retry_after: Option<Duration> }, QuotaExhausted, Auth,
    Unsupported(&'static str), InvalidOutput { raw: String, reason: String },
    Timeout, Transport(String),
}
```

## 3. 提供方与适配器

| 适配器 | 实现 | 覆盖 | 定位 |
|---|---|---|---|
| `SiwcProvider` | async-openai 0.42（Responses API 全类型，含 `NamespaceToolParam`）+ oauth2 5（PKCE 登录与刷新） | ChatGPT 订阅 | **默认** |
| `GenaiProvider` | genai `=0.7.1`，按配置的 `kind` / `model` / `base_url` / `structured` 实例化 | OpenAI、Anthropic、Gemini、DeepSeek、通义千问、Kimi、智谱、Ollama 及任意 OpenAI 兼容端点 | 降级备选 |
| `MockProvider` | 按脚本返回结果 / 错误 | — | 测试 |

选 genai 的理由：它是唯一同时满足以下条件的 Rust 库——原生 Anthropic / Gemini 协议（不是兼容层）、三家都支持 JSON Schema 结构化输出、内置国内主流厂商与 Ollama、可自定义端点、**可用异步回调按请求提供 Bearer 令牌**（`AuthResolver`），而且只是“客户端”，不带 Agent 框架包袱。

### 3.1 各提供方能力与坑（以记账解析为准）

| 提供方 | 接入方式 | JSON Schema | 图片 | 工具 | 主要坑 |
|---|---|---|---|---|---|
| ChatGPT 订阅（SIWC） | `SiwcProvider` | ❓ `text.format` 官方未提及 → 用 namespace 工具兜底 | ✅（模型支持时） | ✅（须放进 namespace） | 见第 4 节 |
| OpenAI（API key） | genai `OpenAI` / `OpenAIResp` | ✅ strict | ✅ | ✅ | 付费；默认不启用 |
| Anthropic Claude | genai **原生** `Anthropic`（不走兼容层） | ✅ 原生 structured outputs | ✅ | ✅ | 官方 OpenAI 兼容层“非生产方案”，会忽略 `response_format` 与工具 `strict`；新一代模型不支持强制 `tool_choice`，所以用 structured outputs 而不是“强制调用工具” |
| Google Gemini | genai **原生** `Gemini` | ✅ `responseSchema`（genai 自动把 JSON Schema 收窄到 Gemini 支持的子集） | ✅ | ✅ | OpenAI 兼容端点仍标 beta |
| DeepSeek | genai `DeepSeek` | ⚠️ 官方只写 `json_object`（并提示偶尔返回空内容） | ⚠️ 未实测 | ✅ | 用工具调用或 json_object + 服务端校验 |
| 通义千问（百炼） | genai `Aliyun` / `QwenCloud` | ✅ 仅部分模型；json_object 覆盖大部分 | VL 系列（未逐一核实） | ✅ | 两处官方文档的模型列表不一致，以控制台为准 |
| Kimi | genai `Kimi` / `Moonshot` | ✅（复杂 schema 在部分模型上不稳定） | 未核实 | ✅ | — |
| 智谱 GLM | genai `Zai` / `BigModel` | ⚠️ 未核实 | 未核实 | ✅ | 需实测 |
| Ollama（本地） | genai `Ollama` 原生或 OpenAI 兼容 `/v1` | ⚠️ genai 原生适配器只发 `format: "json"`；要 schema 需用 `extra_body` 发 `format: <schema>` | ✅ 仅 base64 | ✅ | 质量随模型大幅变化；ARM64 上可跑多大的模型需实测 |

## 4. 默认提供方：ChatGPT 订阅（SIWC）

### 4.1 官方流程

- **登录**：浏览器 OAuth（PKCE、本机回环地址回调、动态注册客户端），scope `offline_access resource.invoke chatgpt.tokens.use.direct`，`resource=https://api.openai.com/v1`；每台主机一个持久的 `ext_agent_host_id`。
- **请求**：`POST https://api.openai.com/v1/responses`，`Authorization: Bearer <访问令牌>`。官方明确要求**不要**指向 ChatGPT 的 `backend-api` 端点。
- **令牌刷新**：应用自己负责刷新 OAuth 令牌；刷新后原子替换凭据文件。

### 4.2 请求约束（预览期限制）

- 每个请求必须 `store: false`、`stream: true`，收到 `response.completed` 才算成功。
- `previous_response_id` 不可用，历史需在 `input` 里带全；显式 `role: "system"` 消息被拒，改用 `instructions`。
- 必须省略：`background`、`conversation`、`max_output_tokens`、`max_tool_calls`、`metadata`、`moderation`、`multi_agent`、`prompt`、`prompt_cache_retention`、`safety_identifier`、`temperature`、`top_logprobs`、`top_p`、`truncation`、`user`。
- function / custom 工具必须放进 **namespace**，或通过 `additional_tools` 输入项提供；不支持图片生成、file search、Code Interpreter、托管 MCP、`tool_search`。
- 文本、图片、文件仅当所选模型接受时可用。
- 额度错误 `subscription_sharing_usage_limit_exceeded` / `subscription_sharing_usage_unavailable` 可能在流开始后以 `response.failed` 到达，适配器要映射成 `ProviderError::QuotaExhausted`。

这些约束正是不能直接用 genai 的原因：genai 没有 namespace 工具类型，且默认会发送 `temperature`、`max_output_tokens` 等必须省略的字段。

### 4.3 无头服务器上的登录

SIWC 只有浏览器 + 本机回环回调，没有设备码流程。按官方“Self-hosted VMs”指南：在本地电脑上用 `admin` 命令完成登录，再经 SSH 等安全通道把凭据文件转移到服务器；服务器使用自己的 `ext_agent_host_id`，自行负责后续刷新。也可以用 SSH 端口转发在服务器上直接完成登录。官方说明：被转移会话的“按主机用量归属与吊销”暂不可用。

### 4.4 接入验证清单（实现 `SiwcProvider` 时逐项通过）

1. 登录拿到含 `chatgpt.tokens.use.direct` 的令牌；`GET /v1/models` 查看账号可用模型。
2. 纯文本请求（stream + store=false）收到 `response.completed`。
3. 图片输入（收据照片 base64 data URL）成功。
4. namespace 工具调用：模型返回 `submit_record_draft` 工具调用，参数满足 JSON Schema。
5. `text.format: json_schema` 是否被接受（不通过则全部走工具调用）。
6. refresh_token 轮换：过期前自动刷新，凭据原子替换。
7. 额度用尽：不切换付费提供方，任务记为“待 AI 处理 · 额度不足”，稍后重试。

## 5. 结构化输出

- **同一份 schema**：`RecordDraftWire` 用 `schemars` 1.2 生成 JSON Schema。
  - `JsonSchema` 模式：直接下发；
  - `ToolCall` 模式：包成唯一工具 `submit_record_draft`（SIWC 下放进 namespace）；
  - `JsonObject` / `PromptOnly` 模式：写进系统提示。
- **统一校验 `validate()`**：serde 反序列化 → `jsonschema` 0.60 校验 → 业务规则（金额 > 0、账户 / 标签存在且属于任务所在空间、日期不在未来过远）。
- 校验失败：带错误原因重试一次；再失败按降级规则处理。
- 图片在服务端先压缩到 ≤ 1600px JPEG 再发给模型；原图另行留存。

## 6. 任务与追问状态

> 权限：AI 任务以发起成员的身份运行。组装上下文、执行工具时都经服务端统一的 `authorize(member, module, action)`，只能读写该成员有权限的模块（v1 为账本与资料）；无权模块的数据从源头就不进入提示词，而不是靠提示词要求模型“别说”。


AI 解析是异步任务，状态放在 PostgreSQL 里（“持久的人在回路”：用户可能隔几小时才回答追问）。

```sql
create table ai_jobs (
  id uuid primary key default uuidv7(),
  record_id uuid,                    -- 关联的聊天条目 / 记录
  space_id uuid not null,                      -- 任务所属空间；上下文与写入都只限于此空间
  requested_by_member_id uuid not null,        -- 发起者的空间成员 ID
  status text not null check (status in ('queued','running','waiting_user','waiting_ai','done','failed')),
  attempt int not null default 0,
  run_after timestamptz not null default now(),
  locked_until timestamptz,
  conversation jsonb not null default '[]',   -- 本任务的追问来回
  pending_question jsonb,                      -- 当前追问及选项
  provider_id text, last_error text,
  origin_request_id uuid,                      -- 用户原始请求的 X-Request-Id
  assistant_message_id uuid,                   -- 本轮回复在 chat_entries 中的 ID（ChatWeave 消息 ID）
  client_capabilities jsonb,                   -- 客户端声明能渲染的块类型（ChatWeave 能力声明），映射时参考
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
```

- 原话 / 图片入库时**同事务**插入 `ai_jobs(status = 'queued')`。
- worker 用 `SELECT … FOR UPDATE SKIP LOCKED` 取任务，`LISTEN/NOTIFY` 唤醒；处理时设 `locked_until` 租约。
- `Draft` → 校验后写记录，回复 = 一句文字 + 记录卡块，任务 `done`；`NeedsFollowUp` → 存 `pending_question`，回复 = 已识别内容的文字 + 选项块（`choice`），任务 `waiting_user`；`NotARecord` → 回复为文字（流式），任务 `done`。块的映射见第 13 节。
- 用户回答追问 = ChatWeave 动作 `clarification.answer`（动作 ID 即 `Idempotency-Key`）：服务端校验所选项确实在该选项块里、追问仍未回答，追加到 `conversation` 并把状态改回 `queued`；选项块状态改为“已回答”并同步到所有设备。
- 链上全部提供方失败 → `waiting_ai`，按 `run_after` 退避重试；用户也可以手工补录。
- 每次处理都从库里重建上下文，worker 本身无状态；重建时只读取 `space_id` 对应空间的数据，并确认发起成员仍是活跃成员——已退出则任务置 `failed`（原因“空间不可用”），不写入。

## 7. 路由、降级与计费策略

```toml
# config/ai.toml（凭据只写环境变量名或文件路径变量名，不写值）
[[provider]]
id = "chatgpt"
kind = "siwc"
model = "<按账号可用模型>"
credentials_path_env = "SIWC_CREDENTIALS_FILE"
structured = "tool_call"
vision = true
billing = "subscription"

[[provider]]
id = "local"
kind = "ollama"
model = "<本地模型>"
base_url = "http://localhost:11434/"
structured = "json_object"
vision = true
billing = "local"

[[provider]]
id = "gemini"
kind = "gemini"
model = "<按控制台>"
api_key_env = "GEMINI_API_KEY"
structured = "json_schema"
vision = true
billing = "paid"

[[provider]]
id = "qwen"
kind = "aliyun"
model = "qwen-plus"
api_key_env = "DASHSCOPE_API_KEY"
structured = "json_schema"
vision = false
billing = "paid"

[route]
text  = ["chatgpt", "local", "qwen"]
image = ["chatgpt", "local", "gemini"]   # 只挑 vision = true 的

[policy]
allow_paid_fallback = false      # 为 false 时链上 billing = "paid" 的提供方一律跳过
breaker = { failures = 3, cool_down_secs = 300 }
```

降级规则：

| 错误 | 处理 |
|---|---|
| `Timeout` / `Transport` / `RateLimited` / 5xx / `InvalidOutput`（重试一次后） | 链上下一个 |
| `Auth` / `QuotaExhausted` | 链上下一个，并告警 |
| `Unsupported`（如无视觉能力） | 路由前就过滤掉 |
| 链全部失败 | 任务置 `waiting_ai`，稍后重试 |

- 每个提供方一个熔断器（连续失败 N 次冷却 M 分钟）。
- **降级永远不越过 `billing` 策略**：订阅 / 本地失败后，只有 `allow_paid_fallback = true` 才会尝试付费提供方。
- **热切换**：配置文件变更后重新加载 `AiRouter`（`ArcSwap`），无需重启；已在跑的任务不受影响。

## 8. 可观测

```sql
create table ai_calls (
  id bigint generated always as identity primary key,
  job_id uuid not null, provider_id text not null, model text not null,
  structured_mode text not null, latency_ms int, input_tokens int, output_tokens int,
  outcome text not null, error_kind text, at timestamptz not null default now()
);
```

- 每次模型调用写一行，用于比较提供方质量、延迟和成本，也可经任务的发起成员关联到内部用户 ID，统计共享订阅的用量。
- worker span 带 `job_id`、`origin_request_id`、`provider_id`、模型名、重试次数、降级原因、耗时、token 用量。
- 日志不记原话、图片和模型完整回复。

## 9. 测试策略

1. **单元测试（无网络）**：`MockProvider` 按脚本返回 `Draft` / `NeedsFollowUp` / 各种错误，覆盖 worker 状态机、追问挂起与恢复、路由降级、熔断、billing 策略、校验与重试、幂等。
2. **适配器契约测试（录制回放）**：每个启用的提供方用真实凭据录一次 HTTP 交互（含 SSE 流），脱敏后存 `tests/fixtures/<provider>/*.json`；测试时用 `wiremock` 0.6 回放，并用 `insta` 1.49 对**我们发出去的请求体**做快照——genai / async-openai 都是 pre-1.0、发版频繁，升级若改了请求格式，快照会先报警（这条最重要）。SIWC 的快照还要断言必须省略的字段确实不存在。
3. **在线冒烟（手动）**：`cargo test --features live -- --ignored`，每个提供方 3 条样例，确认凭据、端点、模型名仍有效。
4. **评测集**：`eval/entries/*.yaml` 先做 60–100 条，覆盖口语中文（“昨天楼下早饭 18 块”）、一句多笔、相对日期、转账 / 退款、收据照片（清晰 / 倾斜 / 长小票）、信息不足应追问、闲聊非记账。每条写期望字段；`cargo run -p ai-eval -- --provider chatgpt,local,gemini` 输出 JSON 合法率、金额精确率、日期 / 分类准确率、追问触发的精确率与召回率、P50 / P95 延迟、单条成本。结果 CSV 入库；调整降级顺序或升级模型前必须跑一遍。**评测集只用自造或脱敏数据**。

## 10. 依赖草案

```toml
genai = "=0.7.1"                       # 锁死：pre-1.0，升级走快照测试
async-openai = { version = "0.42", features = ["responses"] }   # SiwcProvider；feature 以编译为准
oauth2 = "5"                           # SIWC 登录与刷新
schemars = "1.2"
jsonschema = { version = "0.60", default-features = false }
async-trait = "0.1"
arc-swap = "1"

[dev-dependencies]
wiremock = "0.6"
insta = { version = "1.49", features = ["json"] }
```

## 11. 风险

| # | 事项 | 对策 |
|---|---|---|
| 1 | 官方未写明“自建服务器、两位家庭成员共用一份订阅”是否在 SIWC 允许范围内（官方措辞：开源项目、本地运行的个人项目和少数私有应用可用；付费或远程托管应用需加入候补） | 架构上提供方可替换；本地模型可作为免费备选；按内部用户 ID 记录每次调用，便于日后拆分 |
| 2 | SIWC 仍是预览期，限制可能变化；`text.format` 结构化输出未被官方提及 | 每次升级前复读官方 preview limitations；结构化输出走 namespace 工具兜底 |
| 3 | 没有任何 Rust crate 封装官方 SIWC | 用 async-openai 自写，契约测试守住 |
| 4 | genai 基本单人维护（bus factor 1），发版频繁 | 领域 trait 隔离 + 锁版本 + 请求体快照；退路是手写适配器 |
| 5 | genai Ollama 原生适配器不下发 JSON Schema | 用 `extra_body` 发 `format`，或走 `/v1`（未实测） |
| 6 | DeepSeek / 智谱 json_schema、智谱 / Kimi 图片、千问 VL 结构化输出 | 未核实，靠评测集实测 |

## 12. Agent 运行时分期（待定）

当前接口是“单次解析 + 追问”。后续可能需要“主 Agent 带工具”（例如查余额、查历史、调拨）乃至外部 Agent 接入。**分期尚未确定**，当前提议：

- **v1**：持久化澄清（第 6 节的 Postgres 状态表）+ 单个主 Agent 带工具。Agent 循环在 genai / async-openai 之上自写（“调用模型 → 有工具调用则执行 → 回填结果 → 循环；遇到 `ask_user` 就挂起”，估 300–600 行），状态放 Postgres，工具执行前同样经过空间成员与业务校验。工具在服务端绑定任务的 `space_id`：工具参数里没有 `space_id`，模型无法指定或切换空间，查余额、查历史等也只能看到当前空间。
- **v2**：外部 Agent 网关（例如接入 Claude Code 等通用编程 / 助手类 Agent）。
- 不引入 Rig 的 `AgentRun` 作为持久状态（其 0.44 版本改过序列化格式，旧数据无法加载）；Temporal / Restate 等持久工作流引擎对两人应用过重。

见 [待定问题](../decisions/README.md#待定问题open-questions)。

## 13. 回复内容：语义块与流式输出（ChatWeave，草案）

聊天回复使用开源库 [ChatWeave](https://github.com/zz-howard/chatweave) 的协议：一条回复是有序的“语义块”（只有数据和含义，没有颜色、尺寸、布局），外加一段必有的纯文本兜底。库的设计在其仓库里；这里只写家簿 AI 层怎么产出这些块。

### 13.1 原则

- **模型决定“说什么”，服务端决定“用哪个块”**：映射是服务端代码里的确定性规则（查表），不调用额外的模型，v1 没有 UI Agent。
- **数字不由模型编**：余额、笔数、合计、视力数值等一律由服务端按任务的 `space_id` 经 `authorize()` 查询后填进块；模型只通过类型化工具说明“要查什么”。
- **先校验再发出**：每个块经 ChatWeave 的 Schema 与限制校验（自定义块 `x-jiabu.*` 用家簿注册的 Schema）后才进入流和数据库；校验失败的块改为一段兜底文字，整条回复照常完成。
- **按客户端能力选块**：任务记录了客户端声明的能力；客户端不支持某类型（例如图表）时，映射直接选更朴素的类型（表格或文字）。持久化的始终是规范形态。

### 13.2 映射表（v1）

| AI 结果 / 工具 | 生成的块 |
|---|---|
| 模型的文字输出（任何一轮） | `markdown`，逐字流式（服务端把 token 合并成约 20 字或 50ms 一批） |
| `ParseOutcome::Draft` | `markdown`（服务端模板生成的一句话，如“记好了：午饭 68。”）+ `x-jiabu.record_card { recordId }` |
| `ParseOutcome::NeedsFollowUp` | `markdown`（已识别的内容）+ `choice { prompt: 追问句, options, allowFreeText: true, action: clarification.answer }` |
| `ParseOutcome::NotARecord` | `markdown` |
| 家庭资料整理完成 | `markdown` + `x-jiabu.document_card { documentId }` |
| 问数工具 `query_stats { metric, period, filters }`（v1 单主 Agent 的工具） | 服务端执行真实查询 → 单值用 `metric`，多值用 `metric_group`，明细用 `dataset`，按时间的数值用 `time_series`（例如历次视力） |
| 首次设置缺多项信息 | `form_intent { action: setup.submit }`；设置完成后账户摘要用 `dataset` |
| 需要用户确认的不可撤销操作（v1 预留） | 服务端暂存待执行操作 → `confirmation { severity: destructive, action: pending_operation.confirm }` |

记录卡、资料卡只带 ID，卡片内容由客户端从本机已同步的记录读取：编辑 / 撤销后自动更新，聊天记录里也不复制业务数据。

### 13.3 流式与提供方

- SIWC 的 Responses API 本来就要求 `stream: true`：文字增量 → `TurnEvent::TextDelta` → `markdown` 块的增量；函数调用参数在流中分片到达，适配器**缓冲到完整**再发出 `TurnEvent::ToolCall`，服务端执行后整块发出组件（与 ChatWeave v1“组件整块到达”一致）。
- genai 接入的提供方：支持流式的同样处理；不支持的在结束时一次性发出文字，客户端只是看不到逐字效果。
- 记账解析（`parse_entry`）仍是一次结构化调用；它产出的回复很短，直接按 13.2 生成块，不需要逐字。
- 链上降级发生在流开始之后时：已发出的文字保留，换下一个提供方前先结束当前块，并在回复里说明（不静默重复已说过的话）；全部失败则回复以 `interrupted` 结束，任务进入 `waiting_ai`。

### 13.4 外部 Agent（v2）

将来接入的外部 Agent（第 12 节）大多只会输出文本：它们的输出整体作为 `markdown` 块流式下发；**适配器不从文本里推断金额、账户等业务事实**，也不生成组件。外部 Agent 想展示结构化内容，只能调用家簿提供的受控工具，由服务端按 13.2 生成块。

## 14. 来源

- OpenAI SIWC：https://developers.openai.com/siwc/ 、https://developers.openai.com/siwc/token-sharing-open-source 、…/models-and-inference 、…/preview-limitations 、https://developers.openai.com/cookbook/articles/sign-in-with-chatgpt
- 各厂商：platform.claude.com（OpenAI SDK 兼容层限制）、ai.google.dev/gemini-api/docs/openai 、api-docs.deepseek.com/guides/json_mode 与 /guides/vision 、docs.ollama.com/api/openai-compatibility 、阿里云百炼结构化输出文档、platform.kimi.ai/docs/guide/response_format
- 库：https://crates.io/crates/genai 、https://github.com/jeremychone/rust-genai 、https://crates.io/crates/async-openai 、https://github.com/64bit/async-openai 、https://github.com/0xPlaygrounds/rig
