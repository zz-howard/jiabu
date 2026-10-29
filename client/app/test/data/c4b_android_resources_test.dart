import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('launcher and notification resources cover every density', () {
    const densities = {
      'mdpi': (adaptive: 108, legacy: 48, notification: 24),
      'hdpi': (adaptive: 162, legacy: 72, notification: 36),
      'xhdpi': (adaptive: 216, legacy: 96, notification: 48),
      'xxhdpi': (adaptive: 324, legacy: 144, notification: 72),
      'xxxhdpi': (adaptive: 432, legacy: 192, notification: 96),
    };
    for (final density in densities.entries) {
      for (final name in ['ic_launcher_foreground', 'ic_launcher_monochrome']) {
        _expectPng(
          'android/app/src/main/res/mipmap-${density.key}/$name.png',
          density.value.adaptive,
        );
      }
      for (final name in ['ic_launcher', 'ic_launcher_round']) {
        _expectPng(
          'android/app/src/main/res/mipmap-${density.key}/$name.png',
          density.value.legacy,
        );
      }
      _expectPng(
        'android/app/src/main/res/drawable-${density.key}/ic_stat_jia.png',
        density.value.notification,
      );
    }
  });

  test('adaptive icon XML and manifest reference every layer', () {
    for (final name in ['ic_launcher.xml', 'ic_launcher_round.xml']) {
      final xml = File('android/app/src/main/res/mipmap-anydpi-v26/$name')
          .readAsStringSync();
      expect(xml, contains('@color/ic_launcher_background'));
      expect(xml, contains('@mipmap/ic_launcher_foreground'));
      expect(xml, contains('@mipmap/ic_launcher_monochrome'));
    }
    final background = File(
      'android/app/src/main/res/values/ic_launcher_background.xml',
    ).readAsStringSync();
    expect(background, contains('#F6EFE2'));
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    expect(manifest, contains('android:icon="@mipmap/ic_launcher"'));
    expect(manifest, contains('android:roundIcon="@mipmap/ic_launcher_round"'));
    expect(manifest, contains('TODO(notifications)'));
  });
}

void _expectPng(String path, int dimension) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: 'missing $path');
  final bytes = file.readAsBytesSync();
  expect(bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
  final data = ByteData.sublistView(Uint8List.fromList(bytes));
  expect((data.getUint32(16), data.getUint32(20)), (dimension, dimension));
}
