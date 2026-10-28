# C3 交付说明

本轮实现总览、历史／搜索、手动记账、记录详情／修改／撤销／恢复／退款、冲突处理、账户与拨入计划，以及三栏主框架。聊天为占位，设置仅有账户；不包含空间切换列表、家庭资料或后续切片功能。

**首轮实现验证边界（后续修正见文末）**：本机没有运行 Dart／Flutter、pub get、代码生成、analyze、单元／组件／服务端测试、golden 或负对照。未安装工具、未联网。下面的检查仅为源码与清单静态核对，不能当作 G1／G2／G3 已通过。生成文件、字体／图标生成产物、PNG 和动态验证由 luna.coco 在构建机完成。本轮未修改 docs/、server/、依赖或 schema。

## 文档没写清、我是这么做的

- 标签显示给支出与收入，转账 / 调拨不显示；服务端对所有种类都接受
  `tag_ids`。退款也不展示标签选择。新建无标签选择的种类明确提交空数组；
  编辑已有此类记录时省略 `tag_ids`，保留原有标签，不做隐式清理。

### G0 后确认的 11 项决定

1. 手动入口按分支已定稿的 C22／设计规范 4.21：总览和历史右下角，距右侧／导航上沿各 16，主色胶囊、白边、贴纸阴影、0°，最小高 52，读屏“手动记一笔”；聊天不常驻。使用自定义 FloatingActionButtonLocation 避免叠加 Scaffold 默认边距。历史筛选不传给新表单。
2. 币种属于空间。账户页只读展示空间币种；AmountText 扩展币种符号、分组／小数分隔符、零位小数，金额解析和显示没有浮点金额往返。CNY、HKD、USD、EUR、GBP 两位，JPY 零位。
3. 归档账户因旧账修改／撤销再次有余额时，显示余额和明确服务端限制提示，不提供必然失败的转账按钮。登记为下述服务端缺口，不阻塞本切片。
4. 不做“停机跨月补拨”客户端集成场景，不修改临时库的计划到期日。真实拨入仅走“先启用每月 1 日计划，再持续启用改为今天日号”的公开工具路径。多币种只验证一个 CNY 空间和一个 JPY 空间。server-it.sh 在 UTC／Asia/Shanghai 任一午夜前不足 10 分钟时等待跨日，然后记录空间日期与时区。
5. PNG 数量采用收敛矩阵：每状态 zh/pine/360/100 与 zh/pine/430/200；每界面选英文代表；indigo 仅主框架和已记录卡。布局／几何／语义仍覆盖两语言×两点缀色×两宽×两字号。完整 PNG 清单见 test/features/c3_golden_test.dart。
6. 当天支出合计为有效支出减有效退款；退款按退款发生日计入。转账、调拨、计划拨入不计消费，不重复统计真实／用途两条关联。
7. 搜索匹配备注，以及本空间类型／账户／标签生成的标题；不增加 title 列。预置标签和类型用当前 locale 的 ARB 名称。数据从带 space_id 的本机 DAO 查询获得，再对该空间的不可变快照做筛选、分组和文本匹配，不调用搜索 HTTP 接口。
8. 标签仅有选择和内联新建；没有独立管理页。删除但仍被旧记录引用的标签可以保留或移除，不能重新选入。
9. “先撤销退款再撤销支出”的依赖统一由 tool_dependencies.dart 的 refundVoidDependencies 构造。即使退款已在本机乐观变为撤销，支出撤销仍等待退款操作确认。保留可执行负对照。
10. 归档后，账户状态立即驱动隐藏记账选项／计划入口；账户归档所导致的计划停用通过后续 pull 校正，不给计划制造没有 outbox 的 pending 行。仓库和组件测试分别覆盖隐藏与 pull 校正。
11. schemaVersion 保持 1，没有增加表、列、索引或迁移。复用 C2 的 records/accounts/allocation_plans/tags/space_members/entity_events/outbox/entity_conflicts/blobs_local。

### 其余最小实现选择

