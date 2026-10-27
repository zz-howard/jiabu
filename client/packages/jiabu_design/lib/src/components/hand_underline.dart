import 'package:flutter/widgets.dart';

import 'package:jiabu_design/src/icons/jiabu_icons.g.dart';
import 'package:jiabu_design/src/theme_context.dart';

class HandUnderline extends StatelessWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _UnderlinePainter(context.jiabu.colors.primary),
    child: Padding(padding: const EdgeInsets.only(bottom: 10), child: child),
  );
}

class _UnderlinePainter extends CustomPainter {
  const new(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..translate(0, size.height - 10)
      ..scale(size.width / 120, 1)
      ..drawPath(
        JiabuIcons.squig.shapes.first.path(),
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_UnderlinePainter oldDelegate) =>
      color != oldDelegate.color;
}
