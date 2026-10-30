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
    final scaler = MediaQuery.textScalerOf(context);
    final titleStyle = context.jiabu.type.pageTitle;
    final titleLineHeight =
        scaler.scale(titleStyle.fontSize ?? 0) * (titleStyle.height ?? 1);
    final backIconSize = scaler
        .scale(24) // The icon follows text, while the tap target stays >= 48.
        .clamp(24, 32)
        .toDouble();
    final backTargetHeight = titleLineHeight < JiabuSpacing.minTapTarget
        ? JiabuSpacing.minTapTarget
        : titleLineHeight;
    final backIconTop = (titleLineHeight - backIconSize) / 2;
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
              crossAxisAlignment: CrossAxisAlignment.start,
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
                        child: SizedBox(
                          key: const Key('jiabu-page-back'),
                          width: JiabuSpacing.minTapTarget,
                          height: backTargetHeight,
                          child: Padding(
                            padding: EdgeInsets.only(top: backIconTop),
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: JiabuIcon(
                                JiabuIcons.uiRight,
                                key: const Key('jiabu-page-back-icon'),
                                size: backIconSize,
                                flipX: true,
                              ),
                            ),
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
                    style: titleStyle,
                  ),
                ),
                if (action case final action?)
                  Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      key: const Key('jiabu-page-action'),
                      constraints: BoxConstraints(
                        maxWidth: constraints.maxWidth / 2,
                      ),
                      child: action,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
