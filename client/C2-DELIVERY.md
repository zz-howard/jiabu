# C2 交付说明

最新状态：协调者第三轮确认 analyze 0 条、默认测试 1504 条通过、352 张 auth golden 已生成、5 个真实服务端场景通过、19 条负对照均为断言失败。以下第三轮修改尚未在构建机复验；本机为 aarch64，没有 Dart / Flutter，按 brief 不安装、不运行构建或测试。历史章节的待验证状态以本段和文末第三轮记录为准。

本机没有 Dart / Flutter；未安装工具、未联网、未运行 pub get / build_runner / Flutter 测试或生成 golden。没有改动 `docs/`、`server/`，没有手写生成文件。开发入口默认也是登录流程，C1 catalog 用 `--dart-define=JIABU_CATALOG=true` 保留。

## 实现与验证边界

- drift v1 SQL schema、分区库与安全存储、最小地址/登录/改密码界面、Dio 与手写 DTO、握手、同步/冲突/租约、后台触发、媒体清理、日志与崩溃上报均有源实现。
- DAO 集中在 `app/lib/data/db/daos/local_store.dart`；每条业务 SQL 显式传 `spaceId`。`DaoScope` 是运行时守护，规则 9 禁止数据库调用逃出 db 层；测试还验证同 ID 跨空间隔离。
- `SyncEngine` 先握手和成员对账，再 drain，最后当前空间优先分页 pull。每个批次一次本机事务；过期会话、成员世代和分区启用代次变化后丢弃旧结果。成员目录请求也保存空间世代快照。
- chat 三种 kind 只保留类型/数据库枚举和 C5 TODO；没有聊天上传。没有 templates 表、模板拉取、C3 记账界面、C4 完整设置/空间界面或 C7 更新流程。
- 本机仅做：`bash -n client/tool/server-it.sh`、`git diff --check`、Python SQLite 建 schema / 空间列检查、YAML/ARB/依赖白名单一致性、Dart 字符串与括号词法检查、负对照锚点唯一性检查。它们不代表 Dart 编译、G1、G2 或 G3 已通过。

## 构建机步骤

构建机已按 Flutter 3.47.8 / Dart 3.13.7 解析依赖，生成代码与 drift 快照已同步回工作树。白名单已对齐最终 pubspec；版本见下表。SQLite 3.8.0 默认构建钩子已成功下载并校验预编译库，没有配置 url_pattern，也没有从源码编译。

```bash
cd client
flutter pub get
cd app
dart run build_runner build --delete-conflicting-outputs
dart run drift_dev schema dump lib/data/db/database.dart test/drift_schemas
dart run drift_dev schema generate test/drift_schemas test/generated_migrations
cd ..
dart format .
flutter analyze --fatal-infos
dart run tool/check_rules.dart
flutter test
cd app
flutter test
cd ../packages/jiabu_design
flutter test
```

生成的 `*.g.dart`、`*.freezed.dart`、drift schema 快照、迁移测试 helper 和 lockfile 已由构建机同步；本轮没有修改它们。构造器声明和 DTO 参数顺序调整后，请在构建机重跑生成一致性检查。CI 增加 build_runner 与 drift schema/helper 生成一致性检查；schema 结构另由 SchemaVerifier 测试守住。构建机若升级依赖，请同时调整白名单的完整版本声明。

新 golden 测试：`app/test/features/auth_golden_test.dart`。实际 PNG 路径：`app/test/goldens/auth/<state>_<zh|en>_<pine|indigo>_w<360|430>_text<100|200>.png`。全部状态名在该文件的 cases 中；没有提交 PNG。由 luna.coco 在固定镜像生成、打开审图、提交并加 `visual-change` 标签。布局测试另外覆盖相同宽度/字号/语言和表单滚动。

真实服务端脚本必须由构建机显式运行，暂不接 CI：

```bash
PG_BIN="$HOME/dev-tools/pg18/bin" \
JIABU_IT_PG_PORT=<空闲端口> \
JIABU_IT_HTTP_PORT=<空闲端口> \
JIABU_IT_HTTP_PORT_B=<另一个空闲端口> \
JIABU_IT_DATA_DIR=<临时测试目录> \
JIABU_IT_SERVER_REF=<本地master提交或引用> \
CARGO_TARGET_DIR=<构建机target目录> \
client/tool/server-it.sh
```

脚本优先使用本机 PostgreSQL 18，`initdb` 创建独立实例（可把数据目录设在 client/.dart_tool/server-it 下）；未指定 PG_BIN 且本机工具不可用时可回退 Docker。端口、数据目录、master ref、Cargo target 均由环境变量提供。flock / nice 留给调用者。脚本从指定 ref 导出 server 快照后构建，不修改 server 工作树。CLI 使用虚构操作人 c2-it-operator，建两个虚构账号及默认空间，测试通过公开接口准备共享空间和成员。测试复用 bootstrap 会话，避免成功登录也计入 5/min 限流。`server` 标签在 dart_test.yaml 里默认 skip（`flutter test` 不支持 `--preset`），默认 `flutter test` 显示为跳过；脚本使用 `--tags server --run-skipped`。测试中关闭 Flutter 的假 HTTP override，所有服务端操作都走真实 HTTP。

## 最可能需要构建机修正的地方

1. 依赖配对已由构建机解析确认；第二轮已将构造器全部恢复传统写法，解决 dart format / freezed 对 new 声明的解析失败；仍需复跑 build_runner 确认生成一致性。build_runner 固定 ^2.16.2：2.17 需要 build 5，riverpod_generator 4.0.9 尚不支持。
2. drift 已生成 schema/helper；数据库构造器改用与生成代码一致的 super.e。迁移与独立连接测试仍待执行，SQLite 预编译构建钩子已在构建机成功。
3. workmanager 的回调注册/任务枚举、connectivity_plus 的列表事件、image_picker limit 参数和 flutter_image_compress 的原生方向/缩放行为。单元测试验证隔离接口与调用契约，不声称已验证真实手机编解码。
4. Dio 泛型响应/adapter 和严格 lint。Dart format / analyze 均未在本机执行；需在构建机规范格式并反馈诊断。
5. 当前仓库没有 Android/iOS runner。没有在本机生成平台项目；平台插件注册、原生构建与真机测试仍待构建环境验证。

## 文档没写清、我是这么做的

### 用户在 G0 定下的六条

1. 版本拿不准的依赖写 any 并加 TODO(luna)，已有文档版本先按约束登记。由 luna.coco 在固定工具链解析最新兼容稳定版、核对许可证并提交 lockfile。sqlite3 3.x 默认下载预编译库并校验，不设置 url_pattern、不源码编译；Riverpod/freezed 配对已通过构建机 pub get；最终版本记录如下。
2. 新增内部 `sync_runtime` 表：启用代次、认证状态、写入门禁、缓存身份/会话种类、空间 ID 目录、整轮同步租约、跨连接变更序号、待确认的清除提示和图片删除待办。不包含令牌或密码。
3. 同空间中，候选条目的 entity_ids/depends_on 并集与任何更早未确认条目的并集交叠就等待；failed/blocked 也属于未确认。采用用户批准的保守规则。
4. 最低服务端 0.1.0、API 版本 1；不以 features 判定能力。
5. C2 不建 templates 表，不拉 templates；C6 按 S6 形状再加。
6. 仅 `data/sync/sync_policy.dart` 放宽技术 Duration 常量；颜色/字体仍受限，界面/其他目录 Duration 仍拒绝，规则有正反例。

### 其余最小实现选择

- 下载的原图不按路径里的 SHA-256 校验：服务端存的是清理后的字节（去 GPS / XMP / APP13、截断 EOI 后数据），仍按上传字节的 SHA-256 寻址，两者可以合法不同。

- 地址按 URI origin 规范 scheme/host/默认端口，保留代理路径大小写和保留字符转义，统一末尾斜杠。userinfo/query/fragment 不作为服务端地址接受。
- spaces 增加显式 space_id 并约束等于 id；grants 从所属空间补 space_id。公开同步投影没有的私有身份字段不在本机伪造。聊天完整载荷暂存 opaque JSON，不建立 ChatWeave 的 message_json/rev/last_seq 专用列。
- v1 使用显式业务列加完整 data_json；JSON/数组存为 TEXT，金额/版本/游标为整数。只给有服务端 version 的实体建立 base_version。
- 首次领取时填 expected_version 并持久化，重试不重绑；改变参数的冲突解决使用新 op_id。整批字节限制包括封套、UTF-8 和填入的版本，2 MB 取 2,097,152 字节。
- 切换提示的 N 是打开提示时的快照；旧分区可继续上传，确认后才停止并失效旧请求，队列始终保留。
- 426 同时删除持久化 meta 缓存并保留写入门禁；重取 meta 断网时不能被另一实例的一小时旧缓存重新放行。
- outbox created_at 在同空间内保持单调，避免时钟回拨改变依赖顺序。用我的/恢复时，将原有依赖项移到新解决写入之后，保留其 op_id、request_id 和参数；否则旧退款可能先于 restore 执行并永久挡住恢复。
- 整轮租约 12 分钟、20 秒心跳；普通 HTTP 超时 30 秒，原图 10 分钟。outbox 每条另有 lease_until，并校验发送次数/租约身份。后台 resume 不递增前台启用代次。
- 429（批内或 HTTP）、503 upload_busy 退避，不置 failed。not_processed 本轮不立即重发。null op_id 的 422 只有在数量/其他 ID/顺序均匹配时才按位置对应。
- 本机库与文件删除不能成为同一原子事务：数据库登记删除任务，SQLite 写锁串行化引用检查与文件发布/删除；启动和同步结束清理无引用 JPEG。共享物理 hash 文件只在最后一个有效空间引用消失后删除。
- 原图先做格式/方向归一化，再按实际 JPEG 尺寸限制长边，最终质量 90；客户端自己去除全部 APP/COM 元数据与 EOI 后内容，最终字节算 hash。上传成功后 30 天清理，之后由下载接口取回。
- 独立连接不共享 drift 的 watch 通知：业务事务同时递增 change_revision，前台每秒检查一次并刷新带空间条件的 stream；离开前台就停止轮询。后台清除提示存原分区，用户点“知道了”后清除，不丢在后台 isolate 的内存里。
- 冷启动离线时从原分区取缓存身份/会话种类，保留临时密码门禁；令牌只在 secure storage。401 删除令牌但不删除分区。安全存储的写入/失效与代次比较由同一数据库写锁协调，旧 isolate 的 401 不能删除重新登录后的令牌。
- API transport 统一抛规范化 ApiError，Repository 对外返回 Result；同步协调器集中处理认证、版本与重试。不同于在每个 DTO/API 方法外再套一层 Result。
- 登录前只写允许列表的启动日志；登录后使用分区日志，避免切换账号/地址后把旧分区日志发给新服务端。崩溃只记录固定事件、CapturedError 和过滤后的 package/dart 堆栈，不记录异常原文。
- 当前切片只给最小会话状态页，不扩展总览或设置页。源码入口可保留 C1 catalog；没有更新下载/安装或厂商省电引导。

