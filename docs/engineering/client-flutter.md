# 家簿 · Flutter 客户端技术与开发规范

> 版本号、发布者与维护状态均于 2026-10-25 从一手来源核实（Flutter 发布清单、pub.dev API、docs.flutter.dev、dart.dev、官方 GitHub 仓库）。视觉规范见 [设计规范](../design/design-spec.md)，产品需求见 [需求](../product/requirements.md)。

## 0. 结论先行

照 Flutter 官方《App 架构指南》的 **MVVM + Repository** 分层来写，采用“功能优先”（feature-first）目录 + **pub workspace** 单仓。状态管理和依赖注入用 **Riverpod 3（代码生成写法）**，本机数据库用 **drift**（本机数据唯一真相源 + outbox 表），网络用 **dio**，数据类用 **freezed + json_serializable**，路由用 **go_router**。手账皮肤做成独立的 **`jiabu_design`** 包（ThemeData + ThemeExtension 令牌、打包字体、生成的图标路径、确定性倾角）。质量关卡四道：very_good_analysis 加自定义检查、单元和组件测试、固定工具链里生成的 golden 截图、几何断言 + 像素差异报告。Flutter 用 FVM 锁定在 3.47.8。

### 约束

- 先做 Android，为 iOS 预留（不写只限安卓的业务逻辑）。
- 目标设备是国内安卓手机：**默认没有 Google Play 服务（GMS）**，厂商系统后台限制严格。
- 代码主要由 AI 编程代理（Codex）编写，人工评审，规则尽量写成机器能检查的形式。
- 构建、测试、golden 只在 **x86_64 Linux** 上跑（Flutter 的安卓构建工具链只有 x86_64 Linux 版本）。

### 技术栈一览

| 层 | 选择 | 版本 |
|---|---|---|
| SDK | Flutter stable / Dart | **3.47.8** / **3.13.7**（新稳定版出到 .1 / .2 补丁后再评估升级） |
| 版本锁定 | FVM（`.fvmrc`）+ 构建机上的固定工具链安装脚本 | fvm 4.3.2 |
| 单仓 | pub workspaces（Dart ≥ 3.6） | 不引入 melos（8.9.0 留作备选） |
| 架构 | 官方 MVVM：View → ViewModel → Repository → Service | docs.flutter.dev/app-architecture |
| 状态 / DI | flutter_riverpod + riverpod_generator + riverpod_lint | 3.4.3 / 4.0.9 / 3.1.9 |
| 本机数据库 | drift + drift_dev（底层 sqlite3 3.x，构建钩子打包 SQLite） | 2.35.3 / 2.35.2 |
| 网络 | dio | 5.11.1 |
| 数据类 / JSON | freezed + json_serializable + build_runner | 4.0.3 / 6.15.2 / 2.17.1 |
| 路由 | go_router（StatefulShellRoute 做底部三栏） | 18.1.1 |
| 后台同步 | 前台触发为主 + workmanager 兜底 + connectivity_plus | 0.10.10 / 7.3.2 |
| 安全存储 | flutter_secure_storage（登录令牌、应用锁 PIN / 图案的加盐哈希，Android Keystore 加密） | 11.2.0 |
| 本地设置 | shared_preferences（上次使用的空间 ID、引导是否完成、应用锁开关与超时） | 2.5.6 |
| 应用锁 | local_auth（指纹 / 人脸）+ 自绘图案锁组件 + 数字 PIN 兜底；默认关闭（见 4.6） | 开工时核实后锁定 |
| ID | uuid（客户端生成 UUIDv7） | 4.6.0 |
| 图标 | `icons.json` → 生成 Dart `Path` 代码；flutter_svg / vector_graphics 仅用于将来的插画 | flutter_svg 2.3.0 / vector_graphics 1.2.4 |
| 动效 | 隐式动画 + 主题里的动效令牌；animations 包按需 | animations 3.0.0 |
| 文案 | gen-l10n + ARB（intl） | intl 0.20.3 |
| 规范 | very_good_analysis + riverpod_lint + 项目自定义检查脚本 | 11.0.0 |
| 测试 | flutter_test（单元 / 组件 / golden）+ mocktail；integration_test；patrol 后补 | mocktail 1.0.5 / patrol 4.10.0 |
| 日志 / 崩溃 | logging + 本机滚动日志 + 上报到自有服务器 | logging 1.3.0 |

## 1. 架构：照官方指南

来源：docs.flutter.dev/app-architecture（概念、指南、建议清单、设计模式、Compass 示范 App）。

| 指南要点 | 官方说法（摘要） | 我们怎么做 |
|---|---|---|
| 分层 | UI 层（View + ViewModel）+ 数据层（Repository + Service）；领域层（use case）可选 | UI + Data。只为“自然语言记账提交”“撤销 / 重做”这类跨仓库逻辑建少量 use case |
| View 与 ViewModel 一对一 | View 只负责布局、动画和简单显示逻辑 | 照做。View 里不许有业务分支 |
| Repository 是数据真相源 | 仓库负责缓存、错误处理、重试和刷新，把原始数据转换成领域模型；Service 是外部 API 的无状态薄封装 | `RecordsRepository` 等仓库是唯一写入口；`ApiClient`、`JiabuDatabase` 是 Service |
| 单向数据流 | 状态向下流动，事件向上传递；UI 状态不可变 | ViewModel 只暴露不可变的 `UiState`（freezed） |
| Command 模式 | 推荐：带 running / error / completed 状态并防重复点击 | 用 Riverpod 的 `AsyncValue` + Notifier 方法表达同样语义，不额外写 Command 类 |
| Result 模式 | 用 `Result<T>`（Ok / Error）代替抛异常 | 仓库和 Service 返回 `Result<T>`（sealed class），ViewModel 用 `switch` 穷举 |
| 离线优先 | “仓库是唯一真相源，也应是唯一能修改数据的地方”；提醒有些设备会限制后台处理 | 本机 drift 为唯一真相源；写入 = 本地表 + outbox 同一事务；`sync_state` 驱动“待上传 / 待 AI 处理 / 已记录” |
| 乐观更新 | 后台任务完成前先显示成功状态 | 本地先写即乐观；失败时卡片显示“失败可重试”，不静默回滚 |
| 依赖注入 | 强烈推荐；状态管理选择“取决于个人偏好” | Riverpod 同时承担 DI，不另加 get_it / injectable |
| 其他强烈推荐 | 不可变模型、抽象仓库接口、用 fake 测试；推荐 freezed 和 go_router | 全部采纳：仓库先定义抽象类，测试用 `FakeRecordsRepository` |
| 目录 | 示范 App：UI 按功能分目录，数据层按类型分目录 | 照这个混合方式（第 8 节） |