- C3 的跨页面记录组件和生成式 ViewModel 放在 shared/ledger，feature 的 view 只做路由入口；共用 LedgerSnapshot 观察和表单状态，避免 feature 互相导入。Repository 的领域接口在 domain，具体实现集中在 data/repositories/ledger_repository.dart。
- 每个空间读取一致性快照；LocalStore.watchLedgerChanges 观察相关表和提交后的 change_revision，不能仅靠 outbox 数量变化判断“失败”或“冲突”更新。跨连接刷新继续沿用 C2。
- 历史查询只读取当前空间；成员、账户、标签选项也来自同一空间快照。账户筛选包含转入／调入端，日期区间包含首尾；已撤销记录保留在历史中但不计支出。历史按记录自身标签筛选（同 search_records），日合计为当前筛选结果的净额，不另调用 query_stats 的父支出标签统计。当前规模采用本机全量空间快照，没有另加分页或全文索引。
- 近期变化采用近期记录。家庭资料摘要只有 C6 TODO，不展示假卡。
- 负余额可以预填补足方向和金额；用途账户存在有效备用金时预填备用金。没有可用另一端时，用户先在账户页建账户，不自动造账户或调整起始余额。
- 本机待上传修改单独标记，不伪造服务端审计事件。entity_events 尚未同步时明确提示；事件按时间／ID 排序，显示字段差异、操作人、操作时 API key 名称。账户／标签名称用当前空间目录解析历史 ID；移除附件只显示数量，不生成旧图链接。
- key 标注来自创建事件的 via_api_key_name；事件还没同步时不猜测名称。已退出成员仍显示其空间显示名与退出标注。
- 原图先查当前空间 ledger blob 元数据及实际文件；缺失则占位。点击时直接复用 C2 downloadBlob，返回前检查请求 fence；没有下载管理、后台下载、图片上传或持久化下载的新状态机。
- 卡片按 9.3 优先级呈现；失败另叠加，避免被撤销外观遮住。versionAtReply 参数与“后来改过”分支预留给 C5，C3 已有组件测试。
- 新计划／离线修改不自行预生成 allocation 记录，也不按手机时区猜 next_run_on；显示待服务器确认，已有计划保留上次确认日期。持续启用的计划修改可能立即补拨，界面明确说明；首次／重新启用严格从下一个拨入日开始。
- 手动日期／起始日期使用本地化日期选择器；内部保存 ISO 日历日期。首次默认取手机当天，用户可选择发生日期；计划执行始终由服务端空间时区决定。
- 不增加依赖；使用已有 intl、Riverpod、freezed、go_router、drift 和 jiabu_design。所有新增构造器采用传统 ClassName(...) 写法。

## 余额与真实服务端对应

纯函数：app/lib/domain/ledger_balance.dart。

| 规则 | 只读核对的服务端来源 |
|---|---|
| 起始余额直接加入；opening_on 不截断历史 | server/crates/db/src/ledger/queries.rs:5 |
| 真实账户收入／退款加，支出／转出减，转入加 | queries.rs:7–9 |
| 用途账户拨入／退款加，支出／调出减，调入加 | queries.rs:10–12 |
| 仅同空间 active 记录，包含归档账户 | queries.rs:13–15 |
| 精确中间累加，最终绝对值 ≤ 9,007,199,254,740,991 | queries.rs:241–255 |
| 日消费按支出减退款，退款按发生日 | queries.rs:170–205 |
| 币种精度 | server/crates/domain/src/money.rs:18 起 |
| 首次／持续启用／月末规则 | server/crates/domain/src/allocation.rs:4–45 |
| 先补旧计划、可能即时按新计划拨入、停用不补拨 | server/crates/db/src/ledger/writes.rs:574–610 |
| 空间时区、按月 UUIDv5 去重、逐月补拨 | db/src/ledger/mod.rs:198；db/src/ledger/allocation.rs:81–110 |

余额从服务器版本的 records 行推导，绝不从 entity_conflicts.mine_json 取值。冲突捕获／解决／后续拉取直接复用 C2 ConflictService，不另写状态机。

## 写入与工具

创建记录（五种手工类型）、更新、撤销、恢复分别用 create_record、update_record、void_record、restore_record。退款是 create_record(kind=refund)，不是第五码表单选项。账户使用 create_account、update_account、archive_account；计划使用 set_allocation_plan；内联标签使用 create_tag。

全部经 LocalMutationsRepository.enqueueTool 写 kind=tool、payload={tool,args}，乐观行与 outbox 在同一 LocalStore 事务提交。expected_version 由 C2 上传时绑定；通知继续经过 afterCommit。失败保留逐条错误和重试；has_refunds、refund_exceeds_original、parent_voided 等映射为双语提示。

冲突普通两选一分别调用 resolveWithServer／resolveWithMine。服务器已撤销时只提供 acknowledgeVoided／restoreAndApplyMine；后者由 C2 生成 restore_record→update_record。保留 explicit_restore_required 门禁以及 unarchive_not_supported／restore_tag_not_supported 的明确失败。

