# C4 交付说明

## Review 第 1 轮修正

- **2026-10-29 P71 取代本条：** 只有 owner 能邀请并看到「发出的邀请」（默认个人空间仍隐藏），服务端 `Change::requires_owner()` 含邀请；owner 可撤回任何待接受邀请，前任 owner 仍可撤回自己转让前发出的；邀请人离开后邀请仍有效。（原 Review 第 1 轮修正“任何活跃成员可邀请、撤回仅限邀请人”已作废。）

## 构建机第 4 轮视觉修正

第 4 轮 format、analyze、rules、icons、workspace、design package 与 app 门禁全部通过。空间切换测试挂死已在提交 `1eb2938` 修复：preview runtime 的 `runtime.close()` 不返回，且测试需等待新空间实际渲染；本轮保留该修复，不修改 `c4_space_switch_test.dart`。构建机生成但尚未提交的 135 张 C4 golden 仅用于人工审图，本轮未修改任何 PNG。

- API key 详情的不可修改说明与名称输入框之间增加 `decor.cardGap`。新建空间的「币种」标签与选项间使用 `decor.messageGap`，币种选项与时区输入框间使用 `decor.cardGap`；没有扩大 C4Form 全局子项间距，避免无关页面整体漂移。
- unlock golden 的米白矩形来自 catalog 预览层：固定 760 高的白色 `Material + SingleChildScrollView` 包住了内部按内容高度绘制的 `PaperBackground`，内容以下露出白色 Material。unlock 预览现在直接把完整 760 高约束交给 UnlockScreen，由其内部滚动和点阵纸覆盖整个区域；生产 AppLockGate 的布局不变。
- API key 与邀请列表分别记录「最近一次列表加载是否失败」。重试按钮只在加载失败时出现；离线、空列表、正常列表、已收到/发出邀请及邀请操作失效都不显示。邀请接受/拒绝/取消等操作错误不会被误判为加载错误。
- C4 全矩阵布局测试新增几何与状态断言：三个说明/控件间距使用对应 token，全部 unlock 的内部纸面高 760，`keys_failure` 显示重试，其余审图列出的非失败状态及 `received_offline` / `keys_inactive` 不显示重试。组件测试另覆盖邀请加载失败显示重试，以及邀请操作失效不显示重试。

本轮改动文件（9 个）：

```text
client/C4-DELIVERY.md
client/app/lib/app/c4_preview.dart
client/app/lib/features/settings/api_keys/api_key_details.dart
client/app/lib/features/settings/api_keys/api_keys_screen.dart
client/app/lib/features/spaces/view/invitations_body.dart
client/app/lib/features/spaces/view/space_form.dart
client/app/lib/shared/c4/c4_view_model.dart
client/app/test/features/c4_interaction_test.dart
client/app/test/features/c4_layout_test.dart
```

## 构建机第 3 轮尝试（后由第 4 轮定位替代）

第 3 轮的 format、analyze、rules、icons、workspace 测试、设计包测试及其余 3488 条 app 测试已通过；仅空间切换的 3 条 widget 测试在 10 分钟超时。当时按 FakeAsync 与真实 I/O 边界假设，将目录、Drift 与关闭流程移入 `runAsync`；构建机第 4 轮证明该改动仍未解决超时。最终根因与有效修复以文首第 4 轮记录为准：preview runtime 的 `runtime.close()` 不返回，且需等待新空间实际渲染。

本轮将以下边界放入 `tester.runAsync`：

- `SyncHarness.create` 的临时目录、Drift 初始化和首次 reconcile；
- 测试准备阶段的第二次 membership reconcile；
- `runtime.switchSpace` 内的 Drift 空间查询及设置保存；
- finally 先有限 pump 到所有 ledger 订阅取消，再在 `runAsync` 中关闭 fake ledger、runtime、Drift 数据库和临时目录，避免 `StreamController.close` 等待仍活跃的 FakeAsync listener。

该轮保留了 Flutter widget 的有限 pump、旧订阅取消、新订阅建立及两个空间数据负对照，并增加 60 秒 timeout，但仍会超时；后续提交 `1eb2938` 才完成修复。本轮未加入诊断输出，也未修改生成文件、字体、图标或 golden PNG。

本轮改动文件（2 个）：

```text
client/C4-DELIVERY.md
client/app/test/features/c4_space_switch_test.dart
```

## 构建机第 2 轮修正

第 2 轮的生成代码、格式化结果和测试报告已回传；本轮仍不手改生成文件、字体或 golden PNG。以下修正待构建机复验：