## 按真实代码处理的接口差异 / 服务端边界

1. pull 是 POST `/v1/sync/pull`，不是任务文字中出现的 GET。
2. conflict 的实体在 `problem.current`，不是结果顶层 current。
3. PUT blob 成功是无响应体 204；重复图片也发完整字节。必须带 X-Jiabu-Join-Epoch；upload_busy 是 503 + Retry-After。
4. wire entity 为 space_member_grant；本机表名 member_grants。allocation_plan 的键为 account_id，不是 id。
5. GET /spaces 是成员关系摘要，spaces/member 的 pull 投影也不暴露私有身份列；不能要求所有 PostgreSQL 列都出现在客户端 DTO。
6. /meta 当前 features=[]，server_version=0.1.0；features 不能用作 S4 功能门禁。服务端同时提供根 healthz 和 v1/healthz；客户端相对服务根调用 healthz。
7. POST /me/password 返回 204，当前 token 留用并升级为 full，不返回新 token；/me 对 password_change 会话返回 password_change_required。
8. push 最多 50 条 / 2 MB；逐条 rejected + 429 + retry_after 是可重试。畸形条目的 op_id 可为 null。内部错误后的 not_processed 不代表成功。
9. OpenAPI 的 push result/pull data 示例有意是局部 JSON；DTO envelope 往返保留它们，完整实体用同步测试夹具验证。
10. admin CLI 没有独立空间创建子命令，只能随建账号创建默认空间；共享空间、邀请、移除、重加使用公开 API，未增加服务端测试后门。
11. /client-logs 需要会话，每批最多 100 条，并有 message/stack/设备元数据字节上限；按实际请求封套上报。
12. 服务端虽然也清理 GPS/XMP/EOI 尾部，客户端仍独立清理，测试不依赖服务器。
13. 当前版本中间件只接受 android/ 客户端头；iOS 原生接入时需要服务端支持 ios/，这里没有改 server。
14. 当前 registry 的写工具主要为 ledger；资料表同步基础保留，不虚构尚待 S6 的工具接口。

## 构建机最终依赖版本

以下为当前 pubspec 约束和构建机 lockfile 的解析结果；SDK 依赖与本地 jiabu_design 不列入版本表。

| 依赖 | pubspec 约束 | lockfile 版本 |
| --- | --- | --- |
| connectivity_plus | `^7.3.2` | 7.3.2 |
| crypto | `^3.0.8` | 3.0.8 |
| device_info_plus | `^13.3.0` | 13.3.0 |
| dio | `^5.11.1` | 5.11.1 |
| drift | `^2.35.3` | 2.35.3 |
| flutter_image_compress | `2.5.1` | 2.5.1 |
| flutter_riverpod | `^3.4.3` | 3.4.3 |
| flutter_secure_storage | `^11.2.0` | 11.2.0 |
| freezed_annotation | `^3.1.0` | 3.1.0 |
| go_router | `^18.1.1` | 18.1.1 |
| image_picker | `1.2.4` | 1.2.4 |
| intl | `any` | 0.20.3 |
| json_annotation | `^4.12.0` | 4.12.0 |
| logging | `^1.3.0` | 1.3.0 |
| package_info_plus | `^10.2.2` | 10.2.2 |
| path | `^1.9.1` | 1.9.1 |
| path_provider | `^2.1.6` | 2.1.6 |
| riverpod_annotation | `^4.0.7` | 4.0.7 |
| shared_preferences | `^2.5.6` | 2.5.6 |
| sqlite3 | `^3.8.0` | 3.8.0 |
| uuid | `^4.6.0` | 4.6.0 |
| workmanager | `^0.10.10` | 0.10.10 |
| build_runner | `^2.16.2` | 2.16.2 |
| drift_dev | `^2.35.2` | 2.35.2 |
| freezed | `^4.0.3` | 4.0.3 |
| image | `^4.12.0` | 4.12.0 |
| json_serializable | `^6.15.2` | 6.15.2 |
| mocktail | `^1.0.5` | 1.0.5 |
| riverpod_generator | `^4.0.9` | 4.0.9 |

image 仅用于测试。未再增加依赖；build_runner 保留 ^2.16.2 的兼容约束。

## 依赖许可证（待 lockfile 后复核）

MIT：drift/drift_dev、sqlite3（SQLite 本体 public domain）、dio、freezed/freezed_annotation、Riverpod annotation/generator、workmanager、flutter_image_compress、uuid、mocktail、image（测试）。BSD-3-Clause：json_annotation/json_serializable、build_runner、go_router、flutter_secure_storage、shared_preferences、connectivity_plus、image_picker、crypto、logging、package_info_plus、device_info_plus、path/path_provider。原生传递依赖在构建机解析后一起核对。

## 负对照清单

机器清单：`tool/c2-negative-controls.json`。每条都有仓库相对文件路径、原文 find、替换 replace、唯一匹配计数、容忍格式化的 find_regex、测试文件/精确测试名和执行命令。这里不提交任何改坏代码，也没有执行负对照。

构建机先让原版测试通过，再逐项临时替换、要求断言失败、恢复。编译失败不算负对照成功。匹配必须恰好一次；正则替换使用 lambda，避免把替换文本中的转义解释成正则引用。

| 控制项 | 源文件 | 应失败的测试 |
|---|---|---|
| one_entity_in_flight | `lib/data/sync/outbox_processor.dart` | `same_record_three_edits_use_three_batches` |
| bind_version_at_send | `lib/data/repositories/local_mutations_repository.dart` | `expected_version_is_bound_after_predecessor_ack` |
| refund_dependency | `lib/domain/outbox_operation.dart` | `refund_waits_for_expense_ack` |
| blob_before_reference | `lib/data/sync/outbox_processor.dart` | `unuploaded_blob_metadata_prevents_reference_upload` |
| freeze_retry_payload | `lib/data/sync/outbox_processor.dart` | `retry_replays_identical_operation` |
| rejoin_purge | `lib/data/sync/membership_reconciler.dart` | `rejoin_purges_then_pulls_from_zero` |
| purge_includes_outbox | `lib/data/db/daos/local_store.dart` | `rejoin_purges_then_pulls_from_zero` |
| purge_includes_sync_cursors | `lib/data/db/daos/local_store.dart` | `rejoin_purges_then_pulls_from_zero` |
| purge_includes_entity_conflicts | `lib/data/db/daos/local_store.dart` | `rejoin_purges_then_pulls_from_zero` |
| purge_includes_blobs_local | `lib/data/db/daos/local_store.dart` | `rejoin_purges_then_pulls_from_zero` |
| rejoin_resets_cursor | `lib/data/sync/membership_reconciler.dart` | `rejoin_purges_then_pulls_from_zero` |
| epoch_response_fence | `lib/data/db/daos/local_store.dart` | `local_request_fence_rejects_epoch_change` |
| activation_response_fence | `lib/data/db/daos/local_store.dart` | `local_request_fence_rejects_a_b_a_generation` |
| late_pull_fence | `lib/data/sync/sync_engine.dart` | `late_pull_cannot_restore_purged_rows_or_cursor` |
| round_lease_compare_and_set | `lib/data/db/daos/local_store.dart` | `two_isolates_cannot_upload_same_entity` |
| outbox_sending_lease | `lib/data/db/daos/local_store.dart` | `two_isolates_cannot_upload_same_entity` |
| in_flight_writeback | `lib/data/sync/conflict_service.dart` | `upload_in_flight_edit_keeps_latest_content` |
| resolution_before_refund | `lib/data/sync/conflict_service.dart` | `restoring_mine_keeps_refund_behind_restore_and_update` |
| late_spaces_snapshot | `lib/data/sync/sync_engine.dart` | `late_spaces_response_does_not_remove_rejoined_space` |

世代/代次的直接守护测试与 late push/blob/pull/spaces 的结果测试同时存在。部分旧响应还有“outbox 已清除/仅 UPDATE 已有缓存行”的第二层保护；负对照用直接守护测试验证第一层条件，避免因第二层保护还在而误称第一层已被测试。

## 改动文件清单

