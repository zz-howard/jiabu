import 'package:flutter/material.dart';
import 'package:jiabu_design/src/theme_context.dart';

/// Dragging and activating accessible points produce the same ordered sequence.
/// This widget only retains an in-progress gesture, never a saved credential.
class PatternLock extends StatefulWidget {
  const PatternLock({
    required this.points,
    required this.onChanged,
    required this.label,
    this.enabled = true,
    this.error = false,
    super.key,
  });

  static const padKey = ValueKey<String>('pattern-lock-pad');

  final List<int> points;
  final ValueChanged<List<int>> onChanged;
  final String label;
  final bool enabled;
  final bool error;

  @override
  State<PatternLock> createState() => _PatternLockState();
}

class _PatternLockState extends State<PatternLock> {
  List<int> _gesture = [];

  void _add(int point, {bool dragging = false}) {
    final points = dragging
        ? _gesture
        : widget.error
        ? <int>[]
        : widget.points;
    if (widget.enabled && !points.contains(point)) {
      final next = [...points, point];
      if (dragging) {
        _gesture = next;
      }
      widget.onChanged(next);
    }
  }

  void _select(Offset offset) {
    final column = (offset.dx / 72).floor();
    final row = (offset.dy / 72).floor();
    if (column >= 0 && column < 3 && row >= 0 && row < 3) {
      _add(row * 3 + column, dragging: true);
    }
  }

  @override
  Widget build(BuildContext context) => Center(
    child: SizedBox.square(
      key: PatternLock.padKey,
      dimension: 216,
      child: GestureDetector(
        onPanDown: widget.enabled
            ? (details) {
                _gesture = widget.error ? <int>[] : List.of(widget.points);
                _select(details.localPosition);
              }
            : null,
        onPanUpdate: widget.enabled
            ? (details) => _select(details.localPosition)
            : null,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _PatternPainter(
                  widget.points,
                  widget.error
                      ? context.jiabu.colors.neg
                      : context.jiabu.colors.primary,
                ),
              ),
            ),
            for (var point = 0; point < 9; point++)
              Positioned(
                left: (point % 3) * 72.0 + 4,
                top: (point ~/ 3) * 72.0 + 4,
                child: Semantics(
                  label: '${widget.label} ${point + 1}',
                  selected: widget.points.contains(point),
                  button: true,
                  child: InkWell(
                    onTap: widget.enabled ? () => _add(point) : null,
                    child: SizedBox.square(
                      dimension: 64,
                      child: Center(
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: widget.points.contains(point)
                                ? context.jiabu.colors.primary
                                : context.jiabu.colors.lineStrong,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _PatternPainter extends CustomPainter {
  _PatternPainter(this.points, this.color);

  final List<int> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    Offset position(int point) =>
        Offset((point % 3) * 72.0 + 36, (point ~/ 3) * 72.0 + 36);
    for (var i = 1; i < points.length; i++) {
      canvas.drawLine(position(points[i - 1]), position(points[i]), paint);
    }
  }

  @override
  bool shouldRepaint(_PatternPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.color != color;
}
