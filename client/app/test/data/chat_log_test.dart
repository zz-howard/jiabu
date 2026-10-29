import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/data/services/log_redactor_service.dart';
import 'package:logging/logging.dart';

void main() {
  test('chat_log_keeps_only_fixed_event_code_and_request_id', () {
    final redactor = LogRedactorService();
    final safe = redactor.redact(
      LogRecord(
        Level.WARNING,
        const SafeLogEvent(
          'chat_failed',
          code: 'network',
          requestId: '019a0000-0000-7000-8000-000000000001',
        ),
        'chat',
      ),
    );
    expect(safe.message, 'chat_failed:network');
    final private = redactor.redact(
      LogRecord(
        Level.WARNING,
        const SafeLogEvent(
          'chat_failed',
          code: '用户A 午饭68 synthetic-access',
          requestId: '用户A',
        ),
        'chat',
      ),
    );
    expect(private.message, 'chat_failed');
    expect(private.requestId, isNull);
  });
}
