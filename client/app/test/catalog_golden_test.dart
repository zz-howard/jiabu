@Tags(<String>['golden'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/features/catalog/catalog_cases.dart';

import 'support/catalog_harness.dart';

void main() {
  // C3 uses its explicitly budgeted matrix in c3_golden_test.dart.
  for (final sample in catalogCases().where(
    (sample) =>
        sample.component != 'c3' &&
        sample.component != 'c4' &&
        sample.component != 'c4b' &&
        sample.component != 'c5' &&
        sample.component != 'c7',
  )) {
    final variants =
        sample.component.startsWith('ui1_') ||
            sample.component.startsWith('ui2_')
        ? const [(360.0, 1.0), (430.0, 2.0)]
        : const [(360.0, 1.0), (360.0, 2.0), (430.0, 1.0), (430.0, 2.0)];
    for (final (width, scale) in variants) {
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
