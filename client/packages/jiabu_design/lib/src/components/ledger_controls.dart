import 'package:flutter/material.dart';
import 'package:jiabu_design/src/components/hand_circle.dart';
import 'package:jiabu_design/src/components/hand_text.dart';
import 'package:jiabu_design/src/components/jiabu_icon.dart';
import 'package:jiabu_design/src/components/tape.dart';
import 'package:jiabu_design/src/components/tilt.dart';
import 'package:jiabu_design/src/icons/icon_data.dart';
import 'package:jiabu_design/src/icons/jiabu_icons.g.dart';
import 'package:jiabu_design/src/theme_context.dart';
import 'package:jiabu_design/src/tokens/ledger_metrics.dart';
import 'package:jiabu_design/src/tokens/spacing.dart';

class ManualEntryButton extends StatelessWidget {
  const ManualEntryButton({
    required this.label,
    required this.semanticLabel,
    required this.onPressed,
    super.key,
  });
  final String label;
  final String semanticLabel;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel,
    button: true,
    enabled: onPressed != null,
    onTap: onPressed,
    child: ExcludeSemantics(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(JiabuLedgerMetrics.manualHeight),
          boxShadow: context.jiabu.decor.stickerShadow,
        ),
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            minimumSize: const Size(
              JiabuLedgerMetrics.actionExtent,
              JiabuLedgerMetrics.manualHeight,
            ),
            side: BorderSide(
              color: context.jiabu.colors.onPrimary,
              width: JiabuLedgerMetrics.manualBorder,
            ),
            textStyle: context.jiabu.type.listTitle,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const JiabuIcon(
                JiabuIcons.uiPlus,
                size: JiabuLedgerMetrics.manualIcon,
              ),
              SizedBox(width: context.jiabu.decor.cardGap),
              Text(label),
            ],
          ),
        ),
      ),
    ),
  );
}

class SpaceHeading extends StatelessWidget {
  const SpaceHeading({
    required this.name,
    required this.accent,
    this.style,
    super.key,
  });
  final String name;
  final Color accent;
  final TextStyle? style;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      ExcludeSemantics(
        child: Container(
          width: JiabuLedgerMetrics.spaceDot,
          height: JiabuLedgerMetrics.spaceDot,
          decoration: BoxDecoration(
            color: accent,
            shape: BoxShape.circle,
            border: Border.all(color: context.jiabu.colors.paper),
          ),
        ),
      ),
      SizedBox(width: context.jiabu.decor.cardGap),
      Expanded(
        child: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: (style ?? context.jiabu.type.listTitle).copyWith(
            color: accent,
          ),
        ),
      ),
    ],
  );
}

class PaperBottomNavigation extends StatelessWidget {
  const PaperBottomNavigation({
    required this.labels,
    required this.selected,
    required this.onSelect,
    super.key,
  });
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;