- analyze 的 3 条 cascade 诊断改为在 ViewModel 局部变量初始化时直接开始 cascade；两份测试字体加载器改用 `existsSync` / `readAsBytesSync`，消除测试启动阶段的慢异步文件 I/O。
- C4 全矩阵布局测试和 PatternLock 无障碍测试改为 `try/finally`，在测试体结束前显式释放 `SemanticsHandle`。全仓检索确认 C4 新增的 `ensureSemantics` 只有这两处；不再依赖框架检查之后才执行的 `addTearDown`。
- API key 卡片在 `PaperCard` 与 `ListTile` 之间增加透明 `Material`，确保水墨背景上的 Ink 与 ListTile 状态可见。非活跃列表的 `ExpansionTile` 显式使用现有 `JiabuIcons.uiDown`，不再生成 MaterialIcons 字形；无需新增或重生成项目图标。
- 空间设置中的邀请与发出邀请入口现在同时要求 owner 且不是默认个人空间。普通 member 仍可查看成员列表、修改自己的显示名和退出空间，但看不到 owner 邀请入口；组件测试在 member 和个人空间场景之间显式卸载旧 ProviderScope，并分别断言 member 无邀请、个人空间无邀请/退出/删除。
- 空间切换测试移除切换后的无界 `pumpAndSettle`，改为最多 20 次、每次 20ms 的有限 pump，并把「新空间订阅已建立、旧空间订阅已取消」作为停止条件和最终断言。每个参数化测试独占一个数据库，测试体 `finally` 中依次卸载组件、触发 provider 取消、关闭 fake stream/runtime/database/temp directory，避免数据库跨测试存活。
- C4 golden 目录缺失及其余 130 条无基线失败按构建机说明留待生成和人工审图，本轮没有创建或修改 PNG。

本轮改动文件（11 个）：

```text
client/C4-DELIVERY.md
client/app/lib/features/settings/api_keys/api_key_row.dart
client/app/lib/features/settings/api_keys/api_keys_screen.dart
client/app/lib/features/spaces/view/spaces_screen.dart
client/app/test/features/c4_interaction_test.dart
client/app/test/features/c4_layout_test.dart
client/app/test/features/c4_space_switch_test.dart
client/app/test/features/c4_view_model_test.dart
client/app/test/flutter_test_config.dart
client/packages/jiabu_design/test/c4_components_test.dart
client/packages/jiabu_design/test/flutter_test_config.dart
```

## 构建机第 1 轮修正

构建机已完成 pub get、build_runner 与 dart format 并回传生成文件；本轮不手改这些生成文件。第 1 轮报告 analyze 70 条、应用测试被编译错误阻挡、设计包两项失败；以下修正尚未在构建机复验，不能声称 analyze 已归零或测试已通过。

- 修复 `restrictedAuthenticationReady`：直接 watch AuthViewModel 的类型化状态，移除不可用的 select 及其推断/dynamic 连带诊断。
- 抽出 LockCredentials 接口用于注入，生产 LockCredentialsService 继续保持 final；测试替身实现接口，避免跨库继承 final 类。
- 修复测试名 `${days}` 插值及常量 map spread 覆盖重复键；需要改字段的测试数据使用运行时副本。
- 必填 API/缓存/夹具字段统一用既有 requireValue 做类型检查，避免 nullable→非空强转及额外 `!`。错误仍不包含原始值。邀请决定的 accept 改为必需命名参数，所有实现和调用同步更新。
- 逐项处理 Future await/unawaited、级联、const/构造器 tearoff、空值感知 map 元素、children 参数置后、条件集合元素及长注释；不添加 lint ignore、不放宽规则。
- PatternLock 增加内部点阵的稳定 key，几何测试测量实际 216×216 SizedBox，而不是会随父约束扩展的外层 Center。拖动/点选及去重断言保留。
- 设计包补充日志中的两个 load 失败均指向缺失 `/opt/jiabu/dev-tools/test-fonts/NotoSansCJKsc-Regular.otf`，并非业务断言。两份 testExecutable 现在按 setup.sh 的路径规则解析：JIABU_TEST_FONT 优先，其次 JIABU_TOOLS_DIR，再其次 HOME/dev-tools。缺失仍明确失败；原 pinned SHA-256 校验保留，不回退到任意系统字体、不跳过测试、不下载字体。
- cmap 静态核对另发现新增手写文案缺字，因此 `handC4Locked` → `c4Locked`、`handC4KeysSubtitle` → `c4KeysSubtitle`，内容不变，改用 Sans。`handC4Personal` 已有完整覆盖，保留。两份 ARB 已同步更新，须重新 flutter gen-l10n。
- 下一字体 PR 待补：锁屏中文 `簿 U+7C3F、锁 U+9501`，英文 `J U+004A、b U+0062、k U+006B`；副标题中文 `以 U+4EE5、和 U+548C、簿 U+7C3F、脚 U+811A、让 U+8BA9`，英文 `J U+004A、L U+004C、b U+0062`。这些字符目前已在 Serif 子集中，缺的是 hand 子集。本轮未改字体、manifest 或字体来源配置。
- 全量字体来源检查另发现 Serif 缺 `黛 U+9EDB、琥 U+7425、珀 U+73C0、胭 U+80ED`。中文颜色显示名暂用「青绿 / 金黄 / 朱红」替代「青黛 / 琥珀 / 胭脂」，颜色标识、色值及英文不变；这四字也交下一字体 PR。
- 更新负对照的「离线成员按钮」「敏感剪贴板」锚点，兼容回传的格式化结果；仍为 8 条，command/预期失败测试不变。

