import 'package:flutter/widgets.dart';

import 'package:jiabu_design/src/icons/icon_data.dart';
import 'package:jiabu_design/src/theme_context.dart';

class JiabuIcon extends StatelessWidget {
  const new(
    this.icon, {
    this.size = 24,
    this.color,
    this.strokeWidth,
    this.flipX = false,
    this.flipY = false,
    super.key,
  });

  final JiabuIconData icon;
  final double size;
  final Color? color;
  final double? strokeWidth;
  final bool flipX;
  final bool flipY;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: size,
      height: size * icon.height / icon.width,
      child: CustomPaint(
        painter: _IconPainter(
          icon,
          color ?? context.jiabu.colors.ink,
          strokeWidth,
          flipX: flipX,
          flipY: flipY,
        ),
      ),
    ),
  );
}

class _IconPainter extends CustomPainter {
  const new(
    this.icon,
    this.color,
    this.strokeWidth, {
    required this.flipX,
    required this.flipY,
  });

  final JiabuIconData icon;
  final Color color;
  final double? strokeWidth;
  final bool flipX;
  final bool flipY;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..translate(flipX ? size.width : 0, flipY ? size.height : 0)
      ..scale(
        (flipX ? -1 : 1) * size.width / icon.width,
        (flipY ? -1 : 1) * size.height / icon.height,
      );
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth ?? icon.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final shape in icon.shapes) {
      final path = shape.path();
      if (shape.fill) {
        paint.style = PaintingStyle.fill;
        canvas.drawPath(path, paint);
      }
      // Filled prototype shapes still inherit the SVG's round outline.
      paint.style = PaintingStyle.stroke;
      canvas.drawPath(path, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_IconPainter oldDelegate) =>
      icon != oldDelegate.icon ||
      color != oldDelegate.color ||
      strokeWidth != oldDelegate.strokeWidth ||
      flipX != oldDelegate.flipX ||
      flipY != oldDelegate.flipY;
}