## 测试与 golden

共享夹具：app/test/fixtures/ledger/c3_ledger.json；domain 单测与真实工具 API 集成测试读取同一份账户／操作／期望余额。计划拨入经真实公开工具产生，不插入测试记录。

新增服务端场景位于现有 app/test/server/local_sync_server_test.dart，与原冲突场景共用同一进程／缓存会话，避免重新登录触发限流。保留默认 server 标签跳过策略，由 tool/server-it.sh 使用 --tags server --run-skipped 执行。

- 共享夹具与服务端／客户端余额逐项一致。
- CNY＋JPY 两个空间独立精度与数据。
- 空空间离线建四个账户、计划、四类记录，恢复后真实上传并比较余额。
- 逐条服务端拒绝超额退款、有退款支出的撤销、同端转账和非零归档；使用不相交实体，避免一条失败阻挡另一条验证。
- 持续启用改今天日号，真实生成 allocation；撤销／恢复及余额一致。
- 原有 server_conflict_server_mine_and_explicit_restore_paths 覆盖真实两客户端 409／撤销优先；新增组件测试验证对应按钮和两版展示。

**golden 总数：113 张。** 49 状态×2＋13 英文代表＋2 indigo；所有路径逐条写在 app/test/features/c3_golden_test.dart。既有 catalog_golden_test.dart 跳过 C3，避免重复出 PNG。catalog 本身仍注册全部 C3 状态；布局测试不减少矩阵。

app/test/features/c3_layout_test.dart 对 49 状态跑完整 16 组合，检查异常、卡片宽度、手动入口位置／点击尺寸、我圆章尺寸和语义。其他新增测试覆盖 domain 校验／日历、真实 DAO 双空间、事务回滚、退款撤销顺序、审计／图片数据、计划归档校正、ViewModel 命令、卡片状态、冲突选择和从零手动建账交互。

## 负对照清单

机器清单：tool/c3-negative-controls.json。11 项均有仓库相对文件、唯一 find/find_regex、replace、精确测试名和命令。构建机先跑原版，再逐条临时改坏，要求断言失败并恢复；编译失败不算成功。本机未执行任何负对照。

1. real_outflow_sign：真实账户支出／转出符号。
2. purpose_outflow_sign：用途账户支出／调出符号。
3. voided_records_excluded：撤销记录不计余额。
4. safe_aggregate_range：精确聚合范围。
5. conflict_uses_server_balance：冲突前余额按服务器版本。
6. explicit_restore_only：普通“用我的”不能恢复服务器撤销。
7. history_current_space_only：历史不返回其他空间记录。
8. refund_remaining_limit：退款不可超过可退余额。
9. transfer_distinct_endpoints：转账两端不能相同。
10. reallocation_distinct_endpoints：调拨两端不能相同。
11. refund_void_before_expense：退款撤销确认先于支出撤销。

## 服务端缺口与接口差异

- 归档账户因旧账更正再次出现余额：ledger/writes.rs:345 起的新建记录检查禁止使用归档账户；当前工具没有 unarchive_account。因此无法完成从该账户新转账／调拨清零。客户端展示真实余额与限制，不给必然失败按钮；已按用户决定作为独立服务端事项登记。
- 持续启用的拨入计划修改规则比技术文档“今天之后／下一次生效”的概括更具体，存在立即拨入。界面与测试以 writes.rs／domain allocation.rs 为准。
- create_account 没有 currency；货币来自空间，不能让账户页发送该参数。
- C2 交付说明的部分历史缺口已过时：当前 OpenAPI 有资料工具，Cargo.lock 已包含此前列出的图片依赖；本切片不据旧说明改服务端或放宽 --locked。构建机仍需验证当前 server ref。

## 构建机步骤与最可能编译失败的地方

先生成，再格式化／analyze；本机没有手写这些输出：

1. client 根按现有锁定依赖运行 flutter pub get；运行 dart run tool/icons/gen_icons.dart（新增 uiKey 源路径），在 app 运行 flutter gen-l10n 和 dart run build_runner build --delete-conflicting-outputs。
2. 按既有字体流程，用缓存原字体运行 tool/fonts/subset.py --offline --cache-dir <构建机缓存目录>，生成包含新增 ARB 的手写／Serif 子集。没有修改字体二进制。
3. dart format、flutter analyze --fatal-infos、dart run tool/check_rules.dart；分别运行 workspace／app／jiabu_design 测试。
4. 运行上述真实服务端脚本，再执行 11 项负对照并恢复。
5. 按 tool/golden.sh 既有固定镜像流程生成／审阅／提交 113 张 C3 PNG，附 visual-change 标注；新的日期／随机数据均固定在 catalog preview 中。

