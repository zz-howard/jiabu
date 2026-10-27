# client/ — Flutter 客户端

这里将放家簿的 Flutter 客户端，采用 **pub workspace**（Dart 3.6+ 内置的单仓多包机制：一份依赖解析、一个 lock 文件）：

```
client/
  pubspec.yaml               # workspace 根：workspace: [app, packages/jiabu_design]
  .fvmrc                     # 锁定 Flutter 3.47.8
  AGENTS.md                  # 给 AI 编程代理的项目规则
  analysis_options.yaml
  tool/                      # 自定义检查、依赖白名单、图标生成、字体子集、像素比对报告
  app/                       # App 本体（功能优先目录，MVVM + Repository）
  packages/jiabu_design/     # 手账风格设计系统：主题令牌、字体、图标、装饰组件
```

开工前请先读：

- [Flutter 客户端技术与开发规范](../docs/engineering/client-flutter.md)
- [设计规范「手账拼贴」](../docs/design/design-spec.md)
- [产品需求](../docs/product/requirements.md)

## 构建与 C1 生成

jiabu-build 是共享构建机：所有重任务（Flutter test / analyze /
build、Gradle、字体子集）统一加 `nice -n 19 ionice -c3`，同一时间只跑一个。
工具与工作文件合计不得超过 40GB。Gradle 配置 `org.gradle.workers.max=2`、
`org.gradle.jvmargs=-Xmx4g`（4GB 只限制 JVM 堆，不代表整个构建或容器上限）。
尚无 Android 工程，创建时将两项写入 `android/gradle.properties`。
完成后运行 `nice -n 19 ionice -c3 gradle --stop`（或 `./gradlew --stop`），
并停止、删除使用的容器。

C1 字体由构建机生成，缓存文件直接命名为 SHA-256（六个源文件 / 许可）：

```sh
nice -n 19 ionice -c3 python3 tool/fonts/subset.py --cache-dir /path/to/cache --offline
flutter pub get
flutter gen-l10n
dart run tool/icons/gen_icons.dart --check
dart format .
nice -n 19 ionice -c3 flutter analyze --fatal-infos
dart run tool/check_rules.dart
nice -n 19 ionice -c3 flutter test
```

在 `app/`、`packages/jiabu_design/` 各自再单独跑带上述前缀的 `flutter test`。
字体工具依赖见 `tool/fonts/requirements.txt`，详细示例见 `subset.py` docstring；
工具测试为 `python3 -m unittest discover -s tool/fonts -p 'test_*.py'`。
`JIABU_FONT_MIRROR` 直接拼在原始完整 URL 前，仍校验原 SHA-256。
生成的三个字体及 manifest 应一同提交；`pubspec.lock` 由 pub 解析后更新。

组件目录仅 `app/lib/main_dev.dart` 可达。golden 以 CI 的固定镜像为准；
不要在构建机 rootless Docker 中拉取 ghcr 镜像生成 golden。基准 PNG 在构建机
用同版本 Flutter 与同一字体夹具生成、人工审查后提交，是否一致以 CI 为准；
失败时 CI 上传 `client/**/failures/` 差异图。
