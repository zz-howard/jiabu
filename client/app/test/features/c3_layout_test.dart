import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/features/catalog/c3_cases.dart';
import 'package:jiabu/shared/ledger/record_card.dart';
import 'package:jiabu_design/jiabu_design.dart';

import '../support/c3_harness.dart';
import '../support/vertical_spacing.dart';

const _minimumStackPairs = <String, int>{
  // The chat placeholder is one top-level component; chat is outside UI2.
  'shell_chat': 0,
  'settings': 1,
  'shell_overview': 8,
  'shell_history': 1,
  // No accounts and no records: empty state, pending section + body (the
  // page title now lives in the shared MainFrame header).
  // The summary, account groups and recent changes are intentionally absent.
  'overview_empty': 2,
  'overview_accounts': 8,
  // One extra stack item for the negative-balance note.
  'overview_negative': 9,
  'overview_pending': 8,
  'overview_failure': 8,
  'overview_conflict': 8,
  'overview_busy': 8,
  'history_empty': 1,
  'history_grouped': 1,
  'history_24': 1,
  'history_search': 1,
  'history_filters': 2,
  // The empty account page contains one section marker and no block pair.
  'accounts_empty': 0,
  'accounts': 4,
  'accounts_long_6': 6,
  // LedgerRecordCard is one encapsulated component; its internal layout is
  // deliberately not treated as page-level stacking.
  'card_denied': 0,
  'card_loading': 0,
  'card_recorded': 0,
  'card_pending': 0,
  'card_failed': 0,
  'card_voided': 0,
  'card_conflict': 0,
  'card_changed': 0,
  'card_api_key': 0,
  'card_left': 0,
  'details': 11,
  'details_image': 12,
  'details_audit': 12,
  'edit': 11,
  'conflict': 4,
  'conflict_voided': 5,
  'manual_expense': 12,
  'manual_income': 10,
  'manual_transfer': 10,
  'manual_reallocation': 10,
  'manual_invalid': 13,
  'refund': 10,
  'refund_limit': 11,
  // This state is a single explanatory notice.
  'void_refunds': 0,
  'account_real': 7,
  'account_purpose': 8,
  'account_rename': 3,
  'archive_positive': 2,
  'archive_negative': 2,
  'plan_new': 8,
  'plan_enabled': 8,
  'plan_disabled': 8,
  'plan_pending': 9,
};

const _minimumChipPairs = <String, int>{
  'shell_history': 4,
  'history_empty': 4,
  'history_grouped': 4,
  'history_24': 4,
  'history_search': 4,
  'history_filters': 4,
  'edit': 1,
  'manual_expense': 3,
  'manual_income': 3,
  'manual_transfer': 3,
  'manual_reallocation': 3,
  'manual_invalid': 3,
  'refund': 1,
  'refund_limit': 1,
  'account_real': 1,
  'account_purpose': 1,
};

