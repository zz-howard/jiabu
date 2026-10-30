@Tags(['golden'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu_design/jiabu_design.dart';

import '../support/c3_harness.dart';

/// The history page with its filter chip row scrolled all the way to the end
/// (the owner-reported case: the last chip used to stay under a fade).
const v4ChipEndGoldens = <({String locale, int width, int scale, String path})>[
  (
    locale: 'zh',
    width: 360,
    scale: 100,
    path: '../goldens/v4/history_chips_end_zh_pine_w360_text100.png',
  ),
  (
    locale: 'zh',
    width: 360,
    scale: 200,
    path: '../goldens/v4/history_chips_end_zh_pine_w360_text200.png',
  ),
  (
    locale: 'en',
    width: 430,
    scale: 100,
    path: '../goldens/v4/history_chips_end_en_pine_w430_text100.png',
  ),
];

void main() {
  for (final sample in v4ChipEndGoldens) {
    testWidgets(sample.path, (tester) async {
      await pumpC3(
        tester,
        state: 'shell_history',
        locale: sample.locale,
        width: sample.width.toDouble(),
        scale: sample.scale / 100,
      );
      // The scrollable holding the filter chips (also on the pre-V4 page).
      final row = find.ancestor(
        of: find.byType(PaperFilterChip).first,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.right,
        ),
      );
      final position = tester.state<ScrollableState>(row).position;
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(find.byKey(c3Boundary), matchesGoldenFile(sample.path));
    });
  }
}
