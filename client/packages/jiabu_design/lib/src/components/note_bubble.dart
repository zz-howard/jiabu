import 'package:flutter/widgets.dart';
import 'package:jiabu_design/src/components/tilt.dart';
import 'package:jiabu_design/src/geometry/tilt.dart';
import 'package:jiabu_design/src/theme_context.dart';

class NoteBubble extends StatelessWidget {
  const new({required this.id, required this.child, super.key});

  final String id;
  final Widget child;

  @override
  Widget build(BuildContext context) => Tilt(
    degrees: tiltFor(id, amp: context.jiabu.decor.noteAmp),
    child: Container(
      padding: const EdgeInsets.fromLTRB(16, 11, 16, 12),
      decoration: BoxDecoration(
        color: context.jiabu.colors.note,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(2),
          topRight: Radius.circular(2),
          bottomLeft: Radius.circular(2),
          bottomRight: Radius.circular(14),
        ),
        boxShadow: context.jiabu.decor.cardShadow,
      ),
      child: CustomPaint(
        foregroundPainter: _FoldPainter(context.jiabu.colors.noteEdge),
        child: DefaultTextStyle(
          style: context.jiabu.type.body.copyWith(
            color: context.jiabu.colors.noteInk,
          ),
          child: child,
        ),
      ),
    ),
  );
}

class _FoldPainter extends CustomPainter {
  const new(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final right = size.width + 16;
    final bottom = size.height + 12;
    canvas.drawPath(
      Path()
        ..moveTo(right - 14, bottom)
        ..lineTo(right - 14, bottom - 14)
        ..lineTo(right, bottom - 14)
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_FoldPainter oldDelegate) => color != oldDelegate.color;
}