void main() {
  test('stack pair table covers every C3 state', () {
    expect(_minimumStackPairs.keys.toSet(), c3States.toSet());
  });

  testWidgets('manual account label captions its chip group', (tester) async {
    await pumpC3(tester, state: 'manual_expense');
    final label = find.byKey(
      const ValueKey('account-choices-label-account_id'),
    );
    final chips = find.byKey(const ValueKey('account-choices-account_id'));
    expect(
      tester.getRect(chips).top - tester.getRect(label).bottom,
      closeTo(JiabuSpacing.captionGap, geometryTolerance),
    );
  });

  testWidgets('manual note counter follows its field as a caption', (
    tester,
  ) async {
    await pumpC3(tester, state: 'manual_expense');
    final field = find.byKey(const ValueKey('expense-note-0'));
    final counter = find.text('0/500');
    expect(counter, findsOneWidget);
    expect(
      tester.getRect(counter).top - tester.getRect(field).bottom,
      closeTo(JiabuSpacing.captionGap, geometryTolerance),
    );
  });

  for (final state in c3States) {
    for (final locale in ['zh', 'en']) {
      for (final accent in ['pine', 'indigo']) {
        for (final width in [360.0, 430.0]) {
          for (final scale in [1.0, 2.0]) {
            testWidgets('$state $locale $accent $width $scale', (tester) async {
              final semantics = tester.ensureSemantics();
              try {
                await pumpC3(
                  tester,
                  state: state,
                  locale: locale,
                  accent: accent,
                  width: width,
                  scale: scale,
                );
                expect(tester.takeException(), isNull);
                final stackPairs = expectJiabuVerticalRhythm(
                  tester,
                  reason: '$state $locale $accent $width $scale',
                  requireStack: _minimumStackPairs[state]! > 0,
                );
                expect(
                  stackPairs,
                  greaterThanOrEqualTo(_minimumStackPairs[state]!),
                  reason: '$state minimum stack pair table',
                );
                final chipPairs = expectJiabuChipSpacing(
                  tester,
                  reason: '$state $locale $accent $width $scale',
                );
                expect(
                  chipPairs,
                  greaterThanOrEqualTo(_minimumChipPairs[state] ?? 0),
                  reason: '$state minimum chip pair table',
                );
                for (final card in find.byType(LedgerRecordCard).evaluate()) {
                  expect(
                    tester.getSize(find.byWidget(card.widget)).width,
                    lessThanOrEqualTo(332),
                  );
                }
                for (final element
                    in find.byType(ManualEntryButton).evaluate()) {
                  expect(
                    tester.getSize(find.byWidget(element.widget)).height,
                    greaterThanOrEqualTo(48),
                  );
                }
                for (final element in find.byType(SpaceBadge).evaluate()) {
                  expect(
                    tester.getSize(find.byWidget(element.widget)).height,
                    greaterThanOrEqualTo(48),
                  );
                }
                if (find.byType(JiabuPageScaffold).evaluate().isNotEmpty) {
                  final header = tester.getRect(find.byType(JiabuPageHeader));
                  final body = tester.getRect(
                    find.byKey(const Key('jiabu-page-body')),
                  );
                  expect(body.top, greaterThanOrEqualTo(header.bottom));
                }
                if (state.startsWith('accounts')) {
                  final pageInset = width <= 380 ? 14.0 : 18.0;
                  expect(
                    tester
                        .getRect(find.byKey(const Key('jiabu-page-back')))
                        .left,
                    closeTo(pageInset, .1),
                  );
                  if (find.byType(JiabuSettingsGroup).evaluate().isNotEmpty) {
                    expect(
                      tester
                          .getRect(find.byType(JiabuSettingsGroup).first)
                          .left,
                      closeTo(pageInset, .1),
                    );
                  }
                  expect(
                    tester
                        .getRect(find.byKey(const Key('jiabu-page-action')))
                        .right,
                    closeTo(width - pageInset, .1),
                  );
                }
                if (state == 'accounts') {
                  final amounts = find.byType(AmountText);
                  expect(amounts, findsNWidgets(4));
                  final right = tester.getRect(amounts.first).right;
                  for (var index = 0; index < 4; index++) {
                    expect(
                      tester.getRect(amounts.at(index)).right,
                      closeTo(right, .1),
                    );
                    expect(
                      tester.widget<AmountText>(amounts.at(index)).role,
                      AmountRole.list,
                    );
                  }
                  final menus = find.byType(PopupMenuButton<String>);
                  expect(menus, findsNWidgets(4));
                  final menuRight = tester.getRect(menus.first).right;
                  for (var index = 1; index < 4; index++) {
                    expect(
                      tester.getRect(menus.at(index)).right,
                      closeTo(menuRight, .1),
                    );
                  }
                }
                final richText = find.byType(RichText);
                expect(richText, findsWidgets);
                await expectLater(
                  tester,
                  meetsGuideline(labeledTapTargetGuideline),
                );
                if (state.startsWith('shell_')) {
                  expect(find.byType(PaperBottomNavigation), findsOneWidget);
                  if (state != 'shell_chat') {
                    final nav = tester.getRect(
                      find.byType(PaperBottomNavigation),
                    );
                    final button = tester.getRect(
                      find.byType(ManualEntryButton),
                    );
                    expect(nav.top - button.bottom, closeTo(16, 0.5));
                    expect(width - button.right, closeTo(16, 0.5));
                  }
                }
              } finally {
                semantics.dispose();
              }
            });
          }
        }
      }
    }
  }
  for (final state in ['details', 'edit', 'manual_expense', 'plan_enabled']) {
    for (final width in [360.0, 430.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('$state keyboard $width $scale', (tester) async {
          await pumpC3(
            tester,
            state: state,
            width: width,
            scale: scale,
            keyboard: 280,
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
  for (final locale in ['zh', 'en']) {
    for (final width in [360.0, 430.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('chat content starts below header $locale $width $scale', (
          tester,
        ) async {
          await pumpC3(
            tester,
            state: 'shell_chat',
            locale: locale,
            width: width,
            scale: scale,
          );
          final header = tester.getRect(
            find.byKey(const Key('main-frame-header')),
          );
          final contentFinder = find.byKey(const Key('main-frame-content'));
          final content = tester.getRect(contentFinder);
          expect(tester.widget(contentFinder), isA<ClipRect>());
          expect(content.top, greaterThanOrEqualTo(header.bottom));
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('history margin line stays four pixels left of all row content', (
    tester,
  ) async {
    await pumpC3(tester, state: 'history_grouped');
    final lines = find.byKey(const Key('history-margin-line'));
    final contents = find.byKey(const Key('history-row-content'));
    expect(lines, findsWidgets);
    expect(contents, findsNWidgets(lines.evaluate().length));
    for (var index = 0; index < lines.evaluate().length; index++) {
      final line = tester.getRect(lines.at(index));
      final content = tester.getRect(contents.at(index));
      expect(line.center.dx, lessThan(content.left - 4));
    }
  });

  testWidgets('history filter fade keeps the paper color channels', (
    tester,
  ) async {
    await pumpC3(tester, state: 'history_filters');
    final fade = find.byWidgetPredicate((widget) {
      if (widget is! Container || widget.decoration is! BoxDecoration) {
        return false;
      }
      return (widget.decoration! as BoxDecoration).gradient is LinearGradient;
    });
    final container = tester.widget<Container>(fade.first);
    final gradient =
        (container.decoration! as BoxDecoration).gradient! as LinearGradient;
    final transparentPaper = gradient.colors.first;
    final paper = gradient.colors.last;
    expect(transparentPaper.a, 0);
    expect(transparentPaper.r, paper.r);
    expect(transparentPaper.g, paper.g);
    expect(transparentPaper.b, paper.b);
  });
}
