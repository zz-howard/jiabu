# S7 ③ 评测与在线冒烟

84 条完全虚构的输入经 **RunService + Runtime worker + 真实 PG18 + ToolRegistry**
完整循环执行：原有 64 条记账/追问样例保持 v1 不变，另有 20 条 genUI 展示样例使用 v2。
Mock 的 100% 只证明夹具、格式和评分自洽；收据识别与模型能力须看 live 结果。
本切片不调提示词，不增加 HTTP 接口，不录制真实交互。

## 构建机准备

本机不编译或运行测试。先由 luna.coco 在构建机生成并提交三张图片：

```bash
python3 -m pip install Pillow==11.3.0
python3 server/eval/tool/gen_receipts.py
```

脚本只依赖 Python 3（支持 `zip(strict=True)`，建议 3.11+）及 Pillow 11.3.0（HPND）。
固定日期、商户、金额、布局、旋转角度、编码参数，无随机数、EXIF、当前时间。
两份仓库字体逐字符检查覆盖，优先 hand，缺字回退 serif；两者都缺则失败。
`tool/receipt_outputs.txt` 是生成器和数据测试共用的固定清单：
`receipt_clear.jpg`（18.50 元）、`receipt_tilted.jpg`（32.70 元，旋转 7°）、
`receipt_long.jpg`（136.00 元，16 个商品行）。同一 Python/Pillow/字体版本生成可重复字节；
跨 Pillow/FreeType 版本不保证 JPEG 哈希相同。

所有数据测试都要求清单中的文件存在、格式为 JPEG 且可完整解码；没有占位图或缺图跳过。
随后在 `server/` 下由构建机更新 Cargo.lock 并运行门禁。新增 Rust 依赖仅
`yaml-rust2 = "=0.11.1"`（MIT OR Apache-2.0，已有锁定的传递依赖），CSV 编码无新依赖。
`ai-eval` 包/二进制位于 `crates/eval`，由 workspace `crates/*` 自动纳入。

## 数据格式 v1

每个 `entries/*.yaml` 只有一个文档。严格类型，拒绝未知字段、重复键、非字符串键、
浮点数、别名、anchor、显式 tag。日期必须加引号，格式 `YYYY-MM-DD`。

```yaml
schema_version: 1
id: zh-example-001
locale: zh-Hans
category: colloquial_single
today: "2026-10-21"
timezone: Asia/Shanghai
input:
  text: "昨天楼下虚构团团铺早饭18块，用虚构零钱、日常用途，人民币"
  # images: ["fixtures/receipt_clear.jpg"]
setup:
  currency: CNY
  accounts:
    - key: cash
      kind: real
      name: 虚构零钱
      opening_on: "2026-01-01"
    - key: daily
      kind: purpose
      name: 日常用途
      opening_on: "2026-01-01"
  records: []
expect:
  behavior: write
  hard: false
  records:
    - operation: create
      kind: expense
      amount_minor: 1800
      currency: CNY
      occurred_on: "2026-10-20"
      preset_key: dining
      account: cash
      purpose: daily
```

字段约定：

- `id` 唯一，只含英文字母、数字、连字符；`locale` 为 `zh-Hans` / `en`（与 users.locale 约束一致）。
- `category`：`colloquial_single`、`multi_record`、`relative_date`、`income`、`transfer`、
  `reallocation`、`refund`、`receipt`、`insufficient`、`confirmation`、`chat`、`english`、`ambiguous_date`。
  当前各类依次为 6、4、6、3、3、2、3、3、4、3、3、4、20 条；各类至少一条。
- `today` 固定参照日；首批时区仅支持 `UTC`、`Asia/Shanghai`、`Asia/Singapore`。
  提交时刻固定为该日 UTC 12:00，在这三个时区都仍是 `today`。
  `start_at` 仅冻结输入时间，租约/确认到期/worker 超时仍用墙钟时间。
- `input.text` 必填，`input.images` 可省略；图片路径只能来自清单，位于 `fixtures/`。
- `setup` 必填；账户 `key` 是本样例别名，`kind` 为 `real` / `purpose`。
  当前币种为 CNY。所有样例有正常账户/用途上下文；明确输入指定账户和用途（收入只指定收款账户），避免默认猜测。
