import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

final class WindowPrivacyService {
  WindowPrivacyService({
    MethodChannel? channel,
    Future<void> Function()? afterFrame,
  }) : channel = channel ?? const MethodChannel('jiabu/window_privacy'),
       afterFrame = afterFrame ?? _nextFrame;
  final MethodChannel channel;
  final Future<void> Function() afterFrame;
  static Future<void> _nextFrame() => WidgetsBinding.instance.endOfFrame;
  final Set<String> _reasons = {};
  Future<void> _pending = Future<void>.value();
  bool get secure => _reasons.isNotEmpty;

  Future<void> releaseAfterFrame(String reason) async {
    // Keep protection until the frame which removed plaintext has completed.
    // In the background this deliberately waits until frames resume.
    await afterFrame();
    await set(reason, enabled: false);
  }

  Future<String> deviceTimezone() async {
    if (!Platform.isAndroid) {
      return 'UTC';
    }
    return await channel.invokeMethod<String>('deviceTimezone') ?? 'UTC';
  }

  Future<void> set(String reason, {required bool enabled}) {
    if (enabled) {
      _reasons.add(reason);
    } else {
      _reasons.remove(reason);
    }
    final next = secure;
    // Preserve order when lock and one-time-key modals change concurrently.
    return _pending = _pending.catchError((Object _) {}).then((_) async {
      try {
        await channel.invokeMethod<void>('setSecure', {'enabled': next});
      } on MissingPluginException {
        if (Platform.isAndroid) {
          rethrow;
        }
        // Non-Android catalog/tests have no native window. Android must have
        // the registered channel; never silently claim protection there.
      }
    });
  }
}
