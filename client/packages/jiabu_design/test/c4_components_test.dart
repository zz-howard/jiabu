import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu_design/jiabu_design.dart';

void main() {
  testWidgets('logo_has_size_tilt_semantics_and_dark_variant', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: JiabuTheme.light(),
        home: const Scaffold(body: JiabuLogo(size: 96)),
      ),
    );
    expect(tester.getSize(find.byType(JiabuLogo)), const Size(96, 96));
    expect(tester.widget<Tilt>(find.byType(Tilt)).degrees, -8);
    expect(find.bySemanticsLabel('家簿'), findsOneWidget);
    await tester.pumpWidget(
      MaterialApp(
        theme: JiabuTheme.light(),
        home: const Scaffold(body: JiabuLogo(variant: JiabuLogoVariant.dark)),
      ),
    );
    expect(
      tester.widget<Image>(find.byType(Image)).image,
      isA<AssetImage>().having(
        (image) => image.assetName,
        'assetName',
        contains('logo-dark-disc.png'),
      ),
    );
    semantics.dispose();
  });
  testWidgets('mascot poses map to distinct resolution-aware assets', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: JiabuTheme.light(),
        home: const Scaffold(
          body: Row(
            children: [
              JiabuMascot(pose: JiabuMascotPose.greet),
              JiabuMascot(pose: JiabuMascotPose.pen),
              JiabuMascot(pose: JiabuMascotPose.idle),
            ],
          ),
        ),
      ),
    );
    final assets = tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => (image.image as AssetImage).assetName)
        .toSet();
    expect(
      assets,
      containsAll(
        [
          'hamster-greet.png',
          'hamster-pen.png',
          'hamster-idle.png',
        ].map((name) => 'packages/jiabu_design/assets/brand/mascot/$name'),
      ),
    );
  });
  testWidgets('accent_controls_have_48px_targets_and_eight_named_choices', (
    tester,
  ) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        theme: JiabuTheme.light(),
        home: Scaffold(
          body: SpaceAccentPicker(
            value: 'pine',
            label: 'Accent',
            onChanged: (value) => selected = value,
          ),
        ),
      ),
    );
    expect(find.byType(InkWell), findsNWidgets(8));
    for (final element in find.byType(InkWell).evaluate()) {
      expect(tester.getSize(find.byWidget(element.widget)), const Size(48, 48));
    }
    await tester.tap(find.byType(InkWell).first);
    expect(selected, isNotNull);
  });
  testWidgets('pattern_points_are_accessible_and_do_not_repeat', (
    tester,
  ) async {
    final points = ValueNotifier<List<int>>([]);
    addTearDown(points.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: JiabuTheme.light(),
        home: Scaffold(
          body: ValueListenableBuilder<List<int>>(
            valueListenable: points,
            builder: (context, value, child) => PatternLock(
              points: value,
              label: 'Pattern',
              onChanged: (next) => points.value = next,
            ),
          ),
        ),
      ),
    );
    final semantics = tester.ensureSemantics();
    try {
      await tester.tap(find.bySemanticsLabel('Pattern 1'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Pattern 1'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Pattern 2'));
      await tester.pump();
      expect(points.value, [0, 1]);
      points.value = [];
      await tester.pump();
      final pad = find.byKey(PatternLock.padKey);
      final origin = tester.getTopLeft(pad);
      final gesture = await tester.startGesture(origin + const Offset(36, 36));
      await gesture.moveTo(origin + const Offset(60, 36));
      await tester.pump();
      await gesture.moveTo(origin + const Offset(108, 36));
      await tester.pump();
      await gesture.moveTo(origin + const Offset(180, 36));
      await tester.pump();
      await gesture.moveTo(origin + const Offset(180, 108));
      await gesture.up();
      await tester.pump();
      expect(points.value, [0, 1, 2, 5]);
      expect(tester.getSize(pad), const Size(216, 216));
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });
}
