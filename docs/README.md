# 家簿文档索引

本目录只记录**当前结论**。已经确定的事写成事实；仍未确定的事集中列在 [决策清单的“待定问题”](decisions/README.md#待定问题open-questions) 中。

## 产品与设计

| 文档 | 说明 |
|---|---|
| [product/requirements.md](product/requirements.md) | 产品需求：核心方向、三块内容界面 +「我的」、三条关键流程、账户与记账规则、家庭资料、身份与权限（含管理员边界、个人 API key）、AI 接入原则、验收路径 |
| [design/design-spec.md](design/design-spec.md) | 设计规范「手账拼贴」：颜色令牌、字体、间距 / 圆角 / 阴影 / 倾斜、组件、动效、无障碍、Flutter 实现要点、验收清单 |

## 工程

| 文档 | 说明 |
|---|---|
| [engineering/client-flutter.md](engineering/client-flutter.md) | Flutter 客户端：技术栈与版本、MVVM 分层、离线与 outbox、UI 系统、测试与质量关卡、代码规范、项目结构、构建发布、风险 |
| [engineering/server-rust.md](engineering/server-rust.md) | Rust 服务端：技术栈与版本、工程结构、认证与授权（含个人 API key）、API 原则（含工具 API）、数据模型草案、日志追踪、测试、CI / 发布 / 部署、管理 API、风险 |
| [engineering/ai-layer.md](engineering/ai-layer.md) | AI 层：领域接口、AiRouter 路由与降级、默认提供方（ChatGPT 订阅）与备选、结构化输出、追问与任务状态、可观测、测试与评测集、回复的语义块映射与流式、工具定义（同时开放为 API）、持久执行、提示词缓存、用量计量 |
| [engineering/technical-design.md](engineering/technical-design.md) | **技术方案**：系统总览与模块边界、完整建表草案、授权与 RLS、同步协议（outbox、变更序号、冲突、退出与重新加入、按服务端 + 账号分库）、接口清单与工具清单、AI 运行时的实现、资料模板协议（含体检示例）、客户端补充、部署运维、安全控制、可行性验证、与上面三份文档的差异（以它为准） |
| [engineering/implementation-plan.md](engineering/implementation-plan.md) | **实施计划**：切片顺序与依赖（服务端、ChatWeave、客户端三条线）、首版每项能力的最低交付标准、每个切片的范围与验收测试、文档同步、真机实验、评审方式、两台手机终验 |
| [ChatWeave](https://github.com/zz-howard/chatweave)（外部仓库） | 聊天交互开源库：Markdown 优先的生成 UI 协议、流式与续传、组件注册表、动作协议；家簿怎么用它见客户端 4.7、服务端 4.2、AI 层第 13 节、设计规范 4.16 |

## 决策与调研

| 文档 | 说明 |
|---|---|
| [decisions/README.md](decisions/README.md) | 已定决策清单（一行一条，附日期与理由）+ 待定问题 |
| [research/library-evaluation-2026-10.md](research/library-evaluation-2026-10.md) | ORM、Rust LLM 库、ChatGPT 订阅接入、ARM CI、持久工作流的选型调研摘要与来源 |

## 阅读顺序建议

1. 先读产品需求，了解要做什么、不做什么。
2. 做界面的读设计规范 + 客户端规范；做后端的读服务端规范 + AI 层设计。
3. 动手实现前读技术方案：它把上面几份文档落到表、接口和状态机上，并列出与它们的差异。
4. 按实施计划的切片顺序开工，每个切片只做它写明的范围。
5. 想知道“为什么这么选”，看决策清单和调研摘要。

## 文档约定

- 中文为主，术语第一次出现时附简短解释。
- 版本号均为 2026-10 核实的版本；升级依赖时同步更新文档。
- 示例数据一律虚构，不放真实账目、真实证件或真实账号。
