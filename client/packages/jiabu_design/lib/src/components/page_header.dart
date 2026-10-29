import 'package:flutter/material.dart';
import 'package:jiabu_design/src/components/jiabu_icon.dart';
import 'package:jiabu_design/src/icons/jiabu_icons.g.dart';
import 'package:jiabu_design/src/theme_context.dart';
import 'package:jiabu_design/src/tokens/spacing.dart';

class JiabuPageHeader extends StatelessWidget {
  const JiabuPageHeader({
    required this.title,
    this.onBack,
    this.action,
    this.showBack = true,
    super.key,
  });

  final String title;
  final VoidCallback? onBack;
  final Widget? action;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final handleBack = onBack ?? () => Navigator.maybePop(context);
    return ColoredBox(
      color: context.jiabu.colors.bg,
      child: Padding(
        key: const Key('jiabu-page-header-padding'),
        padding: EdgeInsets.symmetric(horizontal: context.jiabu.spacing.page),
        child: LayoutBuilder(
          builder: (context, constraints) => ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: JiabuSpacing.listRowMinHeight,
            ),
            child: Row(
              children: [
                if (showBack)
                  Semantics(
                    button: true,
                    excludeSemantics: true,
                    label: MaterialLocalizations.of(context).backButtonTooltip,
                    onTap: handleBack,
                    child: Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        onTap: handleBack,
                        child: const SizedBox(
                          key: Key('jiabu-page-back'),
                          width: JiabuSpacing.minTapTarget,
                          height: JiabuSpacing.minTapTarget,
                          child: Center(
                            child: JiabuIcon(JiabuIcons.uiRight, flipX: true),
                          ),
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.jiabu.type.pageTitle,
                  ),
                ),
                if (action case final action?)
                  ConstrainedBox(
                    key: const Key('jiabu-page-action'),
                    constraints: BoxConstraints(
                      maxWidth: constraints.maxWidth / 2,
                    ),
                    child: action,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
