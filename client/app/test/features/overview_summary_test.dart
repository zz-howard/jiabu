import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/domain/ledger.dart';
import 'package:jiabu/features/catalog/c3_cases.dart';
import 'package:jiabu/shared/ledger/ledger_pages.dart';
import 'package:jiabu/shared/ledger/overview_widgets.dart';
import 'package:jiabu_design/jiabu_design.dart';

import '../support/c3_harness.dart';

LedgerSnapshot _withRecords(LedgerSnapshot base, List<LedgerRow> records) =>
    LedgerSnapshot(
      spaceId: base.spaceId,
      space: base.space,
      accounts: base.accounts,
      records: records,
      tags: base.tags,
      members: base.members,
    );

List<int> _summaryAmounts(WidgetTester tester) => [
  for (final amount in tester.widgetList<AmountText>(
    find.descendant(
      of: find.byKey(const Key('overview-summary')),
      matching: find.byType(AmountText),
    ),
  ))
    amount.minorUnits,
];

void main() {
  testWidgets('summary_shows_real_total_and_this_month_expense_first', (
    tester,
  ) async {
    final data = c3Snapshot('overview_accounts');
    await pumpC3(tester, child: OverviewPage(snapshot: data));
    // 2 real accounts of 100.00, one 12.00 expense on 2026-10-28.
    expect(_summaryAmounts(tester), [18800, 1200]);
    expect(find.text('总余额'), findsOneWidget);
    expect(find.text('本月支出'), findsOneWidget);
    final summary = tester.getRect(find.byKey(const Key('overview-summary')));
    final firstSection = tester.getRect(find.text('真实资金账户'));
    // The page title is the MainFrame's; the summary is the first block.
    expect(find.text('总览'), findsNothing);
    expect(summary.top, greaterThanOrEqualTo(0));
    expect(summary.bottom, lessThan(firstSection.top));
  });

  testWidgets('expense_in_another_month_is_not_this_month_spending', (
    tester,
  ) async {
    final base = c3Snapshot('overview_accounts');
    final old = LedgerRow({
      ...base.records.first.data,
      'occurred_on': '2026-09-30',
    });
    await pumpC3(
      tester,
      child: OverviewPage(snapshot: _withRecords(base, [old])),
    );
    expect(_summaryAmounts(tester), [18800, 0]);
  });

  testWidgets('accounts_are_rows_of_one_group_per_kind_not_one_card_each', (
    tester,
  ) async {
    final data = c3Snapshot('overview_accounts');
    await pumpC3(tester, child: OverviewPage(snapshot: data));
    // real group, purpose group, recent group
    expect(find.byType(JiabuSettingsGroup), findsNWidgets(3));
    expect(find.byType(OverviewAccountRow), findsNWidgets(4));
    // Only the summary is a shadowed paper card on this state.
    expect(find.byType(PaperCard), findsOneWidget);
    final first = tester.getRect(find.byType(OverviewAccountRow).at(0));
    final second = tester.getRect(find.byType(OverviewAccountRow).at(1));
    expect(second.top, closeTo(first.bottom + 1, 1.01));
    for (var index = 0; index < 4; index++) {
      final row = tester.getRect(find.byType(OverviewAccountRow).at(index));
      final amount = tester.getRect(
        find.descendant(
          of: find.byType(OverviewAccountRow).at(index),
          matching: find.byType(AmountText),
        ),
      );
      expect(amount.right, lessThanOrEqualTo(row.right));
      expect(amount.center.dy, closeTo(row.center.dy, 1));
    }
  });

  testWidgets('recent_changes_are_compact_rows_with_amount_on_the_right', (
    tester,
  ) async {
    final base = c3Snapshot('overview_accounts');
    final records = [
      for (var index = 0; index < 7; index++)
        LedgerRow({
          ...base.records.first.data,
          'id': 'record-$index',
          'note': '虚构记录 $index',
          'amount_minor': 100 * (index + 1),
          'occurred_on': '2026-10-${10 + index}',
        }),
    ];
    await pumpC3(
      tester,
      child: OverviewPage(snapshot: _withRecords(base, records)),
    );
    final rows = find.byType(OverviewRecentRow);
    expect(rows, findsNWidgets(5));
    final one = tester.getRect(rows.first);
    expect(one.height, lessThan(100));
    final title = tester.getRect(find.text('虚构记录 6'));
    final amount = tester.getRect(
      find.descendant(of: rows.first, matching: find.byType(AmountText)),
    );
    expect(amount.left, greaterThan(title.right));
    expect(amount.center.dy, closeTo(one.center.dy, 1));
    expect(find.textContaining('用户A'), findsNWidgets(5));
  });

  testWidgets('no_accounts_shows_only_the_empty_state_and_no_totals', (
    tester,
  ) async {
    final data = c3Snapshot('overview_empty');
    await pumpC3(tester, child: OverviewPage(snapshot: data));
    expect(find.byKey(const Key('overview-summary')), findsNothing);
    expect(find.byType(OverviewAccountRow), findsNothing);
    expect(find.byType(OverviewRecentRow), findsNothing);
    expect(find.byType(JiabuEmptyState), findsOneWidget);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('long_names_keep_amounts_visible_scale_$scale', (tester) async {
      final data = c3Snapshot('accounts_long_6');
      await pumpC3(
        tester,
        scale: scale,
        child: OverviewPage(snapshot: data),
      );
      expect(tester.takeException(), isNull);
      final width = tester.view.physicalSize.width;
      for (final amount in find.byType(AmountText).evaluate()) {
        final rect = tester.getRect(find.byWidget(amount.widget));
        expect(rect.right, lessThanOrEqualTo(width));
        expect(rect.left, greaterThanOrEqualTo(0));
      }
    });
  }
}
