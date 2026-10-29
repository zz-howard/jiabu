import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/data/services/app_lock_service.dart';
import 'package:jiabu/data/services/biometric_auth_service.dart';
import 'package:jiabu/data/services/lock_credentials_service.dart';
import 'package:jiabu/data/services/window_privacy_service.dart';
import 'package:jiabu/domain/app_lock.dart';

import '../support/memory_stores.dart';

class MemoryLockStorage implements LockStorage {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

class FakeBiometrics implements BiometricAuthService {
  @override
  Future<bool> available() async => true;
  Future<bool> Function() respond = () async => true;
  @override
  Future<bool> authenticate(String reason) => respond();
}

class TestCredentials implements LockCredentials {
  @override
  Future<void> save(String scope, String kind, String value) async {}
  @override
  Future<bool> verify(String scope, String kind, String value) async =>
      value == '1234';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DateTime now;
  late MemorySettings settings;
  late FakeBiometrics biometrics;
  late AppLockService lock;
  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('jiabu/window_privacy'),
          (_) async => null,
        );
    now = DateTime.utc(2026, 10, 29);
    settings = MemorySettings();
    biometrics = FakeBiometrics();
    settings.values['lock_config:fictional'] = jsonEncode(
      const LockConfiguration(enabled: true).toJson(),
    );
    lock = AppLockService(
      settings: settings,
      credentials: TestCredentials(),
      biometrics: biometrics,
      privacy: WindowPrivacyService(),
      clock: () => now,
    );
    await lock.load('fictional');
  });
  tearDown(() async {
    await lock.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('jiabu/window_privacy'),
          null,
        );
  });
  Future<void> unlocked() async {
    expect(lock.phase, LockPhase.locked);
    expect(await lock.authenticate(reason: 'fictional reason'), isTrue);
    lock.background();
  }

  test('cold_start_stays_locked_until_success', () async {
    expect(lock.visible, isTrue);
    biometrics.respond = () async => false;
    expect(await lock.authenticate(reason: 'fictional'), isFalse);
    expect(lock.phase, LockPhase.locked);
  });
  test('resume_before_timeout_keeps_unlocked', () async {
    await unlocked();
    now = now.add(const Duration(seconds: 59));
    lock.foreground();
    expect(lock.phase, LockPhase.unlocked);
  });
  test('resume_at_exact_timeout_requires_authentication', () async {
    await unlocked();
    now = now.add(const Duration(minutes: 1));
    lock.foreground();
    expect(lock.phase, LockPhase.locked);
    expect(lock.visible, isTrue);
  });
  for (final result in ['success', 'failure', 'cancel']) {
    test('resume_after_timeout_$result', () async {
      await unlocked();
      now = now.add(const Duration(seconds: 61));
      lock.foreground();
      biometrics.respond = () async {
        if (result == 'cancel') {
          throw PlatformException(code: 'userCanceled');
        }
        return result == 'success';
      };
      expect(await lock.authenticate(reason: 'fictional'), result == 'success');
      expect(
        lock.phase,
        result == 'success' ? LockPhase.unlocked : LockPhase.locked,
      );
    });
  }
  test('repeated_background_does_not_extend_timeout', () async {
    await unlocked();
    now = now.add(const Duration(seconds: 50));
    lock.background();
    now = now.add(const Duration(seconds: 10));
    lock.foreground();
    expect(lock.phase, LockPhase.locked);
  });
  test('late_biometric_result_cannot_unlock_another_account', () async {
    final completion = Completer<bool>();
    biometrics.respond = () => completion.future;
    final authenticating = lock.authenticate(reason: 'fictional');
    await lock.load('other');
    completion.complete(true);
    expect(await authenticating, isFalse);
    expect(lock.phase, LockPhase.disabled);
  });
  test(
    'five_failures_wait_then_double_up_to_five_minutes_and_persist',
    () async {
      for (var batch = 0; batch < 6; batch++) {
        for (var i = 0; i < 5; i++) {
          expect(await lock.authenticate(value: '0000'), isFalse);
        }
        final expected = [30, 60, 120, 240, 300, 300][batch];
        expect(
          lock.configuration.waitUntil?.difference(now).inSeconds,
          expected,
        );
        expect(await lock.authenticate(value: '1234'), isFalse);
        await lock.load('fictional');
        expect(lock.waiting, isTrue);
        now = now.add(Duration(seconds: expected));
      }
      expect(await lock.authenticate(value: '1234'), isTrue);
      expect(lock.configuration.failures, 0);
    },
  );
  test('pin_hash_is_salted_and_scope_isolated', () async {
    final storage = MemoryLockStorage();
    final credentials = LockCredentialsService(storage, random: Random(17));
    await credentials.save('a', 'pin', '1234');
    await credentials.save('b', 'pin', '1234');
    expect(storage.values['lock:a:pin'], isNot(storage.values['lock:b:pin']));
    expect(storage.values.values.join(), isNot(contains('1234')));
    expect(await credentials.verify('a', 'pin', '1234'), isTrue);
    expect(await credentials.verify('a', 'pin', '0000'), isFalse);
    expect(await credentials.verify('c', 'pin', '1234'), isFalse);
  });
}
