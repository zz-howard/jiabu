import 'package:flutter/widgets.dart';
import 'package:jiabu_design/src/components/tilt.dart';
import 'package:jiabu_design/src/geometry/tape_path.dart';
import 'package:jiabu_design/src/theme_context.dart';
import 'package:jiabu_design/src/tokens/decor.dart';

enum TapePattern { stripe, dots, grid }

class Tape extends StatelessWidget {
  const new({
    this.pattern = TapePattern.stripe,
    this.degrees = -5,
    this.width = 76,
    this.height = 22,
    super.key,
  });

  final TapePattern pattern;
  final double degrees;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: IgnorePointer(
      child: Tilt(
        degrees: degrees,
        child: ClipPath(
          clipper: const _TapeClipper(),
          child: SizedBox(
            width: width,
            height: height,
            child: CustomPaint(
              painter: _TapePainter(
                pattern,
                context.jiabu.decor,
                context.jiabu.colors.white,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _TapeClipper extends CustomClipper<Path> {
  const new();

  @override
  Path getClip(Size size) => tapePath(size);
  @override
  bool shouldReclip(_TapeClipper oldClipper) => false;
}

class _TapePainter extends CustomPainter {
  const new(this.pattern, this.decor, this.white);

  final TapePattern pattern;
  final JiabuDecor decor;
  final Color white;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final base = switch (pattern) {
      TapePattern.stripe => decor.tapeB,
      TapePattern.dots => decor.tape2,
      TapePattern.grid => decor.tape3,
    };
    canvas
      ..drawRect(rect, Paint()..color = base)
      ..save()
      ..clipRect(rect);
    final paint = Paint();
    switch (pattern) {
      case TapePattern.stripe:
        paint
          ..color = decor.tapeA
          ..strokeWidth = 5;
        for (var x = -size.height; x < size.width + size.height; x += 10) {
          canvas.drawLine(
            Offset(x, 0),
            Offset(x + size.height, size.height),
            paint,
          );
        }
      case TapePattern.dots:
        paint.color = white.withValues(alpha: .75);
        for (var y = 3.5; y < size.height; y += 7) {
          for (var x = 3.5; x < size.width; x += 7) {
            canvas.drawCircle(Offset(x, y), 1.1, paint);
          }
        }
      case TapePattern.grid:
        paint
          ..color = white.withValues(alpha: .38)
          ..strokeWidth = 1;
        for (var x = 0.0; x < size.width; x += 10) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
        }
        for (var y = 0.0; y < size.height; y += 10) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
        }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TapePainter oldDelegate) =>
      pattern != oldDelegate.pattern ||
      decor != oldDelegate.decor ||
      white != oldDelegate.white;
}
