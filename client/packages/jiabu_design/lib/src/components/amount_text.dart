import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:jiabu_design/src/theme_context.dart';
import 'package:jiabu_design/src/tokens/type.dart';

enum AmountRole { hero, detail, record, balance, list, inline }

/// How an amount is coloured.
///
/// `auto` is for balances: below zero it turns red (a warning), otherwise the
/// role's own ink. `plain` is for signed *movements*: an expense shows its
/// minus sign in the ordinary ink and is never red, because money going out is
/// normal. `positive` is money coming in (green, usually with `showPlus`).
enum AmountTone { auto, plain, positive }

/// Amounts enter as integer minor units, never binary floating point.
class AmountText extends StatelessWidget {
  const AmountText({
    required this.minorUnits,
    required this.semanticLabel,
    this.role = AmountRole.record,
    this.highlighted = false,
    this.tone = AmountTone.auto,
    this.showPlus = false,
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
  final AmountTone tone;
  final bool showPlus;
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
    // Hero, detail and record amounts are the "ink pen" numbers (primary text);
    // balances and list rows are plain ink, like the original design.
    final roleColor = switch (role) {
      AmountRole.hero ||
      AmountRole.detail ||
      AmountRole.record => context.jiabu.colors.primaryText,
      _ => context.jiabu.colors.ink,
    };
    final color = switch (tone) {
      AmountTone.positive => context.jiabu.colors.pos,
      AmountTone.plain => roleColor,
      AmountTone.auto => minorUnits < 0 ? context.jiabu.colors.neg : roleColor,
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
    final text = Text.rich(
      TextSpan(
        children: [
          // The word joiner keeps the sign on the same line as the digits when
          // a large text size forces the amount to wrap.
          if (minorUnits < 0)
            const TextSpan(text: '−\u2060')
          else if (showPlus && minorUnits > 0)
            const TextSpan(text: '+\u2060'),
          TextSpan(text: currencySymbol, style: small),
          TextSpan(text: whole),
          if (decimalDigits != 0)
            TextSpan(text: '$decimalSeparator$decimals', style: small),
        ],
      ),
      textAlign: TextAlign.right,
      style: style.copyWith(
        color: color,
        fontFamilyFallback: const [JiabuType.systemSansFamily],
        fontFeatures: const [ui.FontFeature.tabularFigures()],
      ),
    );
    return Semantics(
      label: semanticLabel,
      child: ExcludeSemantics(
        child: highlighted
            ? CustomPaint(
                painter: _HighlightPainter(context.jiabu.colors.highlight),
                child: Padding(
                  padding: const EdgeInsets.only(left: 2, right: 6),
                  child: text,
                ),
              )
            : text,
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
