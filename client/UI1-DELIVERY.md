# UI1 版面规则统一交付说明

日期：2026-10-30  
分支：`ui1-layout-system`

## 文件清单

- 规范与交付：`docs/design/design-spec.md`、`client/UI1-DELIVERY.md`。
- jiabu_design：`lib/jiabu_design.dart`、`lib/src/theme_context.dart`、新增 `tokens/spacing.dart`；新增 `components/{page_header,page_scaffold,list_row,section_header,empty_state,sheet,settings_group}.dart`；兼容入口 `components/paper_sheet.dart`；测试 `test/{layout_components,font_coverage}_test.dart`。
- 页面与外框：`app/lib/app/c4_preview.dart`；`features/auth/view/{login,server_address,welcome}_screen.dart`、`features/auth/widgets/{auth_frame,auth_progress,invite_signup_sheet,switch_partition_prompt}.dart`；`features/lock/view/{lock_settings_screen,unlock_screen}.dart`；`features/settings/view/settings_screen.dart`；`features/settings/api_keys/{api_key_create,api_key_details,api_key_row,api_keys_screen}.dart`；`features/spaces/view/{invitations_body,space_action_form,space_form,spaces_screen}.dart`；`features/home/view/blank_screen.dart`；`features/catalog/{c3_cases,catalog_cases,catalog_screen}.dart`。
- 共享 UI：`app/lib/shared/navigation.dart`；`shared/c4/{c4_field,c4_form}.dart`；`shared/chatweave/{jiabu_chatweave_theme,jiabu_process_strip}.dart`；`shared/ledger/{ledger_forms,ledger_pages,ledger_sheet,main_frame,record_card,record_details}.dart`。
- 文案：`app/lib/l10n/app_{zh,en}.arb`。
- 规则与测试：`client/tool/check_rules.dart`、新增 `client/tool/ui1-negative-controls.json`、同步菜单结构的 `client/tool/c4-negative-controls.json`、`client/test/check_rules_test.dart`；`app/test/catalog_golden_test.dart`、`app/test/features/{auth_screens,c3_golden,c3_layout,c4_layout,c4_interaction,c5_geometry}_test.dart`。

## 规范与审查取舍

- 页面边距按设计规范：宽度 ≤380 为 14，其余为 18；未采用审查稿建议的统一 16。
- 列表行最小高按规范为 66；未采用审查稿中的 56。
- 主操作色固定为 `primary #B4532D`。空间点缀色只用于空间名称、圆点和记录角标。
- 设置分组使用普通纸面，无横格和装订线，最多一层纸面。
- 历史保留手账横格感：rule 色线位于每个实际行底部；红色装订线位于左侧专用留白，和行内容至少相隔 4。
- routed 设置、关于、账户等使用全屏 PageScaffold；创建、编辑、筛选和确认使用真 JiabuSheet。
- P1-1 聊天表格卡和 P1-5 输入框按任务留给第 4 批。
- P1-2 已将账户新建入口移到页头，名称与金额同排，改名/规划/归档/冲突入口收进「⋯」；归档仍沿用原确认弹层。
- P1-4、P1-7、P1-8、P1-9 已由 ListRow、JiabuSheet、EmptyState 与历史行底线/筛选渐隐迁移处理；P1-6 记录卡改为标题金额同排、元数据单行可换行。P1-3 因需新增汇总展示计算未做。
- 记录卡右上角圆点不是同步状态，而是规范 4.1 允许的空间点缀色角标：颜色来自当前空间 `accent_color`；同步成功不另显示状态，待上传、失败等状态继续使用卡片底部的文字标记。
- 二级页标题仅使用 `JiabuPageHeader` 的 Serif 标题，不使用 `HandUnderline` 或手绘波浪线；波浪线仍只用于一级页面标题。
- C4 固定预览曾在真实页面令牌外额外包 18 像素测试边距；该预览边距已删除，真实路由与预览现在都只有一层 `spacing.page`。
- 成员页及空间设置中的连续成员行与相邻操作统一放入单个 `JiabuSettingsGroup`，由组内分隔线区分，不再堆叠独立卡片。
- `JiabuListRow` 仅在账户有创建失败或归档余额异常时增加可换行的行下说明；无说明的普通列表行保持原 `Row` 布局和几何不变。
- 二级页返回先尝试弹出当前路由；空栈时回明确上级。空间设置属于管理分支，因此回 `/settings`；成员和发出邀请回当前空间设置；根设置页被深链直接打开时回稳定顶级入口 `/chat`。
- `JiabuListRow.enabled` 显式表示业务禁用态：禁用时不响应点击，语义为 `enabled: false`，文字、箭头和附件使用 0.38 透明度；不再根据 `onTap == null` 推断，以保留纯信息行的正常外观。

## 实现形态

