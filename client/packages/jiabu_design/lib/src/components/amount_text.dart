import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:jiabu_design/src/theme_context.dart';
import 'package:jiabu_design/src/tokens/type.dart';

enum AmountRole { hero, detail, record, balance, list, inline }

/// Amounts enter as integer minor units, never binary floating point.
class AmountText extends StatelessWidget {
  const AmountText({
    required this.minorUnits,
    required this.semanticLabel,
    this.role = AmountRole.record,
    this.highlighted = false,
    this.currencySymbol = '¥',
    this.decimalDigits = 2,
    this.groupSeparator = ',',
    this.decimalSeparator = '.',
    super.key,
  });

  final int minorUnits;
  final String semanticLabel;
  final AmountRole role;
  final bool highlighted;
  final String currencySymbol;
  final String groupSeparator;
  final String decimalSeparator;
  final int decimalDigits;

  @override
  Widget build(BuildContext context) {
    final t = context.jiabu.type;
    final style = switch (role) {
      AmountRole.hero => t.heroAmount,
      AmountRole.detail => t.detailAmount,
      AmountRole.record => t.recordAmount,
      AmountRole.balance => t.balanceAmount,
      AmountRole.list => t.listAmount,
      AmountRole.inline => t.inlineAmount,
    };
    final magnitude = minorUnits.abs();
    final scale = decimalDigits == 0 ? 1 : 100;
    final whole = (magnitude ~/ scale).toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (match) => '${match[1]}$groupSeparator\u200B',
    );
    final decimals = (magnitude % 100).toString().padLeft(2, '0');
    final factor = role == AmountRole.list ? .72 : .55;
    final small = style.copyWith(
      fontSize: math.max(12, (style.fontSize ?? 40) * factor),
    );
    return Semantics(
      label: semanticLabel,
      child: ExcludeSemantics(
        child: CustomPaint(
          painter: highlighted
              ? _HighlightPainter(context.jiabu.colors.highlight)
              : null,
          child: Text.rich(
            TextSpan(
              children: [
                if (minorUnits < 0) const TextSpan(text: '−'),
                TextSpan(text: currencySymbol, style: small),
                TextSpan(text: whole),
                if (decimalDigits != 0)
                  TextSpan(text: '$decimalSeparator$decimals', style: small),
              ],
            ),
            textAlign: TextAlign.right,
            style: style.copyWith(
              color: minorUnits < 0
                  ? context.jiabu.colors.neg
                  : context.jiabu.colors.primaryText,
              fontFamilyFallback: const [JiabuType.systemSansFamily],
              fontFeatures: const [ui.FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }
}

class _HighlightPainter extends CustomPainter {
  const _HighlightPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) => canvas.drawRect(
    Rect.fromLTWH(0, size.height * .55, size.width, size.height * .4),
    Paint()..color = color,
  );
  @override
  bool shouldRepaint(_HighlightPainter oldDelegate) =>
      color != oldDelegate.color;
}
