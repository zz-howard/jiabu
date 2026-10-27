import 'dart:typed_data';

/// Unicode cmap formats 4 and 12, including idDelta and relative range offsets.
Set<int> readCmap(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  void bounds(int offset, int length) {
    if (offset < 0 || length < 0 || offset + length > bytes.length) {
      throw const FormatException('Truncated SFNT/cmap');
    }
  }

  int u16(int offset) {
    bounds(offset, 2);
    return data.getUint16(offset);
  }

  int u32(int offset) {
    bounds(offset, 4);
    return data.getUint32(offset);
  }

  bounds(0, 12);
  int? cmap;
  var cmapLength = 0;
  for (var i = 0; i < u16(4); i++) {
    final table = 12 + i * 16;
    bounds(table, 16);
    if (u32(table) == 0x636d6170) {
      cmap = u32(table + 8);
      cmapLength = u32(table + 12);
    }
  }
  if (cmap == null) {
    throw const FormatException('No cmap table');
  }
  final cmapStart = cmap;
  bounds(cmapStart, cmapLength);
  void cmapBounds(int offset, int length) {
    bounds(offset, length);
    if (offset < cmapStart || offset + length > cmapStart + cmapLength) {
      throw const FormatException('cmap offset escapes table');
    }
  }

  final result = <int>{};
  final visited = <int>{};
  cmapBounds(cmapStart, 4);
  final count = u16(cmapStart + 2);
  cmapBounds(cmapStart + 4, count * 8);
  for (var i = 0; i < count; i++) {
    final entry = cmapStart + 4 + i * 8;
    final platform = u16(entry);
    final encoding = u16(entry + 2);
    if (!(platform == 0 ||
        platform == 3 && (encoding == 1 || encoding == 10))) {
      continue;
    }
    final start = cmapStart + u32(entry + 4);
    if (!visited.add(start)) {
      continue;
    }
    cmapBounds(start, 2);
    final format = u16(start);
    if (format == 4) {
      cmapBounds(start, 14);
      final length = u16(start + 2);
      cmapBounds(start, length);
      final segments = u16(start + 6) ~/ 2;
      if (segments == 0 || 16 + segments * 8 > length) {
        throw const FormatException('Invalid format 4 segment count');
      }
      final ends = start + 14;
      final starts = ends + segments * 2 + 2;
      final deltas = starts + segments * 2;
      final ranges = deltas + segments * 2;
      for (var segment = 0; segment < segments; segment++) {
        final first = u16(starts + segment * 2);
        final last = u16(ends + segment * 2);
        if (first > last) {
          throw const FormatException('Reversed format 4 range');
        }
        final delta = u16(deltas + segment * 2);
        final rangeAddress = ranges + segment * 2;
        final range = u16(rangeAddress);
        for (var code = first; code <= last && code < 0xffff; code++) {
          var glyph = 0;
          if (range == 0) {
            glyph = (code + delta) & 0xffff;
          } else {
            final address = rangeAddress + range + 2 * (code - first);
            if (address < start || address + 2 > start + length) {
              throw const FormatException('Invalid format 4 glyph offset');
            }
            glyph = u16(address);
            if (glyph != 0) {
              glyph = (glyph + delta) & 0xffff;
            }
          }
          if (glyph != 0) {
            result.add(code);
          }
        }
      }
    } else if (format == 12) {
      cmapBounds(start, 16);
      final length = u32(start + 4);
      cmapBounds(start, length);
      final groups = u32(start + 12);
      if (16 + groups * 12 > length) {
        throw const FormatException('Invalid format 12 group count');
      }
      for (var group = 0; group < groups; group++) {
        final offset = start + 16 + group * 12;
        final first = u32(offset);
        final last = u32(offset + 4);
        final glyph = u32(offset + 8);
        if (first > last || last > 0x10ffff) {
          throw const FormatException('Invalid format 12 range');
        }
        for (var code = first; code <= last; code++) {
          if (glyph + code - first != 0) {
            result.add(code);
          }
        }
      }
    }
  }
  if (result.isEmpty) {
    throw const FormatException('No supported Unicode cmap');
  }
  return result;
}

bool isHan(int code) =>
    code >= 0x3400 && code <= 0x4dbf ||
    code >= 0x4e00 && code <= 0x9fff ||
    code >= 0xf900 && code <= 0xfaff ||
    code >= 0x20000 && code <= 0x323af;
