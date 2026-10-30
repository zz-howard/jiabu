import 'package:flutter/material.dart';
import 'package:jiabu_design/src/theme_context.dart';

class JiabuSectionHeader extends StatelessWidget {
  const JiabuSectionHeader({required this.title, this.trailing, super.key});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
      children: [
        Expanded(child: Text(title, style: context.jiabu.type.sectionTitle)),
        ?trailing,
      ],
    );
}
