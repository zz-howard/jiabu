import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu_design/jiabu_design.dart';

Widget _host(Widget child, {double scale = 1, double width = 360}) =>
    MaterialApp(
      theme: JiabuTheme.light(),
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 800),
          textScaler: TextScaler.linear(scale),
        ),
        child: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: width, child: child),
          ),
        ),
      ),
    );

void main() {
  testWidgets('plain section header has no highlighter', (tester) async {
    await tester.pumpWidget(_host(const JiabuSectionHeader(title: '待处理')));
    expect(find.byKey(const Key('jiabu-section-highlight')), findsNothing);
  });

  testWidgets('highlighted section header paints behind its title only', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const JiabuSectionHeader(title: '用途账户', highlighted: true)),
    );
    final marker = find.byKey(const Key('jiabu-section-highlight'));
    expect(marker, findsOneWidget);
    expect(
      find.descendant(of: marker, matching: find.text('用途账户')),
      findsOneWidget,
    );
    final text = tester.widget<Text>(find.text('用途账户'));
    expect(
      text.style,
      tester.element(find.text('用途账户')).jiabu.type.sectionTitle,
    );
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('long highlighted title wraps without overflow $scale', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const JiabuSectionHeader(
            title: '一个很长很长的虚构区块标题用来测试换行时的荧光笔',
            highlighted: true,
          ),
          scale: scale,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(find.byType(JiabuSectionHeader)).right,
        lessThanOrEqualTo(360),
      );
    });
  }
}
