import 'package:flutter/material.dart';
import 'package:jiabu_design/src/theme_context.dart';
import 'package:jiabu_design/src/tokens/spacing.dart';

class JiabuSectionHeader extends StatelessWidget {
  const JiabuSectionHeader({required this.title, this.trailing, super.key});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(
      top: JiabuSpacing.sectionTop,
      bottom: JiabuSpacing.sectionBottom,
    ),
    child: Row(
      children: [
        Expanded(child: Text(title, style: context.jiabu.type.sectionTitle)),
        ?trailing,
      ],
    ),
  );
}