- `.github/workflows/client-ci.yml`
- `client/C2-DELIVERY.md`
- `client/app/build.yaml`
- `client/app/dart_test.yaml`
- `client/app/lib/app/bootstrap.dart`
- `client/app/lib/app/partition_host.dart`
- `client/app/lib/app/providers.dart`
- `client/app/lib/app/router.dart`
- `client/app/lib/app/runtime.dart`
- `client/app/lib/data/api/api_client.dart`
- `client/app/lib/data/api/api_error.dart`
- `client/app/lib/data/api/dio_api_client.dart`
- `client/app/lib/data/api/dto/auth_dto.dart`
- `client/app/lib/data/api/dto/client_logs_dto.dart`
- `client/app/lib/data/api/dto/meta_dto.dart`
- `client/app/lib/data/api/dto/problem_dto.dart`
- `client/app/lib/data/api/dto/spaces_dto.dart`
- `client/app/lib/data/api/dto/sync_dto.dart`
- `client/app/lib/data/api/dto/time_codec.dart`
- `client/app/lib/data/db/daos/dao_scope.dart`
- `client/app/lib/data/db/daos/local_store.dart`
- `client/app/lib/data/db/database.dart`
- `client/app/lib/data/db/database_manager.dart`
- `client/app/lib/data/db/schema.drift`
- `client/app/lib/data/db/tables.dart`
- `client/app/lib/data/repositories/auth_repository.dart`
- `client/app/lib/data/repositories/local_mutations_repository.dart`
- `client/app/lib/data/repositories/records_repository.dart`
- `client/app/lib/data/services/app_settings_service.dart`
- `client/app/lib/data/services/blob_cache_service.dart`
- `client/app/lib/data/services/crash_reporter_service.dart`
- `client/app/lib/data/services/device_context_service.dart`
- `client/app/lib/data/services/file_log_sink_service.dart`
- `client/app/lib/data/services/jpeg_sanitizer_service.dart`
- `client/app/lib/data/services/log_redactor_service.dart`
- `client/app/lib/data/services/media_service.dart`
- `client/app/lib/data/services/session_store_service.dart`
- `client/app/lib/data/services/version_handshake_service.dart`
- `client/app/lib/data/sync/background_sync.dart`
- `client/app/lib/data/sync/conflict_service.dart`
- `client/app/lib/data/sync/membership_reconciler.dart`
- `client/app/lib/data/sync/outbox_processor.dart`
- `client/app/lib/data/sync/pull_applier.dart`
- `client/app/lib/data/sync/sync_engine.dart`
- `client/app/lib/data/sync/sync_policy.dart`
- `client/app/lib/data/sync/sync_triggers.dart`
- `client/app/lib/domain/entity_ref.dart`
- `client/app/lib/domain/outbox_operation.dart`
- `client/app/lib/domain/partition.dart`
- `client/app/lib/domain/result.dart`
- `client/app/lib/domain/sync_state.dart`
- `client/app/lib/features/auth/view/auth_shell.dart`
- `client/app/lib/features/auth/view/change_password_screen.dart`
- `client/app/lib/features/auth/view/login_screen.dart`
- `client/app/lib/features/auth/view/server_address_screen.dart`
- `client/app/lib/features/auth/view/session_status_screen.dart`
- `client/app/lib/features/auth/view_model/auth_ui_state.dart`
- `client/app/lib/features/auth/view_model/auth_view_model.dart`
- `client/app/lib/features/auth/widgets/auth_frame.dart`
- `client/app/lib/features/auth/widgets/switch_partition_prompt.dart`
- `client/app/lib/l10n/app_en.arb`
- `client/app/lib/l10n/app_zh.arb`
- `client/app/lib/main_dev.dart`
- `client/app/lib/main_prod.dart`
- `client/app/pubspec.yaml`
- `client/app/test/data/additional_sync_test.dart`
- `client/app/test/data/api_contract_test.dart`
- `client/app/test/data/auth_repository_test.dart`
- `client/app/test/data/conflict_test.dart`
- `client/app/test/data/dao_scope_test.dart`
- `client/app/test/data/generated_migration_test.dart`
- `client/app/test/data/media_and_logs_test.dart`
- `client/app/test/data/migration_test.dart`
- `client/app/test/data/partition_and_lease_test.dart`
- `client/app/test/data/sync_test.dart`
- `client/app/test/data/sync_triggers_test.dart`
- `client/app/test/features/auth_golden_test.dart`
- `client/app/test/features/auth_screens_test.dart`
- `client/app/test/features/auth_view_model_test.dart`
- `client/app/test/fixtures/jpeg_fixture.dart`
- `client/app/test/server/local_sync_server_test.dart`
- `client/app/test/support/memory_stores.dart`
- `client/app/test/support/sync_harness.dart`
- `client/dart_test.yaml`
- `client/test/check_rules_test.dart`
- `client/tool/allowed_deps.yaml`
- `client/tool/c2-negative-controls.json`
- `client/tool/check_rules.dart`
- `client/tool/server-it.sh`
- `client/app/lib/domain/required_value.dart`
- `client/app/lib/app/background_entrypoint.dart`
- `client/app/test/data/external_connection_test.dart`

## 构建机第一轮反馈修正

- 修复后台 Result 的泛型收窄；日志测试通过 Logger.log 捕获带 object 的 LogRecord；HttpOverrides 保存 current，结束时恢复 global。
- 可空必填值使用 requireValue 显式校验，不批量添加 !；错误不包含原值。金额校验先读取局部变量以便类型提升。
- 源文件统一 package imports 和 80 列换行；构造器在第二轮已全部恢复传统写法；长 SQL 使用相邻字符串，复杂 SQL 投影/赋值表达式提取局部变量。没有添加源码 lint ignore；第二轮仅按用户决定关闭 unnecessary_type_name_in_constructor，原因见后文。
- analysis_options 只增加 generated_migrations 目录 exclude。生成文件以本轮开始时的 SHA-256 清单复核，内容未改动。
- 新增 download_accepts_cleaned_bytes_under_uploaded_content_hash 回归测试：地址中的上传哈希与返回字节无关时仍返回下载结果。保留下载语义注释，不对下载内容比对哈希。
- 19 条负对照随排版更新 find / find_regex；所有锚点各匹配一次，没有写入故意改坏的代码。
- 本机通过行宽、词法括号、依赖白名单、生成文件哈希、负对照锚点和 git diff --check 静态检查；仍未执行 Dart format / analyze 或 Flutter 测试，不能把它们当成“零诊断已验证”。构建机需复跑生成、格式化、分析和测试。

本轮修改以下 Dart 源文件/测试，另修改 analysis_options.yaml、app/pubspec.yaml（仅依赖排序）、tool/allowed_deps.yaml、tool/c2-negative-controls.json 和本说明。没有修改生成文件、lockfile、PNG、docs 或 server。

- `client/app/lib/app/background_entrypoint.dart`
- `client/app/lib/app/bootstrap.dart`
- `client/app/lib/app/partition_host.dart`
- `client/app/lib/app/providers.dart`
- `client/app/lib/app/router.dart`
- `client/app/lib/app/runtime.dart`
- `client/app/lib/data/api/api_client.dart`
- `client/app/lib/data/api/api_error.dart`
- `client/app/lib/data/api/dio_api_client.dart`
- `client/app/lib/data/api/dto/auth_dto.dart`
- `client/app/lib/data/api/dto/client_logs_dto.dart`
- `client/app/lib/data/api/dto/meta_dto.dart`
- `client/app/lib/data/api/dto/problem_dto.dart`
- `client/app/lib/data/api/dto/spaces_dto.dart`
- `client/app/lib/data/api/dto/sync_dto.dart`
- `client/app/lib/data/api/dto/time_codec.dart`
- `client/app/lib/data/db/daos/dao_scope.dart`
- `client/app/lib/data/db/daos/local_store.dart`
- `client/app/lib/data/db/database.dart`
- `client/app/lib/data/db/database_manager.dart`
- `client/app/lib/data/db/tables.dart`
- `client/app/lib/data/repositories/auth_repository.dart`
- `client/app/lib/data/repositories/local_mutations_repository.dart`
- `client/app/lib/data/repositories/records_repository.dart`
- `client/app/lib/data/services/app_settings_service.dart`
- `client/app/lib/data/services/blob_cache_service.dart`
- `client/app/lib/data/services/crash_reporter_service.dart`
- `client/app/lib/data/services/device_context_service.dart`
- `client/app/lib/data/services/file_log_sink_service.dart`
- `client/app/lib/data/services/jpeg_sanitizer_service.dart`
- `client/app/lib/data/services/log_redactor_service.dart`
- `client/app/lib/data/services/media_service.dart`
- `client/app/lib/data/services/session_store_service.dart`
- `client/app/lib/data/services/version_handshake_service.dart`
- `client/app/lib/data/sync/background_sync.dart`
- `client/app/lib/data/sync/conflict_service.dart`
- `client/app/lib/data/sync/membership_reconciler.dart`
- `client/app/lib/data/sync/outbox_processor.dart`
- `client/app/lib/data/sync/pull_applier.dart`
- `client/app/lib/data/sync/sync_engine.dart`
- `client/app/lib/data/sync/sync_policy.dart`
- `client/app/lib/data/sync/sync_triggers.dart`
- `client/app/lib/domain/entity_ref.dart`
- `client/app/lib/domain/outbox_operation.dart`
- `client/app/lib/domain/partition.dart`
- `client/app/lib/domain/required_value.dart`
- `client/app/lib/domain/result.dart`
- `client/app/lib/features/auth/view/auth_shell.dart`
- `client/app/lib/features/auth/view/change_password_screen.dart`
- `client/app/lib/features/auth/view/login_screen.dart`
- `client/app/lib/features/auth/view/server_address_screen.dart`
- `client/app/lib/features/auth/view/session_status_screen.dart`
- `client/app/lib/features/auth/view_model/auth_ui_state.dart`
- `client/app/lib/features/auth/view_model/auth_view_model.dart`
- `client/app/lib/features/auth/widgets/auth_frame.dart`
- `client/app/lib/features/auth/widgets/switch_partition_prompt.dart`
- `client/app/test/data/additional_sync_test.dart`
- `client/app/test/data/api_contract_test.dart`
- `client/app/test/data/auth_repository_test.dart`
- `client/app/test/data/conflict_test.dart`
- `client/app/test/data/dao_scope_test.dart`
- `client/app/test/data/external_connection_test.dart`
- `client/app/test/data/generated_migration_test.dart`
- `client/app/test/data/media_and_logs_test.dart`
- `client/app/test/data/migration_test.dart`
- `client/app/test/data/partition_and_lease_test.dart`
- `client/app/test/data/sync_test.dart`
- `client/app/test/data/sync_triggers_test.dart`
- `client/app/test/features/auth_golden_test.dart`
- `client/app/test/features/auth_screens_test.dart`
- `client/app/test/features/auth_view_model_test.dart`
- `client/app/test/fixtures/jpeg_fixture.dart`
- `client/app/test/server/local_sync_server_test.dart`
- `client/app/test/support/memory_stores.dart`
- `client/app/test/support/sync_harness.dart`
- `client/test/check_rules_test.dart`
- `client/tool/check_rules.dart`