业界做法参考：

- **feature-first**（按用户功能而不是按页面分目录）：`features/chat|overview|history|auth`，每个功能下再分 `view/`、`view_model/`、`widgets/`。
- **用包边界强制依赖方向**（借鉴 Very Good Ventures 的分层架构）：设计系统单独做成包；v1 不把每一层都拆成包（两个用户的 App，拆太细维护成本高于收益）。

**聊天首页的特殊之处**：AI 解析在服务器端。手机先把“用户原话”作为聊天条目和 outbox 行写进本机数据库，显示为“待上传”便利贴；上传后服务器返回解析结果（草稿 / 追问），回写本机后渲染成记录卡或追问选项。

**空间是客户端的第一层划分**：账户、记录、家庭资料、聊天与 AI 会话都属于某个空间。App 打开时进入上次使用的空间（ID 存在本机设置里；首次登录进入默认个人空间）；所有页面、查询、outbox 条目和 AI 请求都带当前 `spaceId`。用户不是成员的空间在客户端完全不存在：不缓存、不显示名称、不显示数量或任何动态提示。

## 2. 状态管理：Riverpod 3（代码生成写法）

官方立场：Flutter 官方状态管理页现在只介绍内置方案（`setState`、`ValueNotifier`、`InheritedWidget`），不点名第三方包；官方示范 App 用 `ChangeNotifier` + provider。

| 方案 | 现状（2026-10-25） | 对 AI 代理开发 | 结论 |
|---|---|---|---|
| **Riverpod 3** | 作者 Remi Rousselet（也是 provider / freezed 的作者）；2026-09 仍在发版 | 代码生成 + lint 让写法高度统一；riverpod_lint 已接入官方 `analysis_server_plugin`，规则直接在 `dart analyze` 里报错 | ✅ 采用 |
| ChangeNotifier + provider | Flutter Favorite；最近发布 2025-08 | 概念最少，但 DI、异步状态、错误状态要靠约定，AI 写法容易发散 | 备选 |
| Bloc | Flutter Favorite；最近发布 2025-05 | 事件 / 状态类多，样板代码最多 | 对两人 App 偏重 |

选 Riverpod 的理由（贴合“AI 写、人审、机器验”）：

1. **一种写法**：只允许 `@riverpod` 生成的 `Notifier` / `AsyncNotifier` 和函数式 provider；riverpod_lint 能抓出常见错误。
2. **依赖注入合一**：仓库、Service、数据库都是 provider。
3. **异步状态标准化**：`AsyncValue`（加载中 / 数据 / 错误）让每个页面的加载和出错写法一致，golden 也好覆盖。
4. **测试替身简单**：`ProviderContainer(overrides: [...])` 一行换成假实现。

**空间作用域**：`currentSpaceProvider`（`@riverpod` Notifier）保存当前空间 ID，并写回本机设置；仓库方法一律显式接收 `spaceId`，不在仓库内部偷读全局状态；按空间取数的 provider 以 `spaceId` 为参数（带参数的生成式 provider），并 `watch(currentSpaceProvider)`，切换空间时这些 provider 自动失效重建，不残留上一个空间的数据。聊天 ViewModel 也按空间分开：每个空间有自己的聊天记录和 AI 会话，切换空间就切换对话。

风险：网上和模型语料里有大量 Riverpod 1/2 时代的旧写法（`StateNotifierProvider`、`StateProvider`、`ChangeNotifierProvider`）。对策：AGENTS.md 明文禁止 + CI 检查脚本拦截 + 锁定主版本 `^3.4.3`。

## 3. 数据层

### 3.1 本机数据库

| 候选 | 状态 | 结论 |
|---|---|---|
| **drift** 2.35.3（2026-10-23） | 活跃，Flutter Favorite。类型安全 SQL、查询结果可直接变成 Stream（数据一变界面自动刷新）、事务、迁移测试工具齐全 | ✅ 选用 |
| sqflite 2.4.5 | 活跃，但只有原始 SQL，没有类型检查和响应式查询 | 不选 |
| isar 3.1.0+1 | 最后正式版 2023-04，实际已停滞 | ❌ |
| objectbox 5.3.2 | 维护中，但不是 SQL，与服务器 PostgreSQL 概念对不上 | ❌ |
| sqlite3_flutter_libs | **已宣布停止维护（EOL）**，请升级到 package:sqlite3 3.x | ❌ 禁止引入 |

**构建细节**：drift 底层用 `package:sqlite3` 3.x，它通过 Dart **构建钩子（build hooks）** 把 SQLite 打包进 App，默认**在构建时从 GitHub Releases 下载预编译库**并做 sha256 校验。网络不稳定时：在 `pubspec.yaml` 用 `hooks: user_defines: sqlite3: url_pattern:` 指向自建镜像（推荐，同样有 sha256 校验），或 `source: source` 从源码编译。

### 3.2 离线优先 + outbox

outbox 即“待发送队列”：所有改动先写进本机，再按顺序发给服务器。

