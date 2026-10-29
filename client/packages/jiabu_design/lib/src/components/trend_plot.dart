import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:jiabu_design/src/theme_context.dart';
import 'package:jiabu_design/src/tokens/chat_metrics.dart';

/// Paint coordinates only. Values are formatted by the caller without a
/// floating-point money roundtrip. Gaps are preserved, never interpolated.
class JiabuTrendPlot extends StatelessWidget {
  const JiabuTrendPlot({required this.series, super.key});
  final List<List<double?>> series;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      height: JiabuChatMetrics.chartHeight,
      width: double.infinity,
      child: CustomPaint(
        painter: _TrendPainter(series, [
          context.jiabu.colors.chartLeft,
          context.jiabu.colors.chartRight,
        ], context.jiabu.colors.lineStrong),
      ),
    ),
  );
}

class _TrendPainter extends CustomPainter {
  const _TrendPainter(this.series, this.palette, this.axis);
  final List<List<double?>> series;
  final List<Color> palette;
  final Color axis;
  @override
  void paint(Canvas canvas, Size size) {
    final values = series
        .expand((points) => points)
        .whereType<double>()
        .where((value) => value.isFinite)
        .toList();
    if (values.isEmpty) return;
    final low = values.reduce(math.min);
    final high = values.reduce(math.max);
    final span = high == low ? 1.0 : high - low;
    const inset = JiabuChatMetrics.gap;
    final width = math.max(0, size.width - inset * 2);
    final height = math.max(0, size.height - inset * 2);
    final axisPaint = Paint()
      ..color = axis
      ..strokeWidth = JiabuChatMetrics.chartAxis;
    canvas
      ..drawLine(
        const Offset(inset, inset),
        Offset(inset, inset + height),
        axisPaint,
      )
      ..drawLine(
        Offset(inset, inset + height),
        Offset(inset + width, inset + height),
        axisPaint,
      );
    for (var index = 0; index < series.length; index++) {
      final points = series[index];
      final path = Path();
      var gap = true;
      for (var p = 0; p < points.length; p++) {
        final value = points[p];
        if (value == null || !value.isFinite) {
          gap = true;
          continue;
        }
        final x = inset + width * p / math.max(1, points.length - 1);
        final y =
            inset + height * (high == low ? .5 : 1 - (value - low) / span);
        if (gap) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
        gap = false;
      }
      final paint = Paint()
        ..color = palette[index % palette.length]
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = JiabuChatMetrics.chartStroke;
      if (index < 2) {
        canvas.drawPath(path, paint);
      } else {
        final dash = index.isEven
            ? JiabuChatMetrics.gap
            : JiabuChatMetrics.chartStroke;
        for (final metric in path.computeMetrics()) {
          for (
            var offset = 0.0;
            offset < metric.length;
            offset += dash + JiabuChatMetrics.rowGap
          ) {
            canvas.drawPath(
              metric.extractPath(
                offset,
                math.min(offset + dash, metric.length),
              ),
              paint,
            );
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(_TrendPainter oldDelegate) =>
      oldDelegate.series != series || oldDelegate.palette != palette;
}
