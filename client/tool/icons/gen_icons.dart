import 'dart:convert';
import 'dart:io';

/// Converts SVG path data into Dart Path operations at development time.
/// Runtime code never interprets SVG or parses numbers.
List<String> pathCommands(String source) {
  final tokenPattern = RegExp(
    r'[AaCcHhLlMmQqSsTtVvZz]|[-+]?(?:\d*\.\d+|\d+\.?\d*)(?:[eE][-+]?\d+)?',
  );
  final tokens = <String>[];
  var end = 0;
  for (final match in tokenPattern.allMatches(source)) {
    if (source.substring(end, match.start).replaceAll(RegExp(r'[\s,]'), '') !=
        '') {
      throw FormatException('Unsupported path input', source, end);
    }
    tokens.add(match.group(0)!);
    end = match.end;
  }
  if (source.substring(end).trim().isNotEmpty) {
    throw FormatException('Trailing path input', source, end);
  }
  final result = <String>[];
  var index = 0;
  var command = '';
  var previous = '';
  var x = 0.0;
  var y = 0.0;
  var startX = 0.0;
  var startY = 0.0;
  var controlX = 0.0;
  var controlY = 0.0;
  bool isCommand(String token) => RegExp(r'^[A-Za-z]$').hasMatch(token);
  double number() {
    if (index >= tokens.length || isCommand(tokens[index])) {
      throw FormatException('Incomplete $command command', source);
    }
    final value = double.parse(tokens[index++]);
    if (!value.isFinite) {
      throw FormatException('Non-finite coordinate', source);
    }
    return value;
  }

  while (index < tokens.length) {
    if (isCommand(tokens[index])) {
      command = tokens[index++];
    }
    if (command.isEmpty) {
      throw FormatException('Missing move', source);
    }
    final upper = command.toUpperCase();
    final relative = upper != command;
    final originX = relative ? x : 0.0;
    final originY = relative ? y : 0.0;
    double px() => number() + originX;
    double py() => number() + originY;
    switch (upper) {
      case 'Z':
        result.add('..close()');
        x = startX;
        y = startY;
        command = '';
      case 'M':
      case 'L':
        x = px();
        y = py();
        result.add(
          '..${upper == 'M' ? 'moveTo' : 'lineTo'}('
          '${svgNumber(x)}, ${svgNumber(y)})',
        );
        if (upper == 'M') {
          startX = x;
          startY = y;
          command = relative ? 'l' : 'L';
        }
      case 'H':
        x = px();
        result.add('..lineTo(${svgNumber(x)}, ${svgNumber(y)})');
      case 'V':
        y = py();
        result.add('..lineTo(${svgNumber(x)}, ${svgNumber(y)})');
      case 'C':
      case 'S':
        final x1 = upper == 'C'
            ? px()
            : (previous == 'C' || previous == 'S' ? 2 * x - controlX : x);
        final y1 = upper == 'C'
            ? py()
            : (previous == 'C' || previous == 'S' ? 2 * y - controlY : y);
        controlX = px();
        controlY = py();
        x = px();
        y = py();
        result.add(
          '..cubicTo(${svgNumber(x1)}, ${svgNumber(y1)}, '
          '${svgNumber(controlX)}, ${svgNumber(controlY)}, '
          '${svgNumber(x)}, ${svgNumber(y)})',
        );
      case 'Q':
      case 'T':
        controlX = upper == 'Q'
            ? px()
            : (previous == 'Q' || previous == 'T' ? 2 * x - controlX : x);
        controlY = upper == 'Q'
            ? py()
            : (previous == 'Q' || previous == 'T' ? 2 * y - controlY : y);
        x = px();
        y = py();
        result.add(
          '..quadraticBezierTo('
          '${svgNumber(controlX)}, ${svgNumber(controlY)}, '
          '${svgNumber(x)}, ${svgNumber(y)})',
        );
      case 'A':
        final rx = number().abs();
        final ry = number().abs();
        final rotation = number();
        final large = number();
        final sweep = number();
        if ((large != 0 && large != 1) || (sweep != 0 && sweep != 1)) {
          throw FormatException('Arc flags must be 0 or 1', source);
        }
        final targetX = px();
        final targetY = py();
        if (x != targetX || y != targetY) {
          if (rx == 0 || ry == 0) {
            result.add(
              '..lineTo('
              '${svgNumber(targetX)}, ${svgNumber(targetY)})',
            );
          } else {
            result.add(
              '..arcToPoint(Offset('
              '${svgNumber(targetX)}, ${svgNumber(targetY)}), '
              'radius: Radius.elliptical(${svgNumber(rx)}, '
              '${svgNumber(ry)}), rotation: ${svgNumber(rotation)}, '
              'largeArc: ${large == 1}, clockwise: ${sweep == 1})',
            );
          }
        }
        x = targetX;
        y = targetY;
      default:
        throw FormatException('Unsupported command $command', source);
    }
    previous = upper;
  }
  if (result.isEmpty || !result.first.startsWith('..moveTo')) {
    throw FormatException('Path must start with moveTo', source);
  }
  return result;
}

String svgNumber(num value) {
  if (!value.isFinite) {
    throw const FormatException('Non-finite coordinate');
  }
  final rounded = value.toStringAsFixed(6);
  final trimmed = rounded.replaceFirst(RegExp(r'\.?0+$'), '');
  return trimmed == '-0' ? '0' : trimmed;
}