- `setup.records` 可省略。每项 `{key: old, record: <RecordSpec>}`，record 的 operation 为 create。
  用已有账户别名、预置分类键建记录，退款父记录须先出现；`status: voided` 会经工具再撤销，
  支持恢复测试的版本号。setup 全部通过 `ToolRegistry::invoke()` 写入。
- `expect.behavior` 为 `write` / `ask_user` / `confirm_then_write` / `no_write`。
  非写行为 `ask_user` / `no_write` 必须 `records: []`。
  `ambiguous_date` / `insufficient` 强制 `ask_user + hard: true`；
  `confirmation` 强制 `confirm_then_write + hard: true`。
- `ambiguous_date` 额外必填 `ambiguity_reason`，写明缺少的依据和合理解释。
  中英文恰好各 10 条。固定 today 能判定的普通“上周五”不属于含糊日期；
  旧便签里的“下周三”因原书写日未知而含糊。
- RecordSpec：`operation` 为 `create/update/void/restore`；已有记录操作用 `target` 指向 setup 别名。
  每个旧目标每条样例只声明一个操作；首批确认场景每条一个旧记录操作，自动确认一次。
  新增记录为使理想 Mock 可生成调用，`kind/amount_minor/occurred_on` 必填；其余不关心可省略。
  旧记录的金额/日期/种类等可省略。`amount_minor` 为 i64 最小货币单位，绝不解析浮点金额。
  `currency` 对比空间币种，并非工具参数；`status` 为 `active/voided`。
- 分类 `preset_key` 必须来自 `domain::presets::PRESETS`（11 个）；运行时映射到空间真实标签 UUID，
  实际记录的标签身份集合与该预置标签精确匹配，不依赖中英文名称。
- `account/purpose/to_account/to_purpose` 指 setup 账户别名；`refund_of` 指 setup 记录别名。
  `transfer` 是实账户间转账；`reallocation` 是用途间调拨；不产生计划专属的 `allocation`。

## 数据格式 v2：genUI 展示

v2 只用于 `category: display`，保留与 v1 相同的 `input/setup` 结构。
当前展示评测使用 `expectation-v1`：只判断回复是否满足原始用户请求和虚构账本事实，
除用户明确要求外，不评价自然度、赘述、句数或内部组件偏好。`tier` 仅用于描述样例，不能直接判通过或绕开 Judge。

规则返回 `pass/fail/needs_judge`。只有完整确定的契约才能直接 pass；可证明的写入、非法参数、
不支持的持久组件或对象引用冲突可以直接 fail。自由文字金额/标签匹配、工具顺序、展示选择
和模糊的支出/退款口径不作为硬反证；无法确定的交 AI Judge。现有 20 条均包含自然语言要求，
通过协议检查后仍须 Judge。旧 alternatives/prose 字段保留供 Mock 和历史诊断使用，
不得把旧精确匹配或内部 max_sentences 偏好当作新版本的判分条件。

Judge 输入将独立测试 reference 与 actual candidate 分开：reference 包含虚构 setup、
执行前记录和事实集合；candidate 包含实际可见文字、完整持久组件、真实读取调用及余额证据。
固定 today/timezone/as_of（当日 UTC 12:00）、币种和 minorUnits/format 均保留。
组件 fallback 与服务端降级证据单列，不当作额外可见回复。账户卡只有引用、名称和版本，
不得凭空注入余额；缺失完整快照或关键输入是基础设施未完成。

数据字段示例（prose 字段只兼容历史数据，不参与 expectation-v1 判分）：

```yaml
schema_version: 2
id: display-example
locale: zh-Hans
category: display
today: "2026-10-21"
timezone: Asia/Shanghai
input: {text: "给我看看本月支出分布"}
client_capabilities: # 省略时使用当前 Jiabu 完整能力
  blocks: {markdown: 1, metric_group: 1}
setup:
  currency: CNY
  accounts: []
  records: []
expect:
  behavior: no_write
  hard: false
  records: []
  display:
    hard: true
    alternatives:
      - id: metrics
        expected_invalid_calls: 0
        expected_business_errors: 0
        source_calls: [] # 可选：先执行读取，供 from_call 或纯文字证据复用
        calls:
          - {tool: show_metrics, args: {source: {query: null, from_call: null, demo: monthly_spending}}}
        blocks:
          - {kind: metric_group, labels: [餐饮, 居家, 购物, 交通, 其他], values_minor: [142000, 98000, 75000, 41000, 72600], account: null, demo: true}
        fallback_contains: ["【演示数据】"]
        server_fallback_contains: ["【演示数据】"]
        facts:
          - {kind: aggregate, label: 餐饮, value_minor: 142000}
    prose: {max_sentences: 2, forbid_mermaid: true, forbid_ascii_chart: true, max_table_rows: 5, forbid_numeric_restatement: true}
```