- 表：`records`、`chat_entries`、`accounts`（缓存）、`documents`（缓存）、`outbox(id UUID = 幂等键, space_id, op_type, payload_json, entity_id, request_id, created_at, attempts, state, last_error)`，以及 `spaces`（本人是有效成员的空间：名称、强调色、角色）、`space_members`（成员显示名与状态，用于记录卡上的创建者）、`sync_cursors(space_id, cursor)`。
- **所有业务表都带 `space_id`**，DAO 查询一律按当前空间过滤；没有不带 `space_id` 条件的业务查询（写测试守住）。
- 写操作在 **drift 的同一个事务**里完成：更新业务表（`sync_state = pending_upload`）+ 插入 outbox 行。
- `OutboxProcessor.drain()`：FIFO 逐条上传，`Idempotency-Key = outbox.id`，`X-Request-Id = outbox.request_id`（重发沿用同一个）。
  - 网络错误或超时：停下，稍后退避重试。
  - 401：停下，等待重新登录。
  - 其他永久性 4xx：把这一条标记为 failed（保留，让用户重试），继续下一条。
  - 成功：回写服务器返回值并删除 outbox 行。
- **互斥**：前台触发和后台任务共用一个 drain 锁（串行 `Future` 链或 `package:synchronized`）。workmanager 回调跑在**另一个 isolate**（独立的 Dart 执行线程），内存锁不共享，所以还要用数据库里的租约字段防止两个 isolate 同时上传同一条。服务器端幂等是最后一道兜底。
- **冲突**：更新带 `expected_version`，服务器返回 409 时客户端标记冲突、拉取最新版本并提示用户。
- **增量拉取**：每个空间一个游标（`sync_cursors`），按空间用服务器返回的 `change_seq` 拉取变更（含已作废记录的“墓碑”）；当前空间优先，其余空间随后刷新。幂等规则不变。
- **成员关系刷新**：每次同步先拉取本人的空间成员关系，更新 `spaces` 表。
  - 新加入或重新加入的空间：游标从 0 开始，完整回填该空间数据。
  - 某个空间从成员关系中消失（主动退出或被移除）：在一个事务里删除该空间的全部本地行、outbox 条目和游标，并清理该空间的缓存图片；若它是当前空间，切回默认个人空间。尚未上传的 outbox 条目一并丢弃，界面提示“已退出该空间，未上传的内容无法保存”。
- **创建者显示**：记录卡和详情上的创建者取自 `space_members.display_name`；成员已退出的显示“名字（已退出）”。

### 3.3 后台同步（无 GMS、厂商后台限制）

| 机制 | 说明 | 用法 |
|---|---|---|
| workmanager 0.10.10 | Flutter 官方“后台处理”页推荐；封装 Android WorkManager / iOS BGTaskScheduler；回调在独立 isolate 执行 | 注册唯一任务 “outbox”，要求联网，指数退避。**只当兜底** |
| connectivity_plus 7.3.2 | 只能说明有网卡连接，不保证真能上网 | 前台时网络从无到有立刻 drain；先用一次轻量 `/healthz` 请求确认可达 |
| App 生命周期 | `AppLifecycleListener` 监听回到前台 | 每次回到前台 drain 一次，刷新成员关系，并按空间增量刷新（当前空间优先）；启用应用锁时先验证（见 4.6） |
| 厂商后台限制 | 部分国内厂商系统默认几乎不允许后台任务运行 | 首次使用时引导用户把省电策略设为“无限制”、允许“自启动”；不设也不丢数据，只是上传延迟 |

### 3.4 网络、序列化、路由

| 类别 | 我们怎么定 |
|---|---|
| HTTP | **dio**：拦截器统一注入 `Authorization: Bearer`、`Idempotency-Key`、`X-Request-Id`；把 RFC 9457 problem+json 错误解析成 `ApiError(code, requestId)`。**所有路径都写相对路径**，以便服务端部署在反向代理的子路径下（写测试守住） |
| 序列化 | Dart 宏已于 2025-01 官方停止开发，所以用 **freezed + json_serializable + build_runner**（build_runner 2.13+ 增量构建快 2–4 倍）。DTO 字段用 snake_case 映射（`build.yaml` 全局 `field_rename: snake`）。不引入 OpenAPI 代码生成器：DTO 手写，以服务器导出的 `openapi.json` 中的示例做 JSON 往返测试 |
| 生成代码 | **提交进仓库**：评审者和 AI 代理不跑构建也能读到完整代码；CI 重新生成后 `git diff --exit-code`，不一致即失败 |
| 路由 | go_router：`StatefulShellRoute.indexedStack` 实现底部“聊天 / 总览 / 历史”三栏（切换时各栏保留状态）；详情和编辑用底部弹层，不进路由栈 |
| 金额 | 一律整数“分”（`int`），绝不用 `double` |

### 3.5 空间与成员

| 项 | 我们怎么定 |
|---|---|
| 切换 | `SpaceSwitcher`：顶栏左侧显示空间名称 + 一个强调色小圆点，低调不抢眼；点一下打开底部弹层，列出本人是有效成员的空间，底部是“新建空间”“空间设置”。切换只改当前空间，不换整屏配色 |
| 空间设置 | 改名、查看成员、邀请已有账号（v1 只有预建账号，按用户名邀请，无公开注册）、移除成员（仅 owner）、退出空间。默认个人空间不显示邀请入口，也不能退出 |
| 新建空间 | 填名称、从固定色板选强调色；创建者成为 owner |
| 移动记录 | 记录详情里的手动操作“移到其他空间”，只列出本人同时是成员的空间；服务器端执行“原空间作废 + 目标空间新建”并互相关联，客户端走普通 outbox 写入（带幂等键），完成后两边按增量同步刷新。AI 不做跨空间建议 |
| 隔离测试 | 组件测试和仓库测试覆盖：切换空间后不出现其他空间的记录、资料、聊天、数量和合计；退出空间后本地数据被清除 |

## 4. UI 系统

### 4.1 主题

