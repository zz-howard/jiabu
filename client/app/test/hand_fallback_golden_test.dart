@Tags(<String>['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/features/catalog/catalog_cases.dart';

import 'support/catalog_harness.dart';

void main() {
  final mixed = catalogCases().singleWhere(
    (sample) => sample.id == 'hand_text_mixed_e4',
  );
  for (final locale in [const Locale('zh'), const Locale('en')]) {
    for (final width in [360.0, 430.0]) {
      for (final scale in [1.0, 2.0]) {
        final name =
            'e4_fallback_${locale.languageCode}_w${width.toInt()}_'
            'text${(scale * 100).toInt()}';
        testWidgets(name, (tester) async {
          await pumpCatalogCase(
            tester,
            mixed,
            width: width,
            scale: scale,
            locale: locale,
          );
          expect(tester.takeException(), isNull);
          await expectLater(
            find.byKey(catalogBoundary),
            matchesGoldenFile('goldens/e4/$name.png'),
          );
        });
      }
    }
  }
}