- `source_calls` / `calls` / `blocks` / `facts` 为合成 Mock 和独立事实 reference 提供数据，
  不强制真实回复照搬某条工具路径或组件方案。金额使用整数最小货币单位。
- `client_capabilities` 在 enqueue 时冻结；Judge 看到与实际 Scenario 相同的有效能力。
- `server_fallback_contains`、`fallback_contains`、`prose` 仍可用于历史诊断，不能替代原始用户要求。

## 隔离与提供方

每条样例新建一个临时数据库，完整迁移、种子数据、独立用户/空间/会话；默认最多两条并发，可用 `--jobs 1` 顺序复现，`--jobs` 仅接受 1 或 2。
Live 校准先单独完成，再调度样例；每条需要 Judge 的样例的三票 Judge 仍按原顺序逐票执行。结果始终按语料原顺序汇总，完成先后不改变 CSV 顺序。首次观察到基础设施错误（含结果写入或 worker 错误）后停止派发新样例，等待已开始样例正常收尾后退出 2；展示报告保留所有预期 ID，未完成项明确标为基础设施未完成，不能当作整套结果。不会主动取消已开始样例，以避免初始化中途取消留下测试库。
复用 `tests/support/mod.rs::TestDb` 与 `tests/support/agent.rs::Fixture`，沿用原 runtime 测试的
搭法。原测试名、脚本、断言不变。TestDb 有清理 Drop（正常错误和 unwind 均清理；强制杀进程
需人工清掉 `jiabu_test_*`）。PG18 超级用户 URL 必须指向已有可丢弃集群，带
`jiabu_disposable_test_cluster` 标记，并满足现有测试角色保护检查。
不要把生产凭据库当 scratch；可用既有 `tool/dev-db.sh start` 启动测试集群。

Mock 按 expect 生成 `MockProvider::scripted()` 的真实工具参数：write 调 create_record，
ask_user 持久暂停且不回答，确认类先产生真实确认卡、比较业务基线，再走 ScopedRuns::answer
确认一次，最后检查写入；闲聊只发文字。真实 JPEG 经真实引用校验和 ImageLoader 传入模型请求。

Live 从已经执行 `admin provider login chatgpt` 的 **应用角色数据库 URL** 读取配置、路由、
凭据以及历史价格快照；使用 `AiRouter + SiwcProvider + CredentialManager`，不调用服务器
`ai_runtime::start()`，不做计量恢复、后台配置写入或新登录。
只装配现有服务器支持的 SIWC 适配器，保留路由/billing 策略，未知适配器不会被替换成 Mock。
首批要求 SIWC 凭据源为 `db`，不使用 file/env 登录凭据。

**源库唯一允许的写入是 CredentialManager 原有的凭据轮换/失效路径**：到期前或认证失败时刷新，
新 refresh token 按 revision CAS 写回源库，明确拒绝时按 revision 标失效。
一个 manager/gate 在全集各场景间共享；与运行中的服务器并发轮换仍受数据库 CAS 保护。
使用现有 `JIABU_SECRETS_KEY_FILE`（0600）或 `JIABU_SECRETS_KEY` / `JIABU_SECRETS_KEY_ID`。
不得输出这些变量的内容。空间账本、journal、检查点、ai_calls **仅写临时库**；
临时库只导入非敏感提供方/模型及价格配置，不复制 secrets。

