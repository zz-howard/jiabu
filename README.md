# 家簿 Jiabu

> **Jiabu** (家簿, "family ledger") is a chat-first family bookkeeping app. You talk to an AI assistant in plain language or send it a photo; it records expenses against both real accounts (where the money actually is) and logical "purpose" accounts (envelope-style budgets that roll over month to month), and keeps family documents such as medical check-up records searchable. Everything lives in isolated "spaces": each user gets a default personal space, and a family is simply a space with invited members; a space you are not a member of does not exist for you. The client is Flutter (Android first), the server is Rust (Axum + PostgreSQL), and the AI layer is provider-agnostic. **Status: specification stage — no code yet.**

家簿是一个**以聊天为首页**的家庭记账与家庭资料记录 App：用一句话或一张照片告诉 AI 助手发生了什么，它把账记到“真实资金账户”和“逻辑用途账户”上，也帮你留存、查询家庭资料（例如视力检查单）。所有内容按“空间”严格隔离：每人自动有一个默认个人空间，家庭只是邀请了成员的普通空间。

## 当前状态

**规格阶段，还没有代码。** 本仓库目前只有产品需求、设计规范和工程规范。客户端与服务端都将从零开始实现；API 契约会在服务端开工时重新编写。

## 核心特点

- **聊天即入口**：文字、拍照、选图都在同一个对话页里完成；对话是一对一的，只有你和 AI，共同空间里的其他成员看不到你的对话；信息明确就直接记账并回复记录卡，缺项或识别不确定时才追问；每条记录都可编辑、可撤销。AI 的回复是文字与组件（记录卡、指标、表格、选项）混排，文字边生成边显示；回复顶部的“过程”条显示 AI 正在查什么、做完了哪些，回答写完后自动收起。
- **两类账户**：真实资金账户（钱实际在哪里）+ 逻辑用途账户（心理账户，按月拨入、持续结转，不做预算管理）。一笔支出同时关联两者，只计一次消费。
- **按空间隔离**：每个空间是独立账本（账户、记录、资料、聊天各自独立），可建多个；每人自动有一个仅自己可见的默认个人空间，邀请成员即成为共享空间；不是成员的空间完全不可见，服务端强制校验。可选应用锁（生物识别 / 手势，PIN 兜底）。
- **离线可用**：没网时先存在手机里显示“待上传”，联网后自动补传，绝不静默丢失。
- **AI 可插拔**：服务端自有领域接口，默认通过官方 “Sign in with ChatGPT” 使用 ChatGPT 订阅，其他模型服务商作为备选。

## 技术栈一览

| 部分 | 选择 |
|---|---|
| 客户端 | Flutter 3.47.8 / Dart 3.13.7（先做 Android，为 iOS 预留）；Riverpod 3、drift、dio、freezed、go_router；手账风格设计系统独立成 `jiabu_design` 包 |
| 服务端 | Rust 1.99.1（edition 2024）；Axum 0.8 + Tokio；PostgreSQL 18；SeaORM 2.0（特殊查询用 sea-query / 原生 SQL） |
| AI 层 | 自有领域 trait（`ModelProvider`）+ `AiRouter`；默认提供方 = ChatGPT 订阅（官方 Sign in with ChatGPT，基于 async-openai 的适配器）；其他提供方经 genai 0.7 接入，作为降级备选 |
| 聊天交互 | [ChatWeave](https://github.com/zz-howard/chatweave)（独立开源库，设计阶段）：Markdown 优先的生成 UI 协议 + Rust 服务端 crate + Flutter 包；回复文字逐步显示、组件整块出现；家簿实现手账主题、本机存储适配器、记录卡等自定义组件与服务端动作处理器 |
| 发布 | GitHub Actions 打 tag 构建：GitHub Releases 上的 aarch64 / x86_64 二进制 + GHCR 多架构镜像；用 docker compose 或 systemd 部署，部署机不编译 |
| 开发 | 日常开发与测试在一台 x86 Linux 构建机上进行；代码主要由 AI 编程代理（Codex）编写、人工评审、机器关卡校验 |

## 仓库结构

```
README.md            本文件
LICENSE              MIT
client/              Flutter pub workspace（app/ + packages/jiabu_design），尚未创建
server/              Rust Cargo workspace，尚未创建
docs/
  README.md          文档索引
  product/           产品需求
  design/            视觉与交互设计规范
  engineering/       客户端、服务端、AI 层工程规范
  decisions/         已定决策清单（ADR 风格）与待定问题
  research/          选型调研摘要与来源
```

## 文档索引

| 文档 | 内容 |
|---|---|
| [docs/product/requirements.md](docs/product/requirements.md) | 产品需求：空间模型、三块主界面、三条关键流程、记账规则、家庭资料、身份与权限 |
| [docs/design/design-spec.md](docs/design/design-spec.md) | 设计规范「手账拼贴」：颜色、字体、间距、倾斜、组件、动效、无障碍、Flutter 实现要点 |
| [docs/engineering/client-flutter.md](docs/engineering/client-flutter.md) | Flutter 客户端技术与开发规范 |
| [docs/engineering/server-rust.md](docs/engineering/server-rust.md) | Rust 服务端技术规范、数据与同步原则、日志、测试、发布与部署 |
| [docs/engineering/ai-layer.md](docs/engineering/ai-layer.md) | AI 层设计：领域接口、路由与降级、提供方、结构化输出、测试 |
| [docs/decisions/README.md](docs/decisions/README.md) | 已定决策清单与待定问题 |
| [docs/research/library-evaluation-2026-10.md](docs/research/library-evaluation-2026-10.md) | ORM / LLM 库 / 持久工作流选型调研摘要 |

## 许可证

[MIT](LICENSE)
