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
      plans: base.plans,
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
  testWidgets('hero_shows_purpose_total_then_real_money_and_month_spending', (
    tester,
  ) async {
    final data = c3Snapshot('overview_accounts');
    await pumpC3(tester, child: OverviewPage(snapshot: data));
    // Purpose: 100.00 - 12.00 (the lunch) + 100.00; real: 100.00 - 12.00 +
    // 5,000.00; one 12.00 expense on 2026-10-28.
    expect(_summaryAmounts(tester), [18800, 508800, 1200]);
    expect(find.text('用途账户合计 · Total'), findsOneWidget);
    expect(find.text('真实资金'), findsOneWidget);
    expect(find.text('本月支出'), findsOneWidget);
    expect(find.text('总余额'), findsNothing);
    final hero = tester.widget<AmountText>(
      find
          .descendant(
            of: find.byKey(const Key('overview-summary')),
            matching: find.byType(AmountText),
          )
          .first,
    );
    expect(hero.role, AmountRole.hero);
    expect(hero.highlighted, isTrue);
    final summary = tester.getRect(find.byKey(const Key('overview-summary')));
    final firstSection = tester.getRect(find.text('用途账户'));
    // The page title is the MainFrame's; the summary is the first block.
    expect(find.text('总览'), findsNothing);
    expect(summary.top, greaterThanOrEqualTo(0));
    expect(summary.bottom, lessThan(firstSection.top));
    // Purpose accounts come before real accounts, like the original.
    expect(firstSection.top, lessThan(tester.getRect(find.text('真实资金账户')).top));
  });

  testWidgets('hero_is_tilted_with_two_tapes_and_the_only_heavy_shadow', (
    tester,
  ) async {
    final data = c3Snapshot('overview_accounts');
    await pumpC3(tester, child: OverviewPage(snapshot: data));
    final summary = find.byKey(const Key('overview-summary'));
    final tilt = tester.widget<Tilt>(
      find.ancestor(of: summary, matching: find.byType(Tilt)).first,
    );
    expect(tilt.degrees, -0.6);
    final tapes = find.descendant(
      of: find.ancestor(of: summary, matching: find.byType(Stack)).first,
      matching: find.byType(Tape),
    );
    expect(tapes, findsNWidgets(2));
    expect(tester.widget<Tape>(tapes.at(0)).pattern, TapePattern.stripe);
    expect(tester.widget<Tape>(tapes.at(1)).pattern, TapePattern.dots);
    final cards = tester.widgetList<PaperCard>(find.byType(PaperCard)).toList();
    expect(
      cards.where((c) => c.elevation == PaperElevation.hero),
      hasLength(1),
    );
    expect(cards.where((c) => c.elevation == PaperElevation.card), isEmpty);
    // Tapes overlap the top edge of the card.
    final card = tester.getRect(summary);
    expect(tester.getRect(tapes.at(0)).top, lessThan(card.top));
  });

  testWidgets('no_purpose_accounts_falls_back_to_the_real_money_total', (
    tester,
  ) async {
    final base = c3Snapshot('overview_accounts');
    final snapshot = LedgerSnapshot(
      spaceId: base.spaceId,
      space: base.space,
      accounts: [
        for (final a in base.accounts)
          if (a.text('kind') == 'real') a,
      ],
      records: base.records,
      tags: base.tags,
      members: base.members,
    );
    await pumpC3(tester, child: OverviewPage(snapshot: snapshot));
    expect(_summaryAmounts(tester), [508800, 1200]);
    expect(find.text('总余额'), findsOneWidget);
    expect(find.text('真实资金'), findsNothing);
    expect(find.byType(OverviewPurposeTile), findsNothing);
    expect(find.byKey(const Key('overview-purpose-hint')), findsNothing);
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
    expect(_summaryAmounts(tester).last, 0);
  });

  testWidgets('purpose_accounts_are_a_two_column_tile_grid', (tester) async {
    final data = c3Snapshot('overview_accounts');
    await pumpC3(tester, child: OverviewPage(snapshot: data));
    final tiles = find.byType(OverviewPurposeTile);
    expect(tiles, findsNWidgets(2));
    final a = tester.getRect(tiles.at(0));
    final b = tester.getRect(tiles.at(1));
    expect(a.top, closeTo(b.top, .01));
    expect(a.height, closeTo(b.height, .01));
    expect(b.left - a.right, closeTo(JiabuSpacing.md, .01));
    for (final card in tester.widgetList<PaperCard>(
      find.descendant(of: tiles, matching: find.byType(PaperCard)),
    )) {
      expect(card.elevation, PaperElevation.tile);
    }
    // Tiles are 0°: no Tilt between a tile and the page.
    expect(
      find.ancestor(of: tiles.first, matching: find.byType(Tilt)),
      findsNothing,
    );
    final balance = tester.widget<AmountText>(
      find.descendant(of: tiles.first, matching: find.byType(AmountText)).first,
    );
    expect(balance.role, AmountRole.balance);
    expect(balance.minorUnits, 8800);
    // Only the enabled plan shows its monthly allocation.
    expect(
      find.descendant(of: tiles.at(0), matching: find.text('每月拨入')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: tiles.at(1), matching: find.text('每月拨入')),
      findsNothing,
    );
    final monthly = tester.widget<AmountText>(
      find.descendant(of: tiles.first, matching: find.byType(AmountText)).last,
    );
    expect(monthly.minorUnits, 300000);
    // Section title with the highlighter, then the rollover sentence.
    expect(find.byKey(const Key('jiabu-section-highlight')), findsWidgets);
    expect(find.text('没花完的钱会一直留在各自账户里，按月结转。'), findsOneWidget);
    // Real accounts stay one grouped list; recent changes the other group.
    expect(find.byType(JiabuSettingsGroup), findsNWidgets(2));
    expect(find.byType(OverviewAccountRow), findsNWidgets(2));
  });

  testWidgets('negative_purpose_tile_balance_is_red', (tester) async {
    final data = c3Snapshot('overview_negative');
    await pumpC3(tester, child: OverviewPage(snapshot: data));
    final tile = find.byKey(const Key('overview-purpose-purpose-a'));
    final balance = find
        .descendant(of: tile, matching: find.byType(AmountText))
        .first;
    expect(tester.widget<AmountText>(balance).minorUnits, lessThan(0));
    final text = tester.widget<Text>(
      find.descendant(of: balance, matching: find.byType(Text)),
    );
    expect(text.style!.color, tester.element(balance).jiabu.colors.neg);
  });

  for (final (width, scale, columns) in [
    (360.0, 1.0, 2),
    (430.0, 1.0, 2),
    (360.0, 2.0, 1),
    (430.0, 2.0, 1),
  ]) {
    testWidgets('purpose_grid_${width}_$scale has $columns column(s)', (
      tester,
    ) async {
      await pumpC3(tester, state: 'overview_busy', width: width, scale: scale);
      expect(tester.takeException(), isNull);
      final tiles = find.byType(OverviewPurposeTile);
      expect(tiles, findsNWidgets(2));
      final a = tester.getRect(tiles.at(0));
      final b = tester.getRect(tiles.at(1));
      expect(a.top == b.top, columns == 2);
      for (final rect in [a, b]) {
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(width));
      }
      for (final amount
          in find
              .descendant(of: tiles, matching: find.byType(AmountText))
              .evaluate()) {
        final rect = tester.getRect(find.byWidget(amount.widget));
        expect(rect.right, lessThanOrEqualTo(width));
      }
      final hero = tester.getRect(
        find.byKey(const Key('overview-hero-amount')),
      );
      expect(hero.right, lessThanOrEqualTo(width));
    });
  }

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
    expect(find.byType(OverviewPurposeTile), findsNothing);
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
