# C5 聊天交付说明

构建机已验证（Flutter 3.47.8，ChatWeave 固定 ab5cabb；本段验证数据取自此前固定的 f11bd4f，升级后 golden 已重跑）：format、`flutter analyze --fatal-infos`、check_rules 0 问题；app 非 golden 测试 3130/3130；固定镜像 golden 全过（含 164 张新 C5 PNG，已人工看图：基础与 430×200% 两组联系表）；11 项负对照全部以断言失败捕获。**未运行**真实服务端集成 `server-it.sh`：master 尚无 loopback 假上游入口（Howard 的独立服务端 PR），合并后补跑。

没有修改 `server/`、`docs/` 或 ChatWeave 库。没有手写 `*.g.dart`、`*.freezed.dart`、drift schema/helper、lockfile、字体或 PNG。没有提交任何真实数据或凭据。

## 实现

- 三个 ChatWeave 接口、权威刷新、持续生成中的节流检查点、独立动作意图与上传回执。
- drift v1→v2；`chat_entries` 加 message_json/rev/last_seq/authoritative；本地 `chat_client_states` 保存草稿、停止标记、动作、回执与手动接管状态。DAO 单一事务入口落实同步替换规则。
- chat_send/chat_action/chat_retry 独立 HTTP 上传；保留原有整轮和条目租约、attempts、join_epoch/activation fence、同实体顺序和 blob 依赖。请求前、响应落库前均检查 fence。
- 聊天替换 C3 占位；用户便利贴、七种块、额外 comparison/status 降级兼容、过程条、照片、锁定/回答输入栏、停止、重试、恢复。
- 记录卡只解析 recordId/versionAtReply，watch C3 本机投影；编辑、撤销、恢复、失败重试沿用 C3 工具队列。资料卡不注册。
- AI degraded 提示、C3 手动记账入口、原消息手动接管、空账户空间的对话设置入口。
- 新固定文案进两份 ARB；库固定标签通过 resolver 桥接 ARB。消息、问题、表单标签等服务端内容保持原样。
- 聊天错误使用现有 FileLogSink 的 SafeLogEvent 白名单；不记录原话、动作 payload、照片、凭据或异常正文。

## 文档没写清、我是这么做的

### G0 后确认的决定

1. 假上游入口由 Howard 在独立服务端 PR 实现，本切片不改 server。admin 与 server 均设 `JIABU_AI_ALLOW_LOOPBACK_ENDPOINT=1`；仅允许 HTTP loopback base；Responses 为 `{base}/v1/responses`，OAuth 刷新为 `{base}/oauth/token`。脚本先起假上游、写 0600 合成凭据，再配置 provider/model/routes，最后起 server。不支持时明确失败，输出“服务端尚不支持 loopback 测试端点”，不跳过、不调用官方服务。
2. app 两个包均固定 git URL/ref/path；workspace `dependency_overrides.chatweave_core` 固定相同 git 来源，解决库内部 hosted 依赖来源冲突。root/app 的 pubspec_overrides.yaml 均不入库。本机覆盖由 Howard 在构建机设置。
3. schemaVersion 从 1 升到 2，增加 chat_client_states；替换规则集中在 DAO 事务入口。持久化同步 rev≥1 总替换；rev0 必须游标不倒退，且不能覆盖最终版本；临时写不能覆盖同步确认版本。
4. 过程条用 messageFrameBuilder 适配；结构化块用 BlockRegistry.override。沿用列表传入的 block keys 和 resize 回调，几何测试是硬检查。
5. 动作结果先持久化回执，再用原意图协调。ActionTransport 发现回执直接返回，不再发送业务请求；覆盖超时、重启、后台上传。
6. AI 不可用依据 degraded 机器状态。重启后无法证明 waiting_ai 时显示“待 AI 处理”，不解析双语 label。active-messages 未暴露 waiting_ai 原因列为服务端缺口。
7. 手动接管先取消原 AI 再开 C3 表单；取消表单不恢复 AI。已上传且离线时不能直接手工保存。不从原话抽取金额、账户、用途等字段。
8. 首次设置复用普通对话、ask_user 与账户/计划工具；空账户空间显示“通过对话设置账户”，不做客户端向导和虚假完成标记。
9. 聊天照片上限 8 张。选择新图时只导入剩余可用数量；复用 C2 JPEG 清理、hash、原图保存与 blob 上传。
10. golden 每状态中文/pine×360/430×100/200%；streaming、paused、record_ready、composer_answering 再各补 en/pine 与 zh/indigo，430/100%。无溢出布局仍跑全部 16 组合。
11. 负对照采用 C3 JSON 格式，11 项；每条含 file/find/replace/expected_occurrences/command，另提供 formatter 容忍的 find_regex 和测试名。只在构建机临时改坏，断言失败才算有效。

