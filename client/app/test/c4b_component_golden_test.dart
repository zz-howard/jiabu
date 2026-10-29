@Tags(['golden'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/features/catalog/catalog_cases.dart';

import 'support/catalog_harness.dart';

void main() {
  for (final state in const ['jiabu_logo_variants', 'jiabu_mascot_poses']) {
    final path = 'goldens/c4b/${state}_zh_pine_w360_text100.png';
    testWidgets(path, (tester) async {
      final sample = catalogCases().singleWhere(
        (item) => item.component == 'c4b' && item.state == state,
      );
      await pumpCatalogCase(tester, sample, width: 360, scale: 1);
      expect(tester.takeException(), isNull);
      expectCatalogFits(tester, state);
      await expectLater(find.byKey(catalogBoundary), matchesGoldenFile(path));
    });
  }
}