- **两层结构**：① Material 3 底座 `ColorScheme`、`TextTheme`、组件主题（按钮最小 48×48、底部弹层圆角 20 等）；② `JiabuColors`、`JiabuType`、`JiabuDecor`、`JiabuMotion` 四个 `ThemeExtension`（必须实现 `copyWith` 和 `lerp`）。
- **单一主题 + 空间强调色**：只有一套 `ThemeData`（`JiabuTheme.light()`），不随空间换整屏配色。每个空间创建时从固定色板选一个强调色；色板颜色是 `jiabu_design` 里的设计令牌（`JiabuColors.spaceAccents`），业务代码只按色板序号取色。强调色只用在空间名称和小标记上（例如 SpaceSwitcher 的圆点、记录卡角标），不用于按钮、背景或金额。
- 访问方式统一为 `context.jiabu.colors.primary`；业务代码**禁止**出现 `Color(0x…)`、`Colors.*`、`TextStyle(fontFamily:)`。
- 不启用 Material You 动态取色；v1 不做深色主题。

### 4.2 字体

- 打包三个 OFL 字体：`jiabu_numerals.ttf`（Caveat SemiBold，约 100 KB）、`jiabu_serif.otf`（Noto Serif SC Bold 子集，约 1.1 MB）、`jiabu_hand.ttf`（霞鹜文楷 Medium 子集）。许可证放 `packages/jiabu_design/assets/licenses/`，用 `LicenseRegistry` 登记。
- **不引入 google_fonts**：它默认运行时向 fonts.google.com 请求字体（国内通常访问不了）。pubspec 里**显式写字重**（Flutter 不从文件名推断）。
- 数字 + 中文混排：`TextStyle.fontFamilyFallback` 回退链，或按字符类别切 `TextSpan`，统一封装在 `HandText`（见设计规范 7.2）。
- 手写文案字形覆盖检查：手写文案放 ARB，键名以 `hand` 开头；`tool/fonts/subset.py` 从 ARB 提取字符生成子集；CI 再检查一遍，出现子集外的字就失败。
- 用户输入、记录标题、表单一律用系统 sans。

### 4.3 图标

| 方案 | 结论 |
|---|---|
| **`tool/icons/icons.json` → 生成 Dart `Path` 代码**，`CustomPainter` 描边 | ✅ 采用。几何精确、运行时不解析、golden 稳定 |
| flutter_svg 2.3.0 / vector_graphics 1.2.4 | 只用于将来的插画、空状态图 |
| Material Icons / 第三方图标库 | ❌ 禁止用于业务图标（要求“形状一样”，不是“长得像”） |

### 4.4 动效与手感

| 主题 | 我们怎么定 |
|---|---|
| 隐式动画 | 默认用 `AnimatedContainer`、`TweenAnimationBuilder` 等；显式 `AnimationController` 只用于“三点跳动”“转圈”这类循环动画 |
| animations 包 | 按需使用（例如记录卡到详情），不强制引入 |
| 页面转场 | 保留框架默认（3.38 起安卓默认 `PredictiveBackPageTransitionsBuilder`，时长 450ms；测试里用 `TransitionDurationObserver`，不写死等待时间）；底部三栏切换不用页面转场 |
| 滚动物理 | **不改默认滚动物理**；业务代码禁止设置 `physics:`，除非 AGENTS.md 列为例外 |
| 动效令牌 | `JiabuMotion`：`sheet = 260ms, Cubic(.2,.8,.2,1)`、`scrim = 220ms`、`snack = 220ms`、`space = 250ms`（切换空间时内容淡入淡出）、`send = 200ms`、`cardIn = 220ms`；业务代码禁止写 `Duration(milliseconds: …)` 字面量 |
| 减少动态效果 | 跟随系统：`disableAnimations` 为真时所有时长为 0，循环动画换静态图标；倾斜角保留。v1 不做 App 内开关 |

### 4.5 渲染与性能

- **Impeller**（新一代渲染引擎，构建时预编译着色器，消除首次运行卡顿）：Flutter 3.27 起是 Android API 29+ 的默认引擎。这是 minSdk 定为 29 的主要理由之一——保证所有设备走同一条渲染路径。出现渲染异常时先记录机型和 GPU 再排查，不把“关掉 Impeller”当长期方案。
- 性能验收一律用 profile 或 release 包；在真机上 `flutter run --profile`，用 DevTools 看 UI / Raster 线程（每帧约 16ms 预算）。
- 常见卡顿源：build 里做重计算、整页 `setState`、未加 `const`、`saveLayer`（`Opacity`、`ClipRRect` 等离屏绘制）、过大的阴影模糊。对策：点阵用平铺图块；纸片阴影控制在两层；列表用 `ListView.builder` + `itemExtent` / `prototypeItem`（定高时）。

### 4.6 应用锁与隐私

可选功能，**默认关闭**，在设置里开启；锁的是整个 App，不按空间分别加锁（按空间加锁不在 v1 范围）。

| 项 | 我们怎么定 |
|---|---|
| 验证方式 | 生物识别（指纹 / 人脸，`local_auth`，Android 上走系统 BiometricPrompt，需把 `MainActivity` 改为 `FlutterFragmentActivity`）或图案锁（自绘组件，放在 `jiabu_design`）；两者都必须设置数字 PIN 作为兜底。设备不支持或未录入生物识别时直接用 PIN |
| 何时验证 | App 冷启动时；从后台回到前台且离开超过超时时间时（可配置，建议默认 1 分钟）。验证前只显示锁屏，不渲染任何业务页面 |
| 存储 | PIN 与图案只存加盐哈希（存于 flutter_secure_storage），不存明文；开关与超时存本机设置。连续输错退避等待；忘记 PIN 时重新输入账号密码登录后重设 |
| 通知 | 启用后通知不显示内容，只写“家簿有新消息”之类的通用文字，不出现金额、账户、记录或资料内容 |
| 最近任务缩略图 | 启用后遮挡：进入 `inactive` / `paused` 时盖一层纸面遮罩；同时仅在应用锁开启时给窗口设置 `FLAG_SECURE`（平台通道，几行 Kotlin）。注意 `FLAG_SECURE` 也会禁止截屏和录屏，在设置里说明 |
| 测试 | 单元测试覆盖超时判断、PIN 哈希校验与退避；组件测试覆盖锁屏遮挡与解锁流程；生物识别用假 Service 替身 |

## 5. 日志与崩溃

