import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('brand assets have every declared resolution', () {
    final expected = <String, int>{
      for (final name in ['logo-standard', 'logo-dark-disc']) ...{
        'assets/brand/$name.png': 256,
        'assets/brand/2.0x/$name.png': 512,
        'assets/brand/3.0x/$name.png': 768,
      },
      for (final name in ['hamster-greet', 'hamster-pen', 'hamster-idle']) ...{
        'assets/brand/mascot/$name.png': 360,
        'assets/brand/mascot/2.0x/$name.png': 720,
        'assets/brand/mascot/3.0x/$name.png': 1080,
      },
    };
    for (final entry in expected.entries) {
      final file = File(entry.key);
      expect(file.existsSync(), isTrue, reason: 'missing ${entry.key}');
      final size = _pngSize(file.readAsBytesSync());
      expect(size, (entry.value, entry.value), reason: entry.key);
    }
  });
}

(int, int) _pngSize(List<int> bytes) {
  expect(bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
  final data = ByteData.sublistView(Uint8List.fromList(bytes));
  return (data.getUint32(16), data.getUint32(20));
}