本轮静态检查：全部 7 项字体来源的 hand/serif cmap 覆盖完整；两份 ARB 键集合一致；8 条负对照 find/regex 均唯一；30 份修改的 Dart 源码字符串/注释/括号配对通过；bash -n 与 git diff --check 通过。这些检查不代替 Dart 工具链。

复验请先重新 flutter gen-l10n / build_runner，再跑 format、analyze --fatal-infos、check_rules、三处测试及生成一致性检查。135 张 golden 路径不变；两处 Sans 替换属于本轮明确的视觉变化。当前 gverify=125 只有退出码、无错误详情，需重新生成后复验定位。

如测试字体尚未安装在约定路径，构建机应 source 已有工具链的 jiabu-client-env.sh，或把 JIABU_TEST_FONT 指向已有的 pinned 字体文件。本轮不运行 subset.py，不修改字体，也不把缺夹具误报为测试通过。

### 本轮改动文件（34 个）

```text
client/C4-DELIVERY.md
client/app/lib/app/c4_preview.dart
client/app/lib/app/c4_providers.dart
client/app/lib/data/api/dio_api_client.dart
client/app/lib/data/repositories/api_keys_repository.dart
client/app/lib/data/repositories/spaces_repository.dart
client/app/lib/data/services/app_lock_service.dart
client/app/lib/data/services/lock_credentials_service.dart
client/app/lib/data/services/window_privacy_service.dart
client/app/lib/domain/spaces.dart
client/app/lib/features/lock/view/lock_settings_screen.dart
client/app/lib/features/lock/view/unlock_screen.dart
client/app/lib/features/settings/api_keys/api_key_create.dart
client/app/lib/features/settings/api_keys/api_key_details.dart
client/app/lib/features/settings/api_keys/api_keys_screen.dart
client/app/lib/features/settings/view/settings_screen.dart
client/app/lib/features/spaces/view/invitations_body.dart
client/app/lib/features/spaces/view/space_action_form.dart
client/app/lib/features/spaces/view/space_form.dart
client/app/lib/l10n/app_en.arb
client/app/lib/l10n/app_zh.arb
client/app/lib/shared/c4/c4_view_model.dart
client/app/test/data/c4_app_lock_test.dart
client/app/test/data/c4_privacy_test.dart
client/app/test/data/c4_repositories_test.dart
client/app/test/features/c4_interaction_test.dart
client/app/test/features/c4_space_switch_test.dart
client/app/test/features/c4_view_model_test.dart
client/app/test/flutter_test_config.dart
client/app/test/server/local_sync_server_test.dart
client/packages/jiabu_design/lib/src/components/pattern_lock.dart
client/packages/jiabu_design/test/c4_components_test.dart
client/packages/jiabu_design/test/flutter_test_config.dart
client/tool/c4-negative-controls.json
```

## 状态与验证边界

初次交付时 C4 源码、组件目录、自动化测试、真实服务端测试场景、golden 路径清单和负对照清单已写入工作树；最新进度以文首第 4 轮视觉修正为准。第 4 轮反馈时全部非 golden 门禁已通过，本轮视觉源码与新增断言仍待构建机复验和重新生成 golden。本机未联网、未安装或调用 Dart/Flutter、未运行 pub get/build_runner、未生成字体、图标、PNG、lockfile 或任何生成 Dart 文件。

本机仅做 Python 源码/清单静态核对、ARB JSON 与键集合核对、Dart 字符串/括号配对扫描、负对照 find/regex 唯一性核对、`bash -n client/tool/server-it.sh` 和 `git diff --check`。这些检查不能代替 Dart format、analyze、check_rules 或动态测试。

没有修改 `docs/`、`server/`、登录/服务器地址/首次启动页面、聊天页面、数据库 schema 或 schemaVersion。Android 主题仅为生物识别兼容调整 parent，启动 drawable 未改。

## 实现

