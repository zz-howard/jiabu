import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/data/services/update_installer.dart';
import 'package:jiabu/domain/update.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/update-installer');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'verifySignature' => false,
            'canInstall' => true,
            'install' => 'cancelled',
            _ => null,
          };
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('platform installer maps methods and cancellation', () async {
    final installer = PlatformUpdateInstaller(channel: channel);
    expect(await installer.verifySignature('/cache/fake.apk'), isFalse);
    expect(await installer.canInstall(), isTrue);
    await installer.openInstallSettings();
    expect(await installer.install('/cache/fake.apk'), InstallResult.cancelled);
    expect(calls.map((call) => call.method), [
      'verifySignature',
      'canInstall',
      'openInstallSettings',
      'install',
    ]);
  });
}