## 构建机第二轮反馈修正

### 文档没写清、我是这么做的：构造器语法与 lint

第二轮构建证明，factory new.fromJson、const factory new 和 new._ 不能被当前 dart format / freezed 正确解析。按用户明确决定，全部构造器统一恢复 ClassName(...)、const factory ClassName(...)、factory ClassName.fromJson(...)、ClassName._(...) 的传统写法，包括 app、测试与 jiabu_design 中的声明。

仅在 analysis_options.yaml 的 linter.rules 中设置 unnecessary_type_name_in_constructor: false，避免这条 lint 再次引导到与当前工具链不兼容的声明写法。没有关闭 unnecessary_constructor_name，没有添加源码 ignore。无多余的 ClassName.new(...) 调用；SyncTriggers 中 Timer.new 是所需的构造器函数引用，保留。

### 类型与生成契约核对

- 本轮日志中 42 个不同的“类型 + getter”组合都能在源构造器参数中找到：包括 AuthUiState.partitionRevision、UserDto.locale、ProblemDto.code/status/requestId/retryAfter。当前工作树的对应 Freezed mixin 也包含这些 getter；生成文件未修改。
- toJson / copyWith 和 _$...FromJson 的报错均对应 Freezed / json_serializable 的生成契约，未手写替代 getter、copyWith 或生成类。
- 所有 17 个 part 指令均有匹配的注解与生成入口，无无用 part。日志中的 7 个 uri_does_not_exist 与 6 个 uri_has_not_been_generated 对应下表；当前本机已有这些目标文件，构建机仍需重新生成确认一致性。

| 源文件（app/lib 下） | 生成目标 | 注解 / 入口 |
| --- | --- | --- |
| data/api/dto/auth_dto.dart | auth_dto.freezed.dart、auth_dto.g.dart | @freezed + factory fromJson |
| data/api/dto/client_logs_dto.dart | client_logs_dto.freezed.dart、client_logs_dto.g.dart | @freezed + factory fromJson |
| data/api/dto/meta_dto.dart | meta_dto.freezed.dart、meta_dto.g.dart | @freezed + factory fromJson |
| data/api/dto/problem_dto.dart | problem_dto.freezed.dart、problem_dto.g.dart | @freezed + factory fromJson |
| data/api/dto/spaces_dto.dart | spaces_dto.freezed.dart、spaces_dto.g.dart | @freezed + factory fromJson |
| data/api/dto/sync_dto.dart | sync_dto.freezed.dart、sync_dto.g.dart | @freezed + factory fromJson |
| features/auth/view_model/auth_ui_state.dart | auth_ui_state.freezed.dart | @freezed；无 JSON 序列化需求，不声明 .g.dart |

其余 4 个 part 分别为 providers / router / auth_view_model 的 Riverpod 输出，以及 database 的 drift 输出，注解均存在。

### 其余诊断

- 为 SpaceDto / PushResultDto 的 5 处回调补显式参数类型，恢复生成后不会依赖 dynamic 推断。
- switch_on_type 的 4 条诊断涉及 3 处 switch（其中 outbox 重复报告）：locale 源字段为 String，result.status 为 String，state.page 为 AuthPage。它们是生成失败后的连带类型错误；保留对值进行 switch 的代码，不改成按 Type 分支。
- 为 outbox 的异步冲突条件补大括号；删除 UUID 正则第一段无用的 raw 前缀；日志测试字符串改在空白处分段；golden 路径去掉多余插值大括号；规则测试第二段字符串改为单引号。
- 保留构建机已格式化的文件布局，只对回退后变长的构造器、原本格式化失败的声明及上述诊断做局部排版。19 条负对照已按当前文本刷新精确 find，正则仍各匹配一次。
- 下载原图继续直接接收服务端清理后的字节，不按上传哈希校验；相关注释和回归测试保留。

本机不运行 Dart / Flutter 或代码生成，不手改生成文件；零诊断与生成一致性仍需构建机复验。

本轮修改的源文件 / 测试如下，另修改 analysis_options.yaml、tool/c2-negative-controls.json 和本说明：

- `client/app/lib/app/app.dart`
- `client/app/lib/app/partition_host.dart`
- `client/app/lib/app/runtime.dart`
- `client/app/lib/data/api/api_error.dart`
- `client/app/lib/data/api/dio_api_client.dart`
- `client/app/lib/data/api/dto/auth_dto.dart`
- `client/app/lib/data/api/dto/client_logs_dto.dart`
- `client/app/lib/data/api/dto/meta_dto.dart`
- `client/app/lib/data/api/dto/problem_dto.dart`
- `client/app/lib/data/api/dto/spaces_dto.dart`
- `client/app/lib/data/api/dto/sync_dto.dart`
- `client/app/lib/data/db/daos/local_store.dart`
- `client/app/lib/data/db/database.dart`
- `client/app/lib/data/db/database_manager.dart`
- `client/app/lib/data/repositories/auth_repository.dart`
- `client/app/lib/data/repositories/local_mutations_repository.dart`
- `client/app/lib/data/repositories/records_repository.dart`
- `client/app/lib/data/services/app_settings_service.dart`
- `client/app/lib/data/services/blob_cache_service.dart`
- `client/app/lib/data/services/crash_reporter_service.dart`
- `client/app/lib/data/services/device_context_service.dart`
- `client/app/lib/data/services/file_log_sink_service.dart`
- `client/app/lib/data/services/jpeg_sanitizer_service.dart`
- `client/app/lib/data/services/log_redactor_service.dart`
- `client/app/lib/data/services/media_service.dart`
- `client/app/lib/data/services/session_store_service.dart`
- `client/app/lib/data/services/version_handshake_service.dart`
- `client/app/lib/data/sync/conflict_service.dart`
- `client/app/lib/data/sync/membership_reconciler.dart`
- `client/app/lib/data/sync/outbox_processor.dart`
- `client/app/lib/data/sync/pull_applier.dart`
- `client/app/lib/data/sync/sync_engine.dart`
- `client/app/lib/data/sync/sync_triggers.dart`
- `client/app/lib/domain/entity_ref.dart`
- `client/app/lib/domain/outbox_operation.dart`
- `client/app/lib/domain/partition.dart`
- `client/app/lib/domain/result.dart`
- `client/app/lib/features/auth/view/auth_shell.dart`
- `client/app/lib/features/auth/view/change_password_screen.dart`
- `client/app/lib/features/auth/view/login_screen.dart`
- `client/app/lib/features/auth/view/server_address_screen.dart`
- `client/app/lib/features/auth/view/session_status_screen.dart`
- `client/app/lib/features/auth/view_model/auth_ui_state.dart`
- `client/app/lib/features/auth/widgets/auth_frame.dart`
- `client/app/lib/features/auth/widgets/switch_partition_prompt.dart`
- `client/app/lib/features/catalog/catalog_cases.dart`
- `client/app/lib/features/catalog/catalog_screen.dart`
- `client/app/lib/features/home/view/blank_screen.dart`
- `client/app/test/data/media_and_logs_test.dart`
- `client/app/test/data/sync_triggers_test.dart`
- `client/app/test/features/auth_golden_test.dart`
- `client/app/test/server/local_sync_server_test.dart`
- `client/app/test/support/sync_harness.dart`
- `client/packages/jiabu_design/lib/src/components/amount_text.dart`
- `client/packages/jiabu_design/lib/src/components/hand_circle.dart`
- `client/packages/jiabu_design/lib/src/components/hand_text.dart`
- `client/packages/jiabu_design/lib/src/components/hand_underline.dart`
- `client/packages/jiabu_design/lib/src/components/jiabu_icon.dart`
- `client/packages/jiabu_design/lib/src/components/note_bubble.dart`
- `client/packages/jiabu_design/lib/src/components/paper_background.dart`
- `client/packages/jiabu_design/lib/src/components/paper_card.dart`
- `client/packages/jiabu_design/lib/src/components/paper_sheet.dart`
- `client/packages/jiabu_design/lib/src/components/paper_snack_bar.dart`
- `client/packages/jiabu_design/lib/src/components/pencil_strike.dart`
- `client/packages/jiabu_design/lib/src/components/polaroid.dart`
- `client/packages/jiabu_design/lib/src/components/stamp.dart`
- `client/packages/jiabu_design/lib/src/components/sticker.dart`
- `client/packages/jiabu_design/lib/src/components/tape.dart`
- `client/packages/jiabu_design/lib/src/components/tilt.dart`
- `client/packages/jiabu_design/lib/src/geometry/paper.dart`
- `client/packages/jiabu_design/lib/src/icons/icon_data.dart`
- `client/packages/jiabu_design/lib/src/theme_context.dart`
- `client/packages/jiabu_design/lib/src/tokens/colors.dart`
- `client/packages/jiabu_design/lib/src/tokens/decor.dart`
- `client/packages/jiabu_design/lib/src/tokens/motion.dart`
- `client/packages/jiabu_design/lib/src/tokens/type.dart`
- `client/packages/jiabu_design/test/support/font_sources.dart`
- `client/test/check_rules_test.dart`
- `client/tool/check_rules.dart`

