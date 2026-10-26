# 家簿文档索引

本目录只记录**当前结论**。已经确定的事写成事实；仍未确定的事集中列在 [决策清单的“待定问题”](decisions/README.md#待定问题open-questions) 中。

## 产品与设计

| 文档 | 说明 |
|---|---|
| [product/requirements.md](product/requirements.md) | 产品需求：核心方向、三块主界面、三条关键流程、账户与记账规则、家庭资料、身份与权限、AI 接入原则、验收路径 |
| [design/design-spec.md](design/design-spec.md) | 设计规范「手账拼贴」：颜色令牌、字体、间距 / 圆角 / 阴影 / 倾斜、组件、动效、无障碍、Flutter 实现要点、验收清单 |

## 工程

| 文档 | 说明 |
|---|---|
| [engineering/client-flutter.md](engineering/client-flutter.md) | Flutter 客户端：技术栈与版本、MVVM 分层、离线与 outbox、UI 系统、测试与质量关卡、代码规范、项目结构、构建发布、风险 |
| [engineering/server-rust.md](engineering/server-rust.md) | Rust 服务端：技术栈与版本、工程结构、认证与授权、API 原则、数据模型草案、日志追踪、测试、CI / 发布 / 部署、风险 |
| [engineering/ai-layer.md](engineering/ai-layer.md) | AI 层：领域接口、AiRouter 路由与降级、默认提供方（ChatGPT 订阅）与备选、结构化输出、追问与任务状态、可观测、测试与评测集 |

## 决策与调研

| 文档 | 说明 |
|---|---|
| [decisions/README.md](decisions/README.md) | 已定决策清单（一行一条，附日期与理由）+ 待定问题 |
| [research/library-evaluation-2026-10.md](research/library-evaluation-2026-10.md) | ORM、Rust LLM 库、ChatGPT 订阅接入、ARM CI、持久工作流的选型调研摘要与来源 |

## 阅读顺序建议

1. 先读产品需求，了解要做什么、不做什么。
2. 做界面的读设计规范 + 客户端规范；做后端的读服务端规范 + AI 层设计。
3. 想知道“为什么这么选”，看决策清单和调研摘要。

## 文档约定

- 中文为主，术语第一次出现时附简短解释。
- 版本号均为 2026-10 核实的版本；升级依赖时同步更新文档。
- 示例数据一律虚构，不放真实账目、真实证件或真实账号。