最需要构建机核对：

- 新 ARB getter、uiKey 和 provider/freezed part 在生成前必然缺失；这不是可跳过的步骤。
- Riverpod 生成式 family 的覆盖、泛型 command/submit 返回类型、provider 的生命周期和首次登录初始化顺序。
- freezed 对包含领域快照／HistoryFilter 的 UiState 生成，以及严格 lint／格式。C3 将共用 UI 状态放 shared，避免 feature 跨引用。
- PaperSheet 的固定 footer／Flexible 约束及键盘避让；360／200% 下的卡片、筛选和金额换行。
- 带多表 readsFrom 的 drift watch、真实数据库更改通知；schema 本身没有变化。
- 真实服务端执行顺序、计划即时生成记录的 pull、JNI／图片解码平台差异。测试尚未动态运行，不能宣称已通过。

## 本机静态检查

已做：git diff --check、bash -n tool/server-it.sh、JSON／两份 ARB 键集解析、全部负对照锚点及测试名存在性、113 个 PNG 路径唯一性、手写导入／token／l10n 引用检查，以及 Dart 字符串／注释之外的括号配对检查和源码通读。它们不等价于 Dart parser、formatter、analyze 或测试。

## 改动文件清单

以下为本轮源码／测试／清单文件；C3-DELIVERY.md 为本文件。生成文件与 PNG 不在此清单：

```text
client/C3-DELIVERY.md
client/app/lib/app/ledger_providers.dart
client/app/lib/app/main_shell.dart
client/app/lib/data/repositories/ledger_repository.dart
client/app/lib/domain/allocation_calendar.dart
client/app/lib/domain/history_filter.dart
client/app/lib/domain/ledger.dart
client/app/lib/domain/ledger_balance.dart
client/app/lib/domain/ledger_validation.dart
client/app/lib/domain/money.dart
client/app/lib/domain/record_presentation.dart
client/app/lib/features/catalog/c3_cases.dart
client/app/lib/features/chat/view/chat_screen.dart
client/app/lib/features/history/view/history_screen.dart
client/app/lib/features/overview/view/overview_screen.dart
client/app/lib/features/settings/view/settings_screen.dart
client/app/lib/shared/ledger/ledger_forms.dart
client/app/lib/shared/ledger/ledger_labels.dart
client/app/lib/shared/ledger/ledger_pages.dart
client/app/lib/shared/ledger/ledger_ui_state.dart
client/app/lib/shared/ledger/ledger_view_model.dart
client/app/lib/shared/ledger/main_frame.dart
client/app/lib/shared/ledger/record_card.dart
client/app/lib/shared/ledger/record_details.dart
client/app/test/data/c3_ledger_repository_test.dart
client/app/test/domain/history_filter_test.dart
client/app/test/domain/ledger_balance_test.dart
client/app/test/domain/ledger_validation_test.dart
client/app/test/features/c3_golden_test.dart
client/app/test/features/c3_interaction_test.dart
client/app/test/features/c3_layout_test.dart
client/app/test/features/ledger_view_model_test.dart
client/app/test/features/manual_setup_flow_test.dart
client/app/test/fixtures/ledger/c3_ledger.json
client/app/test/shared/record_card_test.dart
client/app/test/support/c3_harness.dart
client/app/test/support/ledger_fake.dart
client/app/test/support/ledger_fixture.dart
client/packages/jiabu_design/lib/src/components/ledger_controls.dart
client/packages/jiabu_design/lib/src/tokens/ledger_metrics.dart
client/packages/jiabu_design/test/ledger_controls_test.dart
client/tool/c3-negative-controls.json
client/app/lib/app/router.dart
client/app/lib/app/runtime.dart
client/app/lib/data/db/daos/local_store.dart
client/app/lib/data/sync/tool_dependencies.dart
client/app/lib/features/auth/view/auth_shell.dart
client/app/lib/features/catalog/catalog_cases.dart
client/app/lib/l10n/app_en.arb
client/app/lib/l10n/app_zh.arb
client/app/test/catalog_golden_test.dart
client/app/test/server/local_sync_server_test.dart
client/packages/jiabu_design/lib/jiabu_design.dart
client/packages/jiabu_design/lib/src/components/amount_text.dart
client/packages/jiabu_design/lib/src/components/paper_card.dart
client/packages/jiabu_design/lib/src/components/paper_sheet.dart
client/tool/icons/icons.json
client/tool/server-it.sh
```