- `JiabuSpacing` 采用带 `compact` / `regular` 实例的 const enum，不做 ThemeExtension：本批间距是固定设计规则，不存在主题变体；页面边距在 `context.jiabu.spacing.page` 根据 MediaQuery 宽度解析，其余固定档位可在组件内部 const 使用。
- `JiabuPageScaffold` 固定实底页头并裁切其下内容；`JiabuPageHeader`、`JiabuListRow`、`JiabuSectionHeader`、`JiabuEmptyState`、`JiabuSheet`、`JiabuSettingsGroup` 分别承载统一结构和几何。
- 旧 `PaperSheet` 仅保留兼容入口并标记 `@Deprecated('Use JiabuSheet')`；规则 10 禁止 `app/lib` 继续使用。

## 根因修复

- P0-2：过程耗时此前套用了 Caveat `date` 样式，中文“秒”没有 fallback。动态耗时改用 Sans caption；不通过扩大手写子集掩盖错误字体。
- P0-4：MainFrame 顶栏增加实底，内容使用独立 ClipRect，从顶栏下方开始。
- P0-5：auth golden 外壳曾把 `ColorScheme.primary` 覆盖为空间 pine 色；已删除覆盖。真实 App 主题原本就是陶土 primary。

## 间距字面量白名单

以下均为固定绘制/预览几何，不是布局间距：

- `app/lib/features/auth/view/login_screen.dart`：3，连接状态圆点直径。
- `app/lib/features/catalog/catalog_cases.dart`：720，C3 catalog 固定预览高度。
- `app/lib/features/catalog/catalog_cases.dart`：320，PageScaffold catalog 固定预览高度。
- `app/lib/features/catalog/catalog_cases.dart`：180，snackbar catalog 固定预览高度。
- `app/lib/features/catalog/catalog_cases.dart`：520，snackbar 位置预览画布。
- `app/lib/app/c4_preview.dart`：760，C4 固定预览高度。
- `app/lib/features/home/view/blank_screen.dart`：宽 96，B0 视觉基线方块。
- `app/lib/features/home/view/blank_screen.dart`：高 96，B0 视觉基线方块。
- `app/lib/shared/ledger/ledger_pages.dart`：1，历史红色装订线的绘制宽度。

白名单必须与 `// rules:allow-literal <非空原因>` 同行；`jiabu_design` 内部不受页面间距规则限制。

## 构建机生成项

1. 在 `client/app` 运行 gen-l10n。新增键：中英文 `handNothingHere`。
2. 重跑 `tool/fonts/subset.py` 并提交字体与 manifest。新增固定短句为中文“这里还没有内容”和英文“Nothing here yet”；与既有 hand ARB、common/date/punctuation 字符集合相比，唯一新增字形是“还”（U+8FD8）。
3. 重录受影响 golden。不要在实现机生成。

## Golden 清单

新增 20 张：

- `c3/history_24_zh_pine_w360_text100.png`
- `c3/history_24_zh_pine_w430_text200.png`
- `c3/accounts_long_6_zh_pine_w360_text100.png`
- `c3/accounts_long_6_zh_pine_w430_text200.png`
- 8 个 `ui1_*` catalog 状态，各 `light_w360_text100`、`light_w430_text200`：page_scaffold/basic、page_header/action、list_row/basic、list_row/long_name、section_header/basic、empty_state/action、settings_group/basic、sheet/short_content。

重录 358 张：

- C3 既有 113 张。
- C4 既有 135 张。
- Auth/C4b auth 既有 24 张。
- Chat 74 张：带 MainFrame 的 8 状态共 36、process 6 状态 × 4、record_ready 6、record_changed/record_syncing 各 4；streaming/paused 已计入 MainFrame 组，不重复计数。
- Catalog 既有 paper_sheet 3 状态 × 4，共 12 张。

删除 0 张；构建机应生成/更新合计 378 张。新增组件不补四张全矩阵 golden；完整 360/430 × 100%/200% × zh/en 由几何测试覆盖。

独立评审修正后的预计再次重录范围为 148 张：C4 既有 135 张（移除预览外壳额外边距）；C3 账户页 7 张（金额和页头操作对齐）；catalog 的 `ui1_page_header_action`、`ui1_page_scaffold_basic`、`ui1_list_row_long_name` 各 2 张。记录卡长标题加大金额只新增几何测试，不新增 golden；Auth 仅增强几何断言，无视觉改动。

## 尚待构建机确认

- gen-l10n 后的新 getter 名称与调用是否一致。
- 200% 下 PageHeader 右操作与两行标题是否需要进一步收窄。
- PopupMenu 在 Android 实机上的锚点位置和系统返回手势。
- 所有 golden 的实际受影响集合以构建机像素差异报告为准；不得放宽阈值或删除旧覆盖。
