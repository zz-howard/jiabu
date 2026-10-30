import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/shared/ledger/ledger_pages.dart';
import 'package:jiabu/shared/ledger/main_frame.dart';
import 'package:jiabu_design/jiabu_design.dart';

import '../support/c3_harness.dart';
import '../support/c4_harness.dart';

AmountText _amountIn(WidgetTester tester, Finder scope) => tester.widget(
  find.descendant(of: scope, matching: find.byType(AmountText)).first,
);

void main() {
  // V2: one shared page-title block, and the space badge where the original
  // design had its 家庭 / 私人 switch.
  for (final (state, title, accent, sub) in [
    ('shell_chat', '家簿', 'My Home Diary', '家人可见'),
    ('shell_overview', '总览', 'Oct. 29 · Thu', '这个月的小账本'),
    ('shell_history', '历史', 'Diary Log', '账目与家庭资料'),
  ]) {
    testWidgets('page_title_block_and_space_badge_$state', (tester) async {
      await pumpC3(tester, state: state);
      expect(
        find.descendant(
          of: find.byType(JiabuPageTitleBlock),
          matching: find.text(title),
        ),
        findsOneWidget,
      );
      expect(find.byType(HandUnderline), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is Text && w.textSpan?.toPlainText() == '$accent $sub',
        ),
        findsOneWidget,
      );
      expect(
        find.byType(JiabuHomeMark),
        state == 'shell_chat' ? findsOneWidget : findsNothing,
      );
      final badge = tester.widget<SpaceBadge>(find.byType(SpaceBadge));
      expect(badge.name, isNotEmpty);
      // The badge sits in the header's right half, the title block on the left.
      expect(
        tester.getRect(find.byType(SpaceBadge)).left,
        greaterThan(tester.getRect(find.byType(JiabuPageTitleBlock)).left),
      );
    });
  }
  testWidgets('english_ui_uses_caveat_subtitle', (tester) async {
    await pumpC3(tester, state: 'shell_history', locale: 'en');
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Text &&
            w.textSpan?.toPlainText() ==
                'Diary Log Accounts and family records',
      ),
      findsOneWidget,
    );
  });
  testWidgets('settings_page_header_carries_the_title_block', (tester) async {
    await pumpC4Preview(tester, state: 'settings');
    expect(find.byType(JiabuPageTitleBlock), findsOneWidget);
    expect(find.byType(HandUnderline), findsWidgets);
    expect(find.textContaining('账号、空间与安全'), findsOneWidget);
  });

  testWidgets('large_text_stacks_the_badge_and_keeps_the_subtitle_readable', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpC3(tester, state: 'shell_chat', scale: 2);
    // Badge below the title block, subtitle not painted but still announced.
    expect(
      tester.getRect(find.byType(SpaceBadge)).top,
      greaterThanOrEqualTo(
        tester.getRect(find.byType(JiabuPageTitleBlock)).bottom,
      ),
    );
    expect(find.textContaining('家人可见'), findsNothing);
    expect(find.bySemanticsLabel('家簿, My Home Diary, 家人可见'), findsOneWidget);
    semantics.dispose();
  });
  testWidgets('second_level_routes_get_no_main_frame_header', (tester) async {
    await pumpC3(
      tester,
      child: MainFrame(
        spaceName: '虚构空间',
        accent: const JiabuColors().spaceAccents['pine']!,
        labels: const ['a', 'b', 'c'],
        selected: 0,
        onSelect: (_) {},
        child: const SizedBox(),
      ),
    );
    expect(find.byKey(const Key('main-frame-header')), findsNothing);
    expect(find.byType(SpaceBadge), findsNothing);
  });

  // The round "me" button made way for the space badge; the profile / settings
  // entry now lives at the top of the badge's space sheet.
  testWidgets('space_sheet_offers_my_settings', (tester) async {
    await pumpC4Preview(tester, state: 'switcher');
    expect(find.text('我的设置'), findsOneWidget);
    expect(find.text('我的空间'), findsOneWidget);
  });

  // V1: amounts.
  testWidgets('record_card_amount_is_minus_signed_highlighted_not_red', (
    tester,
  ) async {
    await pumpC3(tester);
    final amount = _amountIn(
      tester,
      find.byKey(const Key('record-card-amount')),
    );
    expect(amount.minorUnits, lessThan(0));
    expect(amount.highlighted, isTrue);
    expect(amount.tone, AmountTone.plain);
    final text = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('record-card-amount')),
        matching: find.byType(Text),
      ),
    );
    expect(text.textSpan!.toPlainText(), startsWith('−'));
    expect(
      text.style!.color,
      tester.element(find.byType(AmountText)).jiabu.colors.primaryText,
    );
  });
  testWidgets('voided_record_card_amount_is_not_highlighted', (tester) async {
    await pumpC3(tester, state: 'card_voided');
    final amount = _amountIn(
      tester,
      find.byKey(const Key('record-card-amount')),
    );
    expect(amount.highlighted, isFalse);
  });
  testWidgets('history_rows_show_expenses_as_minus_in_ink', (tester) async {
    await pumpC3(tester, state: 'history_grouped');
    final rows = find.byType(LedgerHistoryRow);
    expect(rows, findsWidgets);
    for (final row in rows.evaluate()) {
      final amount = tester.widget<AmountText>(
        find.descendant(
          of: find.byWidget(row.widget),
          matching: find.byType(AmountText),
        ),
      );
      expect(amount.tone, isNot(AmountTone.auto));
      if (amount.minorUnits < 0) {
        final text = tester.widget<Text>(
          find.descendant(
            of: find.byWidget(amount),
            matching: find.byType(Text),
          ),
        );
        expect(
          text.style!.color,
          tester.element(find.byWidget(amount)).jiabu.colors.ink,
        );
      }
    }
  });
  testWidgets('overview_hero_total_is_highlighted', (tester) async {
    await pumpC3(tester, state: 'overview_accounts');
    final amount = _amountIn(tester, find.byKey(const Key('overview-summary')));
    expect(amount.highlighted, isTrue);
  });
}
