import 'package:flutter/material.dart';

import 'package:jiabu_design/src/components/jiabu_icon.dart';
import 'package:jiabu_design/src/components/ledger_controls.dart';
import 'package:jiabu_design/src/components/tilt.dart';
import 'package:jiabu_design/src/icons/icon_data.dart';
import 'package:jiabu_design/src/icons/jiabu_icons.g.dart';
import 'package:jiabu_design/src/theme_context.dart';
import 'package:jiabu_design/src/tokens/chat_metrics.dart';

/// The assistant's round seal in front of its name (design-spec 4.9): a
/// primary disc with a hand-drawn star, white ring, sticker shadow, −10°.
/// Pure decoration; the name next to it is what screen readers hear.
class ChatAvatarSeal extends StatelessWidget {
  const ChatAvatarSeal({super.key});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Tilt(
      degrees: JiabuChatMetrics.avatarTilt,
      child: Container(
        width: JiabuChatMetrics.avatar,
        height: JiabuChatMetrics.avatar,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: context.jiabu.colors.primary,
          shape: BoxShape.circle,
          border: Border.all(
            color: context.jiabu.colors.white,
            width: JiabuChatMetrics.avatarRing,
          ),
          boxShadow: context.jiabu.decor.stickerShadow,
        ),
        child: JiabuIcon(
          JiabuIcons.doodleStar,
          size: JiabuChatMetrics.avatarGlyph,
          color: context.jiabu.colors.onPrimary,
        ),
      ),
    ),
  );
}

/// One answer capsule under a follow-up question (design-spec 4.10): white,
/// 44 high, fully rounded, 1.5 line-strong ring, alternating −1° / +0.8°.
/// Selected: primary-soft with a ✓ and a white sticker ring. [other] is the
/// trailing 「输入其他内容」 entry: dashed ring, pencil, 0° (an action, not a
/// paper scrap). A null [onPressed] disables it; [dimmed] is the
/// half-transparent look of the options that were not chosen.
class ChatOptionPill extends StatelessWidget {
  const ChatOptionPill({
    required this.label,
    required this.index,
    this.selected = false,
    this.dimmed = false,
    this.other = false,
    this.onPressed,
    super.key,
  });
  final String label;
  final int index;
  final bool selected;
  final bool dimmed;
  final bool other;
  final VoidCallback? onPressed;

  /// −1° for the 1st, 3rd… pill, +0.8° for the 2nd, 4th…; the other-input
  /// entry is never tilted.
  static double tiltFor(BuildContext context, int index, {bool other = false}) {
    if (other) return 0;
    final decor = context.jiabu.decor;
    return index.isEven ? decor.answerOddTilt : decor.answerEvenTilt;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.jiabu.colors;
    final ring = other
        ? PaperDashedBorder(
            radius: JiabuChatMetrics.option / 2,
            side: BorderSide(
              color: colors.lineStrong,
              width: JiabuChatMetrics.optionRing,
            ),
          )
        : StadiumBorder(
            side: BorderSide(
              color: selected ? colors.white : colors.lineStrong,
              width: selected
                  ? JiabuChatMetrics.optionSelectedRing
                  : JiabuChatMetrics.optionRing,
            ),
          );
    final ink = selected
        ? colors.onPrimarySoft
        : other
        ? colors.ink2
        : colors.ink;
    final style = context.jiabu.type.body.copyWith(
      fontSize: 14,
      height: 1.3,
      fontWeight: other ? FontWeight.w400 : FontWeight.w600,
      color: ink,
    );
    Widget pill = DecoratedBox(
      decoration: ShapeDecoration(
        color: selected ? colors.primarySoft : colors.white,
        shape: ring,
        shadows: other ? null : context.jiabu.decor.stickerShadow,
      ),
      child: Material(
        type: MaterialType.transparency,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: JiabuChatMetrics.option,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: JiabuChatMetrics.optionInset,
                vertical: 6,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (selected || other) ...[
                    ExcludeSemantics(
                      child: JiabuIcon(
                        other ? JiabuIcons.doodlePencil : JiabuIcons.uiCheck,
                        size: JiabuChatMetrics.icon,
                        color: ink,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Flexible(child: Text(label, style: style)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (dimmed) pill = Opacity(opacity: .5, child: pill);
    return Semantics(
      button: true,
      selected: selected,
      enabled: onPressed != null,
      child: Tilt(
        degrees: tiltFor(context, index, other: other),
        child: pill,
      ),
    );
  }
}

/// A 48 round paper button with a white sticker ring (the composer's camera
/// button, design-spec 4.17b).
class PaperRoundButton extends StatelessWidget {
  const PaperRoundButton({
    required this.icon,
    required this.label,
    this.onPressed,
    super.key,
  });
  final JiabuIconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.jiabu.colors;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.paper,
            shape: BoxShape.circle,
            border: Border.all(
              color: colors.white,
              width: JiabuChatMetrics.roundRing,
            ),
            boxShadow: context.jiabu.decor.stickerShadow,
          ),
          child: Material(
            type: MaterialType.transparency,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              child: SizedBox.square(
                dimension: JiabuChatMetrics.action,
                child: Center(
                  child: JiabuIcon(
                    icon,
                    color: onPressed == null ? colors.ink3 : colors.ink2,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The composer's text field as a small floating paper card (design-spec
/// 4.17b): paper, radius 12, hairline ring and a soft shadow, a pencil in
/// front of the text and one ruled line under it. Locked (4.18): surface-2
/// with a 1.5 dashed line-strong ring and no shadow.
class PaperComposerField extends StatelessWidget {
  const PaperComposerField({
    required this.child,
    this.locked = false,
    this.trailing,
    super.key,
  });
  final Widget child;
  final bool locked;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.jiabu.colors;
    const radius = JiabuChatMetrics.fieldRadius;
    final decoration = locked
        ? ShapeDecoration(
            color: colors.surface2,
            shape: PaperDashedBorder(
              radius: radius,
              side: BorderSide(
                color: colors.lineStrong,
                width: JiabuChatMetrics.optionRing,
              ),
            ),
          )
        : ShapeDecoration(
            color: colors.paper,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius),
              side: BorderSide(color: colors.line),
            ),
            shadows: [
              BoxShadow(
                color: colors.shadowInk.withValues(alpha: .12),
                offset: const Offset(0, 1),
                blurRadius: 2,
              ),
            ],
          );
    return DecoratedBox(
      key: const Key('paper-composer-field'),
      decoration: decoration,
      child: CustomPaint(
        painter: locked ? null : _FieldRulePainter(colors.rule),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: JiabuChatMetrics.fieldHeight,
          ),
          child: Padding(
            padding: EdgeInsets.only(
              left: 12,
              right: trailing == null ? 12 : 2,
            ),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: JiabuIcon(
                    JiabuIcons.doodlePencil,
                    size: JiabuChatMetrics.pencil,
                    color: colors.ink3,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(child: child),
                ?trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One ruled line 16 above the field's bottom edge, under the text.
class _FieldRulePainter extends CustomPainter {
  const _FieldRulePainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height - 15.5;
    canvas.drawLine(
      Offset(12 + JiabuChatMetrics.pencil + 6, y),
      Offset(size.width - 12, y),
      Paint()
        ..color = color
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_FieldRulePainter oldDelegate) =>
      oldDelegate.color != color;
}
