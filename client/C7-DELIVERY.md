# C7 交付说明：安装与更新

## 做了什么

- prod App 登录后进入主框架检查一次更新；回前台且距上次实际发起检查满 24 小时再查。检查失败和没有新版都安静跳过。
- 更新状态使用 App 级 `SharedPreferences`：检查时间按服务端散列和渠道隔离；关闭提示记录 build 和时间。同 build 三天内不再显示，恰好三天后恢复，更大 build 立即显示。
- 首页顶部增加普通/强制更新提示，详情使用 `JiabuSheet`。支持中英文更新说明回退、下载进度、取消、失败重试、授权说明及跳系统设置。
- 下载只在用户点击后开始，使用缓存目录 `updates/` 下的 `.part` 文件。206 追加、200 截断、416 或过长 partial 删除重下；完成后流式计算 SHA-256，再改名为 `.apk`。
- 安装前通过平台通道比较 APK 与当前 App 的全部签名证书集合。签名不符删除文件；无未知来源安装授权时保留已校验 APK，返回后可直接继续安装。
- Android 使用 `PackageInstaller` session 写入和 commit，结果由仅限本 App 的动态 `BroadcastReceiver` 接收；安装阶段始终提供“重新安装”，新请求会取消旧 Dart 结果并忽略迟到回调。没有加入 `ACTION_VIEW` 退路。
- 现有 426、`/meta`、只读门控和 outbox 逻辑没有重写。`clientTooOld` 只接入立即更新检查和不可关闭入口；本机内容及 outbox 保留测试继续覆盖。
- `security_force` 的新版显示不可关闭提示，但不会自行把账本切成只读；只读仍只由服务端 426/`/meta` 决定。
- 关于页的现有版本号下增加“检查更新”，绕过 24 小时和三天限制。
- dev flavor 不创建 `UpdateService`、不检查、不显示普通更新入口或关于页“检查更新”。dev 收到 `clientTooOld` 时继续显示原来的只读文字提示，因为 prod APK 的包名和签名都不能升级 dev App。
- 发布流水线保留 dev debug APK，新增强制正式签名的 prod arm64 release、发布元数据、SHA-256、GitHub Release 和 symbols artifact。
- prod 构建先由发布脚本从 tag/pubspec 解析 stable 或 beta，再通过 `JIABU_CHANNEL` dart-define 写进包；非法值运行时回退 stable。

## 分层与接口

界面依赖 `UpdateViewModel`，ViewModel 依赖返回 `Result` 的 `UpdateRepository`，Repository 再调用 `UpdateService`、`UpdateTransport` 和 `UpdateInstaller`。View 不导入 `data/`。

- `UpdateTransport.latest(channel)`：取最新版本。
- `UpdateTransport.download(build, start, cancellation)`：返回状态码、总长度、实际起点和字节流。
- `UpdateInstaller.verifySignature(path)`、`canInstall()`、`openInstallSettings()`、`install(path)`：平台行为的最小接口，测试使用假实现或 mock MethodChannel。

下载逻辑不写断点元数据文件，也不把复杂下载状态持久化；每次从磁盘上 `.part` 的真实长度重新决定请求。

## 假定的服务端约定

S8 尚未合并，本片严格按以下约定实现：

1. `GET /v1/app/releases/latest?channel=stable|beta` 需要会话。
2. 200 返回 `{build, version, channel, bytes, sha256, notes, security_force, min_server_api}`；未知字段忽略。
3. 204 和 404 都表示没有可用版本。
4. `sha256` 是 64 位十六进制字符串；客户端比较时不区分大小写。
5. `GET /v1/app/releases/{build}/apk` 需要会话并支持 `Range: bytes=N-`。
6. 206 的实际起点和完整长度来自 `Content-Range: bytes start-end/total`；起点不符视为无效响应。
7. 200 表示服务端忽略 Range，客户端截断 `.part` 并从头写。
8. 416 表示本机 `.part` 无效，客户端删除后只从 0 重试一次。
9. 200 的 `Content-Length` 和 206 的总长度只作传输信息；最终仍以 latest DTO 的 `bytes` 和 SHA-256 为准。
10. `/app/*` 在 426 强制更新期间仍是白名单。
11. 渠道和 build 沿用 `DeviceContext` / `X-Jiabu-Client` 的来源，不另存第二套版本身份。

