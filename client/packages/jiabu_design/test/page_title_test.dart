import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu_design/jiabu_design.dart';

Widget _host(Widget child) => MaterialApp(
  theme: JiabuTheme.light(),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('title block: Serif title, wavy underline, hand subtitle', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) => Localizations.override(
            context: context,
            locale: const Locale('zh', 'CN'),
            child: const JiabuPageTitleBlock(
              title: '历史',
              handEnglish: 'Diary Log',
              subtitle: '账目与家庭资料',
            ),
          ),
        ),
      ),
    );
    expect(find.byType(HandUnderline), findsOneWidget);
    final title = tester.widget<Text>(find.text('历史'));
    expect(title.style!.fontFamily, JiabuType.serifFamily);
    final subtitle = tester.widget<Text>(
      find.byWidgetPredicate(
        (w) => w is Text && w.textSpan?.toPlainText() == 'Diary Log 账目与家庭资料',
      ),
    );
    final spans = (subtitle.textSpan! as TextSpan).children!.cast<TextSpan>();
    expect(spans.first.style!.fontFamily, JiabuType.numeralsFamily);
    expect(spans.last.style!.fontFamily, JiabuType.handFamily);
    expect(find.bySemanticsLabel('历史, Diary Log, 账目与家庭资料'), findsOneWidget);
  });
  testWidgets('space badge: name, house or lock, tap target >= 48', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(
        SpaceBadge(
          name: '我们家',
          accent: const JiabuColors().spaceAccents['pine']!,
          personal: false,
          onTap: () => taps++,
        ),
      ),
    );
    expect(find.text('我们家'), findsOneWidget);
    expect(
      tester.getSize(find.byType(SpaceBadge)).height,
      greaterThanOrEqualTo(48),
    );
    await tester.tap(find.byType(SpaceBadge));
    expect(taps, 1);
  });
  testWidgets('amount: expense minus stays ink, income plus is green', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const Column(
          children: [
            AmountText(
              minorUnits: -6800,
              role: AmountRole.list,
              tone: AmountTone.plain,
              semanticLabel: 'expense',
            ),
            AmountText(
              minorUnits: 300000,
              role: AmountRole.list,
              tone: AmountTone.positive,
              showPlus: true,
              semanticLabel: 'income',
            ),
            AmountText(
              minorUnits: -18000,
              role: AmountRole.list,
              semanticLabel: 'balance',
            ),
          ],
        ),
      ),
    );
    final colors = tester.element(find.byType(Column).first).jiabu.colors;
    Color colorOf(String label) => tester
        .widget<Text>(
          find.descendant(
            of: find.byWidgetPredicate(
              (w) => w is Semantics && w.properties.label == label,
            ),
            matching: find.byType(Text),
          ),
        )
        .style!
        .color!;
    expect(colorOf('expense'), colors.ink);
    expect(colorOf('income'), colors.pos);
    expect(colorOf('balance'), colors.neg);
    final plain = tester.widget<Text>(
      find.descendant(
        of: find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'expense',
        ),
        matching: find.byType(Text),
      ),
    );
    expect(
      plain.textSpan!.toPlainText().replaceAll(RegExp(r'[\u200B\u2060]'), ''),
      '−¥68.00',
    );
  });
}