### 其余实现选择

- authoritative 是本机来源标记，区分流末尾的暂存 final 与同步确认版本；不发给服务端。steps 仍放完整 message JSON，没有新增步骤列。
- v1 迁移从 data_json.message 回填专用列；没有 message 的 opaque 旧行保留，等待真实同步恢复。按 runtime 的空间目录逐空间迁移，保留 outbox 和未知 JSON 字段。
- ClientState 与上传回执独立于消息内容，防止整体同步替换擦掉未提交意图。SQLite writer lock 串行化这些 JSON 的合并。
- 发消息之前尚无服务端会话 ID 时使用本机临时会话 ID；服务端 conversation 到达后重建内存投影，将本机待上传用户消息投影进本人的连续会话。上传 payload 不带临时 conversation ID。
- 同步最终 rev 低于内存 rev 时重建内存投影，以落实家簿“同步持久版本总替换”的规则。库内部比较规则不修改。
- 读取和写入均绑定空间、本人、分区 fence。fence 失效立即清空内存投影，ViewModel 重新取得会话。
- 临时写约一秒节流；块结束、暂停和断线时刷新。监听实时 BlockStore 补充库只在连接结束时调用的持久化回调。
- 权威刷新实际调用 sync/pull；即使另一连接占用上传租约也请求服务端。应用响应前比较本机游标与 fence，迟到的分页重读。
- 永久动作拒绝保留 failed outbox 和拒绝回执，解除“提交中”。用户明确重新回答时可用新意图替换同一块的 failed 条目；不替换 pending/sending 或结果不确定的动作，旧拒绝回执保留。网络重发始终用原动作 ID。
- 未上传且没有发送尝试的消息可在 SQLite 事务里取消；明确 422 拒绝也可本机接管。结果不确定的上传必须先同步确认助手 ID，再在线 stop。已接管的消息可重新打开手动表单，取消表单不恢复队列。
- 服务端已产生记录卡的运行停止后先引导查看已有记录，不允许把整段原话再手工记一次。手动表单不自动带入从原话推断的字段。
- 离页、后台与断网只断线，不 stop。暂停流不循环续订。另一设备回答通过 pull 和 active 状态变化续订原回复。
- 库无列表 reveal API；优先利用公开 block keys ensureVisible。目标消息已回收时，用 Flutter 的公开 Scrollable API 有界遍历较旧视口，让列表建立目标锚点；不改滚动物理。
- golden 容器只挂载 client 时，宿主绝对路径 override 不可见。因此 golden.sh 增加可选 `JIABU_CHATWEAVE_DIR` 只读挂载；默认行为不变。构建机路径覆盖应使用绝对路径。

## ChatWeave 缺口与文档差异

固定使用 `ab5cabb1b67338a52078e8da875804b9a1543a75`，不修改库、不自动升级。

1. 没有 processStripBuilder。MessageView 直接创建 ProcessStrip；家簿用 messageFrameBuilder，保留公开的 block keys、ProcessState、resize 回调与控制器。
2. 主题实际是扁平字段，少于文档中的 icons/status/blockFrame/motion 等插槽。通过注册表覆盖皮肤及家簿消息/输入组件补齐。
3. register 实际为 register(type, BlockRegistration)，非文档的泛型 register/parse/build 参数形式。
4. 没有外部 outbox 结果注入入口；通过持久回执和 retryPending 原意图协调，不二次请求服务端。
5. 持久化回调主要在连接结束时执行；家簿监听实时投影落盘。
6. BlockStore 的 SyncMessage 会拒绝较低 rev；家簿同步持久版本总替换通过内存投影重建处理。
7. ChatWeaveList 没有公开 reveal/scroll 控制器；家簿用公开消息锚点和 Flutter Scrollable 补齐。
8. chatweave_flutter 内部 core 是 hosted ^0.1.0；宿主固定 git override 由 G0 确认。

