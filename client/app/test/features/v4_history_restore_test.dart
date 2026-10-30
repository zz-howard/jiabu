import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/shared/ledger/ledger_pages.dart';
import 'package:jiabu_design/jiabu_design.dart';

import '../support/c3_harness.dart';

// V4 (design-spec 4.12): the history page back to the original design.

Finder _chipRow() => find.descendant(
  of: find.byKey(const Key('history-chip-row')),
  matching: find.byWidgetPredicate(
    (widget) =>
        widget is Scrollable && widget.axisDirection == AxisDirection.right,
  ),
);

Finder _chips() => find.byType(PaperFilterChip);

Future<void> _scrollChips(WidgetTester tester, {required bool toEnd}) async {
  final position = tester.state<ScrollableState>(_chipRow()).position;
  position.jumpTo(toEnd ? position.maxScrollExtent : 0);
  await tester.pumpAndSettle();
}

Finder _rowOf(String title) => find.ancestor(
  of: find.text(title),
  matching: find.byType(LedgerHistoryRow),
);

String _amountText(WidgetTester tester, Finder row) {
  final amount = find.descendant(of: row, matching: find.byType(AmountText));
  final text = tester.widget<Text>(
    find.descendant(of: amount, matching: find.byType(Text)).first,
  );
  return text.textSpan?.toPlainText() ?? text.data ?? '';
}

