import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu_design/jiabu_design.dart';

void main() {
  testWidgets('decorations do not speak, status and user text do', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: JiabuTheme.light(),
        home: const Scaffold(
          body: Column(
            children: [
              Tape(),
              Sticker(category: 'food'),
              HandUnderline(child: Text('家簿')),
              HandCircle(child: Text('总览')),
              Stamp(label: '已记录', state: StampState.recorded),
              NoteBubble(id: 'example', child: Text('示例备注')),
            ],
          ),
        ),
      ),
    );
    expect(find.bySemanticsLabel('已记录'), findsOneWidget);
    expect(find.bySemanticsLabel('示例备注'), findsOneWidget);
    expect(find.bySemanticsLabel('总览'), findsOneWidget);
    expect(find.bySemanticsLabel('家簿'), findsOneWidget);
    expect(find.bySemanticsLabel('food'), findsNothing);
    semantics.dispose();
  });
  for (final position in PaperSnackPosition.values) {
    testWidgets('snackbar $position geometry, duration and action', (
      tester,
    ) async {
      var actions = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: JiabuTheme.light(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () {
                  PaperSnackBar.show(
                    context: context,
                    message: '已撤销',
                    actionLabel: '撤回',
                    onAction: () => actions++,
                    position: position,
                  );
                },
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      final snack = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snack.duration, const Duration(seconds: 5));
      expect(
        snack.margin,
        EdgeInsets.fromLTRB(
          12,
          0,
          12,
          position == PaperSnackPosition.chat ? 150 : 92,
        ),
      );
      expect(
        find.descendant(
          of: find.byType(PaperSnackBar),
          matching: find.byType(Tilt),
        ),
        findsNothing,
      );
      final button = find.widgetWithText(TextButton, '撤回');
      final size = tester.getSize(button);
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
      await tester.tap(button);
      expect(actions, 1);
    });
  }
  testWidgets('modal sheet respects reduced motion and maximum height', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: JiabuTheme.light(),
        home: MediaQuery(
          data: const MediaQueryData(
            disableAnimations: true,
            size: Size(360, 780),
          ),
          child: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  await PaperSheet.show<void>(
                    context: context,
                    builder: (_) =>
                        const SizedBox(height: 2000, child: Text('示例')),
                  );
                },
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(find.byType(PaperSheet), findsOneWidget);
    final context = tester.element(find.byType(PaperSheet));
    final route = ModalRoute.of(context)! as ModalBottomSheetRoute<void>;
    const motion = JiabuMotion();
    expect(route.transitionDuration, Duration.zero);
    expect(route.reverseTransitionDuration, Duration.zero);
    expect(route.sheetAnimationStyle?.duration, Duration.zero);
    expect(route.sheetAnimationStyle?.curve, motion.sheetCurve);
    expect(
      tester.getSize(find.byType(PaperSheet)).height,
      lessThanOrEqualTo(MediaQuery.sizeOf(context).height * .88),
    );
    expect(tester.takeException(), isNull);
  });
  for (final accessible in [false, true]) {
    testWidgets('snackbar with undo, accessibleNavigation=$accessible', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: JiabuTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(accessibleNavigation: accessible),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => PaperSnackBar.show(
                  context: context,
                  message: '已撤销',
                  actionLabel: '撤回',
                  onAction: () {},
                ),
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<SnackBar>(find.byType(SnackBar)).persist,
        accessible,
      );
      await tester.pump(
        PaperSnackBar.visibleDuration + const Duration(seconds: 1),
      );
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(TextButton, '撤回'),
        accessible ? findsOneWidget : findsNothing,
      );
      if (accessible) {
        await tester.tap(find.widgetWithText(TextButton, '撤回'));
        await tester.pumpAndSettle();
        expect(find.byType(SnackBar), findsNothing);
      }
    });
  }
  testWidgets('tappable polaroid is a labelled button', (tester) async {
    final semantics = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: JiabuTheme.light(),
        home: Center(
          child: Polaroid(
            image: const SizedBox(width: 120, height: 90),
            caption: '原图已保存',
            onTap: () => taps++,
          ),
        ),
      ),
    );
    expect(
      tester.getSemantics(find.byType(Polaroid)),
      matchesSemantics(label: '原图已保存', isButton: true, hasTapAction: true),
    );
    await tester.tap(find.byType(Polaroid));
    expect(taps, 1);
    semantics.dispose();
  });
}
