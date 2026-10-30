import 'package:flutter/material.dart';
import 'package:jiabu_design/src/tokens/spacing.dart';

enum JiabuStackItemKind { content, section, caption, action }

@immutable
class JiabuStackItem {
  const JiabuStackItem.content({required this.child})
    : kind = JiabuStackItemKind.content,
      actionCaption = null,
      captionAfter = false;

  const JiabuStackItem.section({required this.child})
    : kind = JiabuStackItemKind.section,
      actionCaption = null,
      captionAfter = false;

  const JiabuStackItem.caption({required this.child})
    : kind = JiabuStackItemKind.caption,
      actionCaption = null,
      captionAfter = false;

  const JiabuStackItem.action({
    required this.child,
    this.actionCaption,
    this.captionAfter = false,
  }) : kind = JiabuStackItemKind.action;

  final Widget child;
  final JiabuStackItemKind kind;
  final Widget? actionCaption;
  final bool captionAfter;
}

class JiabuStack extends StatelessWidget {
  const JiabuStack({
    required this.children,
    this.mainAxisAlignment = MainAxisAlignment.start,
    super.key,
  });

  final List<JiabuStackItem> children;
  final MainAxisAlignment mainAxisAlignment;

  @override
  Widget build(BuildContext context) {
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
          index: index,
          child: child,
        ),
      );
    }
    return Column(
      key: const Key('jiabu-stack'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: mainAxisAlignment,
      children: widgets,
    );
  }

  static double _gap(JiabuStackItem current, JiabuStackItem next) {
    if (next.kind == JiabuStackItemKind.section) {
      return JiabuSpacing.sectionTop;
    }
    if (next.kind == JiabuStackItemKind.action) {
      return JiabuSpacing.actionGap;
    }
    if (current.kind == JiabuStackItemKind.section) {
      return JiabuSpacing.sectionBottom;
    }
    if (next.kind == JiabuStackItemKind.caption) {
      return JiabuSpacing.captionGap;
    }
    return JiabuSpacing.cardGap;
  }
}

class JiabuStackMarker extends StatelessWidget {
  const JiabuStackMarker({
    required this.kind,
    required this.index,
    required this.child,
    super.key,
  });

  final JiabuStackItemKind kind;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
