import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu_design/jiabu_design.dart';

void main() {
  testWidgets('manual entry button uses 4.21 geometry and semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: JiabuTheme.light(),
          home: Scaffold(
            floatingActionButtonLocation: const ManualEntryLocation(),
            floatingActionButton: ManualEntryButton(
              label: '记一笔',
              semanticLabel: '手动记一笔',
              onPressed: () {},
            ),
            bottomNavigationBar: PaperBottomNavigation(
              labels: const ['聊天', '总览', '历史'],
              selected: 1,
              onSelect: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final button = tester.getRect(find.byType(ManualEntryButton));
      final nav = tester.getRect(find.byType(PaperBottomNavigation));
      expect(button.height, 52);
      expect(nav.top - button.bottom, 16);
      expect(find.bySemanticsLabel('手动记一笔'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });
  for (final surface in ['card', 'sheet', 'note']) {
    for (final toggle in [false, true]) {
      testWidgets('paper row hosts tile ink on $surface toggle=$toggle', (
        tester,
      ) async {
        var taps = 0;
        final row = PaperRow(
          child: toggle
              ? SwitchListTile(
                  title: const Text('虚构拨入计划'),
                  value: true,
                  onChanged: (_) => taps++,
                )
              : ListTile(title: const Text('虚构账户'), onTap: () => taps++),
        );
        final Widget paper;
        switch (surface) {
          case 'card':
            paper = PaperCard(child: row);
          case 'sheet':
            paper = JiabuSheet(child: row);
          default:
            paper = NegativeBalanceNote(
              title: '虚构账户',
              body: '余额不足',
              action: row,
            );
        }
        await tester.pumpWidget(
          MaterialApp(
            theme: JiabuTheme.light(),
            home: Scaffold(body: paper),
          ),
        );
        expect(tester.takeException(), isNull);
        final tile = find.byType(ListTile).first;
        final material = tester
            .element(tile)
            .findAncestorWidgetOfExactType<Material>();
        expect(material?.type, MaterialType.transparency);
        await tester.tap(tile);
        await tester.pump(const Duration(milliseconds: 100));
        expect(taps, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('dotted values share baseline and negative values are red', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: JiabuTheme.light(),
        home: const Scaffold(
          body: DottedValueRow(label: '虚构日常', value: '−¥12.00', negative: true),
        ),
      ),
    );
    final row = tester.widget<Row>(
      find.descendant(
        of: find.byType(DottedValueRow),
        matching: find.byType(Row),
      ),
    );
    expect(row.crossAxisAlignment, CrossAxisAlignment.baseline);
    expect(row.textBaseline, TextBaseline.alphabetic);
    final amount = find.text('−¥12.00');
    expect(
      tester.widget<Text>(amount).style?.color,
      tester.element(amount).jiabu.colors.neg,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'amount supports zero decimal currency without truncating whole units',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: JiabuTheme.light(),
          home: const Scaffold(
            body: AmountText(
              minorUnits: 123,
              decimalDigits: 0,
              semanticLabel: '123 JPY',
            ),
          ),
        ),
      );
      final text = tester.widget<Text>(
        find.descendant(
          of: find.byType(AmountText),
          matching: find.byType(Text),
        ),
      );
      expect(text.textSpan!.toPlainText(), '¥123');
    },
  );
}