- `package:logging` + 自写 `FileLogSink`（本机滚动 5 个 1 MB 文件）。
- `FlutterError.onError` + `PlatformDispatcher.instance.onError` 捕获异常，写本机日志，下次启动时上报到服务器的 `/client-logs` 接口。每条带 `request_id`、App 版本、设备型号、系统版本。
- 日志不得包含令牌、密码、记账原话等个人信息。
- 不用 Firebase Crashlytics（后端在国内不可用）；不自建 Sentry（自建版至少 4 核 16 GB，对两人 App 不值得）。

## 6. 测试与质量关卡

### 6.1 测试金字塔

| 层 | 工具 | 内容 | 关卡 |
|---|---|---|---|
| 单元测试 | `flutter_test` + mocktail 1.0.5 | Money 运算与格式、ViewModel 状态迁移、仓库（真 drift 内存库）、OutboxProcessor 全部分支、DTO JSON 往返（用 `openapi.json` 示例做夹具）、drift 迁移测试 | CI 必过 |
| 组件测试 | `flutter_test` | 交互流程：发送 → 记录卡 → 编辑 → 撤销 → 恢复；空间切换与隔离；应用锁遮挡与解锁；360 / 430 宽 × 100% / 200% 字号无溢出（`tester.takeException()` 为空） | CI 必过 |
| **几何断言** | `flutter_test` | 直接断言关键元素：记录卡宽 332、胶带角度 −5°、相对卡片上沿 −10、印章 −5°、贴纸 −6°、便利贴角度 = `tiltFor(id)`；期望值取自设计规范 | **硬关卡，零容差**（尺寸 ±0.5 逻辑像素、角度精确相等） |
| golden 截图 | `matchesGoldenFile`（内置） | 每个界面状态 × 两种空间强调色 × 390×844@2.75 与 360×780；字体真实加载 | CI 必过（只在固定工具链里生成 / 校验） |
| 像素差异报告 | `tool/parity/report.py` | 与冻结的参考截图集比较：每个状态的“差异像素 %”和“>16/255 差异 %”、差异图和叠加图 | **趋势关卡**：不得高于上次批准值，目标 < 6% |
| 集成测试 | `integration_test`（不能操作系统原生界面）；patrol 4.10.0 后补（能操作权限弹窗、通知栏） | 真机冷启动 → 登录 → 记账 → 杀进程 → 重开数据仍在 | 发版前在测试机上手动触发 |
| 静态检查 | `dart analyze`、`dart format --set-exit-if-changed`、`tool/check_rules.dart` | 见第 7 节 | CI 必过 |

像素差异只作为趋势关卡、不硬卡接近 0：字体光栅化和模糊算法的差异使“像素完全一致”在技术上做不到，硬卡只会诱导“作弊式微调”。最终以真机观感为准；某界面在真机确认通过后，其 golden 成为新基线。

### 6.2 golden 测试要点

- **字体**：flutter_test 默认用 Ahem 字体（每个字都是方块）。在 `flutter_test_config.dart` 里用 `FontLoader` 加载真实字体；系统 sans 在测试里用固定版本的 Noto Sans CJK SC（只作为测试夹具放在 `test/fonts/`，不打包进 App）。
- **阴影**：默认测试绑定会关闭阴影（`disableShadows`），要自定义绑定并设 `disableShadows = false`。
- **确定性**：golden 只在**同一套固定工具链**（固定 Flutter 版本、固定字体、x86_64 Linux）里生成和校验（官方文档明确提醒不同操作系统生成的 golden 很可能不同）。时间、随机数、动画一律注入固定值。
- **库**：golden_toolkit 已停更并下架；alchemist 的“CI golden”把文字画成方块，而我们要比较真实字形，所以直接用内置 `matchesGoldenFile` + 自定义绑定。
- **重新录制**：只有 PR 描述写明“预期变化”并附新旧对比图时，才允许 `--update-goldens`；golden 被改动而 PR 没有 `visual-change` 标签，CI 直接失败。

## 7. 代码规范（AI 编程代理必须遵守）

### 7.1 工具与配置

| 项 | 我们怎么定 |
|---|---|
| lint 规则集 | **very_good_analysis 11.0.0**（比 flutter_lints 更严：强制类型标注、禁止 `print`、禁止不必要的 `dynamic`、强制 `const` / `final`） |
| 额外规则 | warning 当 error；启用 `strict-casts`、`strict-inference`、`strict-raw-types`；`plugins: riverpod_lint` |
| 格式化 | `dart format`，默认宽度 80；CI `--set-exit-if-changed` |
| 自定义检查 `tool/check_rules.dart` | ① `lib/features/**`、`lib/data/**` 中禁止 `Color(`、`Colors.`、`fontFamily:`、`Duration(milliseconds:` 字面量；② 禁止 `Transform.rotate` / `RotationTransition`，只能用 `jiabu_design` 的 `Tilt`；③ 禁止导入 `package:http`、`google_fonts`、`firebase_*`、`sqlite3_flutter_libs`、`isar`、`get`；④ 禁止 Riverpod 旧 API；⑤ `features/a` 不得导入 `features/b`；⑥ View 文件不得导入 `data/`；⑦ 新增依赖必须出现在 `tool/allowed_deps.yaml`，由人审批 |
| 命名与目录 | Effective Dart：文件 `snake_case.dart`，类型 `UpperCamelCase`，成员 `lowerCamelCase`；加项目约定 `*_screen.dart`（View）、`*_view_model.dart`、`*_repository.dart`、`*_service.dart`、`*_dto.dart`；一个文件一个公开 Widget |
| 文案 | 即使只有中文也用 gen-l10n + ARB（`app_zh.arb`）：手写字体子集从这里提取字符；文案集中审稿；以后加繁体或英文成本低 |
| 提交规范 | Conventional Commits（`feat:`、`fix:`、`test:`、`refactor:`、`chore:`）；每个提交只做一件事；PR 模板附“测试 / golden 变化 / 几何断言 / 真机验收项” |

### 7.2 AGENTS.md 要点

