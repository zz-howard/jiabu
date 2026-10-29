# 家簿 · AI 层设计

> 文档版本 v0.2（2026-10-27）：按[技术方案](technical-design.md) v0.3 第 13 节和实验 E1 的结论同步；实现层（运行种类、排队、重试、恢复检查）以技术方案第 7 节为准。库版本与官方文档于 2026-10-25～26 核实（持久执行与提示词缓存的部分于 2026-10-26 定稿）。服务端整体规范见 [server-rust.md](server-rust.md)，选型依据见 [调研摘要](../research/library-evaluation-2026-10.md)。文中代码均为设计草图，未编译；genai 0.7 的确切方法签名以 docs.rs 为准。

## 0. 结论先行

1. **我们自己定义领域级 `ModelProvider` trait**（`run_turn(请求) → 文字增量 + 工具调用 + 用量`，一次模型调用），所有模型服务商都是它的适配器；上面一层 **`AiRouter`** 按配置选择提供方并做降级（fallback）。业务代码、任务队列、测试只认这个 trait，不认任何第三方库类型——库换掉不伤业务。
2. **默认提供方 = ChatGPT 订阅**，走官方 **Sign in with ChatGPT（下称 SIWC）**：OAuth 令牌调用公开的 `https://api.openai.com/v1/responses`，按 ChatGPT 订阅额度计费。genai 不支持 SIWC 的特殊要求，所以用 **async-openai 0.42** 自写 `SiwcProvider`。
3. **其他提供方经 genai 0.7（锁定 `=0.7.1`）接入，作为降级备选**：OpenAI API key、Anthropic、Gemini、DeepSeek、通义千问、Kimi、智谱、Ollama 本地模型等，用一个 `GenaiProvider` 按配置覆盖。
4. **结构化输出就是工具调用的参数，不信任库，信任服务端校验**：记账就是模型调用 `create_record` 工具（只有一种运行 `chat`，A16），工具参数的 JSON Schema 就是结构化输出；参数一律经 serde 反序列化 + JSON Schema 校验 + 业务校验，不合法作为工具错误回填给模型（第 5 节）。
5. **计费红线**：不把按量付费的 API key 作为默认，也不在订阅额度耗尽或接入失败时自动切到付费提供方；付费备选只有显式开启才会被使用。全部失败时任务进入 `waiting_ai`，稍后重试，绝不丢数据。
6. **Rig 不采用**：框架面太大、近 6 个月 10 个破坏性小版本、普通 OpenAI 配置只收静态 key、没有 namespace 工具，其内置 `chatgpt` provider 走的是非官方的 ChatGPT `backend-api`。
7. **回复 = 语义块，流式下发（草案）**：模型的文字输出逐步流给客户端；结构化部分（记好的记录、追问、问数）由服务端**确定性地映射**成 [ChatWeave](https://github.com/zz-howard/chatweave) 语义块，数字来自服务端的真实查询而不是模型。v1 没有 UI Agent。见第 13 节。
8. **过程看得见（运行步骤）**：每个工具声明自己的步骤说明（和可选的一行结果说明），Agent 循环在工具调用和 `ask_user` 前后发出 ChatWeave 的步骤事件，客户端在回复顶部显示“过程”条。不下发工具名、参数和原始结果；模型的推理 / 思考文字从不下发也不保存。见 13.5。
9. **Agent = ReAct 循环；v1 只有主 Agent**：思考 → 调用工具 → 看结果 → 再思考，直到给出回答。架构上按“主 Agent + 子 Agent”（主从结构）设计，**v1 不用子 Agent**，以后再加（第 12 节）。
10. **问用户分两种**：运行中途要用户确认或回答（`ask_user`、执行前需要确认的操作）是**中断**——同一条回复暂停，用户的回答是这一步的结果（不是一条新的聊天消息），回答后**同一条回复**接着做完；回答已经写完、最后带一个问题时，用户的回复是新消息、AI 的是新回复。见 13.5。卡片等待回答时输入框锁定，每张中断卡固定多一个“输入其他内容”。
11. **持久执行自写在 PostgreSQL 里**：每次运行一行状态 + 一份只追加的步骤日志；暂停 = 写好后结束这次执行（没有线程在等），回答 = 重新排队，恢复时读日志、已完成的工具绝不重做；会改数据的工具和日志在同一个事务里，做到恰好一次。见第 14 节。
12. **按缓存命中来组织请求**：固定顺序（静态指令 → 工具 → 空间上下文 → 历史 → 本轮输入 → 本次运行的步骤）、每次运行冻结提示词快照、确定性序列化、加密推理数据原样回放，让工具循环和及时回答后的恢复都能命中提示词缓存；长暂停接受一次未命中。见第 15 节。
13. **配置和计量交给管理能力**：提供方、模型、每类任务的路由和官方价格表存在数据库里，经管理 API 或 `admin` 命令修改，改完即时生效（第 7 节）。每次模型调用都写一行计量（成功、失败都写），带空间、成员归属和所用的价格行；每一步只记操作类别和耗时，不记内容，供管理侧按空间 / 成员 / 提供方 / 模型统计用量和成本（第 8 节）。
14. **工具只定义一次，同时开放给 API key**：API key 不能使用 AI 对话；AI 在对话里能调用的工具（除 `ask_user` 这类只在对话里有意义的）都由同一份定义自动生成公开接口，key 直接调用，走同一套参数校验、空间绑定、权限检查和业务校验；AI 要做需要确认的写入时先弹确认卡，key 调用写入类工具直接执行。见 13.6。

## 1. 设计原则

- **AI 只“提议”，服务端“执行”**：模型输出的是记录草稿或工具调用参数；真正写库前由服务端校验空间成员身份和业务规则。提供方失败不能绕过权限。
- **对话一对一**：每段聊天会话只属于一位成员（发起者）和 AI，不会有第三方加入；同一空间的其他成员各有自己的会话，看不到、不能回答、也不能停止别人的会话。共享的是对话产生的记录，不是对话本身。
- **一个任务只属于一个空间**：每个 AI 任务和聊天会话都带 `space_id`；上下文只从该空间组装（该空间的账户、标签、成员、资料，以及发起者本人在该空间的聊天记录——不含其他成员的对话），AI 只往当前空间记账，不推断、不建议其他空间，也看不到其他空间的任何内容。各空间的聊天记录和 AI 上下文互相隔离。
- **上下文先过滤再调用**：用户共享一份订阅凭据，所以每次调用前必须先按空间（并校验发起者是该空间的活跃成员）筛选上下文；其他空间的内容绝不进入请求。记错空间的记录由用户在原空间撤销、到正确的空间重新记（P63），AI 不参与。
- **可替换**：领域 trait 隔离第三方库；即使 genai 停更，手写适配器的退路成本可控（估 1,000–1,500 行）。
- **可观测**：每次调用记账（提供方、模型、模式、耗时、token、结果），日志与用户的原始请求 ID 串起来。
- **可测试**：无网络的单元测试覆盖全部状态机与降级；适配器用录制回放 + 请求体快照守住库升级。

## 2. 领域接口

```rust
// crates/ai —— 领域级接口，不暴露任何第三方库类型（草图，未编译）
/// 一次模型调用的请求：由纯函数 render_request(快照, journal, 历史, 提供方) 生成（15.2），适配器只负责翻译成提供方格式。
pub struct TurnRequest {
    pub run_id: Uuid,                    // = agent_runs.id，日志 / 计量用
    pub session_key: String,             // = 会话 ID；SIWC 的请求头 session_id 与 prompt_cache_key 都用它（4.4 第 8 项）
    pub snapshot: PromptSnapshot,        // 冻结的指令、工具清单（固定顺序、含 schema）、模型参数（15.2）
    pub items: Vec<RequestItem>,         // 空间上下文 → 历史 → 本轮输入（文字、≤1600px JPEG 图片引用、当前日期时间）→ 本次运行的 journal
    // items 包含 RequestItem::ProviderBlob(ProviderBlob)，按模型输出原位置回放；
    // 仅发送提供方、模型、账号均匹配的 blob，其余条目顺序不变（14.9）。
}
/// 流式一轮：适配器把提供方的流事件翻译成 TurnEvent；不支持流式的提供方在结束时一次性发出全部文字（功能不变）。
pub enum TurnEvent {
    TextDelta(String),                                  // 给用户看的文字片段
    ToolCall { call_id: String, name: String, args_raw: String },   // 参数完整后才发出，保留模型给出的原始字符串
    ProviderBlob(ProviderBlob),                         // 加密推理数据，只进 journal
    Done { usage: Usage },                              // 含缓存读取 / 写入 token
}
pub struct Capabilities { pub structured: StructuredMode, pub vision: bool, pub max_images: u8, pub context_tokens: u32 }
pub enum StructuredMode { JsonSchema, ToolCall, JsonObject, PromptOnly }   // 提供方怎么保证工具参数合规（strict 工具、原生 schema……）

#[async_trait::async_trait]   // 需要 dyn，故用 async-trait 或手动 Box<dyn Future>
pub trait ModelProvider: Send + Sync {
    fn id(&self) -> &str;
    fn capabilities(&self) -> &Capabilities;
    async fn run_turn(&self, req: &TurnRequest, sink: &mut dyn TurnSink) -> Result<(), ProviderError>;
}

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

### 3.1 各提供方能力与坑（以工具调用与图片输入为准）

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
- `strict: true` 的函数要求每层对象 `additionalProperties: false` 且所有声明的属性都在 `required` 里，否则整个请求以 `invalid_function_parameters`（`invalid_request_error`）被拒（2026-10-29 实测，`ask_user` 的可选字段触发）。适配器逐个工具判断：满足才发 strict，否则发 `strict: false`，参数仍由 Agent 按 Schema 校验。不把可选字段改写成「必填 + 可空」，因为补丁类工具里 `null` 与「不改」含义不同。`crates/agent/tests/tool_schemas.rs` 离线断言每个工具要么 strict 兼容、要么在显式的非 strict 清单里，并对每个工具 Schema 做快照。
- 模型返回的 namespace 工具调用是裸名加 `"namespace": "jiabu"`（2026-10-29 录制，`crates/ai/tests/fixtures/siwc/tool_call.response.sse`）；适配器把裸名交给 Agent（工具注册表用裸名），也接受 `jiabu.<工具>` 形式，拒绝其他 namespace。
- 历史里的 assistant 消息用字符串 `content` 发送；带 `input_text` 内容块的 assistant 消息会以 `invalid_value`（`input[n].content[0]`）被拒（2026-10-29 实测，对话第二条消息起每次失败）。user / developer 消息仍用 `input_text` / `input_image` 内容块。
- `invalid_request_error`（请求本身被拒）映射为 `ProviderError::Rejected { code, message }`：不重试、不进入「等待 AI」，运行直接失败，`last_error` 记 `request_rejected:<code>`，日志带上游 code 和 message。
- 文本、图片、文件仅当所选模型接受时可用。
- 额度错误 `subscription_sharing_usage_limit_exceeded` / `subscription_sharing_usage_unavailable` 可能在流开始后以 `response.failed` 到达，适配器要映射成 `ProviderError::QuotaExhausted`。

这些约束正是不能直接用 genai 的原因：genai 没有 namespace 工具类型，且默认会发送 `temperature`、`max_output_tokens` 等必须省略的字段。

### 4.3 无头服务器上的登录

SIWC 只有浏览器 + 本机回环回调，没有设备码流程。**v1 用下面已验证的“粘贴回调网址”方式在服务器上直接登录**，凭据只在服务器上生成，服务器使用自己的 `ext_agent_host_id`，自行负责后续刷新。官方“Self-hosted VMs”指南的另外两种做法（在本地电脑登录后经 SSH 转移凭据文件；SSH 端口转发）仍可作退路；官方说明被转移会话的“按主机用量归属与吊销”暂不可用，所以不作首选。

**网页管理控制台做不了这个登录**：回调地址只能是发起登录那台机器的回环地址，而控制台跑在服务器上、管理员的浏览器在自己的电脑上，回调到的是管理员电脑的 localhost，控制台收不到；动态注册的客户端也不能把回调改成控制台的网址。所以登录只在 `admin provider login chatgpt` 里做，管理 API 只提供登录状态、令牌到期时间和最近一次刷新结果（[服务端 9.7](server-rust.md#97-chatgpt-订阅的登录只在命令行)）。

**登录方式（2026-10-27 实测）：粘贴回调网址。** 不需要 SSH 端口转发，也不用在管理员电脑上装工具：
1. 服务器上 `admin provider login chatgpt` 生成授权链接（`client_id=dynamic_agent_client`、`ext_agent_host_id` = 本服务器的持久主机 ID、`agent_name_hint` = 应用名、PKCE S256、`redirect_uri=http://127.0.0.1:1455/auth/callback`），PKCE 校验串只留在服务器。
2. 管理员在自己电脑的浏览器打开链接、登录 ChatGPT、同意授权；OpenAI 当场把它登记成一个独立应用（发放 `oaiapp_…` 应用 ID，用户可在 ChatGPT 设置里管理和撤销）。
3. 浏览器跳到 `127.0.0.1` 打不开，这是正常的；把地址栏里的完整网址粘回命令行，服务器校验 `state`、用授权码 + PKCE 校验串换令牌（`id_token` 验签并核对 nonce），凭据只存在服务器上。授权码几分钟内有效，过期就重新生成链接（复用已发放的应用 ID）。

注意：SIWC 没有设备码流程；Codex 命令行自己的登录属于另一个客户端，权限不同，不能借用（见 4.4 第 1 项）。

### 4.4 接入验证清单（实现 `SiwcProvider` 时逐项通过）

1. 登录拿到含 `chatgpt.tokens.use.direct` 的令牌；`GET /v1/models` 查看账号可用模型。（2026-10-27 实测：Codex 命令行自己的 ChatGPT 登录令牌不含这些权限，`/v1` 返回 401/403，不能借用，必须走本节的 SIWC 登录。） 第 2–5、8 项 2026-10-27 已通过（技术方案实验 E1）。`store: false` 的流里 `response.completed` 的 `output` 是空数组，适配器必须从 `response.output_item.done` 事件拼出输出。
2. 纯文本请求（stream + store=false）收到 `response.completed`。
3. 图片输入（收据照片 base64 data URL）成功。
4. namespace 工具调用：模型返回 namespace 里的工具调用，参数满足 JSON Schema（2026-10-29 录制更正：调用名是裸名 `submit_record_draft` 式，另带 `"namespace": "jiabu"`，不是 `jiabu.submit_record_draft`）。
5. `text.format: json_schema` 被接受（实测通过；v1 不用它，结构化结果一律来自工具调用，第 5 节）。
6. refresh_token 轮换：过期前自动刷新，凭据原子替换。
7. 额度用尽：不切换付费提供方，任务记为“待 AI 处理 · 额度不足”，稍后重试。
8. 提示词缓存（第 15 节）：**必须按会话绑定**——请求头 `session_id` 与请求体 `prompt_cache_key` 设成同一个值（= 会话 ID，同一会话的各次运行、暂停后恢复共用），逐轮追加的多轮对话从第 2–3 轮起稳定命中（实测 16 次后续调用 14 次命中）；不带这个请求头时几乎不命中（约 57 次调用 2 次）。`prompt_cache_options` 与显式断点（`prompt_cache_breakpoint`）会被拒（400），不发。
9. 无状态推理回放：带回上一轮的 reasoning 条目（`encrypted_content`）继续调用成功；暂停一天后再带回仍被接受（不被接受时按 14.10 去掉重试）。

## 5. 结构化输出

- **结构化输出 = 工具调用的参数**：每个工具的参数类型用 `schemars` 1.2 生成 JSON Schema，随工具清单进提示词快照（SIWC 下工具放进 namespace，4.2）。记账是 `create_record`、信息不全是 `ask_user`、问数是 `query_stats`……没有单独的“记账解析”调用（A16，技术方案 7.3）。
- **统一校验**：`ToolRegistry::invoke()` 里 serde 反序列化 → `jsonschema` 0.60 校验 → `validator` → 业务规则（金额 > 0、账户 / 标签存在且属于运行所在空间、日期不在未来过远）。
- 校验失败：作为工具错误（`validation_failed` + 出错的字段）回填给模型，由模型改正或说明；不计入提供方降级。
- 图片在服务端先压缩到 ≤ 1600px JPEG 再发给模型；原图另行留存。

## 6. 运行与中断

> 权限：AI 运行以发起成员的身份进行。组装上下文、执行工具时都经服务端统一的 `authorize(member, module, action)`，只能读写该成员有权限的模块（v1 为账本与资料）；无权模块的数据从源头就不进入提示词，而不是靠提示词要求模型“别说”。

AI 处理是异步的**运行**（run）：一条助手回复从开始到结束是一次运行，中间可以暂停多次（用户可能隔几小时、几天才回答）。运行的状态、队列和步骤日志都在 PostgreSQL 里：`agent_runs`、`agent_run_items`、`agent_tool_calls`（取代早先草案的 `ai_jobs`），完整设计见第 14 节。

- 用户消息入库时**同事务**插入运行（`status = 'queued'`，`kind = 'chat'`：每条用户消息一次运行，A16）并 `NOTIFY`；worker 用 `FOR UPDATE SKIP LOCKED` 领取，带租约和防护令牌（14.4）；同一会话先进先出（技术方案 7.3）。
- 模型调用 `create_record` 等写入工具 → 校验后写记录，回复里出记录卡块；调用 `ask_user` → **中断**：回复 = 已识别内容的文字 + 选项块（`choice`），回复**暂停**（ChatWeave `message.paused`），运行 `paused`；没有工具调用的回答 → 回复为文字（流式），运行 `completed`。一句话说两笔、记完顺便问余额这类混合输入在同一个循环里自然完成。块的映射见第 13 节。
- **回答** = ChatWeave 动作（`clarification.answer` 等，动作 ID 即 `Idempotency-Key`）：点选项是 `selected`，确认 / 取消是 `outcome`，表单是 `values`；用户点了卡片上固定的“输入其他内容”再打字，就是 `freeText`。服务端校验回答者就是这段会话的所属成员、所选项确实在该块里、中断仍未回答，然后把回答**作为这次中断（`ask_user` 或待确认操作）的结果**写进 journal，运行重新排队；回答**不**作为一条聊天消息。worker 在**同一条回复**（同一个 `assistant_message_id`）里继续：卡片改为“已回答”，回复接着往下写，`seq` 接着数，最终版本同步到这位用户的所有设备。
- **自由文字回答交给模型理解**：服务端不把它解析成某个选项；例如在确认卡上写“改成 72 块再记”，这次确认记为没有确认，原话作为结果交给模型，由模型决定接下来怎么做（通常重新发起一次确认）。
- **等待回答时输入框锁定**（客户端，13.5），正常界面上不会“没回答就发了新消息”。放弃这条回复用“停止生成”：这次询问作废（卡片显示“已停止”），被问的那一笔不记，回复以“已停止”结束，运行 `cancelled`。停止只取消还没做完的部分（P50）：同一条回复里已经提交的写入保留，各有记录卡、可单独撤销；停止时的收尾文字由服务端按 journal 生成，写清这条回复已记几笔、哪些没有记（如“已停止：这条回复里已记 1 笔（见上方记录卡），第 2 笔没有记”）。
- **过期**：改记录类的确认 24 小时、澄清类 7 天未回答即过期，同样结束这条回复（卡片显示“已过期”）。
- 回答已经写完、最后问一句（例如“要不要把它设成每月固定支出？”）不是中断：那条回复已经结束，用户的回复是一条新消息，开始新的一轮。
- 链上全部提供方失败 → `waiting_ai`，按 `run_after` 退避重试（14.8）；App 提示“AI 暂时不可用”（P34）。用户可以对排队中的内容选“改为手动填写”（P54）：还在本机 outbox 里的直接撤下、改用手动表单；已经在服务端排队（`queued` / `waiting_ai`）的按“停止”取消这次运行（`cancelled`，不写业务数据），再由手动表单记账，AI 恢复后不会再记一遍。
- worker 本身无状态：每次领取都从库里读出运行行和 journal。空间上下文在运行开始时按 `space_id` 渲染一次、记进 journal（缓存需要，15.2）；每次领取仍重新检查（技术方案 7.5）：发起成员不再活跃或 `join_epoch` 变了 → 运行 `cancelled`（“空间不可用”），不写入；模块权限与运行开始时不同 → `failed`（`permission_changed`，不提供重试）。
- **运行只能由本人在手机上发起**：个人 API key 不能使用 AI（[服务端 3.3](server-rust.md#33-个人-api-key)）。创建运行的唯一入口只接受会话身份，key 提交的聊天、回答、停止、重试一律被拒绝，所以运行没有“经哪个 key”的归属，也没有只读运行。key 需要的查询和写入经工具 API 直接调用同一批工具（13.6），不经过模型。

## 7. 路由、降级与计费策略

**配置存在数据库里**（v0.13 起）：提供方、模型、路由、策略和价格表存在 `ai_providers`、`ai_models`、`ai_routes`、`ai_settings`、`ai_prices` 表里（[服务端 9.5](server-rust.md#95-表结构管理侧草案)），由管理 API 或 `admin` 命令修改；下面的 TOML 是首次导入（`admin ai import`）和导出备份用的格式，字段一一对应。路由按**任务类型**分：`chat`（对话 Agent）、`chat_vision`（这次运行的输入里有图片时用，只挑支持视觉的模型）；每类一个有序列表，第一个是默认模型，其余按顺序降级。

```toml
# config/ai.toml —— 导入 / 导出格式（凭据只写环境变量名或文件路径变量名，不写值）
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
chat        = ["chatgpt", "local", "qwen"]
chat_vision = ["chatgpt", "local", "gemini"]   # 只挑 vision = true 的

[policy]
allow_paid_fallback = false      # 为 false 时链上 billing = "paid" 的提供方一律跳过
breaker = { failures = 3, cool_down_secs = 300 }

# 官方 API 标价（每百万 token，美元），用于每次调用的成本核算；订阅提供方同样按它折算
[[price]]
model = "<模型名>"                # 与 provider.model 一致；SIWC 用该模型的官方 API 标价
input = 0.0
cached_input = 0.0
cache_write = { "30m" = 0.0 }     # 有写缓存费的模型才填（OpenAI 5.6+ 按 TTL、Anthropic 5m / 1h）
output = 0.0
long_context = { above_tokens = 0, input = 0.0, cached_input = 0.0, output = 0.0 }   # 有长上下文加价时
source = "<官方价格页 URL>"
as_of = "<核对日期>"
```

- **成本一律按官方 API 标价折算**：每次调用的成本 = 各类 token（未缓存输入、缓存读取、缓存写入、输出）× 该模型官方 API 标价，**不论**实际走的是 API key 还是订阅（SIWC）。订阅下省下的缓存同样算作省钱，而不只是“省额度”。价格表放在配置里，每一项带来源和核对日期；没有价格的模型调用照常进行，但成本记为空并告警。缓存命中的评估、是否延长缓存有效期这类取舍，都用这个金额来算（第 15 节）。

降级规则：

| 错误 | 处理 |
|---|---|
| `Timeout` / `Transport` / `RateLimited` / 5xx / `InvalidOutput`（流格式错误，重试一次后） | 链上下一个 |
| `Auth` / `QuotaExhausted` | 链上下一个，并告警 |
| `Unsupported`（如无视觉能力） | 路由前就过滤掉 |
| 链全部失败 | 任务置 `waiting_ai`，稍后重试 |

- 每个提供方一个熔断器（连续失败 N 次冷却 M 分钟）。
- **降级永远不越过 `billing` 策略**：订阅 / 本地失败后，只有 `allow_paid_fallback = true` 才会尝试付费提供方。
- **热切换**：管理侧每次改配置都在同一事务里把 `ai_settings.config_version` 加一并 `NOTIFY ai_config`；服务端收到后从库里重建 `AiRouter` 并用 `ArcSwap` 替换，无需重启（另每 60 秒比对一次版本号兜底）。已在跑的运行不受影响：它的提示词快照里记着模型和参数，下一次调用才按新路由选提供方（降级本来就会换提供方，14.10）。
- **密钥**：提供方的 API key 可以经管理 API 录入（加密存库，只写不读），也可以继续用环境变量或文件（[服务端 9.6](server-rust.md#96-密钥加密)）。`AiRouter` 构造客户端时在进程内解密，密钥不进日志。

## 8. 可观测

```sql
create table ai_calls (
  id bigint generated always as identity primary key,
  run_id uuid,                                               -- 管理侧的测试调用（probe）为空
  space_id uuid, member_id uuid, user_id uuid,               -- 归属：冗余存一份，统计时不用联查业务表
  task_kind text not null,                                   -- chat | chat_vision | probe
  provider_id text not null, model text not null,
  structured_mode text not null, latency_ms int, input_tokens int, output_tokens int,
  cached_input_tokens int, cache_write_tokens int,           -- 提示词缓存读取 / 写入（第 15 节）
  call_kind text not null,                                   -- first | continue | resume | retry
  since_prev_call_ms bigint, prefix_hash bytea,              -- 距本运行上一次调用的时间；静态前缀 + 上下文的哈希
  cache_miss_reason text,                                    -- 提供方给出的未命中原因（有时才记）
  cost_usd numeric(12,6), price_id uuid, price_as_of date,   -- 按官方 API 标价折算的成本（订阅也算）、所用价格行及其核对日期
  cache_saving_usd numeric(12,6),                            -- 缓存读取 token ×（输入价 − 缓存价）− 缓存写入的加价
  outcome text not null, error_kind text, at timestamptz not null default now()
);
create index ai_calls_at on ai_calls (at);
create index ai_calls_space_at on ai_calls (space_id, at);

-- 每一步只记“哪一类操作、结果、耗时”，供管理侧的运行明细使用；不记步骤说明、参数和结果内容
create table ai_step_meters (
  run_id uuid not null, step_no int not null,
  step_kind text not null,          -- 固定目录：query_stats → “查询统计”，query_balance → “查询余额”，search_records → “搜索记录”，
                                    -- search_documents → “搜索资料”，write_record → “写入记录”，ask_user → “询问用户”，parse_entry → “识别照片里的信息”…
  status text not null,             -- succeeded | failed | awaiting_user | cancelled
  started_at timestamptz not null, duration_ms int,   -- 不含等待用户的时间
  primary key (run_id, step_no)
);
```

**计量规则**：

- **每次提供方调用结束就写一行 `ai_calls`**，不论成功、失败还是被降级跳过之后的重试；不和 journal 放在同一个事务里——调用失败、`model_turn` 没提交，钱也已经花了，照样要记。进程在流式输出中途崩溃时拿不到用量，这次调用记为 `outcome = 'lost'`、token 为空（数量很少，看板单独显示）。
- **归属**：`space_id`、`member_id`、`user_id`、`task_kind` 在写入时从运行行复制过来；管理侧统计只读 `ai_calls`，不需要也没有权限联查业务表（[服务端 9.2](server-rust.md#92-管理侧看不到内容三层保证)）。
- **价格**：按调用时刻取该模型 `effective_from` 不晚于调用时间的最新价格行，把成本、缓存省下的金额和 `price_id` 一起写进这一行；以后改价不重算历史。找不到价格时 `cost_usd` 为空、照常调用并告警，管理侧把它们单独计数。
- **步骤**：Agent 循环在发 ChatWeave 步骤事件（13.5）的同时写 `ai_step_meters`；`step_kind` 由工具声明（`AgentTool::step_kind()`，取自固定目录），**不是** `step_label`——后者会带账户名、标签名，属于内容，只进 `chat_entries`。
- **测试调用**（管理侧“测试连接”）：`task_kind = 'probe'`，不归属任何空间。

- 每次模型调用写一行，用于比较提供方质量、延迟和成本，并按空间、成员、内部用户 ID 统计共享订阅的用量。工具 API 的调用不经过模型，不写 `ai_calls`（13.6）。
- 每次调用的成本、缓存省下的金额按第 7 节的价格表折算（订阅提供方同样折算），按运行、空间、成员、提供方、模型、日 / 月汇总；汇总经管理 API 与 `admin usage` 提供（[服务端 9.4](server-rust.md#94-接口清单adminv1)），v1 直接查 `ai_calls`（有时间与空间索引），量大了再加按日的汇总表。
- 缓存命中率按 `call_kind` 统计；“暂停后恢复、距上次调用小于缓存有效期、却没命中”应为 0（15.5）。
- worker span 带 `run_id`、`origin_request_id`、`provider_id`、模型名、重试次数、降级原因、耗时、token 用量。
- 日志不记原话、图片和模型完整回复。
- 每个运行步骤（13.5）在 worker span 里记一条子 span：工具名、耗时、结果状态（成功 / 失败 / 等用户 / 已停止）、错误类别；不记参数和结果内容。工具名只出现在服务端日志里，不下发给客户端。

## 9. 测试策略

1. **单元测试（无网络）**：`MockProvider` 按脚本返回文字、工具调用（`create_record`、`ask_user`……）和各种错误，覆盖 worker 状态机、追问挂起与恢复、路由降级、熔断、billing 策略、校验与重试、幂等；持久执行的故障注入见 14.12。
2. **适配器契约测试（录制回放）**：每个启用的提供方用真实凭据录一次 HTTP 交互（含 SSE 流），脱敏后存 `tests/fixtures/<provider>/*.json`；测试时用 `wiremock` 0.6 回放，并用 `insta` 1.49 对**我们发出去的请求体**做快照——genai / async-openai 都是 pre-1.0、发版频繁，升级若改了请求格式，快照会先报警（这条最重要）。SIWC 的快照还要断言必须省略的字段确实不存在。同一份 journal 在暂停前和重启后各渲染一次，前缀部分必须逐字节相同（15.5）。
3. **在线冒烟（手动）**：`cargo test --features live -- --ignored`，每个提供方 3 条样例，确认凭据、端点、模型名仍有效。
4. **评测集**：`eval/entries/*.yaml` 先做 60–100 条，覆盖口语中文（“昨天楼下早饭 18 块”）、一句多笔、相对日期、转账 / 退款、收据照片（清晰 / 倾斜 / 长小票）、信息不足应追问、闲聊非记账。每条写期望字段；评测经完整的 Agent 循环跑（`MockProvider` 换成真实提供方，工具写进临时库）；`cargo run -p ai-eval -- --provider chatgpt,local,gemini` 输出 工具参数合法率、金额精确率、日期 / 分类准确率、追问触发的精确率与召回率、P50 / P95 延迟、单条成本。结果 CSV 入库；调整降级顺序或升级模型前必须跑一遍。**评测集只用自造或脱敏数据**。

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
| 7 | 自写持久执行代码的正确性（崩溃点、抢答、脑裂、过期竞态） | `next_action()` 纯函数 + 属性测试；`MockProvider` 故障注入覆盖 14.6 每一行（14.12） |
| 8 | SIWC 的缓存规则官方没写，靠实测（E1）：要按会话绑定才命中；缓存 token 如何计入订阅额度仍不清楚 | 适配器固定发 `session_id` = `prompt_cache_key` = 会话 ID（4.4 第 8 项），请求体快照断言它存在、断言不发 `prompt_cache_options`；按 15.5 的指标观察 |
| 9 | genai 0.7.1 对 GPT-5.6+ 默认不缓存（发 `mode: explicit` 却没有断点）；TTL 只能写 30 分钟 | `GenaiProvider` 总是自己放断点（15.3），请求体快照断言断点存在；升级 genai 时复查 |

## 12. Agent 运行时分期

Agent 是一个 **ReAct 循环**：调用模型（思考）→ 有工具调用则执行（行动）→ 回填结果（观察）→ 再循环，直到给出回答。架构按**主 Agent + 子 Agent**（主从结构）设计：主 Agent 可以把一部分工作委派给子 Agent，子 Agent 自己也是同样的循环、有自己的工具。

- **v1：只有主 Agent，不用子 Agent**（2026-10-26 已定）。单个主 Agent 带工具。Agent 循环在 genai / async-openai 之上自写（“调用模型 → 有工具调用则执行 → 回填结果 → 循环；遇到 `ask_user` 或需要确认的操作就中断”，估 300–600 行），工具执行前同样经过空间成员与业务校验。工具在服务端绑定任务的 `space_id`：工具参数里没有 `space_id`，模型无法指定或切换空间，查余额、查历史等也只能看到当前空间。每个工具还声明自己在“过程”条上的步骤说明，循环在每次工具调用前后、中断时发出步骤事件（13.5）。
- **以后：子 Agent**。委派给子 Agent 时，主 Agent 这一步是 ChatWeave 的委派步骤（`kind: delegate`），子 Agent 的工具调用作为子步骤挂在它下面（`parentStepId`），过程条里默认收起；子 Agent 里发起的中断让整条回复暂停。ChatWeave 已经支持这种层级步骤，所以以后加子 Agent 不需要改客户端协议。什么时候加、先加哪些子 Agent，到时再定。
- **v2**：外部 Agent 网关（例如接入 Claude Code 等通用编程 / 助手类 Agent）。
- **中断与持久执行**：运行中途的中断（13.5 第 3 条）要求运行能暂停很久（几小时甚至几天）后在同一条回复里继续，而服务端线程不会一直等着。v1 在 PostgreSQL 里**自写**一个小的持久循环（第 14 节），所有存取经一个 `RunStore` 接口。
- **为什么不用 Temporal / Restate / DBOS 这类持久执行引擎**（2026-10-26 重新评估，不再只是一句“过重”）：
  1. 我们会改数据的工具（记一笔、改一笔）写的就是同一个 PostgreSQL，工具写入和“这一步已完成”可以放进同一个事务，做到**恰好一次**；引擎对写操作最多做到“至少一次”，还得自己做幂等。
  2. Agent 循环天然只在步骤之间停下来，恢复只需要读日志看做到哪一步，用不着引擎的确定性重放和 workflow versioning（那是很深的编程模型约束）。
  3. 部署不变：还是一个服务端二进制加一个 PostgreSQL。引擎要再加一个有状态服务（Temporal 生产环境要多个角色加数据库；Restate 是单个二进制但自带存储，另需备份、升级），出故障都是家里人自己扛。
  4. 现状也不支持“现在就用”：Temporal Rust SDK 2026-09 才 1.0；Restate Rust SDK 还是 0.12、服务端是 BSL 许可；DBOS 的 Rust 版只依赖 Postgres、是个库，最贴合，但 0.5 仍是预发布，且自己写明还没有事务型步骤。
  - 我们借鉴的是引擎的做法：每一步落盘、恢复读日志不重做、执行前先记意图、租约加防护令牌、中断语义对齐 AG-UI。**出现以下情况之一时重新评估**（首选 DBOS Rust，到 1.0 并有事务型步骤之后）：子 Agent 大量并行或扇出、大量定时与长时间编排、频繁调用有外部副作用的第三方 API、需要多台机器。
- 子 Agent（以后）就是子运行：加子 Agent 时用一次只追加的迁移给 `agent_runs` 补上 `parent_run_id` / `parent_call_id`（v1 不建这两列，A20），表、日志、恢复算法与主 Agent 相同；委派是一次特殊的工具调用，子运行结束时它的结果写进主运行的日志，主运行重新排队。
- 不引入 Rig 的 `AgentRun` 作为持久状态（其 0.44 版本改过序列化格式，旧数据无法加载）；journal 也不直接存 genai / async-openai 的类型，用自己的规范格式。

见 [待定问题](../decisions/README.md#待定问题open-questions)。

## 13. 回复内容：语义块与流式输出（ChatWeave，草案）

聊天回复使用开源库 [ChatWeave](https://github.com/zz-howard/chatweave) 的协议：一条回复是有序的“语义块”（只有数据和含义，没有颜色、尺寸、布局），外加一段必有的纯文本兜底。库的设计在其仓库里；这里只写家簿 AI 层怎么产出这些块。

### 13.1 原则

- **模型决定“说什么”，服务端决定“用哪个块”**：映射是服务端代码里的确定性规则（查表），不调用额外的模型，v1 没有 UI Agent。
- **数字不由模型编**：余额、笔数、合计、视力数值等一律由服务端按任务的 `space_id` 经 `authorize()` 查询后填进块；模型只通过类型化工具说明“要查什么”。
- **先校验再发出**：每个块经 ChatWeave 的 Schema 与限制校验（自定义块 `x-jiabu.*` 用家簿注册的 Schema）后才进入流和数据库；校验失败的块改为一段兜底文字，整条回复照常完成。
- **按客户端能力选块**：任务记录了客户端声明的能力；客户端不支持某类型（例如图表）时，映射直接选更朴素的类型（表格或文字）。持久化的始终是规范形态。
- **只用一对一场景**：ChatWeave 同时支持一对一和群聊，家簿只用一对一（见第 1 节）。交互块仍按库的规则“点了先显示提交中、服务端确认后才显示结果”——一对一里服务端同样可能拒绝（权限、相关记录已变化或删除、校验不通过），同一用户也可能在两台手机上操作同一张卡；不存在多位成员抢答同一张卡的情况。

### 13.2 映射表（v1）

| AI 结果 / 工具 | 生成的块 |
|---|---|
| 模型的文字输出（任何一轮） | `markdown`，逐字流式（服务端把 token 合并成约 20 字或 50ms 一批） |
| `create_record` 等写入工具成功 | `x-jiabu.record_card { recordId, versionAtReply }`（模型的文字照常是 `markdown`） |
| `ask_user`（选项） | `markdown`（已识别的内容）+ `choice { prompt: 追问句, options, action: clarification.answer, action.expiresAt: 7 天后 }`，然后回复暂停（中断，`reason: input_required`；ChatWeave 默认给卡片加“输入其他内容”，家簿保持开启）；回答后同一条回复继续，接着出记录卡 |
| 没有工具调用的回答 | `markdown` |
| `create_document` / `update_document` 成功 | `x-jiabu.document_card { documentId, versionAtReply }` |
| 问数工具 `query_stats { metric, period, filters }`（v1 单主 Agent 的工具） | 服务端执行真实查询 → 单值用 `metric`，多值用 `metric_group`，明细用 `dataset`，按时间的数值用 `time_series`（例如历次视力） |
| 首次设置缺多项信息（`ask_user` 的小表单） | `form_intent { action: clarification.answer }`（首次设置不单设动作）；设置完成后账户摘要用 `dataset` |
| 需要用户确认的操作（改记录等，v1 预留） | 服务端拦下这次工具调用、冻结参数（14.4 C）→ `confirmation { severity, action: pending_operation.confirm, action.expiresAt: 24 小时后 }`，回复暂停（中断，`reason: confirmation`，同样带“输入其他内容”）；确认、取消或写了别的话之后同一条回复继续 |

记录卡、资料卡只带 ID 和回复时的版本 `versionAtReply`（用来显示“后来改过”，技术方案 9.3），卡片内容由客户端从本机已同步的记录读取：编辑 / 撤销后自动更新，聊天记录里也不复制业务数据。

### 13.3 流式与提供方

- SIWC 的 Responses API 本来就要求 `stream: true`：文字增量 → `TurnEvent::TextDelta` → `markdown` 块的增量；函数调用参数在流中分片到达，适配器**缓冲到完整**再发出 `TurnEvent::ToolCall`，服务端执行后整块发出组件（与 ChatWeave v1“组件整块到达”一致）。
- genai 接入的提供方：支持流式的同样处理；不支持的在结束时一次性发出文字，客户端只是看不到逐字效果。
- 链上降级发生在流开始之后时：已发出的文字保留，换下一个提供方前先结束当前块，并在回复里说明（不静默重复已说过的话）；全部失败则回复以 `interrupted` 结束，任务进入 `waiting_ai`。
- **可读的推理内容一律丢弃**：推理 / 思考文字和推理摘要在适配器里直接丢掉，`TurnEvent` 没有对应的变体；不进流、不进 `chat_entries`、不进日志，也不用来生成步骤说明。**例外**：提供方加密的、不可读的推理数据（Responses API reasoning 条目的 `encrypted_content`、Anthropic thinking 的 `signature`、Gemini 的 thought signature）只存进运行 journal（14.9），用于工具循环和恢复时原样回放（正确性和缓存命中都需要），同样不下发、不进日志，运行结束 7 天后删除。

### 13.4 外部 Agent（v2）

将来接入的外部 Agent（第 12 节）大多只会输出文本：它们的输出整体作为 `markdown` 块流式下发；**适配器不从文本里推断金额、账户等业务事实**，也不生成组件。外部 Agent 想展示结构化内容，只能调用家簿提供的受控工具，由服务端按 13.2 生成块。

### 13.5 运行步骤（“过程”条）

客户端在每条回复顶部显示一条“过程”：生成中逐行显示 AI 正在做的事，回答写完后自动收起成一行（产品规则见[需求 · 聊天回复](../product/requirements.md#聊天回复文字与组件混排逐步显示)，外观见[设计规范 4.17](../design/design-spec.md#417-过程条ai-正在做什么)）。服务端用 ChatWeave 的步骤事件 `step.started` / `step.finished` 产出它（事件与 AG-UI 1.0 的 `STEP_STARTED` / `STEP_FINISHED` 对齐，协议细节见 ChatWeave 文档）。

**每个工具声明自己的步骤说明**：

```rust
// crates/tools —— AI 的工具。Agent 循环和工具 API（服务端 4.3）共用这一份定义（草图，未编译）
#[async_trait::async_trait]
pub trait AgentTool: Send + Sync {
    fn name(&self) -> &'static str;                          // 工具名：给模型看的名字，也是工具 API 的路径段；不下发给 App
    fn description(&self) -> &'static str;                   // 给模型的说明，同时是 OpenAPI 里的说明
    fn parameters(&self) -> &serde_json::Value;              // 参数 JSON Schema（由参数类型经 schemars 生成）
    fn output_schema(&self) -> &serde_json::Value;           // 结果 JSON Schema：回填给模型的、工具 API 返回的都是它
    fn schema_version(&self) -> u32;
    /// 所属模块与动作，执行前交给 authorize(member, module, action)。
    fn permission(&self) -> (Module, Action);
    /// v1 只有 read | local_write（A20；external 以后才有，14.5）；只读 key 只能调用 read 工具（服务端 3.3）。
    fn effect(&self) -> Effect;
    /// 在对话里执行前是否要用户确认（确认卡，14.4 C）。只有 Agent 循环看它；工具 API 不确认、直接执行。
    fn confirm_in_chat(&self, args: &ValidatedArgs) -> bool { false }
    /// AgentAndApi（默认）| ApiOnly（开放给手机和 key、不进模型的工具清单，如 delete_tag）| AgentOnly（如 ask_user：只在对话里有意义，不注册 API 路由）。
    fn exposure(&self) -> Exposure { Exposure::AgentAndApi }
    /// 过程条上的一句说明（≤ 60 字），服务端按固定模板生成，例如“查本月餐饮支出”。
    /// 只能填入已经过 authorize() 的整理后名称（账户名、标签名、“本月 / 上月”这类期间），
    /// 不得直接拼接模型给的原始参数。只有 Agent 循环用。
    fn step_label(&self, args: &ValidatedArgs, ctx: &ToolCtx) -> StepLabel;
    /// 可选的一行结果说明（≤ 120 字），例如“找到 23 笔”“暂时查不到”；默认不给。
    fn step_summary(&self, outcome: &ToolOutput) -> Option<StepSummary> { None }
    /// 操作类别（固定目录里的一项，如 StepKind::QueryStats），只用于计量（第 8 节 ai_step_meters），不带任何内容。
    fn step_kind(&self) -> StepKind;
    /// 业务校验 + 执行。参数里没有 space_id：空间、成员和调用方都来自 ctx。
    async fn execute(&self, args: ValidatedArgs, ctx: &ToolCtx) -> Result<ToolOutput, ToolError>;
}

/// 调用上下文：两个入口各自构造，工具本身不关心调用它的是模型还是 HTTP 请求。
pub struct ToolCtx {
    pub space_id: SpaceId,
    pub member: SpaceMember,             // 已解析的活跃成员
    pub via: Via,                        // Agent { run_id, call_id } | Api { principal }（会话或 API key：id + 名称快照）
    pub idempotency_key: Uuid,           // Agent：uuidv5(run_id, call_id)；API：uuidv5(user_id, Idempotency-Key)
    pub request_id: Uuid,
}
```

实现时每个工具写成带类型参数的 `TypedTool`（`type Args: DeserializeOwned + JsonSchema + Validate`、`type Output: Serialize + JsonSchema`），由一个通用实现得到上面这个对象安全的 `AgentTool`；`parameters()` / `output_schema()` 由 schemars 从类型生成并缓存，所以 schema 不会和代码走样。

v1 工具与步骤说明（示例；完整工具清单见[技术方案 6.4](technical-design.md#64-工具清单v1)）：

| 工具 | `effect` | 开放给 API | 步骤说明 | 结果说明（可选） |
|---|---|---|---|---|
| `query_stats` | read | ✅ | 查本月餐饮支出 / 对比上月 | 找到 23 笔 |
| `query_balance` | read | ✅ | 查教育用途余额 | — |
| `search_records` | read | ✅ | 查找相关记录 | 找到 5 条 |
| `search_documents` | read | ✅ | 查找视力检查资料 | 找到 3 次检查 |
| 写入类（如 `create_record` 记一笔、`update_record` 改一笔、`void_record` 作废、调拨） | local_write | ✅（只限读写 key） | 记下这笔 / 修改这笔记录 | — |
| `ask_user` | — | ❌（`AgentOnly`） | 确认用哪张卡付的 / 确认要不要调拨 | — |
| （有图片时第一次模型调用前后，不是工具；`step_kind = parse_entry`） | — | — | 识别照片里的信息 | — |

**循环怎么发事件**（ChatWeave 的流生成器负责 `seq`、耗时和事件日志）：

1. 模型给出完整的工具调用 → 参数校验通过后，`step.started{label: step_label(...)}` → 执行（同样经过 `authorize()`）→ `step.finished{state: succeeded | failed, summary: step_summary(...)}`。模型一次给出多个工具调用时并行执行，各自一个步骤。
2. **失败只影响这一步**：工具出错、超时或被 `authorize()` 拒绝 → 这一步 `failed`（结果说明用模板，如“暂时查不到”），错误作为工具结果回填给模型，让它在回答里说明哪部分没查到；其他步骤和回答照常。整轮是否失败仍按第 7 节的降级规则判断。
3. **中断（`ask_user` 与需要确认的操作）**：映射出选项 / 确认块（13.2）后，回复**暂停**（ChatWeave `message.paused`，这一步显示“等你确认 / 等你回答”），运行挂起（`agent_runs.status = paused`，worker 不再持有它），回复**不结束**。用户的回答是这次工具调用的结果（不是聊天消息）；回答后**同一条回复**继续：这一步回到运行、照常结束（耗时不含等待），回复接着往下写，过程条还是同一条。等待回答时客户端锁定普通输入框，卡片上固定有“输入其他内容”，点了才能打字回答（作为这张卡的回答，不是新消息）。暂停中停止或过期：这一步记为 `cancelled`，回复以“已停止 / 已过期”结束。暂停与恢复的服务端实现见第 14 节。
4. **最终回答里带着问题不是中断**：回答已经写完、最后问一句时，回复照常结束；用户的回复是新消息，开始新的一轮，有自己的步骤。
5. **停止**：用户点“停止”时，仍在运行的步骤记为 `cancelled`，再结束回复（`interrupted`）。崩溃恢复时仍在运行的步骤记为 `failed`；暂停中的回复不受崩溃影响。
6. **子 Agent（以后）**：v1 没有子 Agent。以后加子 Agent 时，委派是一个 `kind: delegate` 的步骤，子 Agent 的步骤带 `parentStepId` 挂在它下面（ChatWeave 层级步骤）；子 Agent 的内部名字和推理文字同样不下发。
7. **照片**：输入里有图片时，第一次模型调用前后发一个步骤“识别照片里的信息”；没有工具调用的简短回答没有步骤，回复里就没有过程条。
8. **不下发**工具名、参数、原始查询结果和模型的推理文字。步骤说明和结果说明只用当前空间、当前成员有权看到的数据生成；对话是一对一的，过程只有发起者本人看得到。
9. **持久化**：回复结束时，ChatWeave 把精简的步骤记录（说明、最终状态、耗时、可选的结果说明）随消息存进 `chat_entries.message` 的 `steps` 字段，与内容块分开，不进纯文本兜底；不新增表。

### 13.6 工具同时是公开 API

> 2026-10-26 定（P31、A15）。API key 不能使用 AI 对话；作为替代，AI 在对话里能调用的每个工具也开放成公开接口，key 可以直接调用。接口、路由与 OpenAPI 的细节见 [服务端 4.3](server-rust.md#43-工具-apiai-能用的工具key-也能直接调用)。

- **唯一的事实来源**：工具只在 `crates/tools` 里定义一次（13.5 的 `AgentTool`）。参数与结果的 schema、说明、权限（模块与动作）、`effect`、空间绑定、业务校验和执行都在这里；Agent 循环和工具 API 都经同一个 `ToolRegistry::invoke()`，不存在“给模型的一份、给 API 的另一份”。
- **Agent 循环额外做的**：把工具清单渲染进提示词快照（15.2）；`confirm_in_chat()` 为真时先发起中断、冻结参数、等确认（14.4 C）；写 journal、`agent_tool_calls`、步骤事件和 `ai_step_meters`；按 13.2 把结果映射成语义块。
- **工具 API 额外做的**：从 `Principal`（会话或 key）和路径里的空间构造 `ToolCtx`；只读 key 只能调 `effect = read` 的工具；写入类要求 `Idempotency-Key`、**不确认、直接执行**；key 调用时写 `api_key_audit`；直接返回结构化结果，不生成语义块。不调用模型，所以不写 `ai_calls` / `ai_step_meters`，也没有 AI 用量。
- **不开放的**：`exposure = AgentOnly` 的工具（`ask_user`，以后子 Agent 的委派）。`ApiOnly` 的工具开放给手机和 key，但不进模型的工具清单。
- **改工具要同时想到两边**：工具的说明和 schema 既是提示词的一部分，也是公开接口。只做向后兼容的改动，并照常升 `agent_def_version`（14.10）；不兼容时起新工具名。`openapi.json` 的 CI 检查会把每次改动摆出来。
- **测试**：同一组参数分别经 `MockProvider` 驱动的 Agent 循环和工具 API 调用，断言写入结果、`entity_events`、权限拒绝一致（服务端 4.3）。

## 14. 持久执行：暂停、恢复与崩溃

> 2026-10-26 定稿。v1 在现有 PostgreSQL 里自写一个小的持久 Agent 循环，不引入外部引擎（理由见第 12 节）。本节是服务端实现规范；对客户端的契约（ChatWeave 的暂停 / 继续）见 13.5，提示词缓存的配套规则见第 15 节。SQL 为草图，未执行。

### 14.1 思路

- 一次**运行**（run）= 一条助手回复从开始到结束，中间可以暂停多次。运行有一行状态（`agent_runs`，这一行本身就是队列里的任务），外加一份**只追加的步骤日志**（journal，`agent_run_items`）：本次运行的输入、模型每一轮的完整输出、每个工具结果、每次中断和回答，各记一条。
- **暂停 = 写好 journal 和 ChatWeave 暂停检查点，然后结束这次执行**：没有线程、连接或任务在等用户；等几小时、几天，服务端代价都是零。
- **回答 = 一个 HTTP 动作**：在同一个事务里记下答案、把运行重新排队；后台 worker 领取后读出 journal，从断开的那一步接着做。恢复不重放代码，只看 journal 做到了哪一步。
- **已经记进 journal 的工具结果直接复用，绝不再执行一次**。会改数据的工具写的就是同一个 PostgreSQL，业务写入和“这一步已完成”放进同一个事务，所以本地写入是**恰好一次**（14.5）。
- 两份日志各管各的，不要混：

| | Agent 日志 `agent_run_items` | 界面事件日志 `chat_stream_events` |
|---|---|---|
| 给谁用 | 服务端恢复运行、重建模型请求 | 客户端续传、重放 |
| 内容 | 模型能看到的一切：每轮模型输出（文字、工具调用、加密的推理数据）、工具参数和原始结果、中断、用户的回答 | ChatWeave 事件：块、步骤说明、暂停 / 继续；**不含**工具名、参数、原始结果、推理 |
| 保留 | 运行结束 30 天后压缩（14.9） | 消息结束或暂停后 10 分钟 |
| 权威性 | 运行状态的唯一事实来源 | 只是传输缓冲；权威的是 `chat_entries` 里的检查点或最终版本 |

### 14.2 表结构（草案）

```sql
-- 一次运行 = 一条助手回复（中间可以暂停多次）。这一行本身就是队列里的任务；取代早先草案的 ai_jobs。
create table agent_runs (
  id uuid primary key default uuidv7(),
  space_id uuid not null, member_id uuid not null,             -- 发起成员；每次领取都重新校验仍是活跃成员
  conversation_id uuid not null,
  assistant_message_id uuid not null,                           -- ChatWeave 消息 ID（暂停 / 继续都是这一条）
  input_entry_id uuid not null,                                 -- 触发这次运行的用户消息
  join_epoch int not null,                                      -- 运行开始时发起成员的 join_epoch，恢复时比对（技术方案 7.5）
  retry_of_run_id uuid references agent_runs,                   -- 重试接着哪次运行做（技术方案 7.3）
  kind text not null check (kind = 'chat'),                     -- v1 只有一种（A16）；子 Agent 的列以后用只追加的迁移补上（A20）
  status text not null check (status in
    ('queued','running','paused','waiting_ai','completed','cancelled','expired','failed')),
  agent_def_version text not null,                              -- 提示词模板 + 工具清单的版本，如 'chat@2026-10-26.1'
  prompt_snapshot bytea not null,                               -- 本次运行冻结的提示词快照（agent_prompt_snapshots.hash，15.2）
  journal_schema smallint not null default 1,
  provider_id text, model text,                                 -- 最近一次模型调用实际用的提供方 / 模型
  -- 队列与租约
  run_after timestamptz not null default now(),
  lease_owner uuid, lease_until timestamptz,
  lease_epoch bigint not null default 0,                        -- 防护令牌（fencing）：每次领取 +1
  attempt int not null default 0,                               -- 崩溃重试次数（不含正常的暂停后继续），上限 2
  -- 中断
  open_interrupt jsonb,                                         -- {id, call_id, step_id, block_id, reason, kind, expires_at}；仅 paused 时非空
  cancel_requested boolean not null default false,
  -- 预算（14.8）
  model_turns int not null default 0,
  active_ms bigint not null default 0,                          -- 活跃时长，不含暂停
  next_item_idx int not null default 1,
  history_item jsonb,                                           -- 运行结束时写入：这一轮在以后各轮提示词里的固定形式（15.2），之后不再改
  last_error text, origin_request_id uuid, client_capabilities jsonb,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  ended_at timestamptz
);
create index agent_runs_ready on agent_runs (run_after) where status in ('queued','waiting_ai');
create index agent_runs_lease on agent_runs (lease_until) where status = 'running';
create index agent_runs_expiry on agent_runs (((open_interrupt->>'expires_at')::timestamptz)) where status = 'paused';
-- 一段会话同一时刻只有一个运行中或暂停中的运行；排队的按会话先进先出领取（A17，技术方案 7.3）
create unique index one_active_run_per_conversation on agent_runs (conversation_id)
  where status in ('running','paused');
create index agent_runs_conversation_fifo on agent_runs (conversation_id, created_at)
  where status in ('queued','running','paused','waiting_ai');
create unique index one_retry_per_run on agent_runs (retry_of_run_id) where retry_of_run_id is not null;

-- 只追加的 Agent 日志。按 idx 顺序读出来就是本次运行的完整模型上下文。
create table agent_run_items (
  run_id uuid not null references agent_runs, idx int not null,
  kind text not null check (kind in (
    'context',          -- 运行开始时渲染一次的空间上下文（15.2）
    'input',            -- 本轮用户输入（文字 / 图片引用、当前时间）
    'model_turn',       -- 模型完整的一轮输出：文字 + 工具调用（参数保留原始字符串）
    'tool_result',      -- 某个工具调用的结果，call_id 唯一
    'interrupt',        -- 发起中断：call_id、问题块 ID、冻结的参数摘要
    'interrupt_answer', -- 回答 / 确认 / 取消 / 自由文字 / 停止 / 过期
    'note')),           -- 系统备注：崩溃后继续、换提供方、版本变化的处理
  call_id text,
  payload jsonb not null,            -- 我们自己的规范格式，不是 genai / async-openai 的类型
  provider_blob jsonb,               -- 不透明的提供方数据（加密推理条目、thinking signature、thought signature）+ 作用范围
  schema_version smallint not null default 1,
  created_at timestamptz not null default now(),
  primary key (run_id, idx)
);
create unique index one_result_per_call on agent_run_items (run_id, call_id) where kind = 'tool_result';

-- 工具调用的执行状态：先记意图，再执行
create table agent_tool_calls (
  run_id uuid not null references agent_runs, call_id text not null,
  tool text not null, tool_schema_version int not null,
  args jsonb not null, args_hash bytea not null,               -- 冻结的参数：确认卡上展示的、确认后执行的都是它
  effect text not null check (effect in ('read','local_write')),   -- v1 没有 external（A20）
  status text not null check (status in
    ('proposed','awaiting_user','approved','rejected','expired','executing','succeeded','failed','cancelled')),
  idempotency_key uuid not null,                                -- = uuidv5(run_id, call_id)；重试时连同原值复制进新运行（技术方案 7.3）
  guard jsonb,                                                  -- 乐观锁前置条件，例如 {record_id, version: 7}
  effect_ref jsonb,                                             -- 写入产生了什么，例如 {record_id}
  attempts int not null default 0, updated_at timestamptz not null default now(),
  primary key (run_id, call_id)
);

-- 提示词快照：按内容哈希去重，同一版本的所有运行共用一行（15.2）
create table agent_prompt_snapshots (
  hash bytea primary key,                                       -- sha256(规范化后的 instructions + tools + settings)
  agent_def_version text not null, provider_kind text not null, model text not null,
  instructions text not null, tools jsonb not null,             -- 工具按固定顺序
  settings jsonb not null,                                      -- 推理强度、verbosity、结构化输出格式等
  created_at timestamptz not null default now()
);
```

ChatWeave 这边沿用 `chat_entries`（暂停检查点：`stream_status = paused`、`message`（`status = paused`、`rev = 0`）、`last_seq`）、`chat_stream_events` 和 `chat_actions`（动作 ID = 幂等键），见 [server-rust.md 5.1](server-rust.md#51-表结构草案postgresql-18)。

**存的形式**：`payload` 只存与提供方无关的规范格式（`{role, text, tool_calls:[{call_id, name, args_raw}]}`、`{call_id, ok, result}` 等），重建请求时由适配器翻译成 SIWC 的 `input` 数组或 genai 的消息；工具原始结果完整存进 journal（模型下一轮要用），只在数据库里，不进日志、不下发。

### 14.3 运行状态机

```
             ┌──────────── 用户回答（动作，同一事务）────────────┐
             ▼                                                   │
 [queued] ──worker 领取──▶ [running] ──中断──▶ [paused] ─────────┘
    ▲  ▲                     │  │  │            │  │  │
    │  └─租约过期（崩溃）────┘  │  │            │  │  └─过期 ──▶ [expired]
    │     attempt+1；超过 2 次 → failed          │  └────停止 ──▶ [cancelled]
    │                           │  └─最终回答 ──▶ [completed]
    └─退避到点── [waiting_ai] ◀─┘ 全部提供方失败
                 （用户点停止 → cancelled；超出预算或等太久 → failed）
```

工具调用：`proposed →（需要确认？awaiting_user → approved | rejected | expired | cancelled）→ executing → succeeded | failed`（`unknown` 只属于以后的 `external` 工具）。只读工具从 `proposed` 直接到 `executing`。

与 ChatWeave 消息状态的对应：`queued / running / waiting_ai` ↔ `streaming`；`paused` ↔ `paused`（带 `interrupt`）；`completed` ↔ `complete`；`cancelled` ↔ `interrupted`（`error.code = cancelled`）；`expired` ↔ `interrupted`（`interrupt_expired`）；`failed` ↔ `interrupted`（`upstream_failed`，可重试）或 `error`。

### 14.4 恢复算法

**A. 用户回答**（`POST /chat/actions`，一个事务）

1. **先鉴权，再查幂等键**（技术方案 5.3、7.1，S34）：回答者此刻是该空间的活跃成员、`join_epoch` 与请求一致、这条消息属于本人的会话，再过宿主 `authorize`；都通过之后才查 `chat_actions` 的幂等键（同一个动作 ID 直接返回第一次的结果，包括 `resume`）。幂等结果不是授权缓存：退出后重放旧的动作 ID 拿到的是 `not_found`。
2. 条件写入：`UPDATE agent_runs SET status = 'queued', run_after = now(), open_interrupt = NULL … WHERE id = $run AND status = 'paused' AND open_interrupt->>'id' = $int AND (open_interrupt->>'expires_at')::timestamptz > now()`。影响 0 行，说明停止或过期已经先到，返回 `already_resolved` / `expired` 并带 `resume`，客户端去看真实结果。
3. 追加 journal：`interrupt_answer{interrupt_id, outcome: confirm | cancel | answer, selected?, values?, freeText?, answered_at}`。确认类：`agent_tool_calls` 改为 `approved` / `rejected`；`ask_user`：直接写一条 `tool_result`，结果就是用户的回答。**自由文字**（用户点了卡片上的“输入其他内容”）原样作为结果交给模型理解，例如在确认卡上写“改成 72 块再记”，对应的工具调用记为 `rejected`、结果写“用户没有确认，而是说：……”。
4. 写事件：取 `chat_entries.last_seq` 为 N，插入 `block.patch`（seq N+1，块 → `resolved`）和 `message.resumed`（seq N+2），更新 `last_seq`，检查点改回 `streaming`。此时运行不被任何 worker 持有，不会有别人同时产生事件。
5. 插入 `chat_actions`（`accepted` + `resume{messageId}`），提交，然后 `NOTIFY agent_runs`。

**B. worker 继续执行**

1. **领取**：`UPDATE agent_runs SET status = 'running', lease_owner = $me, lease_until = now() + '60s', lease_epoch = lease_epoch + 1 WHERE id = (SELECT … WHERE status IN ('queued','waiting_ai') AND run_after <= now() AND 本会话里没有更早的未结束运行 ORDER BY run_after FOR UPDATE SKIP LOCKED LIMIT 1) RETURNING *`（完整 SQL 见技术方案 7.3）；之后每 20 秒续租。**之后的每一次写入都带 `AND lease_epoch = $epoch`**：影响 0 行就立刻放弃（别的 worker 已经接手）。
2. **加载**：运行行、按 `idx` 排序的 journal、`agent_tool_calls`、`chat_entries` 检查点（`last_seq`、块状态）、提示词快照。
3. **环境校验**（技术方案 7.5）：成员仍然活跃、`join_epoch` 未变，否则 `cancelled`（“空间不可用”）；模块权限与开始时不同则 `failed`（`permission_changed`）；都不写任何业务数据；版本检查（14.10）。新的重试运行第一次领取时，先在同一事务里复制原运行的 journal 与工具调用（技术方案 7.3）。
4. **决定下一步**：纯函数 `next_action(items, calls)`，只看 journal：
   - 最后一项是带工具调用的 `model_turn`：逐个看——已有 `tool_result` 的直接复用；`approved` 的按 14.5 执行；`rejected` 的写结果“用户没有确认”（有自由文字时带上原话）；只读的缺结果就执行；需要确认但还没问的发起中断（C）。**每次暂停只问一个**；其余不需要确认的调用先跑完，再暂停。
   - 最后一轮的工具调用全部有了结果：用快照 + journal 重建请求（第 15 节），再调一次模型。
   - 最后一项是不带工具调用的 `model_turn`：这就是最终回答，完成运行。
5. **调用模型**：文字增量照常经 ChatWeave 流生成器推送（seq 从 `last_seq + 1` 开始）。收到完整的结束事件后，**在一个事务里**写入 `model_turn`（含 `provider_blob`）、对应的步骤事件和检查点。
6. **再次中断**：一个事务里写 journal 的 `interrupt`、工具调用改为 `awaiting_user`、`open_interrupt`（含 `expires_at`）、交互块事件、`message.paused`、`chat_entries` 检查点（`paused`、`last_seq`），状态改为 `paused` 并清掉租约。worker 这次执行直接返回，**什么也不持有**。
7. **结束**：一个事务里写最终的 `model_turn`、`message.end`、`chat_entries` 最终版本（`rev = 1`，分配 `change_seq`）、`history_item`，状态改为 `completed`。

**C. 中断放在副作用之前**：需要确认的写操作，先把参数冻结进 `agent_tool_calls.args` / `args_hash`，带上乐观锁前置条件（例如被改记录的 `version`）；确认卡上展示的就是这份冻结参数，确认之后执行的也必须是它，不让模型重新生成。确认之前什么都不写。

### 14.5 恰好一次与至少一次

| 类别 | 例子 | 保证 | 做法 |
|---|---|---|---|
| **本地写入** `local_write` | 记一笔、改一笔、作废、调拨 | **恰好一次** | 一个事务里：工具调用改为 `executing`（带 `lease_epoch` 条件）→ 业务写入（`records`、`entity_events`、`change_seq`；新记录 ID = `uuidv5(run_id, call_id)`，`ON CONFLICT DO NOTHING`）→ 插入 `tool_result`（唯一索引 `(run_id, call_id)`）→ 改为 `succeeded` → 提交。提交前崩溃等于没发生；提交后 journal 里已有结果，恢复时直接复用 |
| **只读** `read` | 查余额、查统计、搜记录 | 至少一次（重跑无害） | 执行后写 `tool_result`；写之前崩溃就重查一次 |
| **外部副作用** `external` | v1 没有、也不实现这条分支（A20；以后可能有推送、外部 Agent） | 至少一次 + 幂等键 | 先提交 `executing` 和 `idempotency_key` 再调用。恢复时看到 `executing` 却没有结果 = 不确定：对方支持幂等键就用同一个键重试，能查询就先查，都不行就标 `unknown`，把“不确定是否成功”作为结果告诉模型和用户，**绝不盲目重试** |
| **模型调用** | | 至少一次 | 无法纳入事务。`model_turn` 提交前崩溃就重新调用（14.6） |
| **ChatWeave 事件** | | 对客户端恰好一次 | 至少一次投递 + 按 `seq` 去重；`chat_stream_events` 主键 `(message_id, seq)` 冲突说明出现了两个生产者，当前 worker 立即放弃 |
| **用户回答** | | 恰好一次 | 动作幂等键 + 条件写入，先到者胜 |

### 14.6 崩溃与重启

| 崩溃时机 | 恢复后 |
|---|---|
| 暂停中 | 不受影响：检查点和运行行都已提交，没有 worker 持有它 |
| 两步之间（上一步已提交） | 租约过期后被重新领取（`attempt + 1`），从 journal 接着做；客户端续传拿快照后继续收事件 |
| 工具执行中 | 本地写入：事务没提交，等于没发生，重新执行；只读：重查；外部：按 14.5 对账 |
| 模型输出到一半（部分文字已显示，`model_turn` 未提交） | **自动在同一条回复里接着做**：已经显示的文字保留，先补发 `block.end` 结束那个块，再用同一份请求重新调用模型（缓存可命中），新文字另起一块；需要时在请求**末尾**追加一条说明（“上次输出中断了，请接着回答，不要重复已经说过的内容”）。最多 2 次，之后以 `interrupted`（`upstream_failed`，可重试）结束，仍在运行的步骤标 `failed`，用户可以点“重试” |
| 写 `message.end` 的事务中 | 事务原子：要么还没结束（重做最后一步），要么已结束 |

- **启动和每 30 秒**：清扫器把 `status = 'running' AND lease_until < now()` 的运行放回 `queued`（`attempt + 1`），超过 2 次改为 `failed` 并按上表结束消息。
- **优雅停机**（systemd `TimeoutStopSec` 内）：停止领取；进行中的模型调用最多等约 20 秒，否则主动把运行放回 `queued`（`lease_until = now()`，不计 `attempt`），重启后马上接上。
- **重试**：用户在“没有完成”的回复上点“重试”= 开始一次新的运行（新的一条回复），**接着原运行的 journal 做**：原运行的 journal 和工具调用（连同幂等键）复制进新运行，已有结果的工具调用不再执行，所以已记的账不会重复（技术方案 7.3）；原回复保持原样。`permission_changed` 结束的运行不提供重试。

### 14.7 过期、停止与新消息

- **过期时间**按中断的种类：**改记录类的确认 24 小时**（数据会变）、**澄清类（`ask_user`）7 天**。`open_interrupt.expires_at` 与交互块的 `action.expiresAt` 是同一个值。
- 清扫器每分钟一次：`UPDATE … SET status = 'expired' WHERE status = 'paused' AND expires_at < now()`，对每一行在同一事务里写 `interrupt_answer{outcome: expired}`、工具调用改为 `expired`、事件（`block.patch(expired)` → `step.finished(cancelled)` → `message.end(interrupted, interrupt_expired)`）和最终消息。动作处理器自己也检查 `expires_at`，不依赖清扫器的延迟。
- **停止**（“停止生成”，暂停中同样可用）：同一个“关闭中断”的条件写入；块 → `cancelled`（`stopped`），步骤 → `cancelled`，`message.end(interrupted, cancelled)`，运行 `cancelled`。运行中点停止则设 `cancel_requested`，worker 在每一步之间检查；已经提交的本地写入保留（用户可在记录上撤销），不做自动补偿。结束时的文字按 journal 里已成功的写入工具调用生成“已记几笔、哪些没有记”（P50），不再调用模型。
- **新消息**：卡片等待回答时客户端锁定输入框（13.5），正常界面发不出新消息。只有离线排队的新消息在服务端到达时恰好遇到暂停中的回复（例如另一台手机上刚开始暂停），处理器在同一事务里先按“停止”关闭暂停中的运行，再创建新运行（受唯一索引 `one_active_run_per_conversation` 保护）。有排队 / 运行中的回复时，新运行照常排队、先进先出。

### 14.8 预算与超时

- 每次运行最多 **20 轮模型调用**、**10 分钟活跃时长**（不含暂停）；超限时让模型给一个说明性的结尾（不再调用工具），再以 `interrupted` 结束。
- 租约 60 秒、每 20 秒续租；单次模型调用空闲超时 60 秒（没有新的流事件）、总超时 5 分钟；单个工具 10 秒。
- 全部提供方都失败：`waiting_ai`，按 `run_after` 指数退避（第 7 节）；消息保持 `streaming`，显示“稍后继续”的临时提示；累计超过 10 分钟就以 `interrupted`（可重试）结束，免得一直显示“生成中”。

### 14.9 推理数据与 journal 保留

- **可读的推理文字和推理摘要一律丢弃**（13.3）。**提供方加密的推理数据**（OpenAI 的 reasoning 条目 `encrypted_content`、Anthropic thinking 的 `signature`（用 `display: "omitted"`，不要思考文字）、Gemini 的 thought signature）只存进 journal 的 `provider_blob`，带上作用范围（提供方、模型、账号）；不下发、不进 `chat_entries`、不进日志。工具循环必须原样回放它们（Anthropic 是硬性要求，OpenAI 强烈建议），也是缓存命中所必需的（第 15 节）。
- 运行结束 **7 天**后把 `provider_blob` 清空（置 NULL）。
- 运行结束 **30 天**后压缩 journal：删掉工具原始结果和模型输出原文，只保留步骤摘要（种类、工具名、状态、耗时），便于排查问题。财务数据本身在业务表里，不靠 journal 保存；以后各轮的提示词只读 `history_item`，不受压缩影响。

### 14.10 版本变化与记录冲突

journal 存的是**数据**，不是“代码执行到第几行”，所以服务端升级后照常恢复，不需要确定性重放。

| 变化 | 处理 |
|---|---|
| 提示词或工具清单改了（`agent_def_version` 变了） | 用**当前**版本生成新快照（代价是一次缓存未命中）；版本没变就继续用本次运行的快照 |
| 工具改了 | 每个工具有 `schema_version`。待执行的调用用当前 schema 重新校验冻结参数，通过就执行；工具已删除或参数不再合法，写结果“此操作已不可用”，由模型说明。不兼容的改动换新工具名 |
| journal 格式改了 | `schema_version` + 读取时升级，只追加、不改历史 |
| 换了提供方或模型（降级、配置热切换） | 历史按规范格式翻译给新提供方；`provider_blob` **只在提供方、模型、账号都相同时回放**，否则丢掉（这一次没有“延续推理”，不报错）。工具调用 ID 由适配器映射，契约测试覆盖 |
| 提供方拒绝回放的推理数据（过期、账号不符） | 去掉 `provider_blob` 重试一次，记一条 `note` |
| **确认之后发现记录已被改过**（例如另一台手机改了这一笔） | 执行前再校验 `guard`：版本不对就**不写**，结果写“记录已变化”，由模型说明，必要时重新发起一次确认 |
| 成员已退出空间 | `cancelled`，“空间不可用”，不执行任何写入（技术方案 7.5） |

`agent_def_version` 记在运行上，用于排查和统计；v1 不保留旧版本的代码路径。

### 14.11 并发与长时间暂停

- **两台手机抢答**：14.4 A 的条件写入只会让一个成功，另一个拿到 `already_resolved` 和 `resume`；同一个动作 ID 重复提交，回放第一次的结果。
- **两个 worker**：`SKIP LOCKED` + 租约 + `lease_epoch` 防护令牌；即使租约过期而旧 worker 还活着，它的下一次写入也会因 epoch 不匹配而失败，写事件时 `seq` 主键冲突同样让它退出。
- **10 分钟事件日志 vs 几天的暂停**：暂停检查点（`chat_entries`）不过期；事件日志从 `message.paused` 起保留 10 分钟后删除，之后来订阅的设备拿暂停中的快照。恢复执行只依赖 `agent_runs` 和 journal，与界面事件日志无关。

### 14.12 测试

- `next_action()` 是纯函数：单元测试 + 属性测试。
- `MockProvider` + 故障注入，覆盖 14.6 表里的每个崩溃点、抢答、租约脑裂（epoch）、过期与回答的竞态、停止与回答的竞态、确认后记录被改、暂停中升级版本、换提供方。
- 集成测试连真实 PostgreSQL 18：多个 worker 并发领取（`SKIP LOCKED`）、本地写入工具在事务回滚时不留痕、同一会话先进先出、`one_active_run_per_conversation` 与 `one_retry_per_run`、重试不重复执行已有结果的工具调用。
- 缓存相关的请求体快照与在线验收见 15.5。

## 15. 提示词缓存

> 2026-10-26 核实（来源见第 16 节）。提示词缓存对成本影响很大：命中部分按约 1/10 的价格计（OpenAI、Anthropic、Gemini 都是这个量级）。走订阅（SIWC）时同样按该模型的官方 API 标价折算成本，缓存省下的就是钱，不只是额度（第 7 节价格表），Agent 的工具循环每一轮都要把整段前缀再发一次。持久执行的设计本身不妨碍命中——恢复就是“同一份历史 + 末尾追加”——但必须守住本节的规则。

### 15.1 什么能命中，什么不能

| 情况 | 结果 |
|---|---|
| 运行内的每一次后续模型调用（工具循环） | 命中到上一次请求为止，只有新追加的部分按原价。**收益最大的地方** |
| 暂停后在缓存有效期内回答（OpenAI GPT-5.6+ 30 分钟，Anthropic 5 分钟，旧 OpenAI 模型视保留策略） | 命中到暂停前最后一次请求为止 |
| 崩溃后自动重试（14.6） | 请求与崩溃前相同，命中 |
| 同一会话的下一轮新消息 | 静态前缀、空间上下文和以前各轮的历史命中；上一轮内部的工具往来不再出现（历史只保留压缩形式），从那里起按原价 |
| 超过有效期的长暂停（几小时、几天后才回答） | **不命中一次**，之后重新写入。接受（15.4） |
| 暂停期间升级了提示词 / 工具 / 模型；换了提供方 | 不命中一次。版本升级很少；降级本来就换了缓存 |

### 15.2 前缀稳定规则

1. **请求的固定顺序**：①静态指令（SIWC 的 `instructions` / 其他提供方的 system）→ ②工具定义 → ③空间上下文（账户、标签、成员等）→ ④会话历史 → ⑤本轮用户输入 → ⑥本次运行的 journal 条目。**易变的东西只往后放**：当前日期时间放在⑤，不放进①或③。
2. **每次运行冻结一份提示词快照**（`agent_prompt_snapshots`）：开始时把渲染好的指令、工具清单（固定顺序、含 schema）、模型、推理强度、verbosity、结构化输出格式存成快照，本次运行的每次调用（包括恢复后）都用它。运行只由本人发起（第 6 节），工具清单不随发起方式变化，同一版本的所有运行共用一份。空间上下文只在运行开始时渲染一次，存成 journal 的第一条（`context`）；运行中途工具改了空间数据，模型从工具结果里知道，不重新渲染。只有 `agent_def_version` 变了才换快照（14.10）。
3. **工具定义里不放动态数据**：例如不把本空间的账户名做成参数的 `enum`，否则每改一个账户，所有会话从工具定义起全部失效。账户名单放在③。
4. **确定性序列化**：请求由纯函数 `render_request(快照, journal, 历史, 提供方)` 生成；不用 `HashMap`，JSON 字段顺序固定；工具调用参数保存模型给出的原始字符串并原样回放；加密推理数据原样回放（14.9）；图片只在入库时压缩一次，之后引用同一份字节，不重新压缩。
5. **运行内不截断、不压缩**：journal 只追加；不用提供方的服务端压缩（会被记为 compaction 未命中）；运行长度由 14.8 的预算约束。
6. **会话历史：平时只追加，整理只在两种时机做**（A19）：运行结束时把这一轮写成不可变的 `history_item`（用户输入 + 最终回答的文字，中途的问答也记在里面），以后各轮只读它，前面的内容不动。**整理**（把较早的部分压缩成一条摘要 `history_summary`，最近若干轮原样保留）只在新运行开始前、满足下列任一条件时做一次：①历史超出长度预算；②距这段会话上一次模型调用已超过缓存有效期（此时缓存反正已失效，重排前缀不多花一分钱），且历史已超过“值得整理”的下限。整理后切点和摘要固定，直到下一次触发；**运行内（含暂停后恢复）永不整理**。不做每轮滑动一条的窗口（那样每一轮的前缀都变，等于永远不命中）。摘要由模型生成、存库、可审计；摘要失败时退回成块截断最早的一半。
7. **同一次运行里模型参数不变**：模型、推理强度、verbosity、结构化输出格式、`tool_choice` 都不随轮次变化。
8. **补充说明只追加在末尾**：崩溃重试的提示（14.6）、长暂停后“已经过去多久”（写在回答的工具结果里）都不改前面的内容。

### 15.3 各提供方的放法

| 提供方 | 做法 |
|---|---|
| ChatGPT 订阅（SIWC，async-openai） | **按会话绑定缓存**（E1 实测）：请求头 `session_id` 与请求体 `prompt_cache_key` 都设成会话 ID（同一会话的各次运行、暂停后恢复共用）；不带时几乎不命中。`prompt_cache_options` 与显式断点会被拒（400），不发；必须省略 `prompt_cache_retention`。断点由服务端自动放在最新一条输入末尾，正好是下一次调用要命中的位置（4.4 第 8 项） |
| OpenAI API key，GPT-5.6 及以后（genai） | **必须自己放断点**：genai 0.7.1 对这些模型在没有任何缓存设置时会发 `prompt_cache_options: {mode: "explicit"}` 而不带断点，按官方说法这次请求**完全不缓存**。`GenaiProvider` 总是在③末尾、④末尾和最后一条输入上设消息级 `cache_control`（genai 映射成 `prompt_cache_breakpoint`，TTL 30 分钟） |
| OpenAI 旧模型（≤ 5.5） | 自动缓存；按会话设 `prompt_cache_key`（只影响路由），不设保留策略 |
| Anthropic（genai） | 最多 4 个断点：①末尾（连同工具定义，所有会话共用）、③末尾、④末尾、每次请求的最后一块（随运行前移）。TTL 用默认 5 分钟。改工具定义、`tool_choice`、thinking 参数都会让缓存失效，所以同一次运行里不变（规则 7） |
| Gemini（genai） | 只用默认的隐式缓存；不建显式缓存（按小时收存储费，两人规模不划算） |
| 本地模型（Ollama 等） | 不涉及 |

前缀太短（OpenAI 1,024 token、Anthropic 512–4,096、Gemini 2,048–4,096，随模型）时不会缓存，也不报错；不为凑长度而填充。

### 15.4 长暂停不延长缓存、不保温

- **更长的有效期**（Anthropic 1 小时：写入 2 倍价而不是 1.25 倍；OpenAI 12 小时：2.5 倍）：模型调用之前并不知道这一轮会不会中断，只能给所有请求都开，等于每个工具循环都多付写入费；只有回答恰好落在“默认有效期之后、延长有效期之内”时才省下一次，按价格算这个概率要超过约 65%（Anthropic）才划算。**不采用**。
- **保温请求**（每隔几分钟发一次让缓存续期）：一小时的保温费已经超过一次未命中的代价，而追问可能等 24 小时、7 天。**不采用**。
- 以上取舍都按“token × 官方 API 标价”的金额计算（订阅提供方同样如此）。以 8k token 前缀、输入 4 美元 / 缓存 0.4 美元 / 30 分钟写入 5 美元（每百万 token）的价格为例：一次未命中约 0.04 美元，命中约 0.003 美元。
- 长暂停接受一次未命中。上线后看指标（15.5），如果“在默认有效期之后一小时内回答”的比例很高，再单独评估 Anthropic 1 小时有效期。

### 15.5 指标与验收

- `ai_calls`（第 8 节）每次调用记：缓存读取 token、缓存写入 token、未缓存输入 token、`prefix_hash`（①–③的哈希）、调用种类（首次 / 运行内续调 / 暂停后恢复 / 崩溃重试）、距本运行上一次调用的时间；OpenAI 返回缓存诊断时记下未命中原因；按价格表折算的成本与缓存省下的金额。不记内容。
- 看板：按调用种类的命中率和缓存省下的金额（按官方 API 标价，订阅也算）；“暂停后恢复、距上次调用小于有效期、却没命中”的比例——应接近 0，持续偏高说明我们的前缀不稳定（提供方偶尔不命中是正常的：E1 实测 SIWC 16 次后续调用命中 14 次）。
- **离线测试（必须）**：同一份 journal 在“暂停前”和“重启后恢复”各渲染一次，前缀部分逐字节相同（`insta` 请求体快照）；换进程、换 serde 特性组合都不变。
- **正确性门槛只有上面的离线测试**：命中与否取决于提供方，不能做成零容错的验收。
- **在线验收（每个启用的提供方，看比例不看单次）**：跑一组多轮对话（例如 10 段、每段 5 轮），运行内续调和有效期内的暂停后恢复，**多数**调用缓存读取 token > 0（前缀超过该提供方的最短长度）；达不到时先查前缀快照，再看提供方。上线后的命中率作为性能指标看板，不作为发版门槛。SIWC 另记：缓存参数是否被接受、用量里是否返回缓存 token。

## 16. 来源

- OpenAI SIWC：https://developers.openai.com/siwc/ 、https://developers.openai.com/siwc/token-sharing-open-source 、…/models-and-inference 、…/preview-limitations 、https://developers.openai.com/cookbook/articles/sign-in-with-chatgpt
- 各厂商：platform.claude.com（OpenAI SDK 兼容层限制）、ai.google.dev/gemini-api/docs/openai 、api-docs.deepseek.com/guides/json_mode 与 /guides/vision 、docs.ollama.com/api/openai-compatibility 、阿里云百炼结构化输出文档、platform.kimi.ai/docs/guide/response_format
- 库：https://crates.io/crates/genai 、https://github.com/jeremychone/rust-genai 、https://crates.io/crates/async-openai 、https://github.com/64bit/async-openai 、https://github.com/0xPlaygrounds/rig
- 提示词缓存（2026-10-26 访问）：https://developers.openai.com/api/docs/guides/prompt-caching 、…/prompt-caching/diagnostics 、https://developers.openai.com/api/docs/pricing 、https://learn.chatgpt.com/docs/pricing 、https://platform.claude.com/docs/en/build-with-claude/prompt-caching 、https://ai.google.dev/gemini-api/docs/generate-content/caching ；genai 0.7.1 源码 `src/adapter/adapters/openai/cache_policy.rs`、`anthropic/adapter_shared.rs`；async-openai 0.42.2 源码 `src/types/shared/prompt_cache.rs`
- 推理回放：https://developers.openai.com/api/docs/guides/reasoning 、https://platform.claude.com/docs/en/build-with-claude/extended-thinking 、https://ai.google.dev/gemini-api/docs/thinking
- 持久执行与人在回路：https://docs.ag-ui.com/concepts/interrupts 、https://openai.github.io/openai-agents-python/human_in_the_loop/ 、https://docs.langchain.com/oss/python/langgraph/interrupts 、https://docs.restate.dev/ai/patterns/human-in-the-loop 、https://github.com/temporalio/sdk-rust/releases/tag/v1.0.0 、https://github.com/dbos-inc/dbos-transact-rust