## 构建机第三轮反馈修正与独立审查

审查依据：`docs/engineering/technical-design.md` 5.1–5.8、9.1–9.4，`client-flutter.md` 3.x / 5，实施计划 C2，以及 `/home/avatar1/zylos/workspace/jiabu-c2/brief.md`。S4 行为直接核对当前 server 的 sync 服务、blob handler、错误与限流实现；只读这些文件。

### 界面结论与修正

- **成立：表单子项没有间距。** AuthFrame 的 Column 统一使用现有 `context.jiabu.decor.cardGap`，覆盖标题、进度条、输入框、按钮、错误提示之间的间距。
- **部分成立：错误缺主题色和播报，但当前源码没有四分之三宽的额外约束。** 原 Column 已 stretch；360 宽扣除卡片外、内各一层 16 的 inset 后，正文内宽是 296。正文 token 为 15，200% 时 10 字约需 300，句号不能单独放行首，因而可能出现“用户名或密码不正 / 确。”，不能仅凭墨迹长度认定约束缩窄。现在显式给卡片父节点可用全宽、错误 Text 使用 parent 宽度和主题 bodyMedium / colorScheme.error，并加 liveRegion。新增测试检查错误与输入框同宽、等于卡片内宽，以及可访问性标签；不压缩字号、不禁止正常换行。
- **成立：切换提示需要额外装饰留白。** PaperSheet 本身已有 handle 下方间距；SwitchPartitionPrompt 再加一个 cardGap 顶部留白，各操作之间也用 cardGap。新增大字号几何断言。

### 同步审查结论（结论在前）

| 项目 | 结论、理由与落地 |
| --- | --- |
| `blob:` 依赖缺少 blobs_local 行 | **成立，已修。** RecordsRepository.create 可接受带 hash 的参数；旧的缓存过期逻辑也可能删除 failed / blocked 条目还在引用的 uploaded 行。因此缺行实际可能发生。现在缺行与 uploaded != 1 都等待，不上传该引用；无关条目仍能发送，等待项不领取租约、不增加 attempts。 |
| 原图缓存过期与依赖 | **成立，已修。** 缓存过期跳过仍被 outbox 引用的原图及其上传凭据（包括 failed / blocked）；条目确认后恢复正常过期。修改记录和“用我的”解决冲突时，服务器当前版本中保留的附件不再要求本机上传凭据，避免已清理缓存的服务器附件被误挡。新增附件仍必须等待对应 blob。 |
| 重新导入原图的恢复顺序 | **成立，已修。** 新 blob 若排在已经等待该 hash 的条目之后，会与它互相等待。MediaService 入队 blob 后，调用 DAO 将依赖项及其后续修改按原顺序移到新 blob 后；不只移动直接依赖项，避免把后来的同实体修改错误地提前。新增原图 → 新建记录 → 后续修改的回归测试。 |
| 更早 failed 条目让同实体后续等待 | **不成立为缺陷，保持。** 5.2 明确说“更早的、还没确认成功的”，failed 不等于成功，且永久拒绝保留给用户重试；交付说明既有 G0 第 3 条也明确包含 failed / blocked。新增测试验证用户重试前等待，重试成功后后续条目继续。不静默越过失败修改。 |
| 原图读文件抛 FileSystemException | **部分成立，已修。** 原代码不会永久卡死：租约到期或重新启用分区可回收 sending；但此前会滞留最多 12 分钟，再次失败还会走通用异常日志。现在直接异步读取并捕获文件系统异常，转换为固定 local_blob_unreadable，沿 ApiError 路径退回 pending、清 lease、指数退避。异常文字和文件路径不入 last_error；退避期间触发同步不增加尝试次数。文件恢复后使用同一个 op_id / request_id 重试。 |
| HTTP 401 | **不成立为缺陷。** tool / blob 均回 pending 后上抛，SyncEngine 进入 loginRequired、失效本机认证；实际令牌清理由已有认证回调处理，分区和队列保留。新矩阵测试覆盖两种上传；已有 401_clears_token_stops_sync_and_keeps_partition 覆盖令牌。 |
| HTTP 426 | **不成立为缺陷。** tool / blob 均保留队列并上抛，写入门禁关闭、meta 强制刷新；不会立即重放写请求。已有 426_interceptor_and_engine_do_not_refresh_meta_twice 验证拦截器与引擎不重复刷新。新矩阵补两种上传的门禁与队列断言。 |
| 批内 / HTTP 429 | **不成立为缺陷。** S4 的批内 rejected + problem.status=429 / retry_after 已映射到 pending + retry_at；HTTP 层从 problem 或 Retry-After 取秒数，tool / blob 都退避。批内已有 rejected_429_is_retryable_and_honors_retry_after；新矩阵补 HTTP 429。 |
| 原图 503 upload_busy + Retry-After | **不成立为缺陷。** S4 upload handler 返回 503、retry_after=1，错误封装发 Retry-After；Dio 正确读取，OutboxProcessor 保留 pending。已有 upload_busy_retries_after_header_without_failed_state 和 problem_json_maps_code_request_id_status_and_retry_header；新矩阵补边界前不重发、边界后成功。 |
| DioException 字符串化泄露 URL / Authorization | **不成立为缺陷。** 生产日志落盘只接收 Redactor 的允许列表结果；任意 message / object / error 原文都不序列化，仅固定事件、允许代码、UUID request_id 和过滤堆栈。新增专项测试实际记录带查询串、Authorization、PAT、原话的 DioException 字符串和异常对象，检查落盘及上报均不含这些信息。无须改生产脱敏逻辑。 |
| 修改记录的新实体引用 | **成立，已修。** create 登记账户、用途和标签依赖，update 原先只登记附件；若新建账户 / 标签失败，引用它的 update 会先发并被永久拒绝。update 现在也登记四类账户字段及 tag_ids；五个回归测试验证失败依赖先等待、用户重试后分批成功。 |
| 聊天同步检查点倒退（9.1） | **成立，已修。** pull 原先无条件替换 synced 聊天行，并对 pending 聊天行直接跳过。现在 rev=0 且 last_seq 小于本机时跳过该行，但仍推进分页游标；rev>=1 始终替换，rev=0 的相等 / 较新检查点也可替换。rev / last_seq 直接保留在既有 data_json，无 schema 或生成变更，不增加 C5 上传器。 |

其余核对：5.1 同步顺序与当前空间优先分页、5.3 整批事务、5.5 base_version / pending 跳过 / conflict 回写、5.6 空间与模块清除及迟到响应 fence、5.7 分库、9.4 JPEG 元数据清理与哈希、日志滚动和上报快照均未发现本轮可确认的额外缺陷。9.3 卡片 UI 属于后续 C3 / C5 / C6，本轮不增加实现。

### 文档没写清、我是这么做的

- 缺失 blob 上传凭据时，客户端无法判断是原图未上传还是凭据丢失，采用不发送的保守行为，保留 pending 和内容，不自动猜测服务器已有图。已有服务器附件在 update / 冲突解决中原样保留时不需要本机凭据。新依赖缺凭据需要重新导入同一张图；C2 没有修复依赖的界面，后续需提供重新选图 / 处理失败项入口。
- 30 天原图缓存保留与长期 failed / blocked 队列的优先级未明确：队列仍引用时延后清理，优先保证可重试；确认后可在本轮末清理。只有冲突快照、没有 outbox 引用的原图仍按既有 30 天规则清理；很久后解决冲突若新附件凭据已缺失，会保守等待重新选图。
- 文件读取异常不能仅凭 FileSystemException 区分临时挂载问题、权限问题或删除；统一保留 pending 并退避，不把一次 IO 失败标成不可恢复。后台重试与前台既有触发负责后续尝试，没有添加每秒重试定时器。

### 本轮新增测试名

`app/test/data/sync_audit_test.dart`：

- `missing_blob_metadata_blocks_reference_but_not_unrelated`
- `queued_blob_receipt_survives_retention_until_reference_ack`
- `blob_read_failure_releases_lease_and_backs_off`
- `failed_predecessor_waits_for_user_retry`
- `retained_server_attachment_needs_no_local_receipt`
- `conflict_retained_server_attachment_needs_no_local_receipt`
- `record_update_waits_for_new_reference_{account_id,to_account_id,purpose_id,to_purpose_id,tag_ids}`（5 条）
- `{tool,blob}_http_{401,426,429,503}_preserves_operation_for_retry`（8 条）
- `pull_checkpoint_cannot_roll_back_chat_sequence`
- `pull_chat_accepts_rev_0_sequence_20`、`pull_chat_accepts_rev_0_sequence_21`、`pull_chat_accepts_rev_1_sequence_10`

`app/test/data/media_and_logs_test.dart`：`dio_exception_url_headers_and_string_are_redacted`、`reimported_blob_preserves_waiting_record_edit_order`。

`app/test/features/auth_screens_test.dart`：`auth_form_gaps_and_error_use_full_inner_width`、`switch_tape_has_clearance_at_large_text`。

修复前断言失败的对应关系：缺行测试原先会发送 dependent；保留缓存测试原先找不到 uploaded 行；读失败测试原先得到 sending；update 引用测试原先已发送 update；旧检查点测试原先得到 last_seq=10；pending 聊天接受测试原先仍是本机文字；附件保留测试原先会多登记 blob 依赖；重新导入测试原先会提前发送，只有加缺行守护而不调整恢复顺序则最终不能清空队列。错误色 / 语义 / 间距断言也针对旧实现缺项。文件系统读失败用 IOOverrides 固定注入，不依赖 chmod、进程用户权限或平台私有路径。以上是源码对应关系，本机没有执行 Dart 测试，不能声称已实测修前红 / 修后绿。

