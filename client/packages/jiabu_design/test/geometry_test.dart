import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu_design/jiabu_design.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double scale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: JiabuTheme.light(),
      home: MediaQuery(
        data: MediaQueryData(
          textScaler: TextScaler.linear(scale),
          size: const Size(360, 780),
        ),
        child: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: Align(alignment: Alignment.topLeft, child: child),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Tape has exact dimensions, angle and no pointer/semantic target',
    (tester) async {
      var taps = 0;
      await _pump(
        tester,
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => taps++,
          child: const Tape(),
        ),
      );
      expect(tester.getSize(find.byType(Tape)), const Size(76, 22));
      expect(tester.widget<Tilt>(find.byType(Tilt)).degrees, -5);
      expect(
        find.descendant(
          of: find.byType(Tape),
          matching: find.byWidgetPredicate(
            (widget) => widget is IgnorePointer && widget.ignoring,
          ),
        ),
        findsOneWidget,
      );
      // Tape ignores pointers, so the tap lands on the detector behind it.
      await tester.tap(find.byType(Tape), warnIfMissed: false);
      expect(taps, 1);
      expect(
        tapePath(const Size(76, 22)).getBounds(),
        const Rect.fromLTWH(0, 0, 76, 22),
      );
    },
  );
  for (final compact in [false, true]) {
    testWidgets('Sticker size and white border compact=$compact', (
      tester,
    ) async {
      await _pump(tester, Sticker(category: 'food', compact: compact));
      expect(
        tester.getSize(find.byType(Sticker)),
        compact ? const Size(36, 36) : const Size(40, 40),
      );
      expect(tester.widget<Tilt>(find.byType(Tilt)).degrees, -6);
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(Sticker),
          matching: find.byType(Container),
        ),
      );
      final decor = container.decoration! as BoxDecoration;
      expect((decor.border! as Border).top.width, 2.5);
      expect((decor.border! as Border).top.color, const JiabuColors().white);
      expect(tester.widget<JiabuIcon>(find.byType(JiabuIcon)).strokeWidth, 1.9);
    });
  }
  for (final scale in [1.0, 2.0]) {
    for (final state in StampState.values) {
      testWidgets('Stamp geometry $state scale=$scale', (tester) async {
        await _pump(
          tester,
          Stamp(
            label: state == StampState.recorded ? '✓ 已记录' : '已撤销 · 余额已恢复',
            state: state,
          ),
          scale: scale,
        );
        expect(tester.widget<Tilt>(find.byType(Tilt)).degrees, -5);
        final size = tester.getSize(find.byType(Stamp));
        expect(size.height, scale == 1 ? equals(24) : greaterThanOrEqualTo(24));
        final container = tester.widget<Container>(
          find.descendant(
            of: find.byType(Stamp),
            matching: find.byType(Container),
          ),
        );
        final decor = container.decoration! as BoxDecoration;
        expect((decor.border! as Border).top.width, 1.8);
        expect(decor.borderRadius, BorderRadius.circular(5));
        expect(tester.takeException(), isNull);
      });
    }
    testWidgets('Polaroid frame and caption scale=$scale', (tester) async {
      await _pump(
        tester,
        const Polaroid(
          caption: '原图已保存',
          image: SizedBox(width: 282, height: 100),
        ),
        scale: scale,
      );
      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(Polaroid),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(
        container.padding,
        const EdgeInsets.only(left: 9, right: 9, top: 9),
      );
      final height = tester
          .getSize(find.byKey(const Key('polaroid-caption')))
          .height;
      expect(height, scale == 1 ? equals(34) : greaterThanOrEqualTo(34));
      final tilts = tester.widgetList<Tilt>(find.byType(Tilt));
      expect(tilts.first.degrees, -2);
      expect(tester.widget<Tape>(find.byType(Tape)).pattern, TapePattern.dots);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Tilt preserves layout and unrotated rectangle hit tests', (
    tester,
  ) async {
    var taps = 0;
    final child = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => taps++,
      child: const SizedBox(width: 100, height: 40),
    );
    await _pump(tester, child);
    final original = tester.getRect(find.byType(GestureDetector));
    await _pump(tester, Tilt(degrees: 30, child: child));
    expect(tester.getSize(find.byType(Tilt)), original.size);
    final transform = tester.widget<Transform>(
      find.descendant(of: find.byType(Tilt), matching: find.byType(Transform)),
    );
    expect(transform.transformHitTests, isFalse);
    expect(transform.alignment, Alignment.center);
    final matrix = transform.transform;
    expect(matrix.entry(0, 0), math.cos(30 * math.pi / 180));
    await tester.tapAt(original.topLeft + const Offset(1, 1));
    await tester.tapAt(original.bottomRight - const Offset(1, 1));
    expect(taps, 2);
  });
  testWidgets('PaperCard remains horizontal; tape overlaps top by ten', (
    tester,
  ) async {
    await _pump(
      tester,
      const Stack(
        clipBehavior: Clip.none,
        children: [
          PaperCard(child: SizedBox(width: 100, height: 60)),
          Positioned(top: -10, left: 12, child: Tape()),
        ],
      ),
    );
    expect(
      find.descendant(of: find.byType(PaperCard), matching: find.byType(Tilt)),
      findsNothing,
    );
    final positioned = tester.widget<Positioned>(find.byType(Positioned));
    expect(positioned.top, -10);
  });
  testWidgets('PencilStrike and NoteBubble use exact deterministic angles', (
    tester,
  ) async {
    await _pump(tester, const PencilStrike(child: Text('午饭')));
    expect(tester.widget<Tilt>(find.byType(Tilt)).degrees, -2.5);
    await _pump(tester, const NoteBubble(id: '家簿📝', child: Text('午饭')));
    expect(
      tester.widget<Tilt>(find.byType(Tilt)).degrees,
      tiltFor('家簿📝', amp: .8),
    );
  });
  testWidgets('sheet handle is horizontal and 74 by 20', (tester) async {
    await _pump(tester, const JiabuSheet(child: Text('午饭')));
    expect(tester.getSize(find.byType(Tape)), const Size(74, 20));
    expect(tester.widget<Tilt>(find.byType(Tilt)).degrees, 0);
    expect(
      tester.getSize(find.byType(JiabuSheet)).height,
      lessThanOrEqualTo(780 * .88),
    );
  });
  test('navigation circle remains open; stroke tokens match specification', () {
    expect(
      JiabuIcons.circle.shapes.single.path().computeMetrics().single.isClosed,
      isFalse,
    );
    expect(const JiabuDecor().circleStroke, 2.4);
    expect(const JiabuDecor().strikeStroke, 2);
    expect(Sticker.icons['doc'], JiabuIcons.uiEye);
    expect(Sticker.icons['fund'], JiabuIcons.uiCard);
  });
}
