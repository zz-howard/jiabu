import 'package:flutter/widgets.dart';
import 'package:jiabu_design/src/components/tilt.dart';
import 'package:jiabu_design/src/theme_context.dart';

class PencilStrike extends StatelessWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    children: [
      child,
      Positioned.fill(
        child: ExcludeSemantics(
          child: IgnorePointer(
            child: Tilt(
              degrees: context.jiabu.decor.strikeTilt,
              child: CustomPaint(
                painter: _StrikePainter(
                  context.jiabu.colors.ink3,
                  context.jiabu.decor.strikeStroke,
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

class _StrikePainter extends CustomPainter {
  const new(this.color, this.stroke);
  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height / 2;
    final path = Path()
      ..moveTo(0, mid)
      ..cubicTo(
        size.width * .3,
        mid - .6,
        size.width * .7,
        mid + .5,
        size.width,
        mid,
      );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_StrikePainter oldDelegate) =>
      color != oldDelegate.color || stroke != oldDelegate.stroke;
}
