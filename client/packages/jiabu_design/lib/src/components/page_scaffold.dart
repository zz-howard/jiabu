import 'package:flutter/material.dart';
import 'package:jiabu_design/src/components/page_header.dart';
import 'package:jiabu_design/src/components/paper_background.dart';
import 'package:jiabu_design/src/theme_context.dart';

class JiabuPageScaffold extends StatelessWidget {
  const JiabuPageScaffold({
    required this.title,
    required this.body,
    this.onBack,
    this.action,
    this.showBack = true,
    this.handEnglish,
    this.subtitle,
    super.key,
  });

  final String title;
  final Widget body;
  final VoidCallback? onBack;
  final Widget? action;
  final bool showBack;
  final String? handEnglish;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.jiabu.colors.bg,
    child: Column(
      children: [
        JiabuPageHeader(
          title: title,
          onBack: onBack,
          action: action,
          showBack: showBack,
          handEnglish: handEnglish,
          subtitle: subtitle,
        ),
        Expanded(
          child: ClipRect(
            key: const Key('jiabu-page-body'),
            child: PaperBackground(child: body),
          ),
        ),
      ],
    ),
  );
}