void main() {
  group('chip row', () {
    for (final locale in ['zh', 'en']) {
      for (final width in [360.0, 430.0]) {
        for (final scale in [1.0, 2.0]) {
          final label = locale == 'zh' ? '时间' : 'Dates';
          testWidgets('last_chip_fully_visible_at_scroll_end '
              '$locale $width $scale', (tester) async {
            await pumpC3(
              tester,
              state: 'shell_history',
              locale: locale,
              width: width,
              scale: scale,
            );
            final gutter = width <= 380 ? 14.0 : 18.0;
            await _scrollChips(tester, toEnd: true);
            final last = tester.getRect(_chips().last);
            expect(
              find.descendant(of: _chips().last, matching: find.text(label)),
              findsOneWidget,
            );
            // Fully on screen, one page gutter before the right edge.
            expect(last.left, greaterThanOrEqualTo(0));
            expect(last.right, lessThanOrEqualTo(width - gutter + .5));
            expect(last.right, greaterThan(width - gutter - 1));
            // Nothing fades over it: the end fade is gone at the end; a
            // start fade (more chips hidden on the left) never reaches it.
            expect(find.byKey(const Key('chip-fade-end')), findsNothing);
            final start = find.byKey(const Key('chip-fade-start'));
            final scrolled =
                tester.state<ScrollableState>(_chipRow()).position.pixels > .5;
            expect(start, scrolled ? findsOneWidget : findsNothing);
            if (scrolled) {
              expect(
                tester.getRect(start).overlaps(last),
                isFalse,
                reason: 'the start fade covers the last chip',
              );
            }
            // The chip itself is the hit target at its own centre.
            final result = HitTestResult();
            WidgetsBinding.instance.hitTestInView(
              result,
              last.center,
              tester.view.viewId,
            );
            final body = tester.renderObject(
              find.descendant(
                of: _chips().last,
                matching: find.byKey(const Key('paper-filter-chip-body')),
              ),
            );
            expect(
              result.path.any((entry) => entry.target == body),
              isTrue,
              reason: 'the last chip is not hit at its centre',
            );
          });
        }
      }
    }

    testWidgets('fades_only_where_more_chips_are_hidden', (tester) async {
      await pumpC3(tester, state: 'shell_history', scale: 2);
      final position = tester.state<ScrollableState>(_chipRow()).position;
      expect(position.maxScrollExtent, greaterThan(0));
      // At the start: the first chip sits on the page gutter, no left fade,
      // a right fade because chips are hidden on the right.
      expect(tester.getRect(_chips().first).left, closeTo(14, .5));
      expect(find.byKey(const Key('chip-fade-start')), findsNothing);
      expect(find.byKey(const Key('chip-fade-end')), findsOneWidget);
      position.jumpTo(position.maxScrollExtent / 2);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chip-fade-start')), findsOneWidget);
      expect(find.byKey(const Key('chip-fade-end')), findsOneWidget);
      await _scrollChips(tester, toEnd: true);
      expect(find.byKey(const Key('chip-fade-start')), findsOneWidget);
      expect(find.byKey(const Key('chip-fade-end')), findsNothing);
    });

    testWidgets('chips_have_dropdown_arrows_selected_is_solid', (tester) async {
      await pumpC3(tester, state: 'history_filters');
      final colors = tester.element(_chips().first).jiabu.colors;
      expect(_chips(), findsNWidgets(5));
      for (final chip in _chips().evaluate()) {
        final widget = chip.widget as PaperFilterChip;
        final of = find.byWidget(widget);
        expect(
          find.descendant(
            of: of,
            matching: find.byKey(const Key('paper-filter-chip-arrow')),
          ),
          findsOneWidget,
        );
        final body = find.descendant(
          of: of,
          matching: find.byKey(const Key('paper-filter-chip-body')),
        );
        expect(tester.getSize(body).height, greaterThanOrEqualTo(44));
        final decoration = tester.widget<Container>(body).decoration;
        final check = find.descendant(
          of: of,
          matching: find.byKey(const Key('paper-filter-chip-check')),
        );
        if (widget.selected) {
          expect(decoration, isA<BoxDecoration>());
          final box = decoration! as BoxDecoration;
          expect(box.color, colors.primarySoft);
          expect(box.boxShadow, isNotEmpty);
          expect(check, findsOneWidget);
        } else {
          expect(decoration, isA<ShapeDecoration>());
          expect(
            (decoration! as ShapeDecoration).shape,
            isA<PaperDashedBorder>(),
          );
          expect(check, findsNothing);
        }
      }
      expect(
        _chips().evaluate().where(
          (chip) => (chip.widget as PaperFilterChip).selected,
        ),
        hasLength(2),
      );
    });
  });

  testWidgets('search_is_a_rounded_card_with_a_magnifier', (tester) async {
    await pumpC3(tester, state: 'history_grouped');
    final card = find.byKey(const Key('paper-search-card'));
    expect(card, findsOneWidget);
    final decoration =
        tester.widget<Container>(card).decoration! as BoxDecoration;
    expect(decoration.borderRadius, BorderRadius.circular(12));
    expect(decoration.boxShadow, isNotEmpty);
    expect(tester.getSize(card).height, greaterThanOrEqualTo(52));
    final icon = find.descendant(
      of: card,
      matching: find.byKey(const Key('paper-search-icon')),
    );
    expect(icon, findsOneWidget);
    final field = tester.getRect(
      find.descendant(of: card, matching: find.byType(TextField)),
    );
    expect(tester.getRect(icon).right, lessThan(field.left));
    expect(find.text('搜索备注、类型、账户或标签'), findsOneWidget);
  });

  group('timeline', () {
    testWidgets('stickers_sit_on_the_red_line_inside_a_paper_card', (
      tester,
    ) async {
      await pumpC3(tester, state: 'history_diary');
      final cards = find.byKey(const Key('history-day-card'));
      expect(cards, findsNWidgets(2));
      final card = cards.first;
      final shadow = tester
          .widgetList<DecoratedBox>(
            find.descendant(of: card, matching: find.byType(DecoratedBox)),
          )
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .where((box) => box.boxShadow != null);
      expect(
        shadow.first.boxShadow,
        tester.element(card).jiabu.decor.cardShadow,
      );
      final line = tester.getRect(
        find.descendant(
          of: card,
          matching: find.byKey(const Key('history-margin-line')),
        ),
      );
      final cardRect = tester.getRect(card);
      expect(line.top, closeTo(cardRect.top, .5));
      expect(line.bottom, closeTo(cardRect.bottom, .5));
      final stickers = find.descendant(
        of: card,
        matching: find.byKey(const Key('history-row-sticker')),
      );
      expect(stickers, findsNWidgets(3));
      for (final sticker in stickers.evaluate()) {
        final rect = tester.getRect(find.byWidget(sticker.widget));
        // A full 40 sticker centred on the line, not a narrow gutter.
        expect(rect.width, greaterThanOrEqualTo(40));
        expect(rect.center.dx, closeTo(line.center.dx, 1));
        expect(rect.left, greaterThan(cardRect.left));
      }
    });

    testWidgets('rows_show_account_category_time_and_signed_amount', (
      tester,
    ) async {
      await pumpC3(tester, state: 'history_diary');
      final lunch = _rowOf('虚构午饭');
      expect(
        find.descendant(of: lunch, matching: find.text('虚构银行卡A · 虚构日常')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: lunch, matching: find.text('15:14')),
        findsOneWidget,
      );
      expect(find.text('用户A'), findsNothing);
      expect(_amountText(tester, lunch), startsWith('−'));
      final amount = tester.widget<AmountText>(
        find.descendant(of: lunch, matching: find.byType(AmountText)),
      );
      expect(amount.role, AmountRole.list);
      final style = tester.element(lunch).jiabu.type.listAmount;
      expect(style.fontFamily, JiabuType.numeralsFamily);
      expect(style.fontWeight, FontWeight.w600);
      // The time sits under the amount, both right-aligned.
      final amountRect = tester.getRect(
        find.descendant(of: lunch, matching: find.byType(AmountText)),
      );
      final time = tester.getRect(
        find.descendant(
          of: lunch,
          matching: find.byKey(const Key('history-row-time')),
        ),
      );
      expect(time.top, greaterThanOrEqualTo(amountRect.bottom));
      expect(time.right, closeTo(amountRect.right, 1));
      // Money in is +, a transfer names its kind on the second line.
      expect(_amountText(tester, _rowOf('虚构工资')), startsWith('+'));
      expect(
        find.descendant(
          of: _rowOf('虚构银行卡A → 虚构银行卡B'),
          matching: find.text('转账'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('expense_sticker_follows_its_tag', (tester) async {
      await pumpC3(tester, state: 'history_diary');
      Sticker sticker(String title) => tester.widget<Sticker>(
        find.descendant(of: _rowOf(title), matching: find.byType(Sticker)),
      );
      expect(sticker('虚构午饭').category, 'food');
      expect(sticker('虚构打车').category, 'travel');
      expect(sticker('虚构工资').category, 'income');
    });

    testWidgets('a_day_lists_its_latest_entry_first', (tester) async {
      await pumpC3(tester, state: 'history_diary');
      final lunch = tester.getRect(_rowOf('虚构午饭')).top;
      final taxi = tester.getRect(_rowOf('虚构打车')).top;
      final salary = tester.getRect(_rowOf('虚构工资')).top;
      expect(lunch, lessThan(taxi));
      expect(taxi, lessThan(salary));
    });

    testWidgets('day_tape_and_total_sit_above_the_card', (tester) async {
      await pumpC3(tester, state: 'history_diary');
      final header = find.byKey(const Key('history-day-header')).first;
      final tape = tester.getRect(
        find.descendant(of: header, matching: find.byType(DateTapeLabel)),
      );
      final total = tester.getRect(
        find.descendant(
          of: header,
          matching: find.byKey(const Key('history-day-total')),
        ),
      );
      final card = tester.getRect(
        find.byKey(const Key('history-day-card')).first,
      );
      expect(find.text('10月28日 周三'), findsOneWidget);
      expect(total.left, greaterThan(tape.right));
      expect(total.right, closeTo(card.right, 1));
      expect(tape.bottom, lessThanOrEqualTo(card.top));
      expect(
        find.descendant(
          of: find.byKey(const Key('history-day-total')).first,
          matching: find.text('支出'),
        ),
        findsOneWidget,
      );
    });

    for (final locale in ['zh', 'en']) {
      for (final width in [360.0, 430.0]) {
        for (final scale in [1.0, 2.0]) {
          testWidgets('rows_fit $locale $width $scale', (tester) async {
            await pumpC3(
              tester,
              state: 'history_diary',
              locale: locale,
              width: width,
              scale: scale,
            );
            expect(tester.takeException(), isNull);
            for (final row in find.byType(LedgerHistoryRow).evaluate()) {
              final of = find.byWidget(row.widget);
              final rect = tester.getRect(of);
              final content = tester.getRect(
                find.descendant(
                  of: of,
                  matching: find.byKey(const Key('history-row-content')),
                ),
              );
              final amount = tester.getRect(
                find.descendant(of: of, matching: find.byType(AmountText)),
              );
              expect(rect.right, lessThanOrEqualTo(width));
              expect(amount.right, lessThanOrEqualTo(rect.right - 13.5));
              expect(content.right, lessThanOrEqualTo(amount.left));
              expect(rect.height, greaterThanOrEqualTo(66));
            }
          });
        }
      }
    }
  });

  testWidgets('empty_history_shows_a_magnifier', (tester) async {
    await pumpC3(tester, state: 'history_empty');
    expect(
      find.byWidgetPredicate(
        (widget) => widget is JiabuIcon && widget.icon == JiabuIcons.uiSearch,
      ),
      findsNWidgets(2),
    );
    expect(find.text('没有找到符合条件的记录'), findsOneWidget);
  });
}