## 服务端能力、缺口与接口差异

- 当前 master 的 admin 拒绝非官方 SIWC base，runtime 固定官方端点。**真实 AI 集成场景等待独立 loopback PR 的 server ref**；不能把测试未运行或失败视为通过。
- messages 返回 userMessageId/messageId；没有 conversationId。会话从同步/流取得。
- actions 成功当前只有 accepted+resume，无 patches。服务端错误是 problem+json；interrupt_resolved/expired 后拉取权威结果。
- active-messages 包含 queued/running/waiting_ai/paused，但只暴露 streaming/paused；缺少持久化 waiting_ai 原因。客户端重启无法立即证明 AI 不可用。
- 初次设置已有 create_account/update_account/set_allocation_plan 和 ask_user 表单。没有专用 onboarding 端点或完成标记；展示摘要依赖普通真实工具/模型结果。
- 服务端 stop 返回 accepted，终态通过同步/流确认。停止摘要以服务端内容为准，不在客户端猜已完成笔数。
- 现有模型失败/等待事件没有完整客户端字段错误协议；永久动作失败显示通用双语错误，原始错误码只用于受控处理和本机队列。

## 验收 → 自动化测试名

所有路径以 client/app 为基准。`test/server/chat_server_test.dart` 的 8 条（关键流程与两设备场景）带 `server` 标签，只经 `tool/server-it.sh` 运行，**尚未执行**（见“验证状态”）；其余均已在构建机通过。

