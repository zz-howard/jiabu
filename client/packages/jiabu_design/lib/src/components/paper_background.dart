import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'package:jiabu_design/src/geometry/paper.dart';
import 'package:jiabu_design/src/theme_context.dart';
import 'package:jiabu_design/src/tokens/colors.dart';

class PaperBackground extends StatefulWidget {
  const new({
    required this.child,
    this.pattern = PaperPattern.dots,
    this.color,
    super.key,
  });

  final Widget child;
  final PaperPattern pattern;
  final Color? color;

  @override
  State<PaperBackground> createState() => _PaperBackgroundState();
}

class _PaperBackgroundState extends State<PaperBackground> {
  ui.Image? _tile;
  JiabuColors? _colors;
  double? _dpr;

  void _updateTile() {
    final colors = context.jiabu.colors;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    if (_tile != null && colors == _colors && dpr == _dpr) {
      return;
    }
    final old = _tile;
    _tile = createPaperTile(widget.pattern, colors, dpr);
    _colors = colors;
    _dpr = dpr;
    old?.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateTile();
  }

  @override
  void didUpdateWidget(PaperBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pattern != widget.pattern) {
      _tile?.dispose();
      _tile = null;
      _updateTile();
    }
  }

  @override
  void dispose() {
    _tile?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: PaperPainter(
      tile: _tile!, // Created synchronously in didChangeDependencies.
      pattern: widget.pattern,
      colors: context.jiabu.colors,
      background: widget.color ?? context.jiabu.colors.bg,
    ),
    child: widget.child,
  );
}