`client/AGENTS.md` 是 AI 编程代理每次开工先读的规则文件，要点如下：

```markdown
# Jiabu Flutter client — rules for coding agents
Fake data only. Never print or commit secrets.

## Commands (x86_64 Linux build host only)
fvm flutter pub get · dart run build_runner build -d · fvm flutter analyze · dart format --set-exit-if-changed .
fvm flutter test · fvm flutter test --tags golden · dart run tool/check_rules.dart · tool/parity_report.sh

## Architecture (docs.flutter.dev/app-architecture)
View → ViewModel (@riverpod Notifier/AsyncNotifier) → Repository → Service. Views never import data/.
drift is the single source of truth. A write = local row change + outbox row in ONE transaction.
Everything is scoped by spaceId: every table has space_id, every query filters by it, repositories take spaceId explicitly.
Never show, count or hint at data from another space.
Every mutating request carries Idempotency-Key = outbox.id and X-Request-Id. Money = int minor units (fen). Never double.
Repositories return Result<T>; ViewModels expose immutable freezed UiState.

## Design system (packages/jiabu_design)
No Color/Colors/fontFamily/Duration literals outside jiabu_design. Use context.jiabu.* tokens and jiabu components.
Cards/lists/forms/sheets/snackbars are 0°. Tilt only decorations via Tilt(tiltFor(id) * amp).
Icons only from JiabuIcons (generated from tool/icons/icons.json). Never Material/Cupertino icons for business UI.
Hand font only for ARB keys starting with "hand"; user text always system sans.
Motion only from JiabuMotion; honour MediaQuery.disableAnimations. Do not override scroll physics.

## Tests required with every change
Unit tests for ViewModel/repository; widget test for interaction; golden for every new visual state
(two space accents, 390 and 360, 100% and 200% text); geometry assertions for card/tape/stamp/sticker.
Never run --update-goldens unless the task says the visual change is intended; attach before/after.

## Forbidden
Riverpod legacy APIs, setState for business data, `!` on nullable values without a comment,
new dependencies not in tool/allowed_deps.yaml, google_fonts, firebase, sqlite3_flutter_libs, isar, GetX.
```

### 7.3 开发工作流与验收关卡

| 关卡 | 由谁 / 在哪 | 通过标准 |
|---|---|---|
| G0 计划 | AI 代理写，人审 | 每个任务先列：改哪些文件、新增哪些测试和 golden 状态、预期的视觉变化 |
| G1 静态 | CI | analyze 零问题、format 无差异、`check_rules` 通过、生成代码与源一致 |
| G2 测试 | CI | 单元、组件、几何断言全绿；覆盖率不下降（目标：data / view_model ≥ 90%，不追求 100%） |
| G3 视觉 | CI + 人工审图 | golden 全过；有意的视觉变化附新旧对比；像素报告不高于上次批准值；**审图必须真的打开 PNG 看** |
| G4 真机 | 项目负责人 | 在安卓测试机上用 release 包按清单试手感；不通过的项先补测试再修 |

### 7.4 官方 AI 资源

| 资源 | 现状 | 用法 |
|---|---|---|
| 旧的 Flutter “AI rules” 文件 | 已从 flutter/flutter 仓库撤下，改指向 docs.flutter.dev/ai/get-started | 不使用 |
| flutter/agent-plugins | 官方插件，含 10 个技能 | **只挑纯 markdown 的技能**（add-widget-test、apply-architecture-best-practices、fix-layout-issues、setup-localization），逐个审阅后拷进 `docs/agent-skills/flutter/`；`use-http-package` 用 `package:http`，与 dio 冲突，不拷 |
| Dart & Flutter MCP 服务器（`dart mcp-server`，需 Dart ≥ 3.9） | 默认开启 analyze、hot reload、pub、widget inspector 等；run_tests、dart_format 默认关闭 | 只在构建机上给 AI 代理配置，按需 `--enable run_tests,dart_format` |
| GenUI | `genui` 包仍是 alpha | 不用 |

## 8. 项目结构

```
client/                                  # pub workspace 根
  pubspec.yaml                           # workspace: [app, packages/jiabu_design]
  .fvmrc                                 # {"flutter": "3.47.8"}
  AGENTS.md
  analysis_options.yaml                  # very_good_analysis + strict + riverpod_lint
  tool/
    check_rules.dart                     # 自定义规则（第 7 节）
    allowed_deps.yaml
    icons/icons.json + gen_icons.dart    # 图标源 → JiabuIcons 生成
    fonts/subset.py                      # 从 ARB hand* 提取字符 → 子集
    parity/report.py                     # 像素差异报告
    build-host/setup.sh                  # 构建机工具链安装脚本（用户目录安装、锁版本）
  packages/jiabu_design/
    lib/src/tokens/{colors,type,decor,motion}.dart   # ThemeExtension × 4，单套 + 空间强调色色板
    lib/src/theme.dart                   # JiabuTheme.light() → ThemeData
    lib/src/geometry/{tilt,tape_path,paper,shadow}.dart
    lib/src/icons/jiabu_icons.g.dart     # 生成，提交
    lib/src/components/                  # PaperCard, Tape, Sticker, Stamp, Polaroid, HandText,
                                         # AmountText, SpaceSwitcher, PatternLock, NoteBubble, PaperSheet, PaperSnackBar …
    assets/fonts/ assets/licenses/
    test/ goldens/                       # 组件级 golden（两种空间强调色）
  app/
    pubspec.yaml                         # resolution: workspace
    lib/
      main_dev.dart  main_prod.dart      # flavor 入口
      app/{app.dart, router.dart, env.dart}
      l10n/app_zh.arb
      domain/{money.dart, space.dart, record.dart, sync_state.dart, result.dart}
      data/
        db/{tables.dart, daos/, database.dart, migrations/}
        api/{api_client.dart, interceptors/, dto/}
        repositories/{records_repository.dart, chat_repository.dart, overview_repository.dart, auth_repository.dart, spaces_repository.dart}
        services/app_lock_service.dart   # local_auth、PIN / 图案哈希、FLAG_SECURE 平台通道
        sync/{outbox_processor.dart, sync_triggers.dart, background_sync.dart}
      features/
        chat/{view/chat_screen.dart, view_model/chat_view_model.dart, widgets/}
        overview/  history/  auth/  spaces/  lock/
      shared/                            # 跨 feature 的业务组件：RecordCard, RecordRow, EditRecordSheet, TimeLabel
    test/  test/fixtures/sample_data.dart
    integration_test/
    goldens/ goldens/reference/          # 冻结的参考截图集（只读）
    android/                             # Gradle：AGP 9.x 内置 Kotlin、flavor、签名读取环境变量
```