- 顶栏空间入口、空间列表与当前标记、离线切换、上次空间恢复；创建、改名改色、成员列表、本人显示名、用户名邀请、发出/收到邀请、接受/拒绝/撤回、退出、移除、转让和输入准确名称删除。
- 默认个人空间隐藏邀请、退出、删除；owner 操作按服务端权限隐藏；邀请入口仅 owner 可见，撤回对 owner 和邀请人本人可见（P71）。仅 active 成员参与删除/最后 owner 判断，历史成员显示已退出。
- 退出确认读取当前空间 outbox 条数；包括 pending/sending/failed/blocked，是打开确认时的快照。最后 owner 显示转让/删除引导。成功退出/删除与被移出后的清除继续使用 C2 MembershipReconciler、purgeSpace 和缓存清理。
- 新增在线管理 Repository，空间目录仍以 drift 为准。短命管理请求通过现有 ApiClient 的相对路径 JSON 入口发送，使用现有 spaces DTO 和新增领域 SpaceInfo；API key 明文不进入可自动打印的 freezed 状态。
- 切换更新 currentSpace/lastSpace/展示代次；family ViewModel 按 spaceId 重建并取消旧订阅；旧弹层按分区/空间展示归属关闭。A→B→A 的展示代次也会变化。新的空间内容淡入，旧内容不留作交叉淡出。空间管理路由切到对应的新空间 ID。
- 在线状态来自 connectivity_plus、health 可达性和完成的一轮同步。未知状态保守禁用，断网事件不会被迟到 probe 重新放行。管理动作不进 outbox；API key 离线不显示缓存列表。
- 设置增加账号、改密码、语言、应用锁、API key、关于/许可；原 C3「账户」仍是同一名称、首行和 `/settings/accounts` 路径。语言 PATCH /me 成功后更新缓存身份及当前界面，不重启分区同步。
- 应用锁包含生物识别、图案和 4–6 位 PIN；PIN 必设并确认。图案有点选无障碍入口、错误色和减少动画兼容的错误动效。锁门禁位于整个 Router/Navigator 外，覆盖页面及弹层；冷启动锁定时认证恢复仍可执行。
- 只显示一次的 API key 页面禁用拖拽/遮罩关闭，返回键确认；请求中阻止返回。明文仅为弹层 VM 的私有内存字段，关闭/销毁清空；列表/详情只能看到前缀。创建重放 plaintext_available=false 有单独提示。创建重试固定请求和幂等键，提交后冻结表单；需要改参数时退出表单重建。
- API key 支持有效/失效列表、创建、详情、改名、撤销、永久风险提示、默认不预选权限。前缀及明文才用 mono。复制按钮、选择菜单和常见复制快捷键均调用敏感剪贴板包装层。
- 新组件包括 SpaceSwitcher、SpaceAccentPicker、JiabuLogoSealPlaceholder、PinPad、PatternLock、ApiKeyCard、ApiKeySticker、LockErrorMotion；均通过 C4 状态进入 catalog。现有 Stamp 增加可选 degrees，key 失效印章用 0°，C3 默认不变。

## 文档没写清、我是这么做的

