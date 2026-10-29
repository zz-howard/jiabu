# C4b 交付说明

## 实现边界

本切片只改 Flutter 客户端、Android 资源声明、测试和本交付说明。没有修改
`server/` 或 `docs/`，没有增加依赖，没有改登录会话、分区数据库或会话存储逻辑。

实现机没有 Dart / Flutter；全部动态验证由 luna.coco 在构建机上完成：pub get、gen-l10n、
build_runner、format、analyze（无 issue）、`check_rules.dart`、图标检查、workspace /
jiabu_design / app 测试（app 4502 项）和 golden 校验（796 项）全部通过。字体 A/B、keys
golden 原因排查和输入语义负对照的结果见 PR 说明。

## 品牌组件

- `JiabuLogo` 使用 resolution-aware PNG，支持 standard / dark 变体、自定义尺寸与角度，
  默认使用 `JiabuDecor.logoTilt == -8`，默认语义标签为「家簿」。
- 深色变体使用 `logo-dark-disc.png`。
- `JiabuMascot` 支持 greet / pen / idle 三个 pose，默认作为装饰图，也可传入
  语义标签。
- 删除 `JiabuLogoSealPlaceholder`。该包为 `publish_to: none` 的仓库内包，全部
  调用点已同步替换，不保留可被新代码继续误用的 deprecated 空白章别名。
- 解锁页和 lock covered 页均改用正式 Logo；Logo 和三个仓鼠 pose 已进 catalog。

## 首次启动与默认服务器

默认服务器只从编译期参数读取：

```text
--dart-define=JIABU_DEFAULT_SERVER=https://...
```

产品源码和测试中没有真实域名。传入值会按现有 `normalizeServer` 规则归一化；
空值或非法值按「没有默认服务器」处理。

启动判定使用现有 `AppSettingsService.servers()` / `current()` 和 auth resume 结果：

- 没有记住过服务器且无会话：欢迎页。
- 已记住服务器但无会话：直接登录页。
- 恢复会话成功：现有 session 页/主页。

持久化读取和 resume 完成前使用独立 loading 页，不先渲染欢迎页，因此已配置用户
不会闪现首启内容。

没有默认服务器时：

- 欢迎页「直接登录」进服务器页。
- 服务器页直接展示地址输入，不显示默认卡、高级设置或恢复默认。
- 登录页 footer 显示实际地址。

有默认服务器时：

- 欢迎页「直接登录」先用现有 `/v1/meta` 探测，成功才进登录页。
- 服务器页默认收起，展开高级设置后可输入自定义地址和恢复默认。

自定义地址必须以 `https://` 开头。UI 在回调前拒绝不安全地址，ViewModel 再做
一次防御性验证。没有改全局 `normalizeServer`，因此本地服务端集成测试仍可使用 HTTP。

登录页「✓ 已连接」只依赖 `VersionHandshakeService.check()` 成功返回后设置的
`serverProbeSucceeded`；默认 `SyncStatus.idle` 不再被误当成已探测。

## 邀请码占位

「注册 / 加入家庭」只打开 `PaperSheet` 说明弹层，告知用户功能即将开放，并请
家庭管理员先创建账号。没有输入框、提交按钮、repository 或网络调用。

`TODO(invite-signup)` 留在 `invite_signup_sheet.dart`。首版不开放公开注册。

`auth_invite_network_test` 用真实 `AuthShell`、auth repository 和 API client，只替换传输层
（`RuntimeAdapter`），断言点击后请求数不增加；负对照（在点击里接上真实登录）会失败并列出
`v1/auth/login`。

## 字体

以下两条恢复 hand key 与 `HandText`：

- `handC4Locked`
- `handC4KeysSubtitle`

首启新增 hand key：`handAuthStep`、`handAuthWelcomeTagline`、
`handAuthBrandEnglish`、`handAuthWelcomeGreeting`、`handAuthServerHint`、
`handAuthWelcomeHome`、`handAuthWelcomeHomeEnglish`。

相对当前 hand 字符源，重生成子集将新增：

```text
C U+0043, I U+0049, J U+004A, L U+004C, W U+0057,
b U+0062, f U+0066, j U+006A, k U+006B, w U+0077,
不 U+4E0D, 么 U+4E48, 了 U+4E86, 什 U+4EC0, 以 U+4EE5,
句 U+53E5, 呀 U+5440, 和 U+548C, 回 U+56DE, 就 U+5C31,
帮 U+5E2E, 我 U+6211, 接 U+63A5, 改 U+6539, 来 U+6765,
欢 U+6B22, 簿 U+7C3F, 继 U+7EE7, 续 U+7EED, 脚 U+811A,
般 U+822C, 让 U+8BA9, 说 U+8BF4, 迎 U+8FCE, 锁 U+9501
```

