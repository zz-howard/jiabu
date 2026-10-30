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

Rect visibleGlyphRect(WidgetTester tester, Finder finder) {
  final widget = tester.widget<JiabuIcon>(finder);
  final box = tester.getRect(finder);
  var bounds = widget.icon.shapes.first.path().getBounds();
  for (final shape in widget.icon.shapes.skip(1)) {
    bounds = bounds.expandToInclude(shape.path().getBounds());
  }
  if (widget.fitGlyph) {
    return box;
  }
  bounds = bounds.inflate((widget.strokeWidth ?? widget.icon.strokeWidth) / 2);
  final scaleX = box.width / widget.icon.width;
  final scaleY = box.height / widget.icon.height;
  final left = widget.flipX
      ? box.right - bounds.right * scaleX
      : box.left + bounds.left * scaleX;
  final right = widget.flipX
      ? box.right - bounds.left * scaleX
      : box.left + bounds.right * scaleX;
  final top = widget.flipY
      ? box.bottom - bounds.bottom * scaleY
      : box.top + bounds.top * scaleY;
  final bottom = widget.flipY
      ? box.bottom - bounds.top * scaleY
      : box.top + bounds.bottom * scaleY;
  return Rect.fromLTRB(left, top, right, bottom);
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

  testWidgets('page header preserves UI1 geometry at 100 percent', (
    tester,
  ) async {
    const titleText = '二级页面';
    await pumpLayout(tester, const JiabuPageHeader(title: titleText));
    final header = find.byType(JiabuPageHeader);
    final title = find.text(titleText);
    final titleHeight = tester.getSize(title).height;
    final expectedTop = (JiabuSpacing.listRowMinHeight - titleHeight) / 2;
    expect(tester.getSize(header).height, JiabuSpacing.listRowMinHeight);
    expect(
      tester.getRect(title).top - tester.getRect(header).top,
      closeTo(expectedTop, .1),
    );
    expect(
      tester.getRect(find.byKey(const Key('jiabu-page-back'))).center.dy,
      closeTo(tester.getRect(header).center.dy, .1),
    );
  });

  testWidgets('page back glyph scales and aligns with title first line', (
    tester,
  ) async {
    await pumpLayout(
      tester,
      const JiabuPageHeader(title: '一个很长的二级页面标题用于两行检查'),
      scale: 2,
    );
    final icon = find.byKey(const Key('jiabu-page-back-icon'));
    final title = find.text('一个很长的二级页面标题用于两行检查');
    final iconSize = tester.getSize(icon);
    expect(iconSize.width, lessThanOrEqualTo(32));
    final context = tester.element(title);
    final style = context.jiabu.type.pageTitle;
    final firstLineHeight =
        MediaQuery.textScalerOf(context).scale(style.fontSize!) * style.height!;
    final iconWidget = tester.widget<JiabuIcon>(icon);
    final visibleGlyphHeight = visibleGlyphRect(tester, icon).height;
    expect(iconWidget.fitGlyph, isTrue);
    expect(
      visibleGlyphHeight,
      greaterThanOrEqualTo(
        firstLineHeight * JiabuPageHeader.backGlyphTitleRatio,
      ),
    );
    expect(
      tester.getRect(icon).center.dy,
      closeTo(tester.getRect(title).top + firstLineHeight / 2, .1),
    );
    expect(
      tester.getSize(find.byKey(const Key('jiabu-page-back'))).height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('page back glyph keeps token gap before title', (tester) async {
    const titleText = '个人 API key';
    for (final width in [360.0, 430.0]) {
      for (final scale in [1.0, 2.0]) {
        await pumpLayout(
          tester,
          const JiabuPageHeader(title: titleText),
          width: width,
          scale: scale,
        );
        final icon = find.byKey(const Key('jiabu-page-back-icon'));
        final title = find.text(titleText);
        final gap =
            tester.getRect(title).left - visibleGlyphRect(tester, icon).right;
        expect(
          gap,
          greaterThanOrEqualTo(JiabuSpacing.sm),
          reason: '$width at ${scale}x',
        );
        if (scale == 1) {
          final iconWidget = tester.widget<JiabuIcon>(icon);
          final iconBox = tester.getRect(icon);
          final sourceBounds = iconWidget.icon.shapes.first
              .path()
              .getBounds()
              .inflate(
                (iconWidget.strokeWidth ?? iconWidget.icon.strokeWidth) / 2,
              );
          final sourceScale = iconBox.width / iconWidget.icon.width;
          final ui1GlyphRight =
              (JiabuSpacing.minTapTarget - iconBox.width) / 2 +
              iconBox.width -
              sourceBounds.left * sourceScale;
          final ui1Gap = JiabuSpacing.minTapTarget - ui1GlyphRight;
          expect(gap, closeTo(ui1Gap, .1), reason: '$width at ${scale}x');
        }
      }
    }
  });

  testWidgets('stack applies token gaps and grows at 200 percent', (
    tester,
  ) async {
    Widget sample() => JiabuStack(
      children: [
        const JiabuStackItem.content(child: Text('content')),
        const JiabuStackItem.content(child: Text('second content')),
        const JiabuStackItem.caption(child: Text('caption')),
        const JiabuStackItem.section(
          child: JiabuSectionHeader(title: 'section'),
        ),
        const JiabuStackItem.content(child: Text('next content')),
        JiabuStackItem.action(
          actionCaption: const Text('action caption'),
          child: FilledButton(onPressed: () {}, child: const Text('action')),
        ),
      ],
    );
    await pumpLayout(tester, sample());
    final markers = find.byType(JiabuStackMarker);
    double gap(int before, int after) =>
        tester.getRect(markers.at(after)).top -
        tester.getRect(markers.at(before)).bottom;
    expect(gap(0, 1), JiabuSpacing.cardGap);
    expect(gap(1, 2), JiabuSpacing.captionGap);
    expect(gap(2, 3), JiabuSpacing.sectionTop);
    expect(gap(3, 4), JiabuSpacing.sectionBottom);
    expect(gap(4, 5), JiabuSpacing.actionGap);
    final caption = tester.getRect(find.text('action caption'));
    final button = tester.getRect(find.widgetWithText(FilledButton, 'action'));
    expect(button.top - caption.bottom, JiabuSpacing.captionGap);
    final normalHeight = tester.getSize(find.byType(JiabuStack)).height;
    await pumpLayout(tester, sample(), scale: 2);
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(JiabuStack)).height,
      greaterThan(normalHeight),
    );
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

  testWidgets('chip group applies token gaps and selected theme', (
    tester,
  ) async {
    await pumpLayout(
      tester,
      const SizedBox(
        width: 130,
        child: JiabuChipGroup(
          children: [
            SizedBox(width: 60, height: 20),
            SizedBox(width: 60, height: 20),
            SizedBox(width: 60, height: 20),
          ],
        ),
      ),
    );
    final markers = find.byType(JiabuChipGroupMarker);
    expect(
      tester.getRect(markers.at(1)).left - tester.getRect(markers.at(0)).right,
      JiabuSpacing.sm,
    );
    expect(
      tester.getRect(markers.at(2)).top - tester.getRect(markers.at(0)).bottom,
      JiabuSpacing.sm,
    );

    await pumpLayout(
      tester,
      JiabuChipGroup(
        children: [
          ChoiceChip(
            label: const Text('selected'),
            selected: true,
            onSelected: (_) {},
          ),
        ],
      ),
    );
    final chip = find.byType(ChoiceChip);
    final context = tester.element(chip);
    final theme = ChipTheme.of(context);
    expect(theme.selectedColor, context.jiabu.colors.primarySoft);
    expect(theme.checkmarkColor, context.jiabu.colors.onPrimarySoft);
    expect(
      theme.secondaryLabelStyle?.color,
      context.jiabu.colors.onPrimarySoft,
    );
    expect(theme.showCheckmark, isTrue);
    final selectedLabel = (theme.labelStyle! as WidgetStateTextStyle).resolve({
      WidgetState.selected,
    });
    expect(selectedLabel.color, context.jiabu.colors.onPrimarySoft);
    final selectedSide = (theme.side! as WidgetStateBorderSide).resolve({
      WidgetState.selected,
    });
    expect(selectedSide?.color, context.jiabu.colors.white);
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
          JiabuStack(
            children: [
              JiabuStackItem.content(child: Text('堆叠')),
              JiabuStackItem.action(child: Text('动作')),
            ],
          ),
        ],
      ),
    );
    for (final component in [
      find.byType(JiabuPageHeader),
      find.byType(JiabuListRow),
      find.byType(JiabuSectionHeader),
      find.byType(JiabuSettingsGroup),
      find.byType(JiabuStack),
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
