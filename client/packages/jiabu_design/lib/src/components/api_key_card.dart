import 'package:flutter/material.dart';
import 'package:jiabu_design/src/theme_context.dart';

/// Only the caller supplies key text and the mono style. This surface contains
/// no credential handling, clipboard access or application state.
class ApiKeyCard extends StatelessWidget {
  const ApiKeyCard({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: _KeyBorder(context.jiabu.colors.lineStrong),
    child: Container(
      padding: EdgeInsets.all(context.jiabu.decor.cardInset),
      decoration: BoxDecoration(
        color: context.jiabu.colors.paper,
        borderRadius: BorderRadius.circular(context.jiabu.decor.cardRadius),
      ),
      child: child,
    ),
  );
}

class _KeyBorder extends CustomPainter {
  _KeyBorder(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(.75),
          const Radius.circular(3),
        ),
      );
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    for (final metric in path.computeMetrics()) {
      for (var distance = 0.0; distance < metric.length; distance += 10) {
        canvas.drawPath(
          metric.extractPath(
            distance,
            (distance + 6).clamp(0, metric.length).toDouble(),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_KeyBorder oldDelegate) => oldDelegate.color != color;
}
