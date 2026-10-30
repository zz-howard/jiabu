import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu_design/jiabu_design.dart';

void main() {
  testWidgets('HandText uses one Text, ordered fallback and forced strut', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: JiabuTheme.light(),
        home: const HandText('今天 12:36', english: false),
      ),
    );
    final text = tester.widget<Text>(find.byType(Text));
    expect(text.textSpan, isNull);
    expect(text.data, '今天 12:36');
    expect(text.style!.fontFamily, JiabuType.numeralsFamily);
    expect(text.style!.fontFamilyFallback, [
      JiabuType.handFamily,
      JiabuType.systemSansFamily,
    ]);
    expect(text.style!.fontWeight, FontWeight.w600);
    expect(text.strutStyle!.fontFamily, JiabuType.handFamily);
    expect(text.strutStyle!.fontWeight, FontWeight.w500);
    expect(text.strutStyle!.fontSize, 14);
    expect(text.strutStyle!.height, 1.25);
    expect(text.strutStyle!.forceStrutHeight, isTrue);
    expect(text.locale, const Locale('zh', 'CN'));
  });
  testWidgets('English uses Caveat without the hand subset', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: JiabuTheme.light(),
        home: const HandText('My Home Diary'),
      ),
    );
    final text = tester.widget<Text>(find.byType(Text));
    expect(text.style!.fontFamilyFallback, [JiabuType.systemSansFamily]);
    expect(text.strutStyle!.fontFamily, JiabuType.numeralsFamily);
  });
  testWidgets('AmountText groups integer minor units and preserves semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: JiabuTheme.light(),
        home: const AmountText(
          minorUnits: -184260,
          semanticLabel: '支出 1842 元 60 分',
        ),
      ),
    );
    final text = tester.widget<Text>(find.byType(Text));
    expect(
      text.textSpan!.toPlainText().replaceAll(RegExp('[\u200B\u2060]'), ''),
      '−¥1,842.60',
    );
    expect(
      text.style!.fontFeatures,
      contains(const ui.FontFeature.tabularFigures()),
    );
    expect(find.bySemanticsLabel('支出 1842 元 60 分'), findsOneWidget);
    semantics.dispose();
  });
}