1. **用户确认：local_auth 使用 `^3.0.2`**，app pubspec 和依赖白名单一致；保留 TODO(luna)。按 3.x 写 authenticate 的 localizedReason、biometricOnly 直接命名参数，不使用 AuthenticationOptions，不增加其他依赖。
2. **用户确认：离开时间 `>= timeout` 上锁**，默认 1 分钟；立即/1/5/15 分钟。时钟和等待 Timer 均可注入。inactive/paused 不重复覆盖首次离开时间；生物识别系统框的 inactive 与实际 paused 区分处理。
3. **用户确认：不做原生配置持久化**。Dart 在 runApp 前读取当前账号的锁配置并尽早设置 FLAG_SECURE。配置/凭据按服务端+账号作用域存放。
4. **用户确认：错误退避只有一条规则**：PIN/图案每累计 5 次错误等待 30 秒，再每 5 次翻倍，最高 5 分钟；截止时间和计数持久化，成功清零。生物识别由系统限流，系统失败/取消保持锁定，不增加 PIN 错误计数。
5. PIN/图案使用现有 crypto 的 PBKDF2-HMAC-SHA256，16 字节随机盐、100000 轮、32 字节摘要，保存版本/参数；派生放 compute，比较摘要。没有添加密码学依赖；安全存储只存盐、参数、摘要。
6. **用户确认：邀请输入用户名**，无账号搜索接口，不实现虚构的搜索器；本人空间显示名走 members/me 和 expected_version。
7. **用户确认：默认 90 天省略 expires_at，永久显式 null**；7/30/365 天用首次提交时计算并固定的绝对时间，永久有风险提示。权限值为 read/read_write。
8. **用户确认：默认个人空间不可删；仅剩自己且名称准确才可删**。改名/改色仅 owner；邀请仅 owner，owner 或邀请人本人可撤回（P71，2026-10-29）。本人显示名所有在册成员可改。
9. 新建币种选项与服务端一致：CNY/HKD/USD/EUR/GBP/JPY，默认 CNY。Android 用 TimeZone.getDefault().id 取得默认 IANA 时区，通过现有窗口通道读取；其他未实现原生平台的目录/测试回退 UTC，输入可编辑，服务端最终校验。点缀色取色板首个未使用颜色，全用过则回到首色。
10. **用户确认：Kotlin 不写原生单元测试/instrumented test**。通道固定 `jiabu/secure_clipboard`、`jiabu/window_privacy`；Dart 用 TestDefaultBinaryMessengerBinding mock。Android 13+ Kotlin 设置 ClipDescription.EXTRA_IS_SENSITIVE，旧版本正常复制。
11. 窗口安全状态合并「应用锁」「明文 key」原因，关闭 key 弹层不能解除仍开启的应用锁保护。FLAG_SECURE 会同时禁止截屏/录屏，设置页有说明。最近任务纯纸面遮罩与 FLAG_SECURE 同时交付，不承诺系统一定显示自定义缩略图。
12. **用户确认：通知脱敏交付为纯函数和单元测试，不接不存在的发送代码**。策略入口是 `app/lib/domain/notification_privacy.dart` 的 notificationText；开启应用锁时只返回调用者提供的本地化通用文案（ARB c4GenericNotification）。
13. **通知实际发送接入在 C5（聊天）首次加通知时必须调用此策略**。这是显式依赖项，不是省略通知隐私行为。覆盖金额、账户、成员名称不能进入锁定通知的测试。
14. **用户确认：与 C5 共用文件只做接线**。未更改聊天页面或重构三栏路由；共享影响集中于 runtime、router、partition_host、main_shell、ledger_providers、MainFrame、ARB、依赖清单。
15. 不新增本机表/列，schemaVersion 保持 1，不需要 drift 迁移/快照更新。锁开关/超时/退避在 preferences，凭据摘要在 secure storage；API key/invitations 不建表。
16. 公开 Widget 各自独立源文件，通过原入口 export 保持调用兼容；目录/测试的跨 feature 页面组合放 app/c4_preview.dart；features/catalog 仅导出该组合入口，遵守 feature 不互相 import。生产 settings/spaces/lock 不依赖这些虚构夹具。
17. 原 G0 为 152 张 PNG，按用户允许合并近似错误态后是 **135 张**，具体见下一节。布局/几何/语义仍跑完整矩阵。
18. 管理动作后的目录刷新同时检查原空间 ID 集合和 C2 RequestFence，防止迟到 /spaces 响应恢复已清除的旧成员关系；实际清除与世代变化规则仍调用 C2，不另写 purge。
19. 新建空间和接受邀请后保留原当前空间，目录刷新后由用户主动切换。退出/移除使空间管理路由失效时回到默认空间的总览。
20. 临时密码会话先通过 C2 的强制改密门禁（不渲染业务页面），再继续应用锁验证；忘记 PIN 的重新登录结果还检查账号/会话未切换，才重设锁。
21. 清除提示继续沿用 C2 的通知数据和文案，不在已经清除的空间中反查名称。未上传条数使用 C2 相同的 outbox 条目口径。
22. 明文窗口保护按每个弹层的独立原因标识持有，清空/销毁后等待移除明文的 Flutter 帧完成才释放；旧弹层迟到释放不会解除新弹层的保护。每次打开创建表单也使用独立 formId，避免关闭动画期间重开复用旧 VM；目录/测试注入立即完成的帧替身。
23. 语言手动修改在线提交后生效，不新增账号偏好 outbox；保存为 system 后离线也按系统解析。收到邀请在进入列表和点击重试时拉取，不加邀请后台订阅或未读角标。

## 隐私验收与 C5 依赖

① 应用锁开启后维持 FLAG_SECURE，inactive/paused 显示纸面遮罩；Dart 冷启动在 runApp 前尽早设置。
② 应用锁开启时通知只显示「家簿有新消息」，当前交付为纯函数策略和中英文单元测试。

**通知实际发送接入在 C5（聊天）首次加通知时必须调用此策略。** C5 应传入 ARB c4GenericNotification，不得直接把聊天/金额/资料标题送到通知系统。

Android 原生行为还需构建机编译及后续真机验证；Dart 通道测试不能代替真实系统剪贴板预览、最近任务和生物识别检查。

