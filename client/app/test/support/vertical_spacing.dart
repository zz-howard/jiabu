import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu_design/jiabu_design.dart';

/// Layout positions accumulate float error; gap checks allow this much.
const geometryTolerance = 1e-6;

void _expectMinimumGap(
  double actual,
  double expected, {
  required String reason,
}) {
  expect(
    actual + geometryTolerance,
    greaterThanOrEqualTo(expected),
    reason: reason,
  );
}

int expectJiabuVerticalRhythm(
  WidgetTester tester, {
  required String reason,
  bool requireStack = true,
}) {
  final stackElements = find.byType(JiabuStack).evaluate().toList();
  if (requireStack) {
    expect(stackElements, isNotEmpty, reason: '$reason has no JiabuStack');
  }
  var checkedPairs = 0;
  for (final stack in stackElements) {
    final stackWidget = stack.widget as JiabuStack;
    final markers =
        find
            .descendant(
              of: find.byElementPredicate(
                (element) => identical(element, stack),
              ),
              matching: find.byType(JiabuStackMarker),
            )
            .evaluate()
            .where((marker) => identical(_nearestStack(marker), stack))
            .toList()
          ..sort((left, right) {
            final a = (left.widget as JiabuStackMarker).index;
            final b = (right.widget as JiabuStackMarker).index;
            return a.compareTo(b);
          });
    expect(
      markers.length,
      stackWidget.children.length,
      reason:
          '$reason built ${markers.length}/${stackWidget.children.length} '
          'stack items; scroll the test or replace lazy page-level content',
    );
    if (markers.isNotEmpty &&
        (markers.first.widget as JiabuStackMarker).kind ==
            JiabuStackItemKind.section) {
      final stackRect = tester.getRect(
        find.byElementPredicate((element) => identical(element, stack)),
      );
      final firstRect = tester.getRect(
        find.byElementPredicate((element) => identical(element, markers.first)),
      );
      expect(
        firstRect.top - stackRect.top,
        moreOrLessEquals(JiabuSpacing.sectionTop, epsilon: geometryTolerance),
        reason: '$reason first section top gap',
      );
    }
    for (var index = 1; index < markers.length; index++) {
      final previous = markers[index - 1].widget as JiabuStackMarker;
      final current = markers[index].widget as JiabuStackMarker;
      final previousRect = tester.getRect(find.byWidget(previous));
      final currentRect = tester.getRect(find.byWidget(current));
      final expected = _expectedGap(previous, current);
      _expectMinimumGap(
        currentRect.top - previousRect.bottom,
        expected,
        reason:
            '$reason stack pair ${previous.index}->${current.index} '
            '${previous.kind.name}->${current.kind.name}',
      );
      checkedPairs++;
    }
  }
  return checkedPairs;
}

int expectJiabuChipSpacing(WidgetTester tester, {required String reason}) {
  var checkedPairs = 0;
  for (final group in find.byType(JiabuChipGroup).evaluate()) {
    final markers =
        find
            .descendant(
              of: find.byElementPredicate(
                (element) => identical(element, group),
              ),
              matching: find.byType(JiabuChipGroupMarker),
            )
            .evaluate()
            .where((marker) => identical(_nearestChipGroup(marker), group))
            .toList()
          ..sort((left, right) {
            final a = (left.widget as JiabuChipGroupMarker).index;
            final b = (right.widget as JiabuChipGroupMarker).index;
            return a.compareTo(b);
          });
    for (var index = 1; index < markers.length; index++) {
      final previous = markers[index - 1].widget as JiabuChipGroupMarker;
      final current = markers[index].widget as JiabuChipGroupMarker;
      final previousRect = tester.getRect(find.byWidget(previous));
      final currentRect = tester.getRect(find.byWidget(current));
      final overlap =
          currentRect.top < previousRect.bottom &&
          previousRect.top < currentRect.bottom;
      final gap = overlap
          ? currentRect.left - previousRect.right
          : currentRect.top - previousRect.bottom;
      _expectMinimumGap(
        gap,
        JiabuSpacing.sm,
        reason: '$reason chip pair ${previous.index}->${current.index}',
      );
      checkedPairs++;
    }
  }
  return checkedPairs;
}

Element? _nearestStack(Element element) {
  Element? result;
  element.visitAncestorElements((ancestor) {
    if (ancestor.widget is JiabuStack) {
      result = ancestor;
      return false;
    }
    return true;
  });
  return result;
}

Element? _nearestChipGroup(Element element) {
  Element? result;
  element.visitAncestorElements((ancestor) {
    if (ancestor.widget is JiabuChipGroup) {
      result = ancestor;
      return false;
    }
    return true;
  });
  return result;
}

double _expectedGap(JiabuStackMarker previous, JiabuStackMarker current) {
  if (current.kind == JiabuStackItemKind.caption &&
      current.captionTarget == JiabuCaptionTarget.previous) {
    return JiabuSpacing.captionGap;
  }
  if (previous.kind == JiabuStackItemKind.caption &&
      previous.captionTarget == JiabuCaptionTarget.next) {
    return JiabuSpacing.captionGap;
  }
  if (current.kind == JiabuStackItemKind.section) {
    return JiabuSpacing.sectionTop;
  }
  if (current.kind == JiabuStackItemKind.action) {
    return JiabuSpacing.actionGap;
  }
  if (previous.kind == JiabuStackItemKind.section) {
    return JiabuSpacing.sectionBottom;
  }
  return JiabuSpacing.cardGap;
}
