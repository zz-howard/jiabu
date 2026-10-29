import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/features/catalog/c5_cases.dart';

import '../support/c3_harness.dart';

void main() {
  for (final state in c5States) {
    for (final locale in ['zh', 'en']) {
      for (final accent in ['pine', 'indigo']) {
        for (final width in [360.0, 430.0]) {
          for (final scale in [1.0, 2.0]) {
            testWidgets(
              'c5_layout_${state}_${locale}_${accent}_${width}_$scale',
              (tester) async {
                await pumpC3(
                  tester,
                  width: width,
                  scale: scale,
                  locale: locale,
                  child: C5Preview(
                    key: ValueKey('$state-$locale-$accent-$width-$scale'),
                    state: state,
                    accent: accent,
                  ),
                );
                expect(tester.takeException(), isNull);
              },
            );
          }
        }
      }
    }
  }
}