### 本轮文件与验证边界

本轮仅改以下 14 个文件：

- `client/C2-DELIVERY.md`
- `client/app/lib/features/auth/widgets/auth_frame.dart`
- `client/app/lib/features/auth/widgets/switch_partition_prompt.dart`
- `client/app/lib/data/sync/outbox_processor.dart`
- `client/app/lib/data/sync/conflict_service.dart`
- `client/app/lib/data/sync/pull_applier.dart`
- `client/app/lib/data/repositories/records_repository.dart`
- `client/app/lib/data/services/blob_cache_service.dart`
- `client/app/lib/data/services/media_service.dart`
- `client/app/lib/data/db/daos/local_store.dart`
- `client/app/test/data/sync_audit_test.dart`（新文件）
- `client/app/test/data/media_and_logs_test.dart`
- `client/app/test/features/auth_screens_test.dart`
- `client/tool/c2-negative-controls.json`（只更新 blob 守护的精确 / 正则锚点，仍为 19 条）

协调者的两份 dart_test.yaml、server-it.sh、server 测试文件保持本轮开始时字节不变；C2-DELIVERY.md 的 --preset 修正保留。生成文件 / lockfile / PNG / docs / server 的哈希与本轮开始时相同，不提交 git。

本机静态检查：19 条负对照的精确与正则锚点各匹配一次；本轮改动文件无 whitespace 问题。全工作树 git diff --check 仍报告三个已有生成文件尾空格（auth_dto.freezed.dart 两处、auth_ui_state.freezed.dart 一处），按要求未修改。请构建机重跑 format、analyze、check_rules、新增及既有非 golden 测试，并按本轮授权重新生成 / 审查 auth golden；不把第三轮反馈中的 1504 条通过当作本轮改动已验证。

## 构建机实测结果（luna.coco）

- `flutter analyze --fatal-infos` 0 条；`dart format --set-exit-if-changed` 通过；`tool/check_rules.dart` 通过；build_runner 与 drift schema dump / generate 重跑后与提交内容一致。
- `app/` 默认 `flutter test`：1531 通过，`server` 标签的 5 个集成测试显示为跳过；`client/test`（规则测试）50 通过。
- 登录 / 改密码 / 地址设置 / 会话状态 / 切换提示共 22 种状态 × 中英 × 两套主题色 × 360/430 宽 × 100%/200% 字号 = 352 张 golden，在构建机生成并人工抽看。
- `tool/server-it.sh`：真实服务端（master 2a098c1，独立 PostgreSQL 18 实例）5 个场景全过。
- 负对照 19 条逐条在构建机改坏，全部由对应测试以断言失败抓住，恢复后通过。

### 构建机环境说明（不进仓库）

构建机是 Ubuntu 20.04（glibc 2.31）。`sqlite3` 3.8.0 默认下载的预编译 Linux 库需要 glibc ≥ 2.33，主机上的 Flutter 单元测试因此加载不了 SQLite；本地钩子编译又需要 clang（构建机没有）。处理：在构建机上用 gcc 从 sqlite.org 官方 3.54.0 合并源码（与 sqlite3 3.8.0 自带版本相同，编译选项按包文档的默认集）编出一份共享库，**只在构建机的同步副本**里给 `client/pubspec.yaml` 追加 `hooks.user_defines.sqlite3`（`linux: system` + 绝对路径 `name`）。仓库里的 pubspec 不变：CI 镜像（Ubuntu 24.04）与 Android / iOS 照常用包自带的预编译库，未引入 `sqlite3_flutter_libs`。

### 发现的服务端缺口（未改 `server/`）

master 的 `server/Cargo.lock` 落后于 Cargo.toml：S4 引入的 image / kamadak-exif / zune-jpeg 等 18 个包不在锁文件里，`cargo build --locked` 失败（server CI 不带 `--locked`，所以没暴露）。`tool/server-it.sh` 保留 `--locked`；本次实测在构建机临时副本里去掉了 `--locked` 运行。建议单独一个服务端 PR 补锁文件，并让 server CI 带 `--locked`。

## PR 评审修正

本节对应 PR #10 的四条评审。每条均先补回归测试、再改对应行为；第 2 条为了测试真实 runtime 创建路径，先为原有工厂加入可选的 settings / database / session / device / Dio 注入，不改变默认行为，再写测试、修渠道选择。未提交 git。此次只修改下列客户端源文件、测试和交付清单；没有修改 docs/、server/、生成文件或 PNG。

### 1. 冲突解决保留所需 blob 前置顺序

- `LocalStore.deferDependents` 不再从第一个依赖项开始移动整个队尾。只移动直接依赖冲突实体的条目，并沿被移动条目的 entity_ids 继续移动后续修改和下游依赖；解决操作自身和无关的 blob 前置条件保持原位置。只调整 created_at，保留 op_id、request_id 和 payload。
- 新测试 `resolve_mine_keeps_required_blob_ahead_of_resolution`：R 请求在途时排入退款、退款后续修改、blob B、R 的附件修改；R 返回 409 后 B 上传报 network。用我的后断言顺序为 B → R 解决操作 → 退款 → 退款后续修改；重试后队列清空、B 已上传、R 已引用 B，并核对退款身份及参数不变。
- 修前源码推导模型得到 resolution → refund → B；resolution 等未上传的 B，B 又与更早 resolution 的引用交叠，两个均无法领取。此为源码推导模型复现，尚不是 Flutter 动态复现。

### 2. 前后台使用同一渠道

- 前台 `AppRuntime.create` 在 bootstrap 注册后台任务之前，将入口渠道写入 App 级 `client_channel` 设置。后台通过无缓存的 `SharedPreferencesAsync` 读取该设置；缺失或无效值回退 stable，读取失败则创建失败，不创建 beta worker。合法 beta 设置仍保留，前台后续 stable 启动会覆盖旧 beta 设置。
- 同一个 runtime 的 `DeviceContext.channel` 同时用于 `VersionHandshakeService` 和 `X-Jiabu-Client`，不再分别选渠道。
- 新测试 `stable_entry_background_handshake_and_client_header_are_stable` 使用与 main_prod → bootstrap 相同的 `create(channel: 'stable')` 参数，再用 dispatcher 相同的 `create(background: true)` 参数创建后台 runtime。通过真实 Dio 拦截器和内存 adapter 检查所有前后台请求头、实际同步引擎握手的渠道，以及 stable 最低构建 2 / beta 最低构建 0 / 当前构建 1 时后台保留写入门禁、不上传。
- 补充 `background_channel_from_settings_missing`、`background_channel_from_settings_invalid`、`background_channel_from_settings_beta`，覆盖缺失、无效值和合法 beta。

### 3. 用我的版本保留撤销意图

- mine 为 voided、server 为 active 时重新排 `void_record`；发送时仍绑定最新服务器 base_version。void 操作不需要上传 mine 中尚未发布的附件。其他普通状态仍生成 update。
- 新测试 `resolve_mine_preserves_void_intent_after_version_conflict` 从真实的乐观 void_record 入队开始，制造另一设备先改后的 409，检查 mine 状态与原因、解决操作类型、expected_version，以及完成后的本机 / 假服务器均为 voided、synced。假服务器的 void / restore 原因字段同步按真实服务端语义处理。
- 已核对 technical-design 5.5“撤销优先”：server_status=voided 时仍拒绝普通“用我的”（explicit_restore_required），只有显式“恢复并改成我的版本”才排 restore_record → update_record。已有 `voided_mine_requires_explicit_restore`、`restore_then_update_use_successive_server_versions`、`restoring_mine_keeps_refund_behind_restore_and_update` 继续覆盖这些边。
- **接口限制**：当前服务端 `VersionedRecord` 带 deny_unknown_fields，仅接受 id / expected_version；`ledger_record_status` 固定写 void_reason='user'。因此不能把原 void_reason 加到请求参数，否则会变成 422。客户端保持 mine 中原原因直至服务器确认；标准 user 原因可完整保留，自定义原因无法通过当前接口保留。本轮不修改 server，也不声称已满足任意原原因的服务端往返。此限制已向用户询问；未收到进一步指示时按现有严格接口兼容处理。
- 修前源码推导模型确认 update_record 的可编辑字段没有 status / void_reason，voided mine 会被提交为普通字段修改，服务器仍 active。尚未执行 Flutter 动态复现。

### 4. 令牌读取异常结束请求与同步轮

- Dio 请求拦截器捕获 token 读取的异常，以 unknown 类型、规范化 `ApiError('token_unavailable')` 经 handler.reject 结束请求；不附带原异常或异常文本，拒绝后立即 return。
- `token_read_failure_rejects_request_without_sensitive_error` 检查 DioException 类型、错误码、无敏感异常文本且未触达 adapter。
- `token_read_failure_finishes_round_releases_lease_and_can_retry` 使用真实 DioApiClient + SyncEngine + drift，检查一轮结束、round_owner / round_lease_until 清空、心跳取消，并能开始第二轮。现有 SyncEngine 的 finally / whenComplete 即可完成清理，无需修改引擎。
- 测试用隔离 zone 接住修前逃逸的异步错误，并设短超时和心跳清理，防止回归时测试自身无限挂起。

### 新增负对照

清单 `tool/c2-negative-controls.json` 从 19 条增为 21 条；新增两条的精确 find / replace 如下。命令均在构建机 `client/app` 目录执行，必须由对应测试产生断言失败，编译失败不计成功。

1. `resolution_keeps_required_blob_ahead`

   文件：`app/lib/data/db/daos/local_store.dart`

   find：`if (shouldDefer) {`

   replace：`if (shouldDefer || deferredEntities.isNotEmpty) {`

   应失败测试：`resolve_mine_keeps_required_blob_ahead_of_resolution`

   命令：`flutter test test/data/conflict_test.dart --plain-name resolve_mine_keeps_required_blob_ahead_of_resolution`

