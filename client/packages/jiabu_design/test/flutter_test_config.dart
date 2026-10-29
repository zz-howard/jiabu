import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu_design/jiabu_design.dart';

class JiabuTestBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  JiabuTestBinding();
  final toolsDirectory =
      Platform.environment['JIABU_TOOLS_DIR'] ??
      '${Platform.environment['HOME'] ?? '/opt/jiabu'}/dev-tools';
  final systemPath =
      Platform.environment['JIABU_TEST_FONT'] ??
      '$toolsDirectory/test-fonts/NotoSansCJKsc-Regular.otf';
  final systemFont = File(systemPath);
  if (!systemFont.existsSync()) {
    throw FileSystemException(
      'Missing pinned test font. Source jiabu-client-env.sh or set '
      'JIABU_TEST_FONT to the pinned NotoSansCJKsc-Regular.otf.',
      systemPath,
    );
  }
  final systemBytes = systemFont.readAsBytesSync();
  // Goldens depend on this exact stand-in font (client/tool/build-host/setup.sh
  // pins the same file). A different file silently changes every golden.
  const pinnedSha256 =
      '2c76254f6fc379fddfce0a7e84fb5385bb135d3e399294f6eeb6680d0365b74b';
  final actualSha256 = sha256.convert(systemBytes).toString();
  if (actualSha256 != pinnedSha256) {
    throw StateError(
      'Test font $systemPath has sha256 $actualSha256, '
      'expected $pinnedSha256 (NotoSansCJKsc-Regular.otf, setup.sh).',
    );
  }
  final systemData = ByteData.sublistView(systemBytes);
  for (final family in ['Roboto', JiabuType.systemSansFamily]) {
    await (FontLoader(family)..addFont(Future.value(systemData))).load();
  }
  const fonts = {
    JiabuType.numeralsFamily: 'jiabu_numerals.ttf',
    JiabuType.handFamily: 'jiabu_hand.ttf',
    JiabuType.serifFamily: 'jiabu_serif.otf',
  };
  for (final entry in fonts.entries) {
    final bytes = File('assets/fonts/${entry.value}').readAsBytesSync();
    final loader = FontLoader(entry.key)
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
  }
  await testMain();
}