## 自动化测试

- `test/data/c4_app_lock_test.dart`：冷启动、未超时、刚好超时、超时后成功/失败/取消、重复后台事件、迟到验证、5 次错误退避翻倍/上限/持久化、PIN 加盐和账号隔离。
- `test/data/c4_privacy_test.dart`：敏感复制参数、双原因窗口保护、旧弹层等待安全帧释放且不影响新弹层、锁定通知仅通用文本。
- `test/data/c4_network_test.dart`：网络接口须验证可达性、迟到 probe 和离线门禁。
- `test/data/c4_transport_test.dart`：代理子路径、相对路径、请求标识、join_epoch、显式 null。
- `test/data/c4_repositories_test.dart`：空间命令版本/世代、仅当前空间未上传计数、离线不发送、有效成员目录切换、key 期限和错误码。
- `test/features/c4_view_model_test.dart`：key 创建各期限与权限、无空间字段、内存明文清除、离线和幂等重放无明文。
- `test/features/c4_interaction_test.dart`：退出先提示 N 后提交；成员离线按钮禁用；owner/默认个人空间权限；邀请接受/拒绝/失效；邀请入口仅 owner、owner 可撤回任何邀请、前任 owner 仅可撤回自己发的（P71）；退出/移除/转让错误；删除名称精确匹配；明文关闭不可再见、敏感复制及两秒反馈；全局锁屏替换业务内容、未录入生物识别直接 PIN。
- `test/features/c4_space_switch_test.dart`：总览/历史/账户分别用 A/B 的记录、账户、成员和不同金额做负对照，实际调用 runtime.switchSpace，断言只显示 B、A 订阅已取消、lastSpace 更新。聊天/资料的真实内容由 C5/C6 接入同一空间作用域，本片没有虚构它们的数据界面。
- `test/features/c4_layout_test.dart`：54 状态 × 中英 × pine/indigo × 360/430 × 100%/200% = **864 组合**，异常、按钮尺寸、装饰角度与色板语义。
- `packages/jiabu_design/test/c4_components_test.dart`：占位圆章尺寸/角度、色板八项与触控区、图案无障碍点选/去重。
- 现有 `test/server/local_sync_server_test.dart` 增加两个 server 场景：实际创建→邀请→接受→成员一致→转让→退出→本机空间/记录/outbox/游标清除；实际创建 key→只读 query_balance 成功→重放无明文→撤销→401。

server-it.sh 继续使用本地指定 ref 的服务端快照、原临时 PostgreSQL/双 HTTP 实例和缓存会话，最终 `flutter test --tags server --run-skipped` 包含新增场景。不增加脚本、不修改服务端，不打印 key。

## Golden 与目录

完整路径逐条写在 `app/test/features/c4_golden_test.dart`：

- 54 状态 × zh/pine/w360/text100、zh/pine/w430/text200：108 张。
- 26 个界面代表 × en/pine/w360/text100：26 张。
- switcher × zh/indigo/w360/text100：1 张。
- **合计 135 张**，路径 `app/test/goldens/c4/<state>_<locale>_<accent>_w<width>_text<scale>.png`。

合并说明：移除/转让/删除/撤销等确认态的仅错误文案变化共用 C4Form 错误样式，不再各生成失败 PNG；交互测试仍逐动作覆盖。新建/编辑的校验共用 space_validation；key 必填校验复用同一表单错误样式，不另录 key_validation。PIN 输入/二次确认同页呈现，纳入 lock_disabled/lock_pin_mismatch；图案同页确认纳入 lock_pattern_setup。保留 unlock_recovery、key_saved_confirm、key_revoke、logout_confirm 和 keys_inactive 等有实际结构差异的状态。

C4 catalog 注册全部状态，另有明确命名的 jiabu_logo_seal_placeholder 独立入口；圆章外观已由 unlock 基线和组件几何测试覆盖，不重复录 PNG。既有 catalog_golden_test 排除 c4，防止重复 PNG；既有 catalog_layout_test 仍覆盖目录及字体，mono 仅允许 c4_key* 状态。C3 的默认组件参数不变；新可点击顶栏采用 Serif 16，旧 C3 catalog 没有 onSpace 回调，因此其旧基线保留。

PNG 和生成文件由 luna.coco 在固定构建机生成、打开审图后提交，附 visual-change。按第 1 轮反馈，本片不再改字体子集，缺字留给下一字体 PR。

## 负对照

`tool/c4-negative-controls.json` 有 8 条：退出不显示未上传数、离线仍可移除、复制不带敏感标记、超时 >= 改 >、切换保留旧空间、关闭明文不清除、关闭 key 误解除应用锁窗口保护、锁定通知泄露内容。