2. `background_uses_foreground_channel`

   文件：`app/lib/app/runtime.dart`

   find：

   ```dart
   final runtimeChannel = background
       ? await appSettings.clientChannel()
       : channel;
   ```

   replace：`final runtimeChannel = background ? 'beta' : channel;`

   应失败测试：`stable_entry_background_handshake_and_client_header_are_stable`

   命令：`flutter test test/data/runtime_channel_test.dart --plain-name stable_entry_background_handshake_and_client_header_are_stable`

### 本次文件与验证状态

本次修改共 11 个文件：

- `client/app/lib/app/runtime.dart`
- `client/app/lib/data/api/dio_api_client.dart`
- `client/app/lib/data/db/daos/local_store.dart`
- `client/app/lib/data/services/app_settings_service.dart`
- `client/app/lib/data/sync/conflict_service.dart`
- `client/app/test/data/conflict_test.dart`
- `client/app/test/data/api_contract_test.dart`
- `client/app/test/data/runtime_channel_test.dart`（新增）
- `client/app/test/support/sync_harness.dart`
- `client/tool/c2-negative-controls.json`
- `client/C2-DELIVERY.md`

本机为 aarch64、没有 Dart / Flutter；调用 Flutter 得到 command not found，访问已配置的 jiabu-build SSH 被网络沙箱拒绝（socket: Operation not permitted）。按 client/AGENTS.md 不在本机安装或执行构建 / 测试。已完成源码推导场景检查、负对照精确 / 正则锚点唯一性检查、测试名与命令对照、改动 whitespace 检查；**没有实际取得修前红 / 修后绿，也未实测新增负对照**。历史章节的构建机通过记录不覆盖本次修改。

构建机待执行（不要运行生成器或更新 PNG）：

```bash
cd client
# 仅格式化本节列出的 Dart 文件，避免改到生成文件。
flutter analyze --fatal-infos
dart run tool/check_rules.dart
cd app
flutter test test/data/conflict_test.dart test/data/runtime_channel_test.dart test/data/api_contract_test.dart
flutter test test/data/sync_test.dart test/data/sync_audit_test.dart test/data/partition_and_lease_test.dart
```

再逐条应用新增负对照、断言失败、恢复，并复跑对应原版测试。当前工作树另有并行的 CI / 字体相关修改，不属于本次文件清单。

### CI 修正（luna.coco）

- push 事件下 git 不信任容器里的检出目录（只有 PR 事件那一步设了 safe.directory），生成一致性检查里的 `git diff` 因此报用法错误退出 129：把 `safe.directory` 提成所有事件都跑的第一步。
- 字体覆盖测试与 `tool/fonts/subset.py` 原本遇到 ICU plural/select 就直接报错；C2 的英文 ARB 用了 plural。两边都改成取出每个分支的文字（plural 里的 `#` 是数字，不计），其他 ICU 参数仍然报错，并加了 Python / Dart 测试。按新规则在构建机重跑 subset：思源宋体子集多了 1 个 C2 新文案里的字（3883 → 3884），manifest 已更新。
- 构建机上集成测试端口：S6 的开发库占着 55462，本次实测改用 PG 55479、HTTP 18481/18482。


### 第二轮：按服务器当前状态 → mine 整体重建

本轮按 PR #10 第二轮结论统一修正冲突重建、依赖与重排；未提交 git。以下替代上轮只重建一个操作的做法。所列 5 条指定回归先写入，再修改生产实现；受环境限制，尚未实测修前失败 / 修后通过。

#### 修法与真实接口边界

- **共用依赖**：新增 `app/lib/data/sync/tool_dependencies.dart`。`LocalMutationsRepository.enqueueTool` 对所有普通工具写入调用它（与调用方额外依赖取并集），`RecordsRepository` 移除原有重复实现；`ConflictService` 对重建的每一个操作调用同一函数。record create / update 的账户四字段、tag_ids、新附件、create 的退款父记录均集中处理；update 依据前一状态排除已保留的服务器附件。`set_allocation_plan` 登记 account 依赖。
- **record**：先用可编辑字段的值差异生成 `update_record.changes`，再按状态差异追加 `void_record`。只撤销且没有字段差异时仅 void。服务器已撤销时保留显式恢复门禁；明确恢复生成 `restore_record → update_record`。每步都不预填 expected_version，仍由 OutboxProcessor 在领取上传时按最新 base_version 绑定，同实体操作逐个确认。回写中间成功只更新 base_version，保留未完成的最终乐观状态。
- **tag**：mine.deleted_at 非空时仅生成 `delete_tag`（服务器已删除则无需操作），不会先 rename；否则只在名称不同且可写时 rename。乐观状态也按实际操作效果合成，删除不把旧 mine 名称覆盖服务器名称。
- **account**：字段不同先 update，再按 archived_at 的空/非空差异 archive；只归档时仅 archive。字段清单补齐服务端真实支持的 `is_reserve`。
- **allocation_plan**：没有单独删除 / 归档工具；enabled 通过 `set_allocation_plan` 双向设置。即使仅 enabled 不同，也发送必填的 amount_minor、day_of_month、enabled 全部三项。
- **空差异**：不制造空 update，直接使用服务器行并解除冲突；不留下没有上传操作的 pending 行。显式 restore 后仍按既有契约排 update。
- **引用闭包重排**：`LocalStore.deferDependents` 将每个被移动条目的 `references = entityIds ∪ dependsOn` 全部加入传播集合，后续共享任一引用的条目都随之前移到解决操作后，保持原先顺序。F(R,T) → 删除T 变为解决R → F → 删除T；无关的 blob / 新建实体前置操作保留在解决操作前。只改 created_at，保留 id、request_id、payload、重试信息。
- **ICU 一致性**：Dart 对 branching 参数名增加 `^\w+$`（默认 ASCII）校验；Python 将参数名、简单占位符和 selector 的 `\w` 改为 `[A-Za-z0-9_]`。两边均加入 `{bad-name, plural, other{A}}` 与非 ASCII 参数名拒绝断言。

已核对只读来源：`server/crates/tools/src/ledger/mod.rs`、`server/crates/tools/src/lib.rs`、`server/crates/domain/src/ledger.rs`、`server/crates/db/src/ledger/writes.rs` 和 `server/openapi/openapi.json`。没有修改 server/。

服务端没有对应工具的转换及保留的限制：

- 没有取消账户归档或恢复已删标签的工具，update_account 也不接收 archived_at。客户端分别返回 `unarchive_not_supported` / `restore_tag_not_supported`，保留冲突和 mine，不排出只能完成部分意图的操作，不把本机状态误标成功。
- 当前工具注册表与 OpenAPI 完全没有 subject / document 写入、删除或归档工具。遇到这些 kind 的“用我的”返回 `unsupported_conflict_resolution` 并保留冲突，不再猜测 `update_subject` / `update_document`。后续服务端有工具后才能补相应重建与依赖规则。
- void_record 仍只接受 id / expected_version，void_reason 固定为 user；自定义原因不能通过当前接口往返。archive/delete 的具体时间也由服务器分配。归档零余额、退款上限等服务端业务约束继续按既有失败/冲突路径处理。
- 服务器 record 已 voided 时仍要求显式恢复，包括双方都 voided 的快照；显式恢复的目标为 active，保留原有交互语义，不隐式恢复后再撤销。

#### 新测试与原有保护

`app/test/data/conflict_test.dart` 新增：

- `resolve_mine_update_then_void_keeps_field_edits`：真实普通 update 与乐观 void 入队后捕获冲突，检查 update → void、参数只含字段差异、分批 expected_version=2/3，以及假服务器最终金额/备注为 mine 且已撤销。
- `resolve_mine_waits_for_new_tag_dependency`：R 请求在途时创建 T 并让 R 引用 T，409 捕获最终 mine；T 创建网络失败进入 pending/退避，解决操作仍等待，重试后先 T 再 R。
- `resolve_mine_tag_delete_is_not_rename`
- `resolve_mine_account_archive_is_preserved`
- `deferral_keeps_shared_reference_order`：解决R → F(R,T) → 删除T，并检查移动条目的身份、请求与参数保留。
- `resolve_mine_equal_fields_needs_no_operation`
- `resolve_mine_archive_only_needs_no_update`
- `resolve_mine_record_rebuilds_all_changed_reference_dependencies`
- `resolve_mine_allocation_plan_enabled_false` / `resolve_mine_allocation_plan_enabled_true`
- `resolve_mine_unsupported_transition_preserves_{account,tag,subject,document}_conflict`（4 条）

原有 `resolve_mine_preserves_void_intent_after_version_conflict` 调整为只有 version 改变、无字段差异，继续要求仅一个 void；原有 `resolve_mine_keeps_required_blob_ahead_of_resolution`、restore → update 和恢复后退款顺序测试均保留。假服务器补齐 flat update/rename/set、delete_tag 和 archive_account 的效果，供最终状态断言使用。

字体测试：Dart 新增 `ICU argument names require ASCII word characters`；Python 新增 `test_icu_argument_name_must_be_ascii_word`，各覆盖非法连字符与非 ASCII 名称。

#### 新增负对照（清单共 23 条）

`tool/c2-negative-controls.json` 新增两条，精确 find / replace 如下；JSON 中另有容忍格式化的 find_regex，均要求唯一匹配。命令 cwd 为 client/app，必须产生断言失败，编译失败不算通过负对照。

1. `deferral_shared_reference_closure`，文件 `app/lib/data/db/daos/local_store.dart`：
   - find：`deferredReferences.addAll(op.references);`
   - replace：`deferredReferences.addAll(op.entityIds);`
   - 测试/命令：`flutter test test/data/conflict_test.dart --plain-name deferral_keeps_shared_reference_order`
