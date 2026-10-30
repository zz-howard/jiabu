import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/icons/gen_icons.dart';

void main() {
  test('relative coordinates, implicit lines, H/V and close restore start', () {
    expect(pathCommands('M1 2 3 4h2v-1z m1 1l2 3'), [
      '..moveTo(1, 2)',
      '..lineTo(3, 4)',
      '..lineTo(5, 4)',
      '..lineTo(5, 3)',
      '..close()',
      '..moveTo(2, 3)',
      '..lineTo(4, 6)',
    ]);
  });
  test('smooth cubic reflects only a preceding cubic control', () {
    expect(pathCommands('M0 0C1 2 3 4 5 6s2 3 4 5L1 1s2 3 4 5'), [
      '..moveTo(0, 0)',
      '..cubicTo(1, 2, 3, 4, 5, 6)',
      '..cubicTo(7, 8, 7, 9, 9, 11)',
      '..lineTo(1, 1)',
      '..cubicTo(1, 1, 3, 4, 5, 6)',
    ]);
  });
  test('quadratic and smooth quadratic controls', () {
    expect(
      pathCommands('M0 0Q2 3 4 5t4 5').last,
      '..quadraticBezierTo(6, 7, 8, 10)',
    );
  });
  test('arcs retain degrees, flags and relative endpoint', () {
    expect(
      pathCommands('M2 3a4 5 45 1 0 6 7').last,
      '..arcToPoint(Offset(8, 10), radius: Radius.elliptical(4, 5), '
      'rotation: 45, largeArc: true, clockwise: false)',
    );
    expect(pathCommands('M2 3A0 5 0 0 1 8 10').last, '..lineTo(8, 10)');
    expect(pathCommands('M2 3A4 5 0 0 1 2 3'), ['..moveTo(2, 3)']);
  });
  test('numbers accept exponents and adjoining signs', () {
    expect(pathCommands('M.5-.5l1e1-2E0').last, '..lineTo(10.5, -2.5)');
  });
  test('circle and rounded rectangle preserve shapes', () {
    expect(shapeCommands({'type': 'circle', 'cx': 2, 'cy': 3, 'r': 1}), [
      '..addOval(Rect.fromCircle(center: Offset(2, 3), radius: 1))',
    ]);
    const rounded =
        '..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, 4, 2), '
        'Radius.elliptical(2, 1)))';
    expect(shapeCommands({'type': 'rect', 'width': 4, 'height': 2, 'rx': 3}), [
      rounded,
    ]);
  });
  test('unknown input, malformed arguments and invalid flags fail', () {
    for (final path in ['M0 0R1 2', 'M0', 'L1 2', 'M0 0A1 2 0 2 0 3 4']) {
      expect(() => pathCommands(path), throwsFormatException);
    }
    expect(() => shapeCommands({'type': 'ellipse'}), throwsFormatException);
    expect(
      () => shapeCommands({
        'type': 'path',
        'd': 'M0 0L1 1',
        'transform': 'rotate(2)',
      }),
      throwsFormatException,
    );
  });
  test(
    'all prototype icons are committed with deterministic generated paths',
    () {
      final json = jsonDecode(
        File('tool/icons/icons.json').readAsStringSync(),
      ) as Map<String, Object?>;
      final icons = json['icons']! as Map<String, Object?>;
      expect(icons.length, 63);
      // V5b: the composer's paperclip is a Lucide line icon like the rest
      // of the ui family, not the hand-drawn doodle clip.
      final attach = icons['uiAttach']! as Map<String, Object?>;
      expect(attach['category'], 'ui');
      expect(attach['strokeWidth'], 1.85);
      final key = icons['uiKey']! as Map<String, Object?>;
      expect(key['category'], 'ui');
      expect(key['strokeWidth'], 1.85);
      expect(json['source'], contains('Lucide ISC'));
      expect(
        File('packages/jiabu_design/assets/licenses/LUCIDE-LICENSE.txt')
            .readAsStringSync(),
        contains('ISC'),
      );
      expect(
        generateIcons(json),
        File('packages/jiabu_design/lib/src/icons/jiabu_icons.g.dart')
            .readAsStringSync(),
      );
    },
  );
}
