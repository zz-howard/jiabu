import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/data/services/secure_clipboard_service.dart';
import 'package:jiabu/data/services/window_privacy_service.dart';
import 'package:jiabu/domain/notification_privacy.dart';
import 'package:jiabu/domain/required_value.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  test('api_key_copy_always_marks_clipboard_sensitive', () async {
    final calls = <MethodCall>[];
    const channel = MethodChannel('jiabu/secure_clipboard');
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    await const SecureClipboardService().copy('fictional-key-not-a-credential');
    expect(calls.single.method, 'copy');
    expect(calls.single.arguments, {
      'text': 'fictional-key-not-a-credential',
      'sensitive': true,
    });
  });
  test('closing_key_keeps_secure_window_while_app_lock_enabled', () async {
    final values = <bool>[];
    const channel = MethodChannel('jiabu/window_privacy');
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'setSecure');
      values.add(
        requireValue<bool>(
          requireValue<Map<Object?, Object?>>(call.arguments)['enabled'],
        ),
      );
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final privacy = WindowPrivacyService();
    await privacy.set('app-lock', enabled: true);
    await privacy.set('api-key', enabled: true);
    await privacy.set('api-key', enabled: false);
    expect(privacy.secure, isTrue);
    expect(values, [true, true, true]);
    await privacy.set('app-lock', enabled: false);
    expect(values.last, isFalse);
  });
  test(
    'old_modal_releases_only_its_reason_after_plaintext_frame_is_gone',
    () async {
      final frame = Completer<void>();
      const channel = MethodChannel('jiabu/window_privacy');
      final flags = <bool>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        flags.add(
          requireValue<bool>(
            requireValue<Map<Object?, Object?>>(call.arguments)['enabled'],
          ),
        );
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final privacy = WindowPrivacyService(afterFrame: () => frame.future);
      await privacy.set('api-key:old', enabled: true);
      final release = privacy.releaseAfterFrame('api-key:old');
      expect(privacy.secure, isTrue);
      await privacy.set('api-key:new', enabled: true);
      frame.complete();
      await release;
      expect(privacy.secure, isTrue);
      expect(flags, everyElement(isTrue));
      await privacy.set('api-key:new', enabled: false);
      expect(privacy.secure, isFalse);
    },
  );
  test('locked_notifications_contain_only_localized_generic_message', () {
    for (final generic in ['家簿有新消息', 'Jiabu has a new message']) {
      final text = notificationText(
        appLockEnabled: true,
        content: '用户A 账户 午饭 68 元',
        genericMessage: generic,
      );
      expect(text, generic);
      expect(text, isNot(contains('68')));
      expect(text, isNot(contains('用户A')));
      expect(
        notificationText(
          appLockEnabled: false,
          content: 'fictional content',
          genericMessage: generic,
        ),
        'fictional content',
      );
    }
  });
}
