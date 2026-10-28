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
}