不修改 `jiabu_hand.ttf` 或 `subset_manifest.json`。构建机必须在 gen-l10n 后运行
`tool/fonts/subset.py`，并提交重生成的字体与 manifest。既有 `font_coverage_test.dart`
会覆盖全部 hand ARB 字符；新测试另外确认两条恢复文案实际使用 hand font stack。

## Android 图标

- adaptive icon XML 同时声明 background / foreground / monochrome。
- background 来自 `values/ic_launcher_background.xml` 的 `#F6EFE2`。
- Manifest 增加 `android:roundIcon`。
- dev、prod-beta、prod-stable 共用同一套图标，dev 不加角标。
- 当前没有通知投递代码，因此只声明 `ic_stat_jia` 资源要求，Manifest 保留
  `TODO(notifications)`。

## 待 luna.coco 生成/放入

### jiabu_design 品牌 PNG

- Logo：standard 和 dark-disc，每种 256 / 512 / 768 px，对应 1x / 2x / 3x。
- 仓鼠：greet / pen / idle，每种 360 / 720 / 1080 px，对应 1x / 2x / 3x。

`pubspec.yaml` 已登记基准文件，`brand_assets_test.dart` 会检查全部 15 个文件的存在性和
像素尺寸；在图片放入前失败是预期结果。

### Android PNG

- adaptive foreground / monochrome：108 / 162 / 216 / 324 / 432 px。
- legacy `ic_launcher` / `ic_launcher_round`：48 / 72 / 96 / 144 / 192 px。
- `ic_stat_jia`：24 / 36 / 48 / 72 / 96 px。

`c4b_android_resources_test.dart` 会检查文件、像素尺寸、XML 引用和 Manifest。

### 生成代码与字体

1. `flutter gen-l10n`
2. `dart run build_runner build --delete-conflicting-outputs`
3. `python3 tool/fonts/subset.py ...`
4. 不手改 `*.g.dart`、`*.freezed.dart` 或 `subset_manifest.json`

## Golden

C4b 新增 26 张：

- welcome / server_collapsed / server_expanded / login_connected /
  invite_placeholder，每个状态三张：
  `zh_pine_w360_text100`、`zh_pine_w430_text200`、`en_pine_w360_text100`。
- 错误、忙碌和次级页面状态各一张 `zh_pine_w360_text100`：server_unreachable、
  login_invalid、login_busy、password_forced、password_invalid、session_idle、
  session_admin_reset、session_space_cleared、switch_pending。
- `jiabu_logo_variants_zh_pine_w360_text100.png`。
- `jiabu_mascot_poses_zh_pine_w360_text100.png`。

因 Logo/锁屏 hand 文案变化重录 13 张既有 unlock PNG：biometric、pin、pattern、
error、wait、recovery 的中文 360/100% 与 430/200%，另加 pin 英文 360/100%。

因 `c4KeysSubtitle` 恢复为手写 `handC4KeysSubtitle`（文案不变，字体从 Sans 换回手写，
下方布局随之移动）重录 11 张既有 keys PNG：empty、list、offline、failure、inactive 的中文
360/100% 与 430/200%，另加 list 英文 360/100%。

总计 50 张新录或重录（另有 hand 字体重新子集化导致的既有 golden 重录，见 PR 说明）。
旧 C2 auth 352 张全排列已删除，各状态的替代覆盖见 PR 说明中的覆盖对照表。

完整路径清单：

