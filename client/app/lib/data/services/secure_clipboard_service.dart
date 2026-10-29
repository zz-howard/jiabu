import 'package:flutter/services.dart';

final class SecureClipboardService {
  const SecureClipboardService({
    this.channel = const MethodChannel('jiabu/secure_clipboard'),
  });
  final MethodChannel channel;

  Future<void> copy(String key) =>
      channel.invokeMethod<void>('copy', {'text': key, 'sensitive': true});
}
