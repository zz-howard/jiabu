import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu_design/jiabu_design.dart';

Future<void> pumpLayout(
  WidgetTester tester,
  Widget child, {
  double width = 360,
  double scale = 1,
}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = Size(width, 800);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      theme: JiabuTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets('spacing resolves compact and regular page insets', (
    tester,
  ) async {
    await pumpLayout(tester, const SizedBox(), width: 380);
    expect(tester.element(find.byType(SizedBox).first).jiabu.spacing.page, 14);
    await pumpLayout(tester, const SizedBox(), width: 381);
    expect(tester.element(find.byType(SizedBox).first).jiabu.spacing.page, 18);
  });

  testWidgets('page header has localized back semantics and 48 tap target', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpLayout(tester, const JiabuPageHeader(title: '二级页面'));
    final back = find.byKey(const Key('jiabu-page-back'));
    expect(back, findsOneWidget);
    expect(tester.getSize(back).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(back).height, greaterThanOrEqualTo(48));
    expect(find.bySemanticsLabel('Back'), findsWidgets);
    semantics.dispose();
  });

  testWidgets('list row is 66 high and grows without overflow at 200 percent', (
    tester,
  ) async {
    const row = JiabuListRow(
      title: '一个很长很长的账户名称用来验证两行标题不会溢出',
      subtitle: '一行说明',
      showChevron: true,
    );
    await pumpLayout(tester, row);
    expect(
      tester.getSize(find.byType(JiabuListRow)).height,
      greaterThanOrEqualTo(66),
    );
    final rowLeft = tester.getRect(find.byType(JiabuListRow)).left;
    final paddingLeft = tester
        .getRect(find.byKey(const Key('jiabu-list-row-padding')))
        .left;
    expect(paddingLeft, rowLeft);
    expect(tester.getRect(find.textContaining('一个很长')).left - rowLeft, 14);
    await pumpLayout(tester, row, scale: 2);
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(JiabuListRow)).height, greaterThan(66));
  });

  testWidgets('layout components stay at zero rotation', (tester) async {
    await pumpLayout(
      tester,
      const Column(
        children: [
          JiabuPageHeader(title: '标题'),
          JiabuListRow(title: '列表'),
          JiabuSectionHeader(title: '分区'),
          JiabuSettingsGroup(children: [JiabuListRow(title: '设置')]),
        ],
      ),
    );
    for (final component in [
      find.byType(JiabuPageHeader),
      find.byType(JiabuListRow),
      find.byType(JiabuSectionHeader),
      find.byType(JiabuSettingsGroup),
    ]) {
      expect(_rotationOffenders(component), findsNothing);
    }
  });

  testWidgets('zero rotation guard catches Tilt and transformed widgets', (
    tester,
  ) async {
    await pumpLayout(
      tester,
      JiabuSettingsGroup(
        children: [
          const Tilt(degrees: 1, child: Text('tilted')),
          Transform.rotate(angle: .1, child: const Text('transformed')),
        ],
      ),
    );
    final offenders = _rotationOffenders(find.byType(JiabuSettingsGroup));
    expect(offenders, findsNWidgets(3));
    expect(
      find.descendant(
        of: find.byType(JiabuSettingsGroup),
        matching: find.byWidgetPredicate(
          (widget) => widget is Tilt && widget.degrees != 0,
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('page scaffold clips content below its opaque header at 200%', (
    tester,
  ) async {
    await pumpLayout(
      tester,
      const JiabuPageScaffold(
        title: '一个很长的二级页面标题用于大字号检查',
        body: ColoredBox(color: Colors.black),
      ),
      scale: 2,
    );
    final header = tester.getRect(find.byType(JiabuPageHeader));
    final body = tester.getRect(find.byKey(const Key('jiabu-page-body')));
    expect(body.top, greaterThanOrEqualTo(header.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings group is plain and sheet has radius twenty', (
    tester,
  ) async {
    await pumpLayout(
      tester,
      const Column(
        children: [
          JiabuSettingsGroup(children: [JiabuListRow(title: '设置')]),
          JiabuSheet(child: Text('弹层')),
        ],
      ),
    );
    expect(JiabuSettingsGroup.paperPattern, isNull);
    final sheet = tester.widget<Container>(
      find.byKey(const Key('jiabu-sheet')),
    );
    final decoration = sheet.decoration! as BoxDecoration;
    final radius = decoration.borderRadius! as BorderRadius;
    expect(radius.topLeft.x, 20);
    expect(radius.topRight.x, 20);
  });
}

Finder _rotationOffenders(Finder component) => find.descendant(
  of: component,
  matching: find.byWidgetPredicate((widget) {
    if (widget is RotatedBox) {
      return widget.quarterTurns % 4 != 0;
    }
    if (widget is RotationTransition) {
      return true;
    }
    if (widget is Tilt) {
      return widget.degrees != 0;
    }
    if (widget is Transform) {
      const identity = <double>[1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1];
      final storage = widget.transform.storage;
      for (var index = 0; index < identity.length; index++) {
        if ((storage[index] - identity[index]).abs() > 0.000001) {
          return true;
        }
      }
    }
    return false;
  }),
);
