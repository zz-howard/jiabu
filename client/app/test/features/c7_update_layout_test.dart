import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/app/c7_preview.dart';
import 'package:jiabu/features/catalog/c7_cases.dart';

import '../support/c3_harness.dart';

void main() {
  for (final state in c7States) {
    for (final locale in const ['zh', 'en']) {
      for (final accent in const ['pine', 'indigo']) {
        for (final width in const [360.0, 430.0]) {
          for (final scale in const [1.0, 2.0]) {
            testWidgets('$state $locale $accent $width $scale fits', (
              tester,
            ) async {
              await pumpC3(
                tester,
                child: C7Preview(state: state),
                locale: locale,
                accent: accent,
                width: width,
                scale: scale,
              );
              expect(tester.takeException(), isNull);
              expect(find.byType(C7Preview), findsOneWidget);
            });
          }
        }
      }
    }
  }
}
