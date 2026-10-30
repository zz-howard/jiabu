import 'package:flutter/material.dart';
import 'package:jiabu_design/src/theme_context.dart';

class JiabuSectionHeader extends StatelessWidget {
  const JiabuSectionHeader({
    required this.title,
    this.trailing,
    this.highlighted = false,
    super.key,
  });
  final String title;
  final Widget? trailing;

  /// Lower-half highlighter under the title text (design-spec 2.2, the
  /// original overview's 「用途账户」). Follows every wrapped line.
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final style = context.jiabu.type.sectionTitle;
    final text = Text(title, style: style);
    return Row(
      children: [
        Expanded(
          child: highlighted
              ? CustomPaint(
                  key: const Key('jiabu-section-highlight'),
                  painter: TextMarkerPainter(
                    text: title,
                    style: DefaultTextStyle.of(context).style.merge(style),
                    scaler: MediaQuery.textScalerOf(context),
                    direction: Directionality.of(context),
                    color: context.jiabu.colors.highlight,
                  ),
                  child: text,
                )
              : text,
        ),
        ?trailing,
      ],
    );
  }
}

/// Text with the same lower-half highlighter as a highlighted section title,
/// following every wrapped line (design-spec 4.10: the follow-up question).
class HighlightedText extends StatelessWidget {
  const HighlightedText(this.text, {required this.style, super.key});
  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => CustomPaint(
    key: const Key('jiabu-text-highlight'),
    painter: TextMarkerPainter(
      text: text,
      style: DefaultTextStyle.of(context).style.merge(style),
      scaler: MediaQuery.textScalerOf(context),
      direction: Directionality.of(context),
      color: context.jiabu.colors.highlight,
    ),
    child: Text(text, style: style),
  );
}

/// Paints the 55%–95% band of every line box of [text], laid out exactly like
/// the [Text] it sits behind, so the marker hugs the words instead of the
/// full row width and follows wrapped lines at large text sizes.
class TextMarkerPainter extends CustomPainter {
  const TextMarkerPainter({
    required this.text,
    required this.style,
    required this.scaler,
    required this.direction,
    required this.color,
  });
  final String text;
  final TextStyle style;
  final TextScaler scaler;
  final TextDirection direction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: direction,
      textScaler: scaler,
    )..layout(maxWidth: size.width);
    final paint = Paint()..color = color;
    for (final box in painter.getBoxesForSelection(
      TextSelection(baseOffset: 0, extentOffset: text.length),
    )) {
      final rect = box.toRect();
      canvas.drawRect(
        Rect.fromLTRB(
          rect.left - _bleedStart,
          rect.top + rect.height * .55,
          rect.right + _bleedEnd,
          rect.top + rect.height * .95,
        ),
        paint,
      );
    }
    painter.dispose();
  }

  static const _bleedStart = 2.0;
  static const _bleedEnd = 3.0;

  @override
  bool shouldRepaint(TextMarkerPainter oldDelegate) =>
      text != oldDelegate.text ||
      style != oldDelegate.style ||
      scaler != oldDelegate.scaler ||
      direction != oldDelegate.direction ||
      color != oldDelegate.color;
}