## 发布元数据与渠道

随版本提交 `app/release-metadata.json`：

```json
{
  "min_server_api": 1,
  "security_force": false,
  "notes": {
    "zh-Hans": "中文说明",
    "en": "English notes"
  }
}
```

版本和构建号只取 `app/pubspec.yaml`。tag 必须严格等于 `app-v<version>`：

- `app-v1.2.0` 是 stable。
- `app-v1.2.0-beta.N` 是 beta，并发布为 GitHub prerelease。
- 其他 prerelease 格式、tag 不一致、缺任一语言说明都会失败。

仓库没有 `env/prod.json`，服务端地址由 App 设置，因此发布命令不加 `dart-define`。prod 构建额外指定仓库实际入口 `--target lib/main_prod.dart`。

## GitHub secrets

- `JIABU_ANDROID_KEYSTORE_BASE64`：正式 keystore 的 base64。
- `JIABU_ANDROID_KEYSTORE_PASSWORD`：keystore 密码。
- `JIABU_ANDROID_KEY_ALIAS`：签名 key alias。
- `JIABU_ANDROID_KEY_PASSWORD`：签名 key 密码。

四项只通过 workflow `env` 传入。任一缺失，prod 构建直接失败。runner 临时目录恢复 keystore，写 `app/android/key.properties`；`if: always()` 删除二者。日志不启用 `set -x`，不打印 secret。

`build.gradle.kts` 的 `requireReleaseKey` 只在发布 job 开启；开启时不完整的 `key.properties` 直接报错。普通本地 release 仍保留原 debug key fallback，dev debug 流程不变。

流水线拆成：

- `package`：容器中构建 dev debug 和 prod release、生成 APK/SHA/release.json，上传 release assets 与独立 symbols artifact；`contents: read`。
- `publish`：普通 `ubuntu-24.04` runner 下载 release assets，用 runner 自带 `gh release create ... --verify-tag` 发布；只有此 job 是 `contents: write`。symbols 不进入 GitHub Release。

## 文档没写清、我是这么做的

1. 设计规范没有更新专用组件。提示使用 4.14 深色水平提示条的令牌和布局，但作为不会自动消失的 feature 组件；弹层用 4.13 `JiabuSheet`；下载条使用 4.16 `status` 的 6dp 纸面进度槽。
2. “距上次检查”按上一次实际发起请求计，网络失败也更新时间，避免每次回前台反复请求。
3. 普通弹层的“稍后”与提示条关闭完全等价：同 build 抑制三天。
4. 检查错误不显示 UI；关于页手动检查也沿用“安静跳过”的产品规则。
5. 下载取消保留 `.part`；校验值或签名失败删除对应 build 的全部下载文件。
6. 已有完整 `.apk` 也会重新流式校验 SHA-256，再进入签名检查。
7. 系统安装失败和用户取消只重试安装；签名不符后的“重试”重新下载。
8. `release.json` 保持技术方案规定字段，不重复放 SHA-256；SHA 在同名 `.apk.sha256` sidecar。
9. prod 构建命令增加 `--target lib/main_prod.dart`，因为仓库没有默认 `lib/main.dart`。
10. dev 不启用更新功能；否则 prod 包名/证书必然无法覆盖 dev 包。

## 自动化测试

- `test/data/c7_update_service_test.dart`：中断续传、200 忽略 Range、416、过长 partial、流式校验失败删除、24 小时和三天边界、更大 build。
- `test/data/c7_update_repository_test.dart`：签名失败删除且不安装、无授权保留已校验文件且不安装。
- `test/data/c7_update_installer_channel_test.dart`：四个平台方法和安装取消结果映射。
- `test/data/c7_forced_update_test.dart`：只读期间本机内容可见、已有 outbox 不清除、不能新增写入。
- `test/features/c7_update_interaction_test.dart`：普通/强制提示关闭能力、授权说明与操作。
- `test/features/c7_update_layout_test.dart`：6 状态 × 中英 × pine/indigo × 360/430 × 100%/200% = 96 个无溢出组合。
- `test/features/c7_update_golden_test.dart`：14 个批准路径。
- `tool/test_release_app.py`：stable、beta、构建前 channel-only 解析、tag 不一致、缺任一语言说明；只用标准库并由 client-ci 以 `python3 -I` 执行。

