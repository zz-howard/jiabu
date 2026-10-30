# V3 原稿还原交付说明（总览）

日期：2026-10-30  
分支：`v3-overview-restore`

依据：`design-gap-audit-2026-10-30` 的总览表与 V3 批次、原稿 `prototype-v1/style-d.html` 的 `overview()` 与 `.hero / .tile / .sec` 样式、Howard 的原稿截图。Howard 已确认：主卡大数字恢复「用途账户合计」，推翻 UI3 的单列决定。

## 改动

- **主卡**（`OverviewSummary`）：−0.6° 倾斜（`decor.heroTilt`，通过 `Tilt`）、主卡级阴影、内边距 24 / 20 / 20；上沿两段胶带：左上斜纹（−5°）、右上圆点（+4°），`top: -10`、距左右 14。标签「用途账户合计 · Total」，大数字 = 所有用途账户余额之和（`purposeAccountsTotal`），Caveat 62 主色 + 荧光笔，任何字号下一行（放不下时 `FittedBox` 等比缩小，不换行不省略）。下面一行「真实资金 ¥…」「本月支出 ¥…」（可换行）。空间没有用途账户时回退为「总余额」= 真实资金合计。
- **用途账户**：排在主卡之后（原稿顺序），区块标题带下半截荧光笔，标题下一句原稿文案「没花完的钱会一直留在各自账户里，按月结转。」；两列格子（`OverviewPurposeGrid` / `OverviewPurposeTile`）：账户名、余额 Caveat 34（负数红色）、启用的每月拨入计划显示「每月拨入 ¥3,000.00」（`monthlyAllocation`，计划关闭或为 0 不显示）；同一行等高；0°；新的格子级轻阴影（`decor.tileShadow`，原稿 `.tile` 的 0 8 14 −10），主卡仍是全页最重的阴影。每格宽度 < 150 × 字号倍数时改单列（360 宽 200% 即单列）。
- **真实资金账户 / 待处理 / 近期变化**：结构不变（分组列表），区块标题同样带荧光笔（原稿所有 `.sec` 都有）。
- **设计包**：`JiabuSectionHeader(highlighted:)`（按每一行文字画 55%–95% 色条，换行也跟随）、`PaperCard(elevation:)`、`PaperElevation.tile`、`JiabuDecor.tileShadow`、`JiabuLedgerMetrics` 的主卡胶带与格子最小宽度。
- **文案**（中英）：`ledgerPurposeTotal`、`ledgerRealMoney`、`ledgerPurposeHint`、`ledgerMonthlyIn`。都不是手写字，衬线子集已覆盖，无需重裁字体。
- **规范**：`docs/design/design-spec.md` 文件头新增 V3 一条（注明推翻 UI3），3.3 新增格子级阴影，重写 4.12a，8 验收清单补总览项。

## 暂不还原（原稿有、本批没做）

- 格子左上的类别贴纸：账户没有类别字段，按名字猜贴纸不可靠，需要先加数据字段。
- 格子底部的月度趋势小柱图、主卡右下手绘小图案、「较上月 +¥…」胶囊、格子的「兜底 / 超支」小标签。

## 测试

- 域：`purposeAccountsTotal`（只算用途账户、负数与归档照算、安全范围）、`monthlyAllocation`（只认启用且 > 0 的计划）。
- 控件 `overview_summary_test.dart`：主卡三个金额与顺序、倾斜 −0.6° 与两段胶带、全页只有一张主卡级阴影、无用途账户回退、两列等高格子与轻阴影、每月拨入只在启用计划显示、负余额格子红色、360/430 × 100%/200% 的列数与不出界。
- 设计包：`section_header_test.dart`（荧光笔、200% 换行不出界）、`tokens_test.dart`（格子级阴影）。
- C3 布局矩阵（zh/en × pine/indigo × 360/430 × 100%/200%）照常覆盖全部总览状态。
- 负对照：`client/tool/v3-negative-controls.json`（6 条）。
- 夹具：总览状态加了每月拨入计划（一个启用 ¥3,000、一个关闭），真实账户 B 余额改为 ¥5,000，让两个合计不同。

## Golden

在 CI 镜像内于构建机重录总览相关的全部 golden（shell_overview、overview_* 各状态），新增 `overview_busy_zh_pine_w360_text200`（单列格子）和 `shell_overview_en_indigo_w430_text200`。
