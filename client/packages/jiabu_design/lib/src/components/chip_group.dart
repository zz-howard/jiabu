import 'package:flutter/material.dart';
import 'package:jiabu_design/src/components/jiabu_icon.dart';
import 'package:jiabu_design/src/icons/jiabu_icons.g.dart';
import 'package:jiabu_design/src/theme_context.dart';
import 'package:jiabu_design/src/tokens/spacing.dart';

class JiabuChipGroup extends StatelessWidget {
  const JiabuChipGroup({
    required this.children,
    this.alignment = WrapAlignment.start,
    this.crossAxisAlignment = WrapCrossAlignment.start,
    super.key,
  });

  final List<Widget> children;
  final WrapAlignment alignment;
  final WrapCrossAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final colors = context.jiabu.colors;
    final theme = ChipTheme.of(context).copyWith(
      selectedColor: colors.primarySoft,
      secondarySelectedColor: colors.primarySoft,
      checkmarkColor: colors.onPrimarySoft,
      showCheckmark: true,
      labelStyle: WidgetStateTextStyle.resolveWith(
        (states) => TextStyle(
          color: states.contains(WidgetState.selected)
              ? colors.onPrimarySoft
              : colors.ink,
        ),
      ),
      secondaryLabelStyle: TextStyle(color: colors.onPrimarySoft),
      side: WidgetStateBorderSide.resolveWith(
        (states) => BorderSide(
          color: states.contains(WidgetState.selected)
              ? colors.white
              : colors.lineStrong,
          width: states.contains(WidgetState.selected) ? 2 : 1,
        ),
      ),
      shape: const StadiumBorder(),
    );
    return ChipTheme(
      data: theme,
      child: Wrap(
        key: const Key('jiabu-chip-group'),
        spacing: JiabuSpacing.sm,
        runSpacing: JiabuSpacing.sm,
        alignment: alignment,
        crossAxisAlignment: crossAxisAlignment,
        children: [
          for (var index = 0; index < children.length; index++)
            JiabuChipGroupMarker(index: index, child: children[index]),
        ],
      ),
    );
  }
}

class JiabuChipGroupMarker extends StatelessWidget {
  const JiabuChipGroupMarker({
    required this.index,
    required this.child,
    super.key,
  });

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

class JiabuOptionChip extends StatelessWidget {
  const JiabuOptionChip({
    required this.label,
    required this.selected,
    required this.onPressed,
    super.key,
  });

  final Widget label;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.jiabu.colors;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: selected ? colors.primarySoft : colors.paper,
        foregroundColor: selected ? colors.onPrimarySoft : colors.ink,
        side: BorderSide(
          color: selected ? colors.white : colors.lineStrong,
          width: selected ? 2 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selected) ...[
            JiabuIcon(
              JiabuIcons.uiCheck,
              size: JiabuSpacing.lg,
              color: colors.onPrimarySoft,
            ),
            const SizedBox(width: JiabuSpacing.xs),
          ],
          Flexible(child: label),
        ],
      ),
    );
  }
}