List<String> shapeCommands(Map<String, Object?> shape) {
  const attributes = {
    'path': {'type', 'd', 'fill'},
    'circle': {'type', 'cx', 'cy', 'r', 'fill'},
    'rect': {'type', 'x', 'y', 'width', 'height', 'rx', 'ry', 'fill'},
  };
  final allowed = attributes[shape['type']];
  if (allowed == null || shape.keys.any((key) => !allowed.contains(key))) {
    throw FormatException('Unsupported shape or attribute: $shape');
  }
  double n(String key, [double fallback = 0]) =>
      (shape[key] as num?)?.toDouble() ?? fallback;
  final type = shape['type'];
  switch (type) {
    case 'path':
      return pathCommands(shape['d']! as String);
    case 'circle':
      final radius = n('r');
      if (radius < 0) {
        throw const FormatException('Negative circle radius');
      }
      final oval =
          '..addOval(Rect.fromCircle(center: Offset('
          '${svgNumber(n('cx'))}, ${svgNumber(n('cy'))}), '
          'radius: ${svgNumber(radius)}))';
      return [oval];
    case 'rect':
      final width = n('width');
      final height = n('height');
      if (width < 0 || height < 0) {
        throw const FormatException('Negative rectangle dimension');
      }
      final rect =
          'Rect.fromLTWH(${svgNumber(n('x'))}, '
          '${svgNumber(n('y'))}, ${svgNumber(width)}, ${svgNumber(height)})';
      final rx = n('rx', n('ry')).clamp(0, width / 2);
      final ry = n('ry', n('rx')).clamp(0, height / 2);
      if (rx == 0 && ry == 0) return ['..addRect($rect)'];
      final rounded =
          '..addRRect(RRect.fromRectAndRadius($rect, '
          'Radius.elliptical(${svgNumber(rx)}, ${svgNumber(ry)})))';
      return [rounded];
    default:
      throw FormatException('Unsupported shape $type');
  }
}

String generateIcons(Map<String, Object?> document) {
  final icons = document['icons']! as Map<String, Object?>;
  final names = icons.keys.toList()..sort();
  final out = StringBuffer()
    ..writeln('// GENERATED by tool/icons/gen_icons.dart. DO NOT EDIT.')
    ..writeln('// dart format off')
    ..writeln("import 'package:flutter/painting.dart';")
    ..writeln()
    ..writeln("import 'icon_data.dart';")
    ..writeln()
    ..writeln('abstract final class JiabuIcons {');
  final paths = StringBuffer();
  for (final name in names) {
    if (!RegExp(r'^[a-z][A-Za-z0-9]*$').hasMatch(name)) {
      throw FormatException('Invalid Dart icon name $name');
    }
    final icon = icons[name]! as Map<String, Object?>;
    final viewport = icon['viewport']! as List<Object?>;
    final shapes = icon['shapes']! as List<Object?>;
    out
      ..writeln('  static const $name = JiabuIconData(')
      ..writeln("    name: '$name', category: '${icon['category']}',")
      ..writeln(
        '    width: ${svgNumber(viewport[0]! as num)}, '
        'height: ${svgNumber(viewport[1]! as num)},',
      )
      ..writeln('    strokeWidth: ${svgNumber(icon['strokeWidth']! as num)},')
      ..writeln('    shapes: [');
    for (var i = 0; i < shapes.length; i++) {
      final shape = shapes[i]! as Map<String, Object?>;
      out.writeln(
        '      JiabuIconShape(_${name}_$i, '
        "fill: ${shape['fill'] == true}),",
      );
      paths.writeln('Path _${name}_$i() => Path()');
      final operations = shapeCommands(shape);
      for (var j = 0; j < operations.length; j++) {
        paths.writeln(
          '  ${operations[j]}'
          '${j == operations.length - 1 ? ';' : ''}',
        );
      }
      paths.writeln();
    }
    out
      ..writeln('    ],')
      ..writeln('  );');
  }
  out
    ..writeln()
    ..writeln('  static const all = <String, JiabuIconData>{');
  for (final name in names) {
    out.writeln("    '$name': $name,");
  }
  out
    ..writeln('  };')
    ..writeln('}')
    ..writeln()
    ..write(paths);
  return out.toString();
}

void main(List<String> arguments) {
  if (arguments.any((argument) => argument != '--check')) {
    stderr.writeln('Usage: dart run tool/icons/gen_icons.dart [--check]');
    exitCode = 64;
    return;
  }
  final source = File('tool/icons/icons.json');
  final document =
      jsonDecode(source.readAsStringSync()) as Map<String, Object?>;
  final generated = generateIcons(document);
  final target = File('packages/jiabu_design/lib/src/icons/jiabu_icons.g.dart');
  if (arguments.contains('--check')) {
    if (!target.existsSync() || target.readAsStringSync() != generated) {
      stderr.writeln(
        'Generated icons differ. Run dart run '
        'tool/icons/gen_icons.dart from client/.',
      );
      exitCode = 1;
    }
  } else {
    target.parent.createSync(recursive: true);
    target.writeAsStringSync(generated);
  }
}
