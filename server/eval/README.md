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

v2 只用于 `category: display`，并保留与 v1 相同的 `input/setup` 结构。展示样例固定为
`behavior: no_write` 且 `records: []`，因此任何账本写入、追问、确认或非完成终态都会使硬标准失败。
`expect.display.hard` 在执行前声明；当前 20 条的组件选择、事实数值、能力降级、演示标记和安全
约束都是硬标准，句式偏好仍单独体现在 prose 指标中。

每条样例可声明 `tier: core|integration|stress`，省略时为 `core`。`core` 测用户可合理
指定的稳定行为，`integration` 测客户端能力降级等跨层契约，`stress` 测合成歧义或指令冲突。
报告分别汇总各 tier；本切片不改变既有 hard pass 或 CLI 退出规则。

展示评分将人类意图与明确指定的表现形式分开：每条样例声明一个或多个完整 `alternatives`，
每个 alternative 自己拥有读取证据、展示调用、最终 block/fallback 和闭合 typed facts。
评分器逐个完整路径独立评分，只要一个路径全部成立即可通过，绝不把 A 的工具与 B 的 block
拼成一次成功；全部失败时按“硬失败 reason class 最少、再按 fixture 顺序”选最近项报告。
等价的 direct query 与成功的 `query_stats/search_records -> from_call` 共用同一查询语义；
纯文字答案则必须先有匹配且成功的 `query_stats`、`search_records` 或空参数 `query_balance`。
查询无法解析或引用失败时标为 `not_assessable`，单独计数且不会让 hard pass 变绿。
报告只导出 alternative ID、枚举名和有界脱敏规范字段，不导出原始用户/模型文字或工具结果。

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

- `source_calls` 是可选的精确有序 `query_stats` / `search_records` / `query_balance` 前置调用；
  `query_balance` 只允许精确空参数。`calls` 是精确有序展示
  工具调用。评分同时核对工具名和完整参数，额外、重复、错序、错误期间/分组/账户/demo 均失败。
  `calls` 可用 `$call:source-0` 断言 `from_call` 必须引用对应前置调用；`$account:<alias>` 会展开为
  setup 中的真实 UUID。
- `blocks` 是最终持久化 checkpoint 中的精确有序非 Markdown 组件序列；额外或重复组件不会被忽略。
  比较 `metric/metric_group/dataset/time_series/breakdown/category_series/x-jiabu.account_card`
  的服务端事实视图，而不是从生产 mapper 反推期望值。
- `labels` 与 `values_minor` 来自数据集明确写下的虚构事实。金额一律用整数最小货币单位；趋势图
  在协议中使用元时，评分器只做确定性的 ×100 还原。账户卡同时核对真实账户 UUID 与 setup 名称，
  余额则由 `fallback_contains` 核对服务端拥有的 fallback，因为账户卡组件故意不携带余额。
- `facts` 是闭合的 typed fact 集合：aggregate、record、account_balance 或 no_data。纯文字路径必须
  陈述全部事实且不能增加金额/记录、错配标签和值、或同时声称“无数据”和“有记录”。余额文字还须
  匹配脱敏观测中的币种、目标账户和余额；观测与报告不保留原始错误或原始工具结果。
- `client_capabilities` 会在 enqueue 时冻结。受限客户端必须产生声明的降级组件，或在完全不支持
  组件时只保留服务端 Markdown fallback；不支持的组件不得持久化。
- `server_fallback_contains` 只检查由对应展示工具结果映射并实际持久化的服务端 fallback，模型 Markdown
  不能冒充；`fallback_contains` 用于明确允许由最终文字回答满足的 no-data/错误兜底断言。
- 演示组件必须有显式 `source.demo`，标题/fallback 必须带「【演示数据】」；无数据样例不得用
  demo 冒充。`expected_invalid_calls/business_errors` 只用于一条故意触发参数校验并验证文字兜底的样例。
- prose 只检查模型生成的 Markdown block，不把组件自带 fallback 当作模型赘述；Mermaid、连续三行
  字符/ASCII 柱图及超过五个数据行的表格是硬安全约束。`max_sentences` 与
  `forbid_numeric_restatement` 是单独报告、不改变进程退出码的软风格指标。

## 隔离与提供方