```bash
# 在 server/ 下；DATABASE_URL 是可丢弃 PG18 的超级用户 URL。
cargo run -p ai-eval -- --provider mock --out eval/results/2026-10-29-mock

# DATABASE_URL 是现有 SIWC 配置/凭据源库的应用角色 URL；
# EVAL_DATABASE_URL 是另一个可丢弃 PG18 集群的超级用户 URL。
cargo run -p ai-eval --features live -- \
  --provider live --judge-model <已启用的精确模型名或模型 UUID> \
  --out eval/results/2026-10-29-live

# 可用 --database-url 显式指定 live 源库，--scratch-database-url 显式指定 scratch。
# 不在 shell 历史或报告中粘贴真实凭据。--dataset 可指定另一份格式兼容的数据目录。
```

凭据、连接 URL、原始请求、模型文字和上游错误正文均不写 CSV 或日志。
CLI 仅输出样例 ID 和固定错误码；配置/数据错误也不格式化底层异常。

Live 启动时先用显式 `--judge-model` 绑定已加载配置中的唯一 enabled 模型和 provider，
没有静默 fallback。先运行校准，再对 `needs_judge` 样例进行三次独立调用并取 2/3 多数。
每票严格只有 `{"expectation_met": bool}`，不含质量维度、理由或 review 状态。
Mock 不调用 Judge，也不能报告模型符合预期。
Transport、超时、缺 usage、缺票或非法 schema 都是基础设施未完成，不折算为 true/false。
仅原始 Transport 且尚无任何输出或 usage 时，对同一请求最多重试一次；两次共享原有每票
120 秒期限，成功票不会重采样。认证/额度/限流/格式错误及部分输出不重试。
每个闭合 bool 票立即保存，后续失败时仍保留已完成票；usage 只在进程内校验，不写报告。

## 报告与证据

展示结果使用独立 `expectation-v1` CSV：每个预期样例一行，包含执行状态、
`expectation_met`、规则/Judge 来源、规则理由码、Judge 模型快照、self-judge 和三票布尔值。
混合语料时，根目录仅输出非 display 旧结果，展示结果位于 `display-expectations/`。
不含旧质量、prose 或 display_pass 列。summary 只汇总符合/不符合/基础设施未完成及来源。
Mock 单列为 pipeline 验证，符合/不符合计数均为零。旧历史报告保持原样。
`0` = 全部完成且符合预期（Mock 为 pipeline 完成），`1` = 已判定不符合，
`2` = 配置、数据或基础设施未完成；未完成优先于不符合退出码。

默认在 `--out/evidence`（可用 `--evidence-dir` 指定）保存虚构回复、完整组件、
独立 Judge 输入和每票 bool。目录 0700、文件 0600，已存在文件拒绝覆写。
证据只允许声明的合成字段，拒绝凭据、URL、headers、provider blob 和 reasoning；
CSV/日志不含原始请求、回复、secret 或上游错误正文。使用新的输出目录保存每一版本。

原有非 display 的 64 条记账/追问场景继续使用原行为/记录/金额等确定性评分。
含糊日期必须真正暂停且零写入，确认类须对应目标、确认前零写入、确认后正确完成。
匹配使用最小成本一对一配对，绑定目标和退款等对象身份，额外/重复写入不能忽略。
本切片不改变这些原有用例的语义。

## 离线测试与在线冒烟

```bash
# 默认不联网：数据校验、真实 PG18 Mock 全集、坏模型负对照、CLI 和纯评分/CSV 测试。
cargo test -p ai-eval
cargo check -p ai-eval --features live --all-targets
# live 内的合成凭据/CAS 测试仍不访问模型或 OAuth 网络端点。
cargo test -p ai-eval --features live --lib

# 手动：已有登录和主密钥，另设 EVAL_DATABASE_URL 为可丢弃 PG18。
DATABASE_URL=... cargo test -p ai-eval --features live -- --ignored --nocapture
```

三条 ignore + live 测试分别跑文字、真实收据、先追问再以动作回答再写入。
每次调用打印 `first/continue/resume/retry`（首次/运行内续调/暂停后恢复/重试），以及
缓存读取、缓存写入、未缓存输入 token。只打印白名单计量字段；缓存命中不设通过门槛。
在线测试结束清理临时库，真实冒烟/全集结果由 luna.coco 执行、评审并提交 CSV。

构建机还须执行 server/AGENTS.md 的 fmt、clippy、workspace nextest、deny、audit、四个检查脚本。
本切片不修改 OpenAPI。
