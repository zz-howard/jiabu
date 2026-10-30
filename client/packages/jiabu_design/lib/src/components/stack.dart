import 'package:flutter/material.dart';
import 'package:jiabu_design/src/tokens/spacing.dart';

enum JiabuStackItemKind { content, section, caption, action }

@immutable
class JiabuStackItem {
  const JiabuStackItem.content({required this.child})
    : kind = JiabuStackItemKind.content,
      captionTarget = null,
      actionCaption = null,
      captionAfter = false;

  const JiabuStackItem.section({required this.child})
    : kind = JiabuStackItemKind.section,
      captionTarget = null,
      actionCaption = null,
      captionAfter = false;

  const JiabuStackItem.captionAfter({required this.child})
    : kind = JiabuStackItemKind.caption,
      captionTarget = JiabuCaptionTarget.previous,
      actionCaption = null,
      captionAfter = false;

  const JiabuStackItem.captionBefore({required this.child})
    : kind = JiabuStackItemKind.caption,
      captionTarget = JiabuCaptionTarget.next,
      actionCaption = null,
      captionAfter = false;

  const JiabuStackItem.action({
    required this.child,
    this.actionCaption,
    this.captionAfter = false,
  }) : kind = JiabuStackItemKind.action,
       captionTarget = null;

  final Widget child;
  final JiabuStackItemKind kind;
  final JiabuCaptionTarget? captionTarget;
  final Widget? actionCaption;
  final bool captionAfter;
}

class JiabuStack extends StatelessWidget {
  const JiabuStack({
    required this.children,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
    super.key,
  });

  final List<JiabuStackItem> children;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    assert(
      children.every((item) => item.child is! JiabuStack),
      'A JiabuStackItem child cannot be a JiabuStack at the same visual '
      'level. Flatten the items or wrap the inner stack in a card/group.',
    );
    final widgets = <Widget>[];
    for (var index = 0; index < children.length; index++) {
      final item = children[index];
      if (index == 0) {
        if (item.kind == JiabuStackItemKind.section) {
          widgets.add(const SizedBox(height: JiabuSpacing.sectionTop));
        }
      } else {
        widgets.add(SizedBox(height: _gap(children[index - 1], item)));
      }
      final child =
          item.kind == JiabuStackItemKind.action && item.actionCaption != null
          ? Column(
              spacing: JiabuSpacing.captionGap,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: item.captionAfter
                  ? [item.child, item.actionCaption!]
                  : [item.actionCaption!, item.child],
            )
          : item.child;
      widgets.add(
        JiabuStackMarker(
          key: ValueKey('jiabu-stack-item-$index'),
          kind: item.kind,
          captionTarget: item.captionTarget,
          index: index,
          child: child,
        ),
      );
    }
    return Column(
      key: const Key('jiabu-stack'),
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: mainAxisAlignment,
      children: widgets,
    );
  }

  static double _gap(JiabuStackItem current, JiabuStackItem next) {
    if (next.kind == JiabuStackItemKind.caption &&
        next.captionTarget == JiabuCaptionTarget.previous) {
      return JiabuSpacing.captionGap;
    }
    if (current.kind == JiabuStackItemKind.caption &&
        current.captionTarget == JiabuCaptionTarget.next) {
      return JiabuSpacing.captionGap;
    }
    if (next.kind == JiabuStackItemKind.section) {
      return JiabuSpacing.sectionTop;
    }
    if (next.kind == JiabuStackItemKind.action) {
      return JiabuSpacing.actionGap;
    }
    if (current.kind == JiabuStackItemKind.section) {
      return JiabuSpacing.sectionBottom;
    }
    return JiabuSpacing.cardGap;
  }
}

enum JiabuCaptionTarget { previous, next }

class JiabuStackMarker extends StatelessWidget {
  const JiabuStackMarker({
    required this.kind,
    required this.captionTarget,
    required this.index,
    required this.child,
    super.key,
  });

  final JiabuStackItemKind kind;
  final JiabuCaptionTarget? captionTarget;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