  /// Tab icons in order: chat, overview, history, me (settings).
  static const icons = <JiabuIconData>[
    JiabuIcons.uiChat,
    JiabuIcons.uiDash,
    JiabuIcons.uiHistory,
    JiabuIcons.uiUser,
  ];
  @override
  Widget build(BuildContext context) => ClipPath(
    clipper: const _NavigationEdgeClipper(),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: context.jiabu.colors.paper,
        border: Border(top: BorderSide(color: context.jiabu.colors.line)),
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: JiabuLedgerMetrics.navigationHeight,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < labels.length; i++)
                Expanded(
                  child: Semantics(
                    selected: i == selected,
                    button: true,
                    child: InkWell(
                      onTap: () => onSelect(i),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: context.jiabu.decor.cardGap,
                          vertical: context.jiabu.decor.messageGap,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (i == selected)
                              HandCircle(
                                child: JiabuIcon(
                                  icons[i],
                                  size: JiabuLedgerMetrics.navigationIcon,
                                ),
                              )
                            else
                              Padding(
                                padding: EdgeInsets.all(
                                  context.jiabu.decor.cardGap,
                                ),
                                child: JiabuIcon(
                                  icons[i],
                                  size: JiabuLedgerMetrics.navigationIcon,
                                ),
                              ),
                            // Four tabs share the width: at large text
                            // sizes a long label shrinks to its column
                            // instead of wrapping and growing the bar.
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                labels[i],
                                maxLines: 1,
                                textAlign: TextAlign.center,
                                style: context.jiabu.type.badge.copyWith(
                                  color: i == selected
                                      ? context.jiabu.colors.primaryText
                                      : context.jiabu.colors.ink2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class PaperFilterChip extends StatelessWidget {
  const PaperFilterChip({
    required this.label,
    required this.selected,
    required this.onPressed,
    super.key,
  });
  final String label;
  final bool selected;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => FilterChip(
    label: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (selected) ...[
          ExcludeSemantics(
            child: JiabuIcon(
              JiabuIcons.uiCheck,
              size: JiabuLedgerMetrics.meIcon,
              color: context.jiabu.colors.onPrimarySoft,
            ),
          ),
          const SizedBox(width: JiabuSpacing.xs),
        ],
        Text(label),
      ],
    ),
    selected: selected,
    onSelected: (_) => onPressed(),
    selectedColor: context.jiabu.colors.primarySoft,
    side: BorderSide(
      color: selected
          ? context.jiabu.colors.white
          : context.jiabu.colors.lineStrong,
      width: selected ? JiabuLedgerMetrics.manualBorder : 1,
    ),
    showCheckmark: false,
    shape: selected
        ? RoundedRectangleBorder(
            side: BorderSide(
              color: context.jiabu.colors.white,
              width: JiabuLedgerMetrics.manualBorder,
            ),
            borderRadius: BorderRadius.circular(context.jiabu.decor.chipRadius),
          )
        : PaperDashedBorder(
            radius: context.jiabu.decor.chipRadius,
            side: BorderSide(color: context.jiabu.colors.lineStrong),
          ),
  );
}

class NegativeBalanceNote extends StatelessWidget {
  const NegativeBalanceNote({
    required this.title,
    required this.body,
    this.action,
    super.key,
  });
  final String title;
  final String body;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      Container(
        padding: EdgeInsets.all(context.jiabu.decor.cardInset),
        decoration: BoxDecoration(
          color: context.jiabu.colors.alert,
          borderRadius: BorderRadius.circular(context.jiabu.decor.noteRadius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: context.jiabu.type.listTitle.copyWith(
                color: context.jiabu.colors.neg,
              ),
            ),
            Text(body, style: context.jiabu.type.secondary),
            SizedBox(height: context.jiabu.decor.cardGap),
            ?action,
          ],
        ),
      ),
      Positioned(
        top: -context.jiabu.decor.messageGap,
        left: context.jiabu.decor.cardGap,
        child: ExcludeSemantics(
          child: Tilt(
            degrees: JiabuLedgerMetrics.noteClipTilt,
            child: JiabuIcon(
              JiabuIcons.doodleClip,
              color: context.jiabu.colors.ink3,
            ),
          ),
        ),
      ),
    ],
  );
}

class DottedFieldRow extends StatelessWidget {
  const DottedFieldRow({required this.label, required this.value, super.key});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(vertical: context.jiabu.decor.messageGap),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: context.jiabu.type.caption),
        Text(value, style: context.jiabu.type.body),
        SizedBox(
          height: context.jiabu.decor.messageGap,
          child: CustomPaint(
            painter: _DottedRulePainter(context.jiabu.colors.lineStrong),
          ),
        ),
      ],
    ),
  );
}

/// Exact 4.21 offsets are measured from the top of the bottom navigation.
class ManualEntryLocation extends FloatingActionButtonLocation {
  const ManualEntryLocation();
  @override
  Offset getOffset(ScaffoldPrelayoutGeometry geometry) => Offset(
    geometry.scaffoldSize.width -
        geometry.floatingActionButtonSize.width -
        JiabuLedgerMetrics.manualInset,
    geometry.contentBottom -
        geometry.floatingActionButtonSize.height -
        JiabuLedgerMetrics.manualInset,
  );
}