## 构建机第一轮 analyze 反馈修正

所提供的 analyze1.txt 实际末行是 865 issues found，其中 768 条为长行；
本轮按该文件的全部诊断逐条核对，而非仅按任务消息中的 170 条计数。

- uiKey 在 icons.json 中替换为 Lucide key-round 的完整外轮廓和实心圆点，
  viewport 24×24、category ui、strokeWidth 1.85，沿用已登记的 ISC 许可。
  未修改 jiabu_icons.g.dart。gen_icons.dart:231 明确生成 static const，
  因此记录卡和历史行的 const ExcludeSemantics／JiabuIcon 保留；
  undefined_getter 与其派生的 const 错误需先重新生成图标才能消失。
- 拆分多变量声明；排序 import／export；给语句级 if／for 补大括号；
  异步事务显式 await 返回的仓库 Future；真正不等待的 UI 调用使用 unawaited。
- 导航 select 改为 selectedIndex setter，并更新调用方；直接可空集合元素改为
  ?status／?action；列表条件表达式改 if 元素；child 参数移至构造调用最后。
- 回滚测试使用 expectLater(..., throwsStateError)，不捕获 Error；
  exists 元数据检查改同步版本，图片字节读取仍异步；移除冗余参数、括号、
  import，补 const，并按诊断整理 cascade。没有新增 ignore 或禁用 lint。
- 拆分长注释／字面量，提取成员名、退款标签、审计字段变化的格式化辅助函数；
  诊断涉及的 43 个 Dart 文件当前均无超过 80 字符的行。
- 更新 c3-negative-controls.json 的精确 find 与格式容忍正则：补大括号后
  仍各有唯一锚点，历史隔离负对照只替换空间比较表达式，保持同样故意改坏效果。

本机发现已有 ARM Dart 及缓存 dart_style 3.1.7。普通 dart format 因 CLI 尝试
写入只读用户目录的分析配置而失败；随后直接通过 VM 调用缓存 formatter，
使用临时 package 映射离线格式化手写源文件，未安装或下载任何工具。
formatter 成功解析并格式化全部 43 个文件；再次运行
--set-exit-if-changed 返回 0（43 files, 0 changed）。临时映射已删除，不进入交付。
项目 very_good_analysis 依赖未在本机缓存，formatter 提示 include 解析警告，
因此这些结果不等于构建机完整 format／analyze 通过。

本轮已运行静态 check_rules（通过）、git diff --check、JSON／ARB／SVG 源清单
检查和 11 项负对照锚点唯一性检查。未编译 App、未执行测试、负对照或 golden，
未运行图标、l10n、build_runner 生成器，也未修改任何生成文件。

构建机下一步：重新运行图标生成；按既有流程重跑 build_runner 以核对 provider
生成一致性，再跑 format／flutter analyze --fatal-infos／check_rules。
仍拿不准的是构建机完整依赖下是否还有派生 lint；本机不宣称 analyze 已清零。
本轮没有修改 schema、依赖、docs/ 或 server/，golden 清单仍为 113 张。

本轮修正文件（43 个 Dart 源文件、2 个 JSON 与本交付说明）：

```text
client/app/lib/app/ledger_providers.dart
client/app/lib/app/main_shell.dart
client/app/lib/app/router.dart
client/app/lib/app/runtime.dart
client/app/lib/data/db/daos/local_store.dart
client/app/lib/data/repositories/ledger_repository.dart
client/app/lib/domain/allocation_calendar.dart
client/app/lib/domain/history_filter.dart
client/app/lib/domain/ledger.dart
client/app/lib/domain/ledger_balance.dart
client/app/lib/domain/ledger_validation.dart
client/app/lib/domain/money.dart
client/app/lib/domain/record_presentation.dart
client/app/lib/features/catalog/c3_cases.dart
client/app/lib/features/catalog/catalog_cases.dart
client/app/lib/shared/ledger/ledger_forms.dart
client/app/lib/shared/ledger/ledger_labels.dart
client/app/lib/shared/ledger/ledger_pages.dart
client/app/lib/shared/ledger/ledger_view_model.dart
client/app/lib/shared/ledger/main_frame.dart
client/app/lib/shared/ledger/record_card.dart
client/app/lib/shared/ledger/record_details.dart
client/app/test/catalog_golden_test.dart
client/app/test/data/c3_ledger_repository_test.dart
client/app/test/domain/history_filter_test.dart
client/app/test/domain/ledger_balance_test.dart
client/app/test/domain/ledger_validation_test.dart
client/app/test/features/c3_golden_test.dart
client/app/test/features/c3_interaction_test.dart
client/app/test/features/c3_layout_test.dart
client/app/test/features/ledger_view_model_test.dart
client/app/test/features/manual_setup_flow_test.dart
client/app/test/server/local_sync_server_test.dart
client/app/test/shared/record_card_test.dart
client/app/test/support/c3_harness.dart
client/app/test/support/ledger_fake.dart
client/app/test/support/ledger_fixture.dart
client/packages/jiabu_design/lib/jiabu_design.dart
client/packages/jiabu_design/lib/src/components/amount_text.dart
client/packages/jiabu_design/lib/src/components/ledger_controls.dart
client/packages/jiabu_design/lib/src/components/paper_card.dart
client/packages/jiabu_design/lib/src/components/paper_sheet.dart
client/packages/jiabu_design/test/ledger_controls_test.dart
client/tool/icons/icons.json
client/tool/c3-negative-controls.json
client/C3-DELIVERY.md
```

