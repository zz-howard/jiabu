import 'dart:typed_data';

final class JpegInfo {
  const JpegInfo(this.width, this.height);
  final int width;
  final int height;
}

/// A structural JPEG parser, including entropy stuffing/restarts/multiple
/// scans.
/// Remove every APP/COM segment and bytes following EOI. No EXIF parser decides
/// which tags are "safe", so GPS, XMP, maker notes and unknown tags all
/// disappear.
final class JpegSanitizerService {
  Uint8List sanitize(Uint8List input) => _walk(input, strip: true).$1;
  JpegInfo dimensions(Uint8List input) => _walk(input, strip: false).$2;

  (Uint8List, JpegInfo) _walk(Uint8List input, {required bool strip}) {
    if (input.length < 4 || input[0] != 0xff || input[1] != 0xd8) {
      throw const FormatException('invalid_jpeg');
    }
    final output = BytesBuilder(copy: false)..add(input.sublist(0, 2));
    var offset = 2;
    var entropy = false;
    JpegInfo? info;
    var sawScan = false;
    while (offset < input.length) {
      if (entropy) {
        final start = offset;
        while (offset < input.length) {
          if (input[offset] != 0xff) {
            offset++;
            continue;
          }
          if (offset + 1 >= input.length) {
            throw const FormatException('truncated_jpeg');
          }
          final next = input[offset + 1];
          if (next == 0 || (next >= 0xd0 && next <= 0xd7)) {
            offset += 2;
            continue;
          }
          break;
        }
        output.add(input.sublist(start, offset));
        entropy = false;
      }
      if (offset + 1 >= input.length || input[offset] != 0xff) {
        throw const FormatException('invalid_jpeg_marker');
      }
      final start = offset;
      while (offset < input.length && input[offset] == 0xff) {
        offset++;
      }
      if (offset >= input.length) {
        throw const FormatException('truncated_jpeg');
      }
      final marker = input[offset++];
      if (marker == 0xd9) {
        if (info == null || !sawScan) {
          throw const FormatException('incomplete_jpeg');
        }
        output.add([0xff, 0xd9]);
        return (output.takeBytes(), info);
      }
      if (marker == 0 ||
          marker == 0xd8 ||
          marker == 1 ||
          (marker >= 0xd0 && marker <= 0xd7)) {
        throw const FormatException('invalid_jpeg_marker');
      }
      if (offset + 2 > input.length) {
        throw const FormatException('truncated_jpeg');
      }
      final length = (input[offset] << 8) | input[offset + 1];
      if (length < 2 || offset + length > input.length) {
        throw const FormatException('truncated_jpeg');
      }
      if (const {
        0xc0,
        0xc1,
        0xc2,
        0xc3,
        0xc5,
        0xc6,
        0xc7,
        0xc9,
        0xca,
        0xcb,
        0xcd,
        0xce,
        0xcf,
      }.contains(marker)) {
        if (length < 8) {
          throw const FormatException('invalid_jpeg_sof');
        }
        final height = (input[offset + 3] << 8) | input[offset + 4];
        final width = (input[offset + 5] << 8) | input[offset + 6];
        if (width == 0 || height == 0) {
          throw const FormatException('invalid_jpeg_dimensions');
        }
        info = JpegInfo(width, height);
      }
      if (!strip || !((marker >= 0xe0 && marker <= 0xef) || marker == 0xfe)) {
        output.add(input.sublist(start, offset + length));
      }
      offset += length;
      if (marker == 0xda) {
        entropy = true;
        sawScan = true;
      }
    }
    throw const FormatException('missing_jpeg_eoi');
  }
}
