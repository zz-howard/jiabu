import 'package:flutter/material.dart';
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
    final body = context.jiabu.type.body;
    final theme = ChipTheme.of(context).copyWith(
      selectedColor: colors.primarySoft,
      secondarySelectedColor: colors.primarySoft,
      checkmarkColor: colors.onPrimarySoft,
      showCheckmark: true,
      // Chip merges labelStyle before resolving it, so a WidgetStateTextStyle
      // drops the font family; only the colour may be state-dependent.
      labelStyle: body.copyWith(
        color: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colors.onPrimarySoft
              : colors.ink,
        ),
      ),
      secondaryLabelStyle: body.copyWith(color: colors.onPrimarySoft),
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
