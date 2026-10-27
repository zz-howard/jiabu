import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import 'package:jiabu_design/src/tokens/colors.dart';

enum PaperPattern { dots, ruled, grid }

/// One small raster tile, retained by its widget until dependencies change.
ui.Image createPaperTile(PaperPattern pattern, JiabuColors colors, double dpr) {
  final step = switch (pattern) {
    PaperPattern.dots => 18.0,
    PaperPattern.ruled => 30.0,
    PaperPattern.grid => 20.0,
  };
  final pixels = (step * dpr).ceil();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(pixels / step);
  final paint = Paint()..color = colors.rule;
  switch (pattern) {
    case PaperPattern.dots:
      canvas.drawCircle(
        Offset(step / 2, step / 2),
        1.1,
        Paint()..color = colors.dot,
      );
    case PaperPattern.ruled:
      canvas.drawLine(
        Offset(0, step / 2),
        Offset(step, step / 2),
        paint..strokeWidth = 1,
      );
    case PaperPattern.grid:
      canvas
        ..drawLine(
          Offset(0, step / 2),
          Offset(step, step / 2),
          paint..strokeWidth = 1,
        )
        ..drawLine(Offset(step / 2, 0), Offset(step / 2, step), paint);
  }
  final picture = recorder.endRecording();
  final image = picture.toImageSync(pixels, pixels);
  picture.dispose();
  return image;
}

class PaperPainter extends CustomPainter {
  const new({
    required this.tile,
    required this.pattern,
    required this.colors,
    required this.background,
  });

  final ui.Image tile;
  final PaperPattern pattern;
  final JiabuColors colors;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    final step = switch (pattern) {
      PaperPattern.dots => 18.0,
      PaperPattern.ruled => 30.0,
      PaperPattern.grid => 20.0,
    };
    final scale = step / tile.width;
    final matrix = Float64List.fromList([
      scale,
      0,
      0,
      0,
      0,
      scale,
      0,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      0,
      1,
    ]);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.ImageShader(
          tile,
          TileMode.repeated,
          TileMode.repeated,
          matrix,
        ),
    );
    if (pattern == PaperPattern.ruled) {
      canvas.drawLine(
        const Offset(30, 0),
        Offset(30, size.height),
        Paint()
          ..color = colors.margin
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(PaperPainter oldDelegate) =>
      tile != oldDelegate.tile ||
      pattern != oldDelegate.pattern ||
      colors != oldDelegate.colors ||
      background != oldDelegate.background;
}
