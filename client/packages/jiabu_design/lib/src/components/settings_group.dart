import 'package:flutter/material.dart';
import 'package:jiabu_design/src/components/paper_background.dart';
import 'package:jiabu_design/src/geometry/paper.dart';
import 'package:jiabu_design/src/theme_context.dart';

class JiabuSettingsGroup extends StatelessWidget {
  const JiabuSettingsGroup({required this.children, super.key});
  static const PaperPattern? paperPattern = null;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        for (var index = 0; index < children.length; index++) ...[
          children[index],
          if (index + 1 < children.length)
            Divider(height: 1, color: context.jiabu.colors.line),
        ],
      ],
    );
    return DecoratedBox(
      key: const Key('jiabu-settings-group'),
      decoration: BoxDecoration(
        color: context.jiabu.colors.paper,
        borderRadius: BorderRadius.circular(context.jiabu.decor.cardRadius),
        border: Border.all(color: context.jiabu.colors.line),
      ),
      child: paperPattern == null
          ? content
          : PaperBackground(pattern: paperPattern!, child: content),
    );
  }
}