### 构建机第二轮测试反馈修正

本轮仅修复测试暴露的问题，保留构建机同步的图标生成文件与
`c3_cases.dart` 的 const 修正。不处理字体子集、113 张缺失的 C3 golden
PNG 或新增 uiKey 导致的 4 张图标 sheet 像素差。

- **语义句柄**：三处原有 `addTearDown` 晚于 Flutter 的测试体结束检查。
  改为测试体内 `try/finally` 释放，包括断言失败的路径；布局测试的异步
  无障碍 matcher 改用 `await expectLater`，确保检查完成才释放句柄。
  没有关掉语义检查或缩减完整布局矩阵。
- **纸面行**：带背景色的纸面隔开了 ListTile 与最近的 Material，导致
  Flutter 的 ink 可见性诊断。新增设计包 `PaperRow`，统一提供
  `Material(type: MaterialType.transparency)`，用于全部 4 处 ListTile
  和 2 处 SwitchListTile。catalog 沿用现有设置、待处理记录、拨入计划
  状态展示这些组件，不新增 golden 状态，C3 总数仍为 113 张。
  新增 6 条设计包回归测试：卡片 / 弹层 / 便利贴 × 普通行 / 开关行，
  验证无诊断、最近的 Material 为透明材质、点击仍生效。
- **手动建账超时**：原测试在 widget 假时钟区调用 `SyncHarness.create`，
  该工厂构造数据库后还会等待真实的临时目录 I/O；超时前初始化无法完成
  时，后续关闭注册也未执行，是数据库重复创建警告的一个直接风险。
  改用测试体外的 `setUp` 创建、`tearDown` 关闭，每条测试只有一个实例。
  测试体用 `finally` 先卸载 ProviderScope / watch 订阅，再关闭数据库。
  直接读库和退款夹具写入放进 `tester.runAsync`；UI 交互用固定 12 轮
  泵帧（每轮真实事件循环让步 10ms、虚拟泵帧 50ms），不等待全局静止。
  `pumpC3` 增加可选 `settle: false`，仅这两条真实数据库流程使用；
  其余测试保留原行为。两条均设置 2 分钟 timeout。SyncHarness 只构造
  SyncEngine，没有启动后台同步，无需禁用业务同步或漂移监听。
  原日志没有给出超时点的异步栈，最终是否完全消除等待仍以构建机重跑为准。
- **图标测试**：数量期望 60 → 61，显式检查 uiKey 的 ui 分类、1.85
  strokeWidth、来源含 Lucide ISC，且登记的许可文件确实含 ISC。
  保留完整生成结果与已提交生成文件的相等检查。

本轮改动文件（相对仓库根）：

- `client/app/lib/shared/ledger/ledger_forms.dart`
- `client/app/lib/shared/ledger/ledger_pages.dart`
- `client/app/lib/features/catalog/catalog_cases.dart`
- `client/app/test/features/c3_layout_test.dart`
- `client/app/test/features/manual_setup_flow_test.dart`
- `client/app/test/shared/record_card_test.dart`
- `client/app/test/support/c3_harness.dart`
- `client/packages/jiabu_design/lib/src/components/ledger_controls.dart`
- `client/packages/jiabu_design/test/ledger_controls_test.dart`
- `client/test/gen_icons_test.dart`
- `client/C3-DELIVERY.md`