本机按任务要求没有运行任何测试、Flutter、Dart、代码生成或打包命令。

## Golden

测试文件逐条列出：

- `goldens/c7/banner_available_zh_pine_w360_text100.png`
- `goldens/c7/banner_available_zh_pine_w430_text200.png`
- `goldens/c7/banner_forced_zh_pine_w360_text100.png`
- `goldens/c7/banner_forced_zh_pine_w430_text200.png`
- `goldens/c7/sheet_available_zh_pine_w360_text100.png`
- `goldens/c7/sheet_available_zh_pine_w430_text200.png`
- `goldens/c7/sheet_downloading_zh_pine_w360_text100.png`
- `goldens/c7/sheet_downloading_zh_pine_w430_text200.png`
- `goldens/c7/sheet_checksum_failed_zh_pine_w360_text100.png`
- `goldens/c7/sheet_checksum_failed_zh_pine_w430_text200.png`
- `goldens/c7/sheet_permission_required_zh_pine_w360_text100.png`
- `goldens/c7/sheet_permission_required_zh_pine_w430_text200.png`
- `goldens/c7/banner_available_en_pine_w360_text100.png`
- `goldens/c7/sheet_available_en_pine_w360_text100.png`

合计 **14 张**。PNG 由 luna.coco 在固定构建机生成、打开审图后提交。

## 待真机验证项（X1 E6）

两台小米分别验证：

- 首次侧载和应用内覆盖升级。
- 拒绝/授予“允许安装未知应用”，从设置返回后不重下。
- 下载中断后真实 HTTP Range 续传。
- 不同证书 APK、证书对但签名块损坏的 APK。
- `PackageInstaller` 的 `STATUS_PENDING_USER_ACTION` 确认 Intent。
- 用户在系统安装界面取消是否稳定返回 `STATUS_FAILURE_ABORTED`。
- 安装成功替换进程时 Dart MethodChannel 是否还能收到成功；不能时按技术方案再评估退路。

当前明确不做 `ACTION_VIEW` 退路。

## S8 合并后补的集成测试

1. 登录会话调用真实 latest，验证 stable/beta、204/404 和 DTO 字段。
2. 真实 APK 首次下载和 206 续传，核对 Range 起点、长度和 SHA-256。
3. 服务端忽略 Range 返回 200 时客户端正确重下。
4. 服务端返回 416 时客户端删除 partial 后恢复。
5. 触发 426 后 `/v1/app/releases/latest` 和 APK 下载仍可用，其他写接口仍只读。
6. GitHub release sidecar、`release.json`、S8 入库后的 bytes/SHA/证书指纹端到端一致。

## 建议的文档修改

- 技术方案 10.5 明确 SHA-256 位于 `.apk.sha256` sidecar，而不是 `release.json`。
- 客户端第 9 节补充 prod 的实际入口 `--target lib/main_prod.dart`，并注明当前没有 `env/prod.json`。
- 设计规范增加“持久更新提示”与强制弹层关闭规则；它不同于 5 秒自动消失的 snackbar。
- 9.6 明确 24 小时按请求尝试还是成功响应计；本实现按请求尝试。
- 9.6 明确 dev flavor 不参与 prod 自更新。

## 最可能需要构建机修正的地方

- Flutter 3.47.8 下 Dio `ResponseBody.stream`、Riverpod 生成签名及 Freezed 生成结果。
- target 37 / minSdk 29 下 `PackageInstaller` 广播 PendingIntent 回调、动态 receiver flags 和 typed parcelable 的 Kotlin API。
- 安装成功替换 App 进程时 MethodChannel result 的生命周期。
- AGP 9.4.1 对 `ORG_GRADLE_PROJECT_requireReleaseKey` 和绝对 `storeFile` 的解析。
- Flutter 实际 prod APK 输出名及 arm64 构建是否仍为 `app-prod-release.apk`。
