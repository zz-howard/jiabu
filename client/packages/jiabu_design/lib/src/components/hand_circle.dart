import 'package:flutter/widgets.dart';

import 'package:jiabu_design/src/icons/jiabu_icons.g.dart';
import 'package:jiabu_design/src/theme_context.dart';

class HandCircle extends StatelessWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _CirclePainter(
      context.jiabu.colors.primary,
      context.jiabu.decor.circleStroke,
    ),
    child: Padding(padding: const EdgeInsets.all(12), child: child),
  );
}

class _CirclePainter extends CustomPainter {
  const new(this.color, this.stroke);
  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final path = JiabuIcons.circle.shapes.first.path();
    final matrix = Matrix4.diagonal3Values(
      size.width / 80,
      size.height / 44,
      1,
    );
    canvas.drawPath(
      path.transform(matrix.storage),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CirclePainter oldDelegate) =>
      color != oldDelegate.color || stroke != oldDelegate.stroke;
}
