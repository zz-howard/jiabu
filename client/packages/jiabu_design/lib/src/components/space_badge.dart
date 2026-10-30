import 'package:flutter/material.dart';
import 'package:jiabu_design/src/components/jiabu_icon.dart';
import 'package:jiabu_design/src/components/ledger_controls.dart';
import 'package:jiabu_design/src/components/tilt.dart';
import 'package:jiabu_design/src/icons/jiabu_icons.g.dart';
import 'package:jiabu_design/src/theme_context.dart';
import 'package:jiabu_design/src/tokens/ledger_metrics.dart';
import 'package:jiabu_design/src/tokens/spacing.dart';

/// The top-right badge of the main pages. In the original design this slot
/// held the 家庭 / 私人 switch; now it names the current space in that same
/// look: a solid, slightly tilted, white-ringed pill with an icon, sitting in
/// a dashed frame. A house means a shared space, a lock the personal one; the
/// pill's fill is the space's accent colour. Tapping opens the space sheet.
class SpaceBadge extends StatelessWidget {
  const SpaceBadge({
    required this.name,
    required this.accent,
    required this.personal,
    this.onTap,
    super.key,
  });

  final String name;
  final Color accent;
  final bool personal;
  final VoidCallback? onTap;

  static const double pillHeight = 44;
  static const double framePadding = 3;
  static const double frameRadius = 12;
  static const double pillRadius = 9;
  static const double badgeTilt = -2;

  @override
  Widget build(BuildContext context) {
    final colors = context.jiabu.colors;
    final pill = Tilt(
      degrees: badgeTilt,
      child: Container(
        height: pillHeight,
        padding: const EdgeInsetsDirectional.only(
          start: JiabuSpacing.sm,
          end: JiabuSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: accent,
          borderRadius: BorderRadius.circular(pillRadius),
          border: Border.all(
            color: colors.white,
            width: JiabuLedgerMetrics.manualBorder,
          ),
          boxShadow: context.jiabu.decor.stickerShadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            JiabuIcon(
              personal ? JiabuIcons.uiLock : JiabuIcons.uiFamily,
              size: 18,
              color: colors.onPrimary,
            ),
            const SizedBox(width: JiabuSpacing.xs),
            Flexible(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.jiabu.type.listTitle.copyWith(
                  color: colors.onPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: JiabuSpacing.xs),
              JiabuIcon(JiabuIcons.uiDown, size: 16, color: colors.onPrimary),
            ],
          ],
        ),
      ),
    );
    return Semantics(
      label: name,
      button: onTap != null,
      onTap: onTap,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: JiabuLedgerMetrics.actionExtent,
            ),
            child: Center(
              widthFactor: 1,
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: colors.paper.withValues(alpha: .7),
                  shape: PaperDashedBorder(
                    radius: frameRadius,
                    side: BorderSide(
                      color: colors.lineStrong,
                      width: JiabuLedgerMetrics.manualBorder * .75,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(framePadding),
                  child: pill,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