```text
app/test/goldens/c4b/welcome_zh_pine_w360_text100.png
app/test/goldens/c4b/welcome_zh_pine_w430_text200.png
app/test/goldens/c4b/welcome_en_pine_w360_text100.png
app/test/goldens/c4b/server_collapsed_zh_pine_w360_text100.png
app/test/goldens/c4b/server_collapsed_zh_pine_w430_text200.png
app/test/goldens/c4b/server_collapsed_en_pine_w360_text100.png
app/test/goldens/c4b/server_expanded_zh_pine_w360_text100.png
app/test/goldens/c4b/server_expanded_zh_pine_w430_text200.png
app/test/goldens/c4b/server_expanded_en_pine_w360_text100.png
app/test/goldens/c4b/login_connected_zh_pine_w360_text100.png
app/test/goldens/c4b/login_connected_zh_pine_w430_text200.png
app/test/goldens/c4b/login_connected_en_pine_w360_text100.png
app/test/goldens/c4b/invite_placeholder_zh_pine_w360_text100.png
app/test/goldens/c4b/invite_placeholder_zh_pine_w430_text200.png
app/test/goldens/c4b/invite_placeholder_en_pine_w360_text100.png
app/test/goldens/c4b/jiabu_logo_variants_zh_pine_w360_text100.png
app/test/goldens/c4b/jiabu_mascot_poses_zh_pine_w360_text100.png
app/test/goldens/c4b/server_unreachable_zh_pine_w360_text100.png
app/test/goldens/c4b/login_invalid_zh_pine_w360_text100.png
app/test/goldens/c4b/login_busy_zh_pine_w360_text100.png
app/test/goldens/c4b/password_forced_zh_pine_w360_text100.png
app/test/goldens/c4b/password_invalid_zh_pine_w360_text100.png
app/test/goldens/c4b/session_idle_zh_pine_w360_text100.png
app/test/goldens/c4b/session_admin_reset_zh_pine_w360_text100.png
app/test/goldens/c4b/session_space_cleared_zh_pine_w360_text100.png
app/test/goldens/c4b/switch_pending_zh_pine_w360_text100.png
app/test/goldens/c4/unlock_biometric_zh_pine_w360_text100.png
app/test/goldens/c4/unlock_biometric_zh_pine_w430_text200.png
app/test/goldens/c4/unlock_pin_zh_pine_w360_text100.png
app/test/goldens/c4/unlock_pin_zh_pine_w430_text200.png
app/test/goldens/c4/unlock_pin_en_pine_w360_text100.png
app/test/goldens/c4/unlock_pattern_zh_pine_w360_text100.png
app/test/goldens/c4/unlock_pattern_zh_pine_w430_text200.png
app/test/goldens/c4/unlock_error_zh_pine_w360_text100.png
app/test/goldens/c4/unlock_error_zh_pine_w430_text200.png
app/test/goldens/c4/unlock_wait_zh_pine_w360_text100.png
app/test/goldens/c4/unlock_wait_zh_pine_w430_text200.png
app/test/goldens/c4/unlock_recovery_zh_pine_w360_text100.png
app/test/goldens/c4/unlock_recovery_zh_pine_w430_text200.png
app/test/goldens/c4/keys_empty_zh_pine_w360_text100.png
app/test/goldens/c4/keys_empty_zh_pine_w430_text200.png
app/test/goldens/c4/keys_list_zh_pine_w360_text100.png
app/test/goldens/c4/keys_list_zh_pine_w430_text200.png
app/test/goldens/c4/keys_list_en_pine_w360_text100.png
app/test/goldens/c4/keys_offline_zh_pine_w360_text100.png
app/test/goldens/c4/keys_offline_zh_pine_w430_text200.png
app/test/goldens/c4/keys_failure_zh_pine_w360_text100.png
app/test/goldens/c4/keys_failure_zh_pine_w430_text200.png
app/test/goldens/c4/keys_inactive_zh_pine_w360_text100.png
app/test/goldens/c4/keys_inactive_zh_pine_w430_text200.png
```

Logo / 仓鼠用 `Image.asset`，golden 截图前由 `test/support/image_harness.dart` 的
`settleImages()` 在 `runAsync` 里预解码全部图片，并断言可见图片都已解码（否则首张截图是空白纸面）。
深色 Logo 是给深色底用的纸色圆盘，catalog 里放在 `ink` 底上展示。

## 负对照

`tool/c4b-negative-controls.json` 含 5 条独立控制：

1. 已配置服务器仍显示欢迎页。
2. 接受非 HTTPS 地址。
3. 未探测即显示已连接。
4. 邀请占位触发登录/网络回调。
5. Logo 默认不倾斜。

## 待构建机确认

- 新 AuthFrame 在 430dp / 200% 下的实际排版与滚动位置。
- Flutter 是否按预期从 package asset 选择 2.0x / 3.0x 变体。
- Android compileSdk 37 对 v26 adaptive XML 中 monochrome 层的实际打包结果。
- gen-l10n / Freezed 生成后的 API 签名与 analyzer 诊断。
- 新字体子集对全部新 hand 文案的 cmap 覆盖。