| 验收 | 文件与测试名 |
|---|---|
| 关键流程1：流式、记录卡、同步、编辑/撤销 | test/server/chat_server_test.dart：chat_flow1_stream_record_card_edit_and_void |
| 关键流程3：离线文字+照片、顺序、失败保留与同ID重发 | 同上：chat_flow3_offline_text_photo_order_failure_and_same_id_retry |
| 两设备回答接同一回复、不产生用户消息 | 同上：chat_two_devices_answer_same_reply_without_user_message |
| 两设备同时回答仅一个生效 | 同上：chat_two_devices_race_only_one_answer_effect |
| 停止保留已完成记录、重试不重复 | 同上：chat_stop_preserves_first_record_and_retry_never_duplicates |
| 杀进程后 active-messages + 游标找回 | 同上：chat_killed_app_recovers_from_active_messages |
| AI 不可用时手动接管、恢复后不重复 | 同上：chat_ai_unavailable_manual_takeover_cancels_server_queue |
| 首次设置真实账户/计划，无收入或消费记录 | 同上：chat_first_setup_uses_real_tools_without_income_or_expense |
| rev总替换、rev0游标、临时不覆盖、steps、隔离与清除 | test/data/chatweave_store_test.dart：synced_persisted_revision_replaces_local；older_checkpoint_cannot_regress_stream；delayed_provisional_cannot_replace_synced_final；checkpoint_cannot_replace_final_and_steps_roundtrip；store_filters_member_and_space_and_purge_clears_intents |
| schema迁移及重开 | test/data/chat_migration_test.dart：chat_v1_to_v2_preserves_two_spaces_queue_and_checkpoints；既有 migration_test.dart / generated_migration_test.dart 更新至v2 |
| 三种上传器成功/逐条失败/fence变化 | test/data/chat_outbox_test.dart：chat_{send,action,retry}_uploads_and_saves_result_before_ack；chat_{send,action,retry}_permanent_failure_is_retained；chat_{send,action,retry}_late_ack_cannot_cross_fence |
| 请求前fence、动作ID固定、blob顺序、同实体串行、手动取消 | 同上：epoch_change_before_dispatch_sends_no_request；offline_action_replays_identical_id_and_payload；chat_send_waits_for_blob_receipt；chat_results_are_per_item_and_same_entity_is_serialized；manual_takeover_prevents_later_ai_duplicate |
| 动作超时/重启/后台回执不二次请求 | test/data/chat_action_receipt_test.dart：action_receipt_{timeout,restart,background}_reuses_intent_without_second_request |
| 能力头、相对路径、认证、401错误体、幂等/epoch头 | test/data/chat_transport_test.dart：capabilities_are_registry_derived_and_stream_headers_are_correct；stream_problem_body_preserves_error_code_and_401_callback；chat_mutations_preserve_outbox_ids_and_epoch |
| 权威刷新确实请求服务端，迟到分页受fence保护 | test/data/chat_refresh_test.dart：authoritative_chat_refresh_contacts_server_and_fences_late_page |
| degraded判定、离线接管门禁、取消表单可重开、离页不stop、原子回滚 | test/data/chat_repository_test.dart：degraded_machine_state_controls_ai_unavailable；uploaded_message_cannot_switch_to_manual_while_offline；manual_form_cancel_does_not_restore_ai_and_can_reopen；stop_offline_and_leaving_page_never_enqueue_stop；send_and_user_entry_rollback_together |
| 输入栏锁定/回答/取消/草稿、回答是动作、不可乐观选择 | test/features/chat_composer_test.dart：other_input_enqueues_action_without_user_entry；queued_action_keeps_authoritative_block_open；composer_reconciles_other_device_close_and_preserves_draft |
| ViewModel失败保留草稿、入队成功后清空 | test/features/chat_view_model_test.dart：chat_view_model_retains_failed_draft_and_clears_only_after_enqueue |
| 不可用入口打开C3表单、便利贴状态、未知块降级、权威回答 | test/features/chat_interaction_test.dart：ai_unavailable_exposes_manual_form_entry；user_{pending,failed,waiting_ai,manual_takeover}_keeps_original_and_manual_entry；record_card_reference_changed_and_syncing；unknown_jiabu_block_falls_back_without_document_registration；choice_answer_is_not_selected_until_authoritative_state |
| 记录块watch同步→后来改过→权限优先 | test/features/chat_record_card_test.dart：record_block_watches_sync_then_changed_and_permission_priority |
| T8文字位置不变、过程伸缩锚点 | test/features/c5_geometry_test.dart：component_fill_preserves_text_top_left_jiabu；process_growth_and_manual_collapse_preserve_scroll_anchor_jiabu；locked_composer_reveals_recycled_interrupt；structured_blocks_are_332_wide_and_horizontal |
| 全状态无溢出 | test/features/c5_layout_test.dart：c5_layout_<state>_<locale>_<accent>_<width>_<scale>，39×16组合 |
| golden | test/features/c5_golden_test.dart：每个 PNG 路径即测试名；164项 |
| 日志脱敏 | test/data/chat_log_test.dart：chat_log_keeps_only_fixed_event_code_and_request_id |

## Golden 与视觉变化

仅聊天替换占位；沿用现有主框架、顶栏和导航。记录卡复用 C3；其他块水平纸面、无胶带；过程条虚线、无卡片背景；输入栏锁定与回答标签有明确状态。登录/地址/首次启动页外观不改。

完整164条路径在 `app/test/features/c5_golden_test.dart` 的 c5Goldens 清单，规则为：

`app/test/goldens/chat/<state>_<zh|en>_<pine|indigo>_w<360|430>_text<100|200>.png`

39个状态在 `app/lib/features/catalog/c5_cases.dart` 的 c5States；catalog 同源。页面状态包含完整 MainFrame、聊天列表和输入栏，组件状态单独展示。旧 catalog_golden_test 排除 c5，避免重复生成不在批准矩阵内的图。无溢出测试不收窄。

164 张 PNG 已在固定镜像（`ghcr.io/zz-howard/jiabu-flutter-ci:3.47.8-1`）生成，按基础（zh/pine/360/100%）与 430×200% 两组联系表逐状态看图，并抽查放大；未见溢出或裁切。430×200% 的 streaming 中较早的便利贴部分滚到顶栏下，为列表贴底的正常滚动。PR 标记 visual-change。

## 构建机命令顺序

先设置不入库的 **绝对路径** ChatWeave overrides。工具链使用 Flutter 3.47.8 / 仓库固定依赖。

