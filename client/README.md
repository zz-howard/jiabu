# client/ — Flutter 客户端（尚未创建）

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

当前还没有代码。开工前请先读：

- [Flutter 客户端技术与开发规范](../docs/engineering/client-flutter.md)
- [设计规范「手账拼贴」](../docs/design/design-spec.md)
- [产品需求](../docs/product/requirements.md)
