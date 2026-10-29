import 'package:flutter/widgets.dart';
import 'package:jiabu_design/src/theme_context.dart';
import 'package:jiabu_design/src/tokens/chat_metrics.dart';

class ChatStepRail extends StatelessWidget {
  const ChatStepRail({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _RailPainter(context.jiabu.colors.lineStrong),
    child: child,
  );
}

class _RailPainter extends CustomPainter {
  const _RailPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = JiabuChatMetrics.rail;
    for (var y = 0.0; y < size.height; y += JiabuChatMetrics.gap) {
      canvas.drawLine(
        Offset(0, y),
        Offset(
          0,
          (y + JiabuChatMetrics.rowGap).clamp(0, size.height).toDouble(),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_RailPainter oldDelegate) => oldDelegate.color != color;
}