**第一批切片**（每片都走完 G0–G4）：

1. 工程骨架：workspace、FVM、构建机工具链脚本、CI 关卡、AGENTS.md、check_rules，加一个空白页的 golden。
2. `jiabu_design`：令牌、字体、图标、Tilt、PaperCard、Tape、Stamp、Sticker，配组件目录页、golden 和几何断言。
3. 聊天页（离线、只用本机）：记录卡 / 追问 / 编辑 / 撤销 / 空间切换。
4. 数据层：drift + outbox + dio + 登录，对接服务端。
5. 总览、历史。
6. 空间管理（新建、改名、成员、邀请、移除、退出、移动记录）与应用锁。

## 9. 构建与发布

| 项 | 我们怎么定 |
|---|---|
| 构建主机 | 只在 x86_64 Linux 上跑 `pub get`、代码生成、测试、golden、打包。构建机工具链由安装脚本固定：Flutter 3.47.8、JDK 17、Android SDK 37、NDK 28.2.13676358、AGP 9.4.1、Gradle 9.8.2、Kotlin 2.4.21、测试字体 |
| 版本锁定 | FVM：`.fvmrc` 写死 `3.47.8`。升级 Flutter 是独立的 PR：先升版本，再重录 golden，再真机确认 |
| Android 版本 | **minSdk 29**（Android 10），compile / target 37；按官方迁移指南配置 AGP 9 内置 Kotlin |
| flavor | `dev`（`applicationIdSuffix ".dev"`，名称“家簿 dev”通过 `manifestPlaceholders` 设置——AGP 9+ 下用 `resValue` 设 `app_name` 会失败——可与正式版同时安装）/ `prod`。base URL 用 `--dart-define-from-file=env/prod.json` 传入，不硬编码 |
| 签名 | `key.properties` + `signingConfigs`，密钥**绝不入库**；正式密钥只存放在构建机上（权限 600）并离线备份两份。丢了密钥就无法给已装的 App 推升级 |
| 产物 | `flutter build apk --release --flavor prod --target-platform android-arm64 --obfuscate --split-debug-info=build/symbols`；release 始终开启 R8；符号文件按版本存档，崩溃堆栈用 `flutter symbolize` 还原（混淆不加密资源、也不能防逆向） |
| 版本号 | `pubspec.yaml` 的 `version: x.y.z+build`；名称按语义化版本，构建号单调递增 |
| 分发 | 不上架应用商店，APK 侧载安装（需允许“安装未知应用”）；v2 再做 App 内“检查更新” |
| Google 开发者验证 | 2026-09-30 起在部分国家对“经过 Google 认证的安卓设备”生效，2027 年起逐步扩展到全球；“有限分发”账号可分发给最多 20 台设备。无 GMS 的国内设备预计不受影响（推断），正式包名仍建议提前登记 |
| iOS（将来） | 需要 macOS + Xcode。drift、dio、Riverpod、go_router 都支持 iOS；后台同步换 BGTaskScheduler（workmanager 已封装）；平台相关代码（后台任务、相机）集中在 Service 层 |

## 10. 风险

| # | 风险 | 影响 | 对策 |
|---|---|---|---|
| 1 | 文字度量、阴影模糊无法做到像素级一致 | 观感“有点不一样” | 几何断言保证位置、尺寸、角度精确一致；像素报告作为趋势关卡；必要时针对组件微调行高（`TextHeightBehavior`、`StrutStyle`） |
| 2 | AI 写出 Riverpod 2 旧写法、过时的包 | 风格混乱、依赖停更 | AGENTS.md 禁用清单、check_rules、依赖白名单 |
| 3 | drift / sqlite3 构建时要从 GitHub 下载 | 网络受限时构建失败 | `url_pattern` 指向自建镜像，或从源码编译 |
| 4 | workmanager 是社区插件；后台回调在独立 isolate | 后台同步不稳定、并发上传 | 前台触发为主；数据库租约防重复；服务器端幂等兜底 |
| 5 | 厂商系统杀后台 | 上传延迟 | 引导设置白名单；数据始终先保存在本机 |
| 6 | 中文输入法在 Flutter 文本框里的组字、光标问题 | 记账核心体验 | 第 3 片就在真机上用主流中文输入法实测，问题记 issue 跟踪上游 |
| 7 | Impeller 在个别 GPU 驱动上有渲染问题 | 个别画面异常 | 记录机型和 GPU；关闭开关不能当长期方案（官方路线图计划移除旧后端） |
| 8 | golden 对环境敏感 | 换一台机器就“全红” | 只在固定工具链里生成；FVM 和安装脚本同时锁版本 |
| 9 | Google 对 Flutter 的长期投入存在不确定性 | 长期风险 | Flutter 仍保持每季度一个稳定版；数据层与 UI 分离，迁移成本可控 |
| 10 | 安装包比原生大（约 18 MB） | 几乎无影响 | 只打 arm64；混淆；字体子集化 |
| 11 | Material 组件将拆分为独立的 `material_ui` / `cupertino_ui` 包 | 升级时要改导入 | 按官方迁移指南处理；业务 UI 大多是自绘组件 |
| 12 | 本机残留已退出空间的数据 | 失去权限后仍能看到内容 | 成员关系刷新时事务性清除该空间的行、outbox、游标与缓存图片；仓库测试覆盖 |

## 附录 A：pubspec 草案

