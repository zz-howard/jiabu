import 'dart:typed_data';

import 'package:image/image.dart' as image;

Uint8List testJpeg({int width = 3, int height = 2, bool gps = false}) {
  final pixels = image.Image(width: width, height: height)
    ..clear(image.ColorRgb8(60, 120, 180));
  final jpeg = Uint8List.fromList(image.encodeJpg(pixels, quality: 90));
  if (!gps) {
    return jpeg;
  }
  // Little-endian TIFF: IFD0 holds Orientation=6 and a GPS IFD pointer.
  // GPS IFD holds GPSVersionID=2.3.0.0, a valid GPS directory with no real
  // location.
  final tiff = Uint8List(50);
  final data = ByteData.sublistView(tiff);
  tiff[0] = 0x49;
  tiff[1] = 0x49;
  data
    ..setUint16(2, 42, Endian.little)
    ..setUint32(4, 8, Endian.little)
    ..setUint16(8, 2, Endian.little)
    ..setUint16(10, 0x112, Endian.little)
    ..setUint16(12, 3, Endian.little)
    ..setUint32(14, 1, Endian.little)
    ..setUint16(18, 6, Endian.little)
    ..setUint16(22, 0x8825, Endian.little)
    ..setUint16(24, 4, Endian.little)
    ..setUint32(26, 1, Endian.little)
    ..setUint32(30, 38, Endian.little)
    ..setUint16(38, 1, Endian.little)
    ..setUint16(40, 0, Endian.little)
    ..setUint16(42, 1, Endian.little)
    ..setUint32(44, 4, Endian.little);
  tiff[48] = 2;
  tiff[49] = 3;
  final exif = [69, 120, 105, 102, 0, 0, ...tiff, 0, 0, 0, 0, 0, 0];
  List<int> app(int marker, List<int> payload) => [
    0xff,
    marker,
    (payload.length + 2) >> 8,
    (payload.length + 2) & 255,
    ...payload,
  ];
  return Uint8List.fromList([
    0xff,
    0xd8,
    ...app(0xe1, exif),
    ...app(
      0xe1,
      'http://ns.adobe.com/xap/1.0/\u0000<fictional-xmp/>'.codeUnits,
    ),
    ...jpeg.skip(2),
    ...'fictional-tail'.codeUnits,
  ]);
}

/// Independent EXIF directory reader used only by assertions. It does not use
/// JpegSanitizerService's segment parser or its metadata-removal predicate.
bool containsGpsIfd(Uint8List jpeg) {
  for (var at = 2; at + 10 < jpeg.length; at++) {
    if (jpeg[at] != 69 ||
        jpeg[at + 1] != 120 ||
        jpeg[at + 2] != 105 ||
        jpeg[at + 3] != 102) {
      continue;
    }
    final start = at + 6;
    final bytes = ByteData.sublistView(jpeg, start);
    if (bytes.getUint16(0, Endian.little) != 0x4949) {
      continue;
    }
    final ifd = bytes.getUint32(4, Endian.little);
    final count = bytes.getUint16(ifd, Endian.little);
    for (var i = 0; i < count; i++) {
      final entry = ifd + 2 + i * 12;
      if (bytes.getUint16(entry, Endian.little) == 0x8825) {
        final gps = bytes.getUint32(entry + 8, Endian.little);
        return bytes.getUint16(gps, Endian.little) > 0;
      }
    }
  }
  return false;
}
