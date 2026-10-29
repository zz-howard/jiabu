import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/features/catalog/c3_cases.dart';
import 'package:jiabu/shared/ledger/record_card.dart';
import 'package:jiabu_design/jiabu_design.dart';

import '../support/c3_harness.dart';

void main() {
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
                for (final element in find.byType(MeSealButton).evaluate()) {
                  expect(
                    tester.getSize(find.byWidget(element.widget)),
                    const Size(48, 48),
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
}
