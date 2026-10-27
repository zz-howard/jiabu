import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/features/catalog/catalog_cases.dart';
import 'package:jiabu_design/jiabu_design.dart';

import 'support/catalog_harness.dart';

void main() {
  for (final locale in [const Locale('zh'), const Locale('en')]) {
    for (final sample in catalogCases()) {
      for (final width in [360.0, 430.0]) {
        for (final scale in [1.0, 2.0]) {
          testWidgets('${locale.languageCode} ${sample.id} $width $scale', (
            tester,
          ) async {
            await pumpCatalogCase(
              tester,
              sample,
              width: width,
              scale: scale,
              locale: locale,
            );
            expect(tester.takeException(), isNull);
            _expectRegisteredFonts(tester, sample.id);
            expectCatalogFits(
              tester,
              '${locale.languageCode} ${sample.id} $width $scale',
            );
          });
        }
      }
    }
  }
  test('catalog state IDs are unique', () {
    final cases = catalogCases();
    expect(cases.map((sample) => sample.id).toSet().length, cases.length);
  });
}

void _expectRegisteredFonts(WidgetTester tester, String state) {
  // Logical families loaded by flutter_test_config.dart. Reject Material
  // defaults (including Roboto) even if a test fixture also aliases them.
  const registeredFamilies = {
    JiabuType.systemSansFamily,
    JiabuType.handFamily,
    JiabuType.numeralsFamily,
    JiabuType.serifFamily,
  };
  final failures = <String>[];

  void visit(
    InlineSpan span,
    String? inheritedFamily,
    List<String> inheritedFallback,
  ) {
    final family = span.style?.fontFamily ?? inheritedFamily;
    final fallback = span.style?.fontFamilyFallback ?? inheritedFallback;
    if (span is TextSpan) {
      final text = span.text;
      if (text != null && text.isNotEmpty) {
        if (!registeredFamilies.contains(family)) {
          failures.add('$state: text="$text", fontFamily=$family');
        }
        for (final name in fallback) {
          if (!registeredFamilies.contains(name)) {
            failures.add('$state: text="$text", fallback=$name');
          }
        }
      }
      for (final child in span.children ?? const <InlineSpan>[]) {
        // TextSpan styles inherit at the paragraph level, including when a
        // TextStyle has inherit:false (which only controls TextStyle.merge).
        visit(child, family, fallback);
      }
    }
  }

  // Includes offstage route content and modal overlays. WidgetSpan children
  // containing text have their own RenderParagraph and are checked here too.
  for (final paragraph
      in tester.allRenderObjects.whereType<RenderParagraph>()) {
    visit(paragraph.text, null, const []);
  }
  expect(failures, isEmpty, reason: failures.join('\n'));
}
