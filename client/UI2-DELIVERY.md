# UI2 纵向节奏与设置细节交付说明

日期：2026-10-30  
分支：`ui2-settings-polish`

## 文件清单

- 规范与交付：`docs/design/design-spec.md`、`client/UI2-DELIVERY.md`。
- jiabu_design：新增 `components/stack.dart`；更新 spacing、PageHeader、SectionHeader、ListRow 与导出；补布局组件测试。
- C4：迁移设置、账号、密码、语言、关于、应用锁、解锁、空间、成员、邀请和 API key 页面及确认弹层。
- C4b：迁移 AuthFrame、登录、服务地址、改密码、会话状态、邀请占位与切换确认。
- C3：迁移设置、总览和账户页的顶层块；历史筛选渐隐使用同色透明纸面。
- 文案：新增应用锁开启/关闭动作键，中英文各两项。
- 规则与测试：SectionHeader 强制 Stack 规则、通用 marker 几何检查、UI2 负对照、页头/API key/锁文案回归测试。

## 实现形态

- `JiabuStackItem` 以 `content`、`section`、`caption`、`action` 显式声明块类型，不检查子组件类型。
- 普通块 12；section 前 30 后 12；action 前 24；caption 与描述块 8。动作自带 caption 时外部 24、内部 8。
- `JiabuSectionHeader` 不再自带 Padding；规则 11 禁止 app/lib 直接使用未被 `JiabuStackItem.section` 包裹的标题。
- `JiabuStackMarker` 让屏幕矩阵测试直接测量相邻块的实际 RenderBox 间隙。

## 细节修正

- 应用锁状态只显示一次；按钮改为“开启应用锁 / 关闭应用锁”动作文案。
- 返回箭头随字号从 24 放大、上限 32；大字号时字形紧配绘制框，实际可见高度至少为标题首行行高的 0.5，并对齐首行中心。字形右缘与标题间距至少为 8；100% 字号保持 UI1 的 66 高垂直居中几何，点击区始终不小于 48。
- 邀请操作位于说明下方的 Wrap，水平和换行间距均为 8。
- API key 权限允许完整换行，覆盖英文 360 宽 200% 字号。
- 历史筛选渐隐由透明 bg 过渡到 bg，避免透明黑插值发灰。
- 非聊天的 chip 组选用 `JiabuChipGroup` 提供 8/8 间距；选中态统一为 primary-soft、on-primary-soft、✓ 和白圈。聊天追问胶囊保持 4.10 的独立视觉与实现。
- `JiabuStack` caption 明确区分描述前一块/后一块；同层直接嵌套 Stack 在 debug 下断言失败。几何矩阵校验 marker 完整数及各状态最低检查对数。
- 规则 12 禁止把 `JiabuStack` / `JiabuChipGroup` 直接放进 `ListView.builder`、`SliverList` 等惰性 delegate，避免未构建项绕过 marker 完整性检查。
- C4b golden 与几何检查共享同一份 14 状态表；几何侧对每个状态执行 zh/en × 360/430 × 100%/200% 完整矩阵。
- C4b 输入框在打开 modal 前逐项验证 EditableText 读屏标签；modal 背景会按 Flutter 路由语义规则被排除。
- 本批不实现 RTL：客户端当前仅支持中文和英文，均使用 LTR 布局。

### C4b 首启三屏复核

- 欢迎：`JiabuStack` 显式居中 Logo、双语标语和仓鼠便签组；360/100% 与 430/200% 下 Logo 中心相对屏幕中心偏差不超过 1，胶带保持在画面内。顶部留白不小于原 24、Logo 到标语不小于原 8、仓鼠便签到主按钮保持 32。
- 服务器（折叠/展开）：恢复进度到标题 30、说明到表单 30、表单到页脚 24；横向对齐不变。
- 登录：恢复进度到标题 30、说明到卡片 30；“还没有账号”作为新区块使用上间距 30，页脚使用 actionGap 24。卡片、注册区及页脚横向对齐不变。

## Golden 清单

- 新增预计 2 张：`ui2_stack_vertical_rhythm` 的 360/100% 与 430/200%。
- 受影响既有 golden 由构建机根据像素差异重录，预计约 258 张，保守上限 282 张。
- 删除 0 张；本机未生成或修改 PNG。

## 构建机生成与验证

1. 在 `client/app` 运行 gen-l10n，生成四个新 getter。
2. 运行 dart format、flutter analyze 与 `dart run tool/check_rules.dart`。
3. 分别运行 workspace、app、jiabu_design 测试；UI1 和 UI2 负对照逐条确认。
4. 重录并人工检查受影响 golden，PR 标记 `visual-change`。

## 尚待构建机确认

- 锁定 Flutter 版本的 TextScaler API 与 marker Finder 行为。
- 760 高 C4 固定预览在新增 actionGap 后是否需要滚动定位调整。
- 360/200% 下邀请 Wrap、API key 行和两行页头的实际像素表现。
- 实际 golden 重录集合以构建机差异报告为准。