验证边界：仅离线语法格式检查、`check_rules` 和静态核对；未在本机
编译、运行 Flutter 测试或完整 analyze。未改生成文件、依赖、schema、
负对照规则、docs、server、PNG。下一轮应先重跑上述相关测试及 analyze，
再跑完整测试矩阵；golden 和字体按构建机安排处理。


### 构建机第三轮 golden 视觉反馈修正

承接构建机 analyze 0、workspace 50 / app 2096（不含 golden）/
jiabu_design 49 全过的结果，以及构建机已提交的 113 张 C3 图片。本轮
只改源码、ARB、测试与交付说明；不改字体、PNG、生成代码、docs 或 server。
新增 ARB 键须在构建机重新 gen-l10n；未手写生成文件。

1. **记录卡**：新增设计组件 `DottedValueRow`，最小高沿用
   `valueRowMinHeight`，以 alphabetic baseline 对齐标签、点线和值。
   普通支出显示真实账户、以用途名称为左键的当前余额、标签三行；转账保留
   两端账户，调拨保留两端用途余额。负值红色，标签主色。操作文字主色、
   最小视觉高度 44；权限不足或该记录正在 sending 时禁用。catalog 先前
   没传回调，导致已记录预览的可用操作呈灰色；现在显式传惰性的预览回调。
   冲突只保留一处“有冲突”状态，入口改为“去处理”。
2. **详情**：退款独占上方一行，底部撤销描边 / 编辑主色各占一半，标准
   字号最小高 48（大字号允许随内容长高）。检查未发现叠绘两层文字；
   编辑仍只有一个 Text，明确使用 Sans token、空 shadows、无 decoration。
3. **负余额**：去掉误用的归档引导文案，标题含账户名与当前负余额，红色
   粗体；说明 Sans 13。新增 `BalanceNoteButton`：整宽、最小高 46、
   白色实线外圈和内虚线；便利贴补上现有 doodleClip 的灰色回形针装饰。
   有有效备用金时预填 reallocation 来源 / 去向 / 差额，按钮金额去掉纯
   `.00`（有小数仍保留），显示“从备用金调拨 ¥12”；没有备用金时仅预填
   转入用途，显示“去调拨”，金额和来源留空。真实资金账户仍只能转账补足，
   不会错误地跨类型调拨。已归档账户的服务端缺口处理继续保持。
4. **标签**：标签行末尾 `+ 新建` ActionChip 才展开输入；展开后用描边
   保存按钮提交，不再常驻输入框或浮着另一条“新建标签”文字按钮。
5. **拨入计划**：一句按所填日号更新的月度规则，加一行 Sans 12 / ink-3
   的首次设置说明。去掉界面的 IANA 时区和长篇细则；仍保留待上传、已确认
   下一次日期等实际状态信息，服务端时间规则未改。
6. **间距与账户卡**：总览所有区块标题统一使用 sectionTop 30 /
   sectionBottom 12。账户卡名称与 Caveat balanceAmount 34 同行，金额
   小于记录卡 40。账户管理新建按钮后加 12、各卡间加 cardGap、归档标题
   上下加区块间距。
7. **历史**：自绘行代替 ListTile 的默认标题 / 副标题排法；金额在标题
   同行右对齐，下方日期 / 时间用 date token。记录只有 occurred_on 日精度
   时按 locale 显示月日，不从 created_at 编造消费时刻；若有带时间的值则
   格式化 Hm。成员、状态、API key 读屏信息保留。
8. **冲突**：两个版本卡各加上下与左右留白，让阴影在滚动视口内保留空间，
   同时避免下一张纸卡盖住上一张底部阴影。
9. **真实路由**：已核对 `app/router.dart` 的 `/overview` →
   `OverviewScreen`、`/history` → `HistoryScreen`，它们分别通过
   `LedgerRoutePage` 渲染真实总览和历史。shell_chat / shell_overview /
   shell_history 的 golden 刻意使用占位内容，只测框架、导航和入口几何；
   实际页面另由 overview_* / history_* 状态覆盖。本轮无需改路由。

新增自动化断言：记录卡键值行、可用主色按钮、只读 / sending 禁用、冲突
状态不重复；详情按钮等宽同高与退款位置；标签按需展开；有 / 无备用金的
预填；拨入说明与时区隐藏；历史金额位置；点线行基线与负值颜色。
既有完整无溢出 / 语义矩阵保持。新设计组件直接进入现有记录卡和负余额
catalog 状态，不额外增加 golden 状态。

#### 本轮改动文件