/// Dashed chip outline; kept in the design package, never painted in views.
class PaperDashedBorder extends OutlinedBorder {
  const PaperDashedBorder({required this.radius, super.side});
  final double radius;
  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);
  @override
  PaperDashedBorder copyWith({BorderSide? side}) =>
      PaperDashedBorder(radius: radius, side: side ?? this.side);
  @override
  ShapeBorder scale(double t) =>
      PaperDashedBorder(radius: radius * t, side: side.scale(t));
  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect.deflate(side.width), textDirection: textDirection);
  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final paint = Paint()
      ..color = side.color
      ..strokeWidth = side.width
      ..style = PaintingStyle.stroke;
    for (final metric in getOuterPath(
      rect.deflate(side.width / 2),
    ).computeMetrics()) {
      for (var offset = 0.0; offset < metric.length; offset += 8) {
        canvas.drawPath(
          metric.extractPath(
            offset,
            (offset + 4).clamp(0, metric.length).toDouble(),
          ),
          paint,
        );
      }
    }
  }
}

class _DottedRulePainter extends CustomPainter {
  const _DottedRulePainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (var x = 0.0; x < size.width; x += 4) {
      canvas.drawCircle(Offset(x, size.height / 2), 0.7, paint);
    }
  }

  @override
  bool shouldRepaint(_DottedRulePainter oldDelegate) =>
      oldDelegate.color != color;
}

class DateTapeLabel extends StatelessWidget {
  const DateTapeLabel({required this.text, required this.pattern, super.key});
  final String text;
  final TapePattern pattern;
  @override
  Widget build(BuildContext context) => Tilt(
    degrees: context.jiabu.decor.dateTilt,
    child: Stack(
      children: [
        Positioned.fill(child: Tape(degrees: 0, pattern: pattern)),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.jiabu.decor.cardGap,
            vertical: context.jiabu.decor.messageGap,
          ),
          child: HandText(text),
        ),
      ],
    ),
  );
}

class _NavigationEdgeClipper extends CustomClipper<Path> {
  const _NavigationEdgeClipper();
  @override
  Path getClip(Size size) {
    const radius = 4.0;
    final path = Path()..moveTo(0, radius);
    for (var x = 0.0; x < size.width; x += radius * 2) {
      path.quadraticBezierTo(x + radius, -radius, x + radius * 2, radius);
    }
    return path
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(_NavigationEdgeClipper oldClipper) => false;
}

/// Keeps tile ink above the decorated paper underneath it.
class PaperRow extends StatelessWidget {
  const PaperRow({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Material(type: MaterialType.transparency, child: child);
}

/// A record's key/value pair shares a text baseline with its dotted leader.
class DottedValueRow extends StatelessWidget {
  const DottedValueRow({
    required this.label,
    required this.value,
    this.negative = false,
    this.primary = false,
    super.key,
  });

  final String label;
  final String value;
  final bool negative;
  final bool primary;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(
      minHeight: context.jiabu.decor.valueRowMinHeight,
    ),
    child: LayoutBuilder(
      builder: (context, constraints) => Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth * .45),
            child: Text(label, style: context.jiabu.type.secondary),
          ),
          Expanded(
            child: ExcludeSemantics(
              child: Text(
                '· ' * 100,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.clip,
                style: context.jiabu.type.secondary.copyWith(
                  color: context.jiabu.colors.lineStrong,
                ),
              ),
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth * .45),
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: context.jiabu.type.secondary.copyWith(
                color: negative
                    ? context.jiabu.colors.neg
                    : primary
                    ? context.jiabu.colors.primaryText
                    : context.jiabu.colors.ink,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// The 4.6 action has a solid white edge and an inset dashed white edge.
class BalanceNoteButton extends StatelessWidget {
  const BalanceNoteButton({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: _NoteButtonEdge(context.jiabu.colors.white),
    child: FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(
          JiabuLedgerMetrics.actionExtent,
          JiabuLedgerMetrics.noteActionHeight,
        ),
        side: BorderSide(
          color: context.jiabu.colors.white,
          width: JiabuLedgerMetrics.manualBorder,
        ),
      ),
      child: Text(label),
    ),
  );
}

class _NoteButtonEdge extends CustomPainter {
  const _NoteButtonEdge(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const border = PaperDashedBorder(
      radius: JiabuLedgerMetrics.noteActionHeight,
    );
    border
        .copyWith(side: BorderSide(color: color))
        .paint(canvas, (Offset.zero & size).deflate(6));
  }

  @override
  bool shouldRepaint(_NoteButtonEdge oldDelegate) => color != oldDelegate.color;
}
