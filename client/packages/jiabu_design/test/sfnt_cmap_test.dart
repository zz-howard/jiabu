import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'support/font_sources.dart';
import 'support/sfnt_cmap.dart';

Uint8List _sfnt(Uint8List subtable, int encoding) {
  final bytes = Uint8List(40 + subtable.length);
  final data = ByteData.sublistView(bytes)
    ..setUint32(0, 0x00010000)
    ..setUint16(4, 1)
    ..setUint32(12, 0x636d6170)
    ..setUint32(20, 28)
    ..setUint32(24, 12 + subtable.length)
    ..setUint16(30, 1)
    ..setUint16(32, 3)
    ..setUint16(34, encoding)
    ..setUint32(36, 12);
  bytes.setRange(40, bytes.length, subtable);
  // Retain the typed view while constructing the fixture.
  expect(data.lengthInBytes, bytes.length);
  return bytes;
}

void main() {
  test('format 4 handles relative glyph arrays, delta and glyph zero', () {
    final table = Uint8List(50);
    ByteData.sublistView(table)
      ..setUint16(0, 4)
      ..setUint16(2, 50)
      ..setUint16(6, 6)
      ..setUint16(14, 0x41)
      ..setUint16(16, 0x44)
      ..setUint16(18, 0xffff)
      ..setUint16(22, 0x41)
      ..setUint16(24, 0x42)
      ..setUint16(26, 0xffff)
      ..setUint16(28, 1 - 0x41 & 0xffff)
      ..setUint16(30, 2)
      ..setUint16(32, 1)
      ..setUint16(34, 0)
      ..setUint16(36, 6)
      ..setUint16(38, 0)
      // First glyph at 36 + 6 = 42. Glyph zero must stay missing.
      ..setUint16(42, 5)
      ..setUint16(44, 0)
      ..setUint16(46, 8);
    expect(readCmap(_sfnt(table, 1)), {0x41, 0x42, 0x44});
  });
  test('format 12 retains supplementary Han and excludes glyph zero', () {
    final table = Uint8List(40);
    ByteData.sublistView(table)
      ..setUint16(0, 12)
      ..setUint32(4, 40)
      ..setUint32(12, 2)
      ..setUint32(16, 0x20000)
      ..setUint32(20, 0x20001)
      ..setUint32(24, 5)
      ..setUint32(28, 0x41)
      ..setUint32(32, 0x42)
      ..setUint32(36, 0);
    expect(readCmap(_sfnt(table, 10)), {0x20000, 0x20001, 0x42});
    expect(isHan(0x20000), isTrue);
    expect(isHan(0xf900), isTrue);
    expect(isHan(0x41), isFalse);
  });
  test('malformed font tables fail with useful errors', () {
    expect(() => readCmap(Uint8List(2)), throwsFormatException);
    final table = Uint8List(16);
    ByteData.sublistView(table)
      ..setUint16(0, 12)
      ..setUint32(4, 16)
      ..setUint32(12, 100);
    expect(() => readCmap(_sfnt(table, 10)), throwsFormatException);
  });
  test('JSON selection traverses object and array wildcards', () {
    expect(
      selectValues(
        {
          'categories': [
            {
              'aliases': ['早饭', 'breakfast'],
            },
            {
              'aliases': ['午饭'],
            },
          ],
        },
        ['categories', '*', 'aliases', '*'],
      ),
      ['早饭', 'breakfast', '午饭'],
    );
    expect(selectValues(['hello'], ['0']), ['hello']);
    expect(messageText('{month}月{day}日 周{weekday}'), '月日 周');
    expect(messageText('{count, plural, one{1 条#} other{{count} 条}}'), '1 条 条');
    expect(messageText('{kind, select, a{甲} other{乙}}'), '甲乙');
    expect(() => messageText('{amount, number}'), throwsFormatException);
    expect(() => selectValues({'a': 1}, ['missing']), throwsFormatException);
  });
  test('ICU argument names require ASCII word characters', () {
    expect(
      () => messageText('{bad-name, plural, other{A}}'),
      throwsFormatException,
    );
    expect(() => messageText('{名字, plural, other{A}}'), throwsFormatException);
  });
}