- `client/app/lib/shared/ledger/record_card.dart`
- `client/app/lib/shared/ledger/record_details.dart`
- `client/app/lib/shared/ledger/ledger_pages.dart`
- `client/app/lib/shared/ledger/ledger_forms.dart`
- `client/app/lib/shared/ledger/ledger_labels.dart`
- `client/app/lib/features/catalog/c3_cases.dart`
- `client/packages/jiabu_design/lib/src/components/ledger_controls.dart`
- `client/packages/jiabu_design/lib/src/tokens/ledger_metrics.dart`
- `client/app/lib/l10n/app_zh.arb`
- `client/app/lib/l10n/app_en.arb`
- `client/app/test/shared/record_card_test.dart`
- `client/app/test/features/c3_interaction_test.dart`
- `client/packages/jiabu_design/test/ledger_controls_test.dart`
- `client/C3-DELIVERY.md`

#### 应重录的 golden

总 manifest 仍为 113 张。本轮受影响 36 个状态、83 张 PNG：每个状态
两张中文，加既有的 10 张英文代表及 1 张 indigo 已记录卡。

- `overview_empty`, `overview_accounts`, `overview_negative`, `overview_pending`, `overview_failure`, `overview_conflict`
- `history_grouped`, `history_search`, `history_filters`
- `card_recorded`, `card_pending`, `card_failed`, `card_voided`, `card_conflict`, `card_changed`, `card_api_key`, `card_left`
- `details`, `details_image`, `details_audit`
- `edit`, `manual_expense`, `manual_income`, `manual_transfer`, `manual_reallocation`, `manual_invalid`, `refund`, `refund_limit`
- `conflict`, `conflict_voided`
- `accounts_empty`, `accounts`
- `plan_new`, `plan_enabled`, `plan_disabled`, `plan_pending`

额外代表：英文 overview_accounts / history_grouped / card_recorded /
details_audit / edit / conflict / manual_expense / refund / accounts /
plan_enabled；indigo card_recorded。对应文件名与完整路径沿用
`app/test/features/c3_golden_test.dart` 的既有 manifest。

其余 30 张（shell、settings、history_empty、card_denied / card_loading、
账户新建 / 改名、归档引导等）无需因本轮改动重录。

本机仅离线语法格式检查与 check_rules；未运行完整 analyze、Flutter 测试、
生成代码或重录 golden。字体子集继续由构建机处理。


### 构建机第四轮：账户两端与标签范围

承接构建机 analyze / 规则 0、workspace 50、app 2106、jiabu_design 50
全过、113 张 golden 已重录、11 条负对照均由断言捕获的反馈。
真实服务端集成测试仍在构建机运行，本轮不预先声明其通过。

- 转账的转入真实账户、调拨的转入用途账户过滤当前转出方。改选转出方若
  撞上已选转入方，ViewModel 在同一次状态更新中清空转入方；新建和编辑
  共用此规则。保留 domain 的 `same_endpoints` 校验与对应负对照。
- 标签仅支出 / 收入可见，包含选择与内联新建。新建转账 / 调拨时即使
  initial 带入旧标签也提交空 `tag_ids`；编辑时不提交该字段，旧标签保留。
  退款同样不展示标签，按新建空数组 / 编辑保留处理；服务端仍允许所有
  种类使用该字段。上述取舍已追加到“文档没写清、我是这么做的”。
- 新增 12 条组件测试：转账 / 调拨 × 新建 / 编辑，检查选 A 后转入列表
  无 A、再选 B 后原转入 B 被清空；四种手动类型 × 新建 / 编辑，检查
  标签区显隐，并在点击保存后核对 repository 实际收到的 tag_ids。
  Fake repository 增加提交参数捕获，不改变模拟的写入结果。

本轮修改文件：

- `client/app/lib/shared/ledger/ledger_forms.dart`
- `client/app/lib/shared/ledger/ledger_view_model.dart`
- `client/app/test/features/c3_interaction_test.dart`
- `client/app/test/support/ledger_fake.dart`
- `client/C3-DELIVERY.md`

受影响 golden：`manual_transfer`、`manual_reallocation`、`refund`、
`refund_limit`，每个既有两张中文，另加 `refund` 的英文代表，共 9 张。
现有 `edit` 预览为支出，因此 PNG 不变；转账 / 调拨编辑由组件测试覆盖。
总 manifest 仍为 113 张，本轮不改 PNG、ARB、生成文件或服务端代码。
本机只做离线格式 / 规则 / 锚点检查，动态测试由构建机跑。