每条有 file/find/replace/expected_occurrences/find_regex/test_names/command。command 均为在 client/app 下执行的 `flutter test <文件> --plain-name "<测试名>"`。原版通过后逐项改坏，必须断言失败；编译失败不算抓到，逐项恢复，不能提交变异。

## 服务端差异与缺口

- 无 GET /spaces/{id} 或独立 GET members：使用 GET /spaces 的摘要/成员列表，不能凭文档虚构接口。
- 邀请按 username；不存在账号搜索接口。收到邀请只返回 pending，且只含邀请 ID、空间名、邀请人名，不含 space_id；接受后通过目录刷新找到新空间。
- 已撤回/已失效邀请不会继续出现在收到列表；决策时遇到 not_found 显示「邀请已失效」，客户端不能从当前接口重建失效历史。
- 改名/改色和本人显示名必须带 expected_version；空间写请求带 X-Jiabu-Join-Epoch。转让参数为 member_id，不是 user_id。
- 默认 90 天取决于 expires_at 字段缺省；null 是永久。创建首次返回 201/key/true，幂等回放 200/false 且无 key。
- PATCH /me 接受 system/zh-Hans/en；POST /me/password 返回 204，沿用 C2 当前会话升级/其他会话失效处理。
- **GET /spaces/{id}/storage 尚未实现**。空间设置只有不可见 TODO(S9)，没有入口、占位数字或本地估算。

以 server/openapi/openapi.json 和 handlers/{spaces,invitations,me,api_keys}.rs、domain/spaces.rs、db/spaces.rs 为准，没有修改服务端。

## 延后项

- 照片占用界面依赖 S9；S9 提供 storage 接口后再显示设置行。
- 通知实际发送接入在 C5（聊天）首次加通知时必须调用此策略。当前纯函数、文案和测试已经交付。
- 正式 Logo 由后续设计任务替换 JiabuLogoSealPlaceholder，不在本片绘制。
- Android 原生编译、真实生物识别/剪贴板预览/最近任务行为由构建机及真机验证；没有 Kotlin 原生测试。

## 构建机步骤与最可能失败处

```bash
cd client
flutter pub get
cd app
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs
cd ..
dart format --set-exit-if-changed .
flutter analyze --fatal-infos
dart run tool/check_rules.dart
flutter test
cd app
flutter test
cd ../packages/jiabu_design
flutter test
```

此外按既有 tool/golden.sh 固定环境录制/查看/提交 135 张 C4 PNG；用原环境变量运行 tool/server-it.sh；最后执行 8 条负对照。构建机需提交 pubspec.lock 和 local_auth 传递依赖解析结果。

新增待生成：app/lib/app/c4_providers.g.dart、app/lib/shared/c4/c4_view_model.g.dart、app/lib/shared/c4/c4_ui_state.freezed.dart，以及 ARB 对应本地化输出。没有 schema 变化，不需要 drift schema/helper 重录。

最可能的编译/分析修正：local_auth 3.x authenticate 参数与 Android AppCompat/FragmentActivity；Riverpod 新 family/overrideWith 和 scoped lint；freezed 新 UiState；Flutter EditableText 工具栏/Focus/PopScope API；严格泛型推断和 import/format/lint。**本机没有 dart format，源码为手工排版，精确格式仍须构建机核验，不能声称格式或 analyze 已通过。**

## PR 描述（可直接使用）

新增空间切换和管理、成员邀请/退出/移除/转让、账号与语言设置、个人 API key 和应用锁。切换清除旧展示订阅，退出前提示未上传条数，离线管理禁用；明文 key 只保留一次并通过 Android 敏感剪贴板复制。应用锁启动/超时验证，开启后使用 FLAG_SECURE 遮挡最近任务并限制截屏。

通知实际发送接入在 C5（聊天）首次加通知时必须调用此策略。本 PR 交付通知脱敏纯函数和测试，开启锁时仅输出「家簿有新消息」。照片占用等待 S9，正式 Logo 使用可替换占位组件。

验证：已写单元、组件、空间隔离、平台通道、server、布局和 golden 测试；135 张 C4 PNG、8 条负对照。构建/测试/生成由 luna.coco 在固定构建机执行，本机仅静态核对，未声称动态验证通过。

## 改动文件完整清单

路径均相对仓库根；不含构建机后续生成的文件。