```bash
cd client
flutter pub get
cd app
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs
dart run drift_dev schema dump lib/data/db/database.dart test/drift_schemas
dart run drift_dev schema generate test/drift_schemas test/generated_migrations
cd ..
dart format .
flutter analyze --fatal-infos
dart run tool/check_rules.dart
flutter test --exclude-tags golden
cd app
flutter test --exclude-tags golden
cd ../packages/jiabu_design
flutter test
cd ../..
JIABU_CHATWEAVE_DIR=/absolute/path/to/chatweave-cw2 tool/golden.sh --update-goldens test/features/c5_golden_test.dart
```

按既有字体子集流程，用构建机缓存原字体离线更新 ARB 字表；若生成器要求更新字体，必须在审图前完成，不运行联网字体下载。本切片没有新增图标。

生成后校验 C5 golden，运行11项负对照并恢复，核对生成文件/lockfile/schema/helper差异。`tool/c5-negative-controls.json` 的 command 在 client/app 执行；编译失败不算负对照成功。

最后运行真实服务端集成。ref 必须包含 S7③ 和独立 loopback 支持：

```bash
PG_BIN="$HOME/dev-tools/pg18/bin" \
JIABU_IT_PG_PORT=<空闲端口> \
JIABU_IT_HTTP_PORT=<空闲端口> \
JIABU_IT_HTTP_PORT_B=<空闲端口> \
JIABU_IT_AI_PORT=<空闲端口> \
JIABU_IT_DATA_DIR=<临时目录> \
JIABU_IT_SERVER_REF=<含loopback支持的本地ref> \
CARGO_TARGET_DIR=<构建机target目录> \
client/tool/server-it.sh
```

脚本继续使用 `flutter test --tags server --run-skipped`。假上游只有 Python 标准库，监听127.0.0.1，不转发、不调用官方端点。Responses SSE 支持文字、工具、完成/usage、故障、分片、CRLF和受控barrier；OAuth刷新仅返回合成令牌。测试脚本通过本机控制端点注册逐轮响应，不修改服务端数据库业务记录或时间。

## 验证状态与仍待验证点

构建机门禁见文首。仍待验证：

1. 真实服务端集成（两实例动作回执、租约、杀进程恢复）：依赖尚待合并的 loopback 假上游契约，脚本 `tool/server-it.sh` 已就绪。
2. 真机：图片拾取/编解码、离后台回来、长期连接与网络切换的手感，由第二个测试 APK 检查。

## 留给后续切片

- C4 协调约定：C5 不新增任何系统通知。已核对聊天实现，当前仅有页面内提示、读屏播报和数据库/状态变更事件，没有系统通知发送路径。
- 后续若接入系统通知，必须遵循应用锁的通知文字规则，并在通知接入点保留 `TODO(C4): route through app-lock notification text rule`；本切片不新增通知插件或发送逻辑。

## 构建机反馈修正

- analyze：修正类型错误与 lint（void 流回调、SafeLogEvent 日志捕获、Tags 名称冲突、Future await、控制流花括号、长行、cascade、命名布尔参数、getter/setter 与依赖顺序），未加 ignore。
- 生成物：drift 生成代码与 schema v2 helper 在构建机重新生成后入库；ChatWeave 在 pubspec.lock 中按 git 来源（ab5cabb）记录，不含构建机路径覆盖。
- 布局：`JiabuMessageView` 改为 `Alignment.topLeft`，下方组件增高时只向下展开（几何测试 `component_fill_preserves_text_top_left_jiabu`）。
- 用户照片 Polaroid 用设计系统默认倾角 −2°（原传 0° 违反 ±2° 断言）。
- AI 不可用入口文案改为“手动记一笔”（新键 `chatManualEntry`），与需求一致；原 `ledgerManual`“记一笔”在此语境含义不清。
- `choice_resolved` 示例只含 `selected`（协议规定 selected 与 freeText 二选一），回显为“已回答：信用卡”。
- 测试：原先无输出卡满 10 分钟的三条组件测试，根因是测试侧 `pumpAndSettle` 等待持续活动态、以及在 FakeAsync 内裸等真实 I/O；改为有上限的 `pumpUntil`、真实 I/O 放在 `runAsync`/测试外层、`pumpC3` 支持根作用域 overrides，并对其设 60 秒上限。无产品逻辑为测试让步。
- 负对照：手动接管一项因缩进变化更新锚点，其余不变。