```yaml
# client/pubspec.yaml（workspace 根）
name: jiabu_workspace
publish_to: none
environment:
  sdk: ^3.13.7
workspace:
  - app
  - packages/jiabu_design

# client/app/pubspec.yaml
name: jiabu
publish_to: none
version: 0.1.0+1
resolution: workspace
environment:
  sdk: ^3.13.7
  flutter: 3.47.8
dependencies:
  flutter: { sdk: flutter }
  flutter_localizations: { sdk: flutter }
  jiabu_design: { path: ../packages/jiabu_design }
  flutter_riverpod: ^3.4.3
  riverpod_annotation: ^4.0.0     # 与 riverpod_generator 4.x 配套（以 pub get 解析为准）
  drift: ^2.35.3
  dio: ^5.11.1
  freezed_annotation: ^3.0.0      # 与 freezed 4.x 配套（以 pub get 解析为准）
  json_annotation: ^4.12.0
  go_router: ^18.1.1
  workmanager: ^0.10.10
  connectivity_plus: ^7.3.2
  flutter_secure_storage: ^11.2.0
  # local_auth: 应用锁（4.6），开工时核实最新稳定版后锁定
  shared_preferences: ^2.5.6
  uuid: ^4.6.0
  intl: ^0.20.3
  logging: ^1.3.0
  package_info_plus: ^10.2.2
dev_dependencies:
  flutter_test: { sdk: flutter }
  integration_test: { sdk: flutter }
  build_runner: ^2.17.1
  riverpod_generator: ^4.0.9
  riverpod_lint: ^3.1.9
  drift_dev: ^2.35.2
  freezed: ^4.0.3
  json_serializable: ^6.15.2
  very_good_analysis: ^11.0.0
  mocktail: ^1.0.5
flutter:
  generate: true      # gen-l10n
hooks:
  user_defines:
    sqlite3:
      source: sqlite3
      url_pattern: "https://<自建镜像>/sqlite3/$RELEASE_TAG/$FILENAME"   # 见 3.1
```

`riverpod_annotation` 与 `freezed_annotation` 的配套主版本是按生成器主版本推断的，以实际 `pub get` 解析结果为准，并提交 `pubspec.lock`。

## 附录 B：analysis_options.yaml 草案

```yaml
include: package:very_good_analysis/analysis_options.yaml
analyzer:
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true
  errors:
    invalid_annotation_target: ignore   # freezed + json_serializable 的已知用法
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"
    - build/**
plugins:
  riverpod_lint: ^3.1.9
linter:
  rules:
    public_member_api_docs: false       # App 代码不强制写公开 API 文档
```

## 附录 C：CI 关卡脚本

```bash
set -euo pipefail
fvm flutter pub get
dart run build_runner build -d && git diff --exit-code         # 生成代码必须已提交且一致
dart format --set-exit-if-changed .
fvm flutter analyze --fatal-infos
dart run tool/check_rules.dart
fvm flutter test --coverage                                     # 单元 + 组件 + 几何 + golden
python3 -I tool/parity/report.py --baseline goldens/reference --check-trend
fvm flutter build apk --release --flavor prod --target-platform android-arm64 \
  --obfuscate --split-debug-info=build/symbols --dart-define-from-file=env/prod.json
```

## 附录 D：待验证项

1. `TextStyle.fontFamilyFallback` 做“Caveat 数字 + 楷体中文”混排在真机上的实际效果（API 存在，需 golden 和真机验证）。
2. workmanager 后台回调与前台不在同一个 isolate、内存锁不共享（按其独立入口设计推断，实现时验证）。
3. Flutter 3.47 所需的最低 Kotlin / Gradle 版本（官方只写“AGP 9+”）。
4. 国内厂商系统（相对已有社区资料）具体的后台限制。
5. 无 GMS 的国内设备不受 Google 开发者验证影响（推断）。
6. `local_auth` 在国内厂商系统上的实际可用方式：BiometricPrompt 不依赖 GMS，但不少机型的人脸解锁不对第三方 App 开放，可能只能用指纹（需真机验证）。
7. 各厂商系统对 `FLAG_SECURE` 与最近任务缩略图遮挡的实际表现。

## 附录 E：主要来源

- Flutter 发布清单：https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json ；版本归档：https://docs.flutter.dev/install/archive ；支持平台：https://docs.flutter.dev/reference/supported-platforms
- 架构：https://docs.flutter.dev/app-architecture （guide / recommendations / design-patterns / case-study）；Compass 示范：https://github.com/flutter/samples/tree/main/compass_app
- 状态管理选项：https://docs.flutter.dev/data-and-backend/state-mgmt/options ；pub workspaces：https://dart.dev/tools/pub/workspaces
- Dart 宏停止开发：https://dart.dev/blog/an-update-on-dart-macros-data-serialization
- sqlite3 构建钩子：https://github.com/simolus3/sqlite3.dart/blob/main/sqlite3/doc/hook.md ；后台处理：https://docs.flutter.dev/packages-and-plugins/background-processes
- 主题：https://docs.flutter.dev/cookbook/design/themes ；字体：https://docs.flutter.dev/cookbook/design/fonts ；动画：https://docs.flutter.dev/ui/animations
- Impeller：https://docs.flutter.dev/perf/impeller ；性能：https://docs.flutter.dev/perf/ui-performance
- 测试：https://docs.flutter.dev/testing/overview ；golden：https://api.flutter.dev/flutter/flutter_test/matchesGoldenFile.html
- 发布：https://docs.flutter.dev/deployment/android 、https://docs.flutter.dev/deployment/obfuscate 、https://docs.flutter.dev/deployment/flavors ；AGP 9 内置 Kotlin：https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin
- FVM：https://fvm.app/documentation/getting-started ；Google 开发者验证：https://developer.android.com/developer-verification
- AI 资源：https://docs.flutter.dev/ai/get-started 、https://github.com/flutter/agent-plugins 、https://github.com/dart-lang/ai/tree/main/pkgs/dart_mcp_server
- 包信息：https://pub.dev/packages/<name>（及 `pub.dev/api/packages/<name>`）