```text
client/C4-DELIVERY.md
client/app/android/app/src/main/AndroidManifest.xml
client/app/android/app/src/main/kotlin/io/github/zzhoward/jiabu/MainActivity.kt
client/app/android/app/src/main/res/values-night/styles.xml
client/app/android/app/src/main/res/values/styles.xml
client/app/lib/app/bootstrap.dart
client/app/lib/app/c4_preview.dart
client/app/lib/app/c4_providers.dart
client/app/lib/app/ledger_providers.dart
client/app/lib/app/main_shell.dart
client/app/lib/app/partition_host.dart
client/app/lib/app/router.dart
client/app/lib/app/runtime.dart
client/app/lib/data/api/api_client.dart
client/app/lib/data/api/dio_api_client.dart
client/app/lib/data/db/daos/local_store.dart
client/app/lib/data/repositories/api_keys_repository.dart
client/app/lib/data/repositories/auth_repository.dart
client/app/lib/data/repositories/spaces_repository.dart
client/app/lib/data/services/app_lock_service.dart
client/app/lib/data/services/biometric_auth_service.dart
client/app/lib/data/services/lock_credentials_service.dart
client/app/lib/data/services/network_status_service.dart
client/app/lib/data/services/secure_clipboard_service.dart
client/app/lib/data/services/window_privacy_service.dart
client/app/lib/data/sync/sync_policy.dart
client/app/lib/domain/api_keys.dart
client/app/lib/domain/app_lock.dart
client/app/lib/domain/notification_privacy.dart
client/app/lib/domain/spaces.dart
client/app/lib/features/catalog/c4_cases.dart
client/app/lib/features/catalog/catalog_cases.dart
client/app/lib/features/lock/view/app_lock_gate.dart
client/app/lib/features/lock/view/lock_settings_screen.dart
client/app/lib/features/lock/view/unlock_screen.dart
client/app/lib/features/settings/api_keys/api_key_create.dart
client/app/lib/features/settings/api_keys/api_key_details.dart
client/app/lib/features/settings/api_keys/api_key_labels.dart
client/app/lib/features/settings/api_keys/api_key_row.dart
client/app/lib/features/settings/api_keys/api_keys_screen.dart
client/app/lib/features/settings/view/settings_screen.dart
client/app/lib/features/spaces/view/invitations_body.dart
client/app/lib/features/spaces/view/space_action_form.dart
client/app/lib/features/spaces/view/space_form.dart
client/app/lib/features/spaces/view/spaces_screen.dart
client/app/lib/l10n/app_en.arb
client/app/lib/l10n/app_zh.arb
client/app/lib/shared/c4/c4_confirmation.dart
client/app/lib/shared/c4/c4_field.dart
client/app/lib/shared/c4/c4_form.dart
client/app/lib/shared/c4/c4_labels.dart
client/app/lib/shared/c4/c4_scope_fence.dart
client/app/lib/shared/c4/c4_ui_state.dart
client/app/lib/shared/c4/c4_view_model.dart
client/app/lib/shared/ledger/main_frame.dart
client/app/pubspec.yaml
client/app/test/catalog_golden_test.dart
client/app/test/catalog_layout_test.dart
client/app/test/data/c4_app_lock_test.dart
client/app/test/data/c4_network_test.dart
client/app/test/data/c4_privacy_test.dart
client/app/test/data/c4_repositories_test.dart
client/app/test/data/c4_transport_test.dart
client/app/test/features/c4_golden_test.dart
client/app/test/features/c4_interaction_test.dart
client/app/test/features/c4_layout_test.dart
client/app/test/features/c4_space_switch_test.dart
client/app/test/features/c4_view_model_test.dart
client/app/test/flutter_test_config.dart
client/app/test/server/local_sync_server_test.dart
client/app/test/support/c4_harness.dart
client/app/test/support/sync_harness.dart
client/packages/jiabu_design/lib/jiabu_design.dart
client/packages/jiabu_design/lib/src/components/api_key_card.dart
client/packages/jiabu_design/lib/src/components/api_key_sticker.dart
client/packages/jiabu_design/lib/src/components/jiabu_logo_seal_placeholder.dart
client/packages/jiabu_design/lib/src/components/ledger_controls.dart
client/packages/jiabu_design/lib/src/components/lock_error_motion.dart
client/packages/jiabu_design/lib/src/components/paper_sheet.dart
client/packages/jiabu_design/lib/src/components/pattern_lock.dart
client/packages/jiabu_design/lib/src/components/pin_pad.dart
client/packages/jiabu_design/lib/src/components/space_accent_picker.dart
client/packages/jiabu_design/lib/src/components/space_switcher.dart
client/packages/jiabu_design/lib/src/components/stamp.dart
client/packages/jiabu_design/lib/src/tokens/type.dart
client/packages/jiabu_design/test/c4_components_test.dart
client/packages/jiabu_design/test/flutter_test_config.dart
client/tool/allowed_deps.yaml
client/tool/c4-negative-controls.json
client/tool/server-it.sh
```