## 改动文件清单

以下为源实现和测试；生成文件/PNG由构建机另行提交。

```text
.gitignore
client/C5-DELIVERY.md
client/app/lib/app/chat_providers.dart
client/app/lib/app/runtime.dart
client/app/lib/data/api/chat_api.dart
client/app/lib/data/api/dio_api_client.dart
client/app/lib/data/chat/chat_action_transport.dart
client/app/lib/data/chat/chat_capabilities.dart
client/app/lib/data/chat/chat_session.dart
client/app/lib/data/chat/chatweave_store.dart
client/app/lib/data/chat/sse_transport.dart
client/app/lib/data/db/daos/local_store.dart
client/app/lib/data/db/database.dart
client/app/lib/data/db/migrations/chat_v2.dart
client/app/lib/data/db/schema.drift
client/app/lib/data/db/tables.dart
client/app/lib/data/repositories/chat_repository.dart
client/app/lib/data/services/log_redactor_service.dart
client/app/lib/data/services/media_service.dart
client/app/lib/data/sync/outbox_processor.dart
client/app/lib/data/sync/pull_applier.dart
client/app/lib/data/sync/sync_engine.dart
client/app/lib/data/sync/sync_policy.dart
client/app/lib/data/sync/sync_triggers.dart
client/app/lib/domain/chat.dart
client/app/lib/features/catalog/c5_cases.dart
client/app/lib/features/catalog/catalog_cases.dart
client/app/lib/features/chat/blocks/record_card_block.dart
client/app/lib/features/chat/view/chat_screen.dart
client/app/lib/features/chat/view_model/chat_ui_state.dart
client/app/lib/features/chat/view_model/chat_view_model.dart
client/app/lib/features/chat/widgets/chat_composer.dart
client/app/lib/features/chat/widgets/user_message_note.dart
client/app/lib/l10n/app_en.arb
client/app/lib/l10n/app_zh.arb
client/app/lib/shared/chatweave/chat_block_revealer.dart
client/app/lib/shared/chatweave/chat_composer.dart
client/app/lib/shared/chatweave/jiabu_chat_localizations.dart
client/app/lib/shared/chatweave/jiabu_chat_registry.dart
client/app/lib/shared/chatweave/jiabu_chatweave_theme.dart
client/app/lib/shared/chatweave/jiabu_message_view.dart
client/app/lib/shared/chatweave/jiabu_process_strip.dart
client/app/lib/shared/chatweave/jiabu_structured_blocks.dart
client/app/lib/shared/chatweave/user_message_note.dart
client/app/lib/shared/ledger/ledger_pages.dart
client/app/pubspec.yaml
client/app/test/catalog_golden_test.dart
client/app/test/data/chat_action_receipt_test.dart
client/app/test/data/chat_log_test.dart
client/app/test/data/chat_migration_test.dart
client/app/test/data/chat_outbox_test.dart
client/app/test/data/chat_refresh_test.dart
client/app/test/data/chat_repository_test.dart
client/app/test/data/chat_transport_test.dart
client/app/test/data/chatweave_store_test.dart
client/app/test/data/generated_migration_test.dart
client/app/test/data/migration_test.dart
client/app/test/features/c5_geometry_test.dart
client/app/test/features/c5_golden_test.dart
client/app/test/features/c5_layout_test.dart
client/app/test/features/chat_composer_test.dart
client/app/test/features/chat_interaction_test.dart
client/app/test/features/chat_record_card_test.dart
client/app/test/features/chat_view_model_test.dart
client/app/test/server/chat_server_test.dart
client/app/test/support/chat_harness.dart
client/packages/jiabu_design/lib/jiabu_design.dart
client/packages/jiabu_design/lib/src/components/chat_rail.dart
client/packages/jiabu_design/lib/src/components/trend_plot.dart
client/packages/jiabu_design/lib/src/tokens/chat_metrics.dart
client/pubspec.yaml
client/tool/allowed_deps.yaml
client/tool/c5-negative-controls.json
client/tool/c5_fake_upstream.py
client/tool/golden.sh
client/tool/server-it.sh
```
