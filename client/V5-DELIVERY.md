# V5 原稿还原交付说明（聊天）

日期：2026-10-30  
分支：`v5-chat-restore`

依据：`design-gap-audit-2026-10-30` 的聊天表与 V5 批次、原稿 `prototype-v1/style-d.html` 的 `.day / .msg / .ai-dot / .opt / .cmp / .nb::before` 样式、Howard 的原稿聊天截图。Howard 已同意聊天页回到原稿。全部在家簿这边完成（主题、注册表覆盖、`userMessageBuilder` / `messageFrameBuilder` 钩子），**没有改 ChatWeave**，依赖版本不变（ab5cabb）。

## 改动

- **日期胶带**：每个本地自然日的第一条消息上方，居中一段斜纹 `DateTapeLabel`（±1.5°）：「今天 · 10月29日 周四」/「昨天 · …」/「10月24日 周六」（英文「Today · Oct 29 Thu」）。ChatWeave 的列表只把单条消息交给构建钩子，所以 `ChatDayBreaks` 按 store 快照（不可变 map）一次算出“哪些消息开启新的一天”，每条消息 O(1) 查。生产页用 `ledgerClockProvider` 判断今天 / 昨天。
- **AI 圆章**：`ChatAvatarSeal`（26 圆、主色、白色手绘星星、2 白描边、贴纸阴影、−10°，读屏隐藏）+ 8 +「家簿助手」Sans 12 粗 ink-2。
- **追问与选项**：问题句改为下半截荧光笔（新 `HighlightedText`，与区块标题共用 `TextMarkerPainter`，按行跟随换行），原来是波浪线；问题和选项**直接写在纸上**，不再包纸面卡（规范 4.16 注明例外）。选项为 `ChatOptionPill`：全圆角、最小高 44、白底、1.5 line-strong 描边 + 贴纸阴影、Sans 14 粗，交替 −1° / +0.8°；服务端确认后选中项 primary-soft + ✓ + 白边，其余 50% 透明并禁用；多选草稿同样显示选中态。「输入其他内容」是最后一个虚线胶囊（铅笔、0°）。
- **我的便利贴**：便利贴里只放我写的文字和照片；状态（Sans 12 粗）与「重试」「改为手动填写」小文字链接（Sans 13 粗、primary-text、下划线，点击区 ≥ 44）放到便利贴下面，最下是 Caveat 手写时间（本机时区 24 小时制）；左侧留 56。
- **输入栏**：去掉整条白底通栏与顶部细线；左 48 圆形拍照钮（`PaperRoundButton`，paper 底、2.5 白边、贴纸阴影），中间纸卡输入框（`PaperComposerField`：paper、圆角 12、line 细边 + 浅阴影、最小高 52、铅笔 18、文字下 rule 横线、框内右端 44 选照片按钮；锁定时 surface-2 + 1.5 虚线），右侧圆形发送 / 停止钮加白边与阴影，有内容可发时转 −8°。#34 的发送 / 停止切换、读屏标签、48×48 点击区不变。
- **底栏撕纸边**：`PaperTornEdgePainter` 取代原来只在栏内凹 4 的裁切：直径 14 的半圆连续排满、高出底栏 7（画在栏外，底栏高度不变），沿边 1 宽 line-strong（70%）描边 + 浅阴影。所有主页面底栏一起变。
- **Markdown**：真机看到的 `**记` 是 CommonMark 的“侧翼”规则：`**` 一侧是中文标点、另一侧是汉字时既不能开也不能闭（`**记账：**后面`、`点**「编辑」**修改`、`这是**“记账”**功能`）。在构建机上用 ChatWeave 用的同一个 `package:markdown` 复现过。`cjkEmphasis` 在交给 `MarkdownBlockView` 前，只在这种情况下于星号与标点之间补一个零宽空格；代码段 / 代码块原样不动，转义的 `\*`、列表符号、分隔线不受影响。流式时的原样露出已由 #35 修好。
- **设计包**：`chat_decor.dart`（`ChatAvatarSeal`、`ChatOptionPill`、`PaperRoundButton`、`PaperComposerField`）、`HighlightedText` / `TextMarkerPainter`、`PaperTornEdgePainter`、`JiabuChatMetrics` 的 V5 尺寸、`JiabuLedgerMetrics.navigationScallop`。
- **规范**：`docs/design/design-spec.md` 文件头 V5 一条，3.4（圆章 −10°、发送钮 −8°）、4.7、4.9、4.10、4.16（`markdown`、`choice` 两行）、4.17b 重写、8 验收清单补聊天项。没有新文案、没有手写字新字符，字体子集不变。

## 暂不还原 / 需要 ChatWeave 的

- 点选后“被点的胶囊里转小圈”：仍是文字提示「提交中… / 已排队」（无限动画也会让 golden 无法稳定）。
- 锁定输入栏框内的向上小箭头：仍是铅笔 + 上方锁定提示行。
- 输入框占位文字仍是「记下文字或照片」（原稿「记一笔，或问点什么…」）。
- 记录卡自身细节（右上空间角标、手写日期等）不在本批。
- ChatWeave 后续（不在本批改）：① `ChatWeaveList` 没有“分组 / 分隔”钩子，日期胶带只能在 `messageFrameBuilder` 里自己算前后消息；建议提供 `separatorBuilder(previous, message)` 或把排序后的相邻消息交给钩子。② 列表每条消息外层固定 `Padding(all: 12)`，原稿消息间距是 6，无法由主题调整；建议做成主题 / 参数。③ `package:markdown` 的 CJK 侧翼问题最好在 ChatWeave 的 `safeMarkdown` 里统一处理，家簿这边的 `cjkEmphasis` 届时可删。

## 测试

