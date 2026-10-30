import 'package:flutter/material.dart';
import 'package:jiabu_design/src/components/jiabu_icon.dart';
import 'package:jiabu_design/src/icons/jiabu_icons.g.dart';
import 'package:jiabu_design/src/theme_context.dart';
import 'package:jiabu_design/src/tokens/spacing.dart';

class JiabuListRow extends StatelessWidget {
  const JiabuListRow({
    required this.title,
    this.subtitle,
    this.subtitleMaxLines = 1,
    this.status,
    this.leading,
    this.value,
    this.valueWidget,
    this.supporting,
    this.supportingGap = JiabuSpacing.xs,
    this.trailing,
    this.showChevron = false,
    this.enabled = true,
    this.onTap,
    super.key,
  });

  final String title;
  final String? subtitle;
  final int? subtitleMaxLines;
  final String? status;
  final Widget? leading;
  final String? value;
  final Widget? valueWidget;
  final Widget? supporting;
  final double supportingGap;
  final Widget? trailing;
  final bool showChevron;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.jiabu.colors;
    final disabledInk = colors.ink.withValues(alpha: .38);
    final disabledSecondary = colors.ink2.withValues(alpha: .38);
    Widget faded(Widget child) =>
        enabled ? child : Opacity(opacity: .38, child: child);
    return Semantics(
      enabled: enabled,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: JiabuSpacing.listRowMinHeight,
        ),
        // Own transparent Material: ink must paint above the group's paper
        // fill and work on routes without a Scaffold.
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: enabled ? onTap : null,
            child: Padding(
              key: const Key('jiabu-list-row-padding'),
              padding: const EdgeInsets.symmetric(
                horizontal: JiabuSpacing.listRowInset,
                vertical: JiabuSpacing.sm,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final row = Row(
                    children: [
                      if (leading != null) ...[
                        faded(leading!),
                        const SizedBox(width: JiabuSpacing.md),
                      ],
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: context.jiabu.type.listTitle.copyWith(
                                color: enabled ? null : disabledInk,
                              ),
                            ),
                            if (subtitle != null)
                              Text(
                                subtitle!,
                                maxLines: subtitleMaxLines,
                                overflow: subtitleMaxLines == null
                                    ? TextOverflow.clip
                                    : TextOverflow.ellipsis,
                                style: context.jiabu.type.secondary.copyWith(
                                  color: enabled ? null : disabledSecondary,
                                ),
                              ),
                            if (status != null)
                              Text(
                                status!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.jiabu.type.secondary.copyWith(
                                  color: enabled ? null : disabledSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (value != null || valueWidget != null) ...[
                        const SizedBox(width: JiabuSpacing.md),
                        ConstrainedBox(
                          key: const Key('jiabu-list-row-value'),
                          constraints: BoxConstraints(
                            maxWidth: constraints.maxWidth / 2,
                          ),
                          child: Align(
                            alignment: Alignment.centerRight,
                            widthFactor: 1,
                            child: valueWidget != null
                                ? faded(valueWidget!)
                                : Text(
                                    value!,
                                    maxLines: 2,
                                    textAlign: TextAlign.end,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: enabled ? null : disabledInk,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                      if (trailing != null) ...[
                        const SizedBox(width: JiabuSpacing.sm),
                        faded(trailing!),
                      ] else if (showChevron) ...[
                        const SizedBox(width: JiabuSpacing.sm),
                        ExcludeSemantics(
                          child: JiabuIcon(
                            JiabuIcons.uiRight,
                            color: enabled ? null : disabledInk,
                          ),
                        ),
                      ],
                    ],
                  );
                  if (supporting == null) {
                    return row;
                  }
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      row,
                      SizedBox(height: supportingGap),
                      faded(supporting!),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