2. `resolution_update_before_void`，文件 `app/lib/data/sync/conflict_service.dart`：
   - find：`return Ok(operations);`
   - replace：`return Ok(operations.reversed.toList());`
   - 测试/命令：`flutter test test/data/conflict_test.dart --plain-name resolve_mine_update_then_void_keeps_field_edits`

既有 `resolution_keeps_required_blob_ahead` 的 replace 同步将变量名 deferredEntities 改为 deferredReferences；find 和测试不变。

#### 本轮文件与验证

本轮修改 13 个文件（相对 client/）：

- `app/lib/data/sync/tool_dependencies.dart`（新增）
- `app/lib/data/sync/conflict_service.dart`
- `app/lib/data/repositories/local_mutations_repository.dart`
- `app/lib/data/repositories/records_repository.dart`
- `app/lib/data/db/daos/local_store.dart`
- `app/test/data/conflict_test.dart`
- `app/test/support/sync_harness.dart`
- `packages/jiabu_design/test/support/font_sources.dart`
- `packages/jiabu_design/test/sfnt_cmap_test.dart`
- `tool/fonts/subset.py`
- `tool/fonts/test_subset.py`
- `tool/c2-negative-controls.json`
- `C2-DELIVERY.md`

用户已有 `app/lib/app/partition_host.dart` 的 scope 导入及 `@Dependencies([router])` 原样保留，不计入本轮修改。未改 docs/、server/、生成文件、PNG 或依赖清单；未提交 git。

本机 aarch64，无 Dart / Flutter；按 client/AGENTS.md，只在 x86_64 构建机运行构建和测试。本轮尝试 SSH jiabu-build，被沙箱以 `socket: Operation not permitted` 拒绝。因此 **尚未执行 Flutter/Dart/Python 测试、format/analyze/check_rules，也未取得实际修前红 / 修后绿或负对照断言失败记录**。已完成 Python AST 语法检查、全部 23 条负对照精确/正则锚点唯一性核对、工具参数静态对照及 git diff --check；这些不能代替动态测试。

构建机后续验证（不要运行生成器、字体子集生成或更新 PNG；重任务依 client/README.md 加 nice/ionice，串行执行）：

```bash
cd client
# 先只格式化本轮改动的 Dart 源码/测试。
nice -n 19 ionice -c3 flutter analyze --fatal-infos
dart run tool/check_rules.dart
nice -n 19 ionice -c3 flutter test
cd app
nice -n 19 ionice -c3 flutter test test/data/conflict_test.dart test/data/sync_test.dart test/data/sync_audit_test.dart test/data/media_and_logs_test.dart test/data/partition_and_lease_test.dart
cd ../packages/jiabu_design
nice -n 19 ionice -c3 flutter test
cd ../..
python3 -m unittest discover -s tool/fonts -p 'test_*.py'
```

需在构建机对这 5 条指定测试补跑修前版本的生产代码以确认断言失败；修后全部通过后，再逐条应用两条新负对照，确认断言失败并恢复，最后复跑原版测试。当前环境无法完成这些执行，不将历史通过记录作为本轮证据。

### 第三轮评审修正（luna.coco）

第三轮评审确认第二轮四条已修好，另提一条：模块权限从 `none` 恢复（或首次获得）时只覆盖了权限，没有重置游标，权限收回期间游标已经推进，恢复后从未再改过的旧数据拉不回来。technical-design “授权变化”一条要求“清掉失去权限的模块数据，并把这个空间的游标归零重拉”。修正：任一模块级别变化（收回或恢复）都把该空间游标归零，并递增 `local_generation`，让在途的拉取响应被栅栏丢弃。测试 `module_regain_resets_cursor_and_fences_late_pull`（修前失败）、`unchanged_module_levels_keep_cursor`，负对照 `module_regain_resets_cursor`。

### 第四轮评审修正

第四轮评审确认第三轮修正通过，本轮处理新增的两条中严重度问题。以下回归测试均先于对应生产代码修复写入；受执行环境限制，尚未取得实际修前红 / 修后绿证据。

1. **旧 runtime 不得失效新登录令牌。** `AppRuntime` 的同步认证失效回调和前台数据库监听共用 `authenticationLost`，调用 `invalidate` 时始终传引擎创建时捕获的 generation，由存储事务检查代次。代次不一致时不改共享令牌和 runtime 行，只通过 `LocalAuthRepository.clearLocalSession` 清理旧实例的认证状态、引擎、订阅和本机视图状态。正常同代次失效仍通过原事务撤销认证和删除令牌。
   - `stale_runtime_cannot_invalidate_new_login_token`：两个 AppRuntime 共用 MemorySettings、MemorySessions 和数据库目录，各有独立 DatabaseManager / SQLite 连接。旧 worker resume 并捕获代次后，另一实例退出并以同账号临时密码登录；此时 authenticated=0。旧引擎启动同步后，新令牌与新代次必须保留、旧 runtime 必须清理，随后新实例改密码成功且请求携带新令牌。两个实例均关闭平台触发器以控制时序，认证仓库和 Dio 请求保持真实调用。
   - `runtime_observing_external_logout_only_clears_local_session`：另一实例只退出、不重新登录时，旧 runtime 清理本机状态，不再次递增共享 generation。
   - 修前源码推导：旧 worker 以 persisted generation 调 invalidate，删除新令牌；只有退出的分支也会再次递增 generation。上述分别由令牌断言和代次断言捕获；尚未动态执行。
2. **已有退款的更新、恢复必须依赖原支出。** `toolDependencies` 新建退款从 args 读取 refund_of_id，更新和恢复从 previous 读取，统一登记 `record:<原支出 ID>`。因此 R 冲突期间 F 不领取、不发送，不会因服务器旧金额被拒成 failed；R 用我的版本解决并确认后，F 自动继续。ConflictService 原已传入 previous 并调用同一函数，重建 update / restore 操作也获得该依赖，无须另加路径。
   - `refund_update_waits_while_parent_expense_in_conflict`：服务器已有 R=100、F=20，离线改 R=200、F=150，模拟另一设备引起 R 版本冲突。只发送 R；F 保持 blocked、attempts=0、无失败错误，重复同步也不发 F。
   - `refund_update_continues_after_parent_conflict_resolved`：R 选择我的版本并确认后，按单独批次 R 冲突 → R 解决确认 → F 更新发送，F=150 成功、队列清空。
   - `refund_restore_waits_for_parent_conflict_resolution`：恢复已有的 voided 退款同样先等待 R 冲突解决与确认，再发送 restore_record 并成功。
   - 假 API 按顺序对 R 返回 version_conflict、对父支出金额仍为 100 的 F 返回 refund_exceeds_original；修前源码推导为同批发送 R/F，F 被拒进 failed，不能自动继续。尚未动态执行。

本轮修改 7 个文件（相对 client/）：`app/lib/app/runtime.dart`、`app/lib/data/repositories/auth_repository.dart`、`app/lib/data/sync/tool_dependencies.dart`、`app/test/data/runtime_auth_test.dart`（新增）、`app/test/data/conflict_test.dart`、`tool/c2-negative-controls.json`、`C2-DELIVERY.md`。未改 docs/、server/、生成文件、PNG；未提交 git。

新增负对照（均 expected_occurrences=1，含兼容 Dart 格式化的 find_regex）：

- `stale_runtime_uses_captured_generation`，文件 `app/lib/app/runtime.dart`：
  - find：`expectedGeneration: requireValue<int>(generation),`
  - replace：`expectedGeneration: requireValue<int>((await store.runtime())['generation']),`
  - 命令：`flutter test test/data/runtime_auth_test.dart --plain-name stale_runtime_cannot_invalidate_new_login_token`
- `existing_refund_depends_on_parent`，文件 `app/lib/data/sync/tool_dependencies.dart`：
  - find：`: previous['refund_of_id'];`
  - replace：`: null;`
  - 命令：`flutter test test/data/conflict_test.dart --name '^refund_(update_waits_while_parent_expense_in_conflict|update_continues_after_parent_conflict_resolved|restore_waits_for_parent_conflict_resolution)$'`

验证：本机为 aarch64，未安装 Flutter / Dart；client/AGENTS.md 要求仅在 x86_64 构建机运行测试。尝试 `ssh -o BatchMode=yes -o ConnectTimeout=8 jiabu-build`，当前沙箱返回 `socket: Operation not permitted`，连接未建立。已通过 `git diff --check`、JSON 解析、全部 26 条负对照 ID 唯一性、精确 / 正则锚点次数及测试文件路径检查，并对两条新负对照做内存替换检查。**尚未执行 Flutter 测试、Dart format、analyze、check_rules，以及负对照动态断言失败验证；静态检查不代替这些证据。**

构建机待验证（不运行生成器、不更新 PNG；重任务加 nice / ionice 并串行执行）：

```bash
cd client
dart format --set-exit-if-changed app/lib/app/runtime.dart app/lib/data/repositories/auth_repository.dart app/lib/data/sync/tool_dependencies.dart app/test/data/runtime_auth_test.dart app/test/data/conflict_test.dart
nice -n 19 ionice -c3 flutter analyze --fatal-infos
dart run tool/check_rules.dart
nice -n 19 ionice -c3 flutter test
cd app
nice -n 19 ionice -c3 flutter test test/data/runtime_auth_test.dart test/data/runtime_channel_test.dart test/data/auth_repository_test.dart test/data/conflict_test.dart test/data/sync_test.dart test/data/sync_audit_test.dart test/data/additional_sync_test.dart test/data/partition_and_lease_test.dart
cd ../packages/jiabu_design
nice -n 19 ionice -c3 flutter test
```

需在隔离副本保留新测试、恢复本轮修前的生产实现，先确认对应测试为断言失败；恢复修复后确认通过。再按 JSON 一次应用一条负对照，确认断言失败（编译失败不算）、恢复并复跑。当前拿不准的是上述动态执行结果，不能声称本轮测试或负对照已跑通过。
