@Tags(<String>['golden'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/features/catalog/catalog_cases.dart';

import 'support/catalog_harness.dart';

void main() {
  // C3 uses its explicitly budgeted matrix in c3_golden_test.dart.
  for (final sample in catalogCases().where(
    (sample) => sample.component != 'c3',
  )) {
    for (final width in [360.0, 430.0]) {
      for (final scale in [1.0, 2.0]) {
        final name =
            '${sample.id}_light_w${width.toInt()}_'
            'text${(scale * 100).toInt()}';
        testWidgets(name, (tester) async {
          await pumpCatalogCase(tester, sample, width: width, scale: scale);
          expect(tester.takeException(), isNull);
          expectCatalogFits(tester, name);
          await expectLater(
            find.byKey(catalogBoundary),
            matchesGoldenFile('goldens/catalog/$name.png'),
          );
        });
      }
    }
  }
}