- 新 `test/features/v5_chat_restore_test.dart`：分日（乱序、跨会话、跨天）、今天 / 昨天 / 日期文案、整段对话两段胶带（中英）且居中带倾斜；圆章 26、−10°、星星、在署名左侧且同一行；便利贴手写时间在下方、状态和链接不在便利贴里、左留 56；链接字号 ≤ 13、下划线、点击区 ≥ 44、可点；已送达无状态行；选项交替倾斜、≥ 44 高、选中 ✓ + primary-soft、其余 50% 且禁用；问题有荧光笔且不在 PaperCard 里、宽 ≤ 332；打开中的选项无 ✓、「输入其他内容」0° 带铅笔；输入栏圆形拍照、铅笔纸卡、选照片在框内、无通栏底、发送钮空时 0° 有字 −8°；撕纸边高出 7；`cjkEmphasis` 用例与屏幕上无 `**`；整段对话 360 / 430 × 100% / 200% × 中英不出界。
- 调整：`chat_thinking_test`（署名前多了圆章，三点相对圆章缩进）、`c5_geometry_test`（`choice` 不再是纸面卡，移出“结构化组件都是 332 宽纸面卡”的循环，由 V5 测试覆盖）。
- C5 布局矩阵（zh/en × pine/indigo × 360/430 × 100%/200%）新增 `conversation` 状态。
- 负对照：`client/tool/v5-negative-controls.json`（11 条）。

## Golden

在 CI 镜像内于构建机重录：聊天全部状态（`chat/*`）、所有带底栏的页面（`c3/shell_*` 等）、受底栏影响的 catalog / c4 截图。新增 `chat/conversation_*` 6 张（zh 360/430 × 100/200、en 360 100、en indigo 430 200）。

## V5b 输入栏附件（仿 Telegram）

分支：`v5b-attachment-sheet`（V5 已合并为 #40 / ec00d8a）。Howard 要求输入栏学 Telegram。

- **输入栏**：去掉左侧圆形拍照钮；输入框纸卡右端的选图按钮换成回形针「附件」（Howard 评审后重画：新图标 `uiAttach` = Lucide paperclip，经 `tool/icons/icons.json` → `gen_icons.dart` 生成，与相机 / 图片 / 底栏图标同一线条族（线宽 1.85、圆头圆角、24 视口），尺寸 20、ink-3 与铅笔一致，停用时 line-strong；原来借用的手绘回形针 `doodleClip` 太小、竖直、内外圈挤在一起，远看像一团）（tooltip / 读屏「附件 / Attach」，点击区 48），锁定、回答中、忙时停用。发送 / 停止圆钮不变。
- **附件弹层** `ChatAttachmentSheet`（`JiabuSheet`：圆角、胶带把手）：底部「相册 / 文件」分段标签（新 `PaperSegmentedTabs`，原稿 家庭 / 私人 开关的画法）。相册页三列格子（新 `PaperAttachTile`）：第一格「拍照」、第二格「从相册选择」；文件页一格「选择图片文件」+ 说明「目前只支持图片文件，PDF 等文件稍后支持」。弹层只返回来源（`ChatAttachSource.camera / gallery / files`），由页面调用原来的 `photos(...)`。
- **文件来源**：`ImagePickerPort.pick(files: true)` → 家簿自己的 Android 通道 `jiabu/image_files`（`MainActivity`：`ACTION_OPEN_DOCUMENT`、`image/*`、可多选、最多 9 张，后台线程读字节）。不需要存储权限、不加依赖；结果走与相册完全相同的 JPEG 规范化 + 去 EXIF + 入队流程，服务端不变。没有平台实现时（桌面 / 测试）回退到系统照片选择器。
- **没做最近照片网格（评估结论）**：需要 `photo_manager` 这类新依赖（`tool/allowed_deps.yaml` 需人工审批）和 `READ_MEDIA_IMAGES`（Android 14 起还有部分访问 `READ_MEDIA_VISUAL_USER_SELECTED`、iOS 有限访问）；Google Play 的照片 / 视频权限政策只允许以照片为核心功能的应用申请，记账应用应使用系统照片选择器，否则有上架被拒的风险。所以按备选方案做成“拍照 + 从相册选择”两格（无需任何权限，也就没有“拒绝权限”状态）。
- **文案**（中英）：`chatAttach`、`chatAttachGallery`、`chatAttachFiles`、`chatAttachChooseGallery`、`chatAttachChooseFiles`、`chatAttachFilesNote`；都是正文字体，不涉及手写字子集。
- **规范**：文件头 V5b 一条，4.17b 改写（无拍照钮、回形针），新增 4.17c（附件弹层与不做网格的原因），8 验收清单。
- **测试**：`v5_chat_restore_test.dart` 新增“附件弹层”组（相册页三列、拍照在第一格、格子不矮于格宽、底部分段在格子下面且 ≥ 44；文件页只有图片文件格和说明；三个格子分别让弹层返回 拍照 / 相册 / 文件；`jiabu/image_files` 通道以 `limit: 9` 调用且最多取 9 张），输入栏测试改为“无拍照钮、框内回形针”；`media_and_logs_test` 新增“图片文件走同一条 JPEG 流程”。C5 布局矩阵新增 `attach_gallery`、`attach_files`。负对照：`client/tool/v5b-negative-controls.json`（7 条），并更新 V5 两条的测试名。
- **Golden**：重录全部聊天 golden（输入栏变化），新增 `chat/attach_gallery_*` 5 张、`chat/attach_files_*` 3 张。
- **验证**：构建机上 debug APK（dev flavor、arm64）编译通过，包含新的 `MainActivity` 通道；**没有在真机上点过**文件选择器。iOS 端没有工程，不涉及。
