import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

@immutable
class JiabuIconData {
  const new({
    required this.name,
    required this.category,
    required this.width,
    required this.height,
    required this.strokeWidth,
    required this.shapes,
  });

  final String name;
  final String category;
  final double width;
  final double height;
  final double strokeWidth;
  final List<JiabuIconShape> shapes;
}

@immutable
class JiabuIconShape {
  const new(this.path, {this.fill = false});

  final Path Function() path;
  final bool fill;
}