每条样例新建一个临时数据库，完整迁移、种子数据、独立用户/空间/会话；默认最多两条并发，可用 `--jobs 1` 顺序复现，`--jobs` 仅接受 1 或 2。
Live 校准先单独完成，再调度样例；每条 core 样例的三票 Judge 仍按原顺序逐票执行。结果始终按语料原顺序汇总，完成先后不改变 CSV 顺序。首次观察到基础设施错误（含结果写入或 worker 错误）后停止派发新样例，等待已开始样例正常收尾后退出 2；此时报告只包含完成的部分，不能当作整套分数。不会主动取消已开始样例，以避免初始化中途取消留下测试库。
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
没有静默 fallback。内置校准通过后，仅对 deterministic hard gate 已通过的 14 条 core display
样例做三次独立 Judge 调用并取 2/3 多数；Mock、integration、stress 及 deterministic 失败均为
零 Judge 调用。Judge transport、超时、缺失 usage 或严格输出 schema 失败均按基础设施错误退出 2。
Judge 仅在原始 `Transport` 错误且尚无任何输出或 usage 时，对同一请求最多重试一次；
两次尝试共享原有每票 120 秒期限，成功票不会重采样，认证/额度/限流/格式错误及部分输出不重试。
基础设施错误只输出闭合 stage/class 标签，不输出底层错误文字。
每票 usage 在 evaluator 进程内捕获以确认调用完整，但不写源库、scratch meter 或 CSV；CSV 只持久化
Judge 模型快照、self-judge、通过/失败票数及闭集布尔/枚举票据，不保存请求、候选文案或自由文本理由。

## CSV 与评分

结果提交到 `server/eval/results/<日期>-<提供方>/`，例如 `2026-10-29-live/`。
每完成一条覆盖写出当前 results/summary，失败后继续跑，最后在 stderr 列出失败 ID。
`hard_pass` 只表示 deterministic 协议/事实/安全门禁，不会被 Judge 结果覆盖；eligible core display
还需 Judge 三票多数通过才算 overall pass。`0` = 全部 overall pass，`1` = 至少一条 deterministic
hard gate 或 Judge 多数失败，`2` = 配置/数据/基础设施错误（包括缺图）。软准确率不设退出门槛，
luna.coco 逐条评审真实失败项后再决定提示词调整。

`results.csv` 每条一行：身份、期望/实际行为、终态、hard/hard_pass、行为/记录检查、
展示 hard/pass、工具序列/组件序列/事实值的正确数与分母、prose 检查、确认前未写入、
金额/日期/分类/工具的正确数及分母和比率、业务错误次数、延迟、成本、失败原因。
展示列还包含声明的可接受 alternative ID 集合和最终选中 ID；core、integration、stress 分层汇总，
integration/stress 的硬失败仍是协议/安全失败，但不会被描述为普通用户的图表选择失败。
eligible core 的 Judge 结果另写 `judge_model`、`judge_self`、pass/fail vote 数及闭集
`judge_votes_json`；未调用 Judge 的行保持空值。Judge fail 会令展示与 overall 失败，但 deterministic
`hard_pass` 仍保留原值，便于分别审计两层。
`calls_json` 为按调用顺序排列的 JSON 数组，各项只有调用种类、缓存读取/写入 token、未缓存输入
token、成本（USD 十进制字符串）、调用延迟与 outcome。未缓存输入沿用现有口径
`input_tokens - cached_input_tokens - cache_write_tokens`，未知为 null。

行为以持久 interrupt 和运行终态判定，不靠模型文字。
含糊日期/信息不足必须真正暂停于 ask_user 且没有任何业务变更；先写后撤仍失败。
确认类必须出现**对应目标和操作**的确认卡，确认前所有实体事件和记录均与基线一致，
确认后完成且目标写入正确。错误暂停、失败或中断不能通过硬标准。

每条新增实体审计事件都纳入观测，非记录业务写入也被识别；实际字段从 SpaceTx 的最终记录读取。
多笔使用确定性最小成本一对一匹配：旧记录绑定目标身份，新增先最大化完整匹配数，再最小化
声明字段差异，固定升序打破平局。种类/操作/账户/用途/退款父身份参与完整匹配；
金额与币种精确匹配，日期按公历日期，分类按真实预置标签身份集合。省略字段不计分。
缺失记录保留在期望分母，额外记录同时增加各准确率分母；重复写入、额外操作不能被忽略。

工具参数合法率覆盖**每个模型投递的工具调用**（包括 journal 提交前被拒绝者）：
评测包装器复用工具 typed/schema 校验与 AskArgs::check，只保留总数和合法数，不留参数正文。
业务校验失败另计，不当作参数 schema 错误。无工具调用的分母为 0，不冒充合法率 100%。

`summary.csv` 是 `metric,value,numerator,denominator`：工具合法率、金额精确率、日期/分类准确率、
展示工具序列/组件序列/事实值准确率、
追问精确率 TP/(TP+FP)、召回率 TP/(TP+FN)、含糊日期子集召回率、nearest-rank P50/P95 延迟、
平均成本、未知成本数、deterministic 硬失败数及追问混淆矩阵计数。确认卡不算追问。
Judge summary 另含 core pass/total、pass/fail/total votes、self-judge 数，以及去重排序的
tested candidate model set 与 ranking/Judge model set。tested set 从全部结果行聚合，包括被 hard gate
拦下而未调用 Judge 的场景；ranking set 只来自实际 judged 行。
比率为 0–1，分母为 0 时 value 留空；成本缺用量或费率也留空。全集任一成本未知则全集均值留空。
临时库沿用 RuntimeMeter 的 PostgreSQL numeric 计费；Mock 使用明确的合成零费率。
延迟排除建库/迁移/setup，包含提交、worker 和即时自动确认。

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
