# UI3 总览页交付说明

日期：2026-10-30  
分支：`ui3-overview`

## 范围

审查项 P1-3「总览：没有总数，每个账户一张带阴影的卡，近期变化放完整大记录卡」。只改总览页，不改业务逻辑、数据流、路由和服务端。

## 改动

- 汇总卡（`OverviewSummary`）：总余额（所有真实资金账户余额之和，含仍有余额的已归档账户，用途账户不重复相加）+ 本月支出（本月发生的支出 − 退款，不含已撤销，规则与历史页当天合计一致）。月份取 `ledgerClockProvider` 的年月。无账户或合计超出安全整数范围时不显示。
- 账户：「真实资金账户」「用途账户」各一个 `JiabuSettingsGroup`，一行一个账户（`OverviewAccountRow`，名称左、余额右，长名最多两行）。没有可显示账户的分区整块省略。负余额便利贴与归档说明改为 `AccountBalanceNote`，作为独立块放在对应分组下方（取代原 `AccountBalanceTile`）。
- 近期变化：最近 5 条，一张分组列表，一行一条（`OverviewRecentRow`：贴纸、标题、记录人 · 日期、状态、金额，API key 记录行尾有钥匙）；没有记录时整段省略。聊天和详情里的完整记录卡不变。
- 域函数：`realAccountsTotal`、`monthExpense`（`domain/ledger_balance.dart`）。新文案 `ledgerTotalBalance`、`ledgerMonthSpent`（中英）。
- 规范：`docs/design/design-spec.md` 增加 4.12a 总览页与文件头一条。

## 测试

- 域测试：总余额只含真实账户并保留归档余额、安全范围、本月支出（月份边界、退款、撤销、他空间）。
- 控件测试 `overview_summary_test.dart`：汇总数值与位置、跨月支出不计、账户为分组行而非逐个卡片、近期为 5 行紧凑行且金额在右、无账户只有空状态、长名 100%/200% 金额不出界。
- C3 几何矩阵（zh/en × pine/indigo × 360/430 × 100%/200%）覆盖全部总览状态，并把各总览状态的最低相邻块对数提高到新结构的真实值；新增状态 `overview_busy`。
- 负对照：`client/tool/ui3-negative-controls.json`。

## Golden

重录 17 张（总览相关：shell_overview、overview_* 各状态），新增 3 张（overview_busy 360/100%、430/200%，overview_busy_scrolled 360/100% 滚到近期变化），删除 0。在 CI 镜像内于构建机录制。
