import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/data/services/log_redactor_service.dart';
import 'package:logging/logging.dart';

Future<LogRecord> _record(SafeLogEvent event) async {
  final logger = Logger.detached('chat');
  final record = logger.onRecord.first;
  logger.warning(event);
  return await record;
}

void main() {
  test('chat_log_keeps_only_fixed_event_code_and_request_id', () async {
    final redactor = LogRedactorService();
    final safe = redactor.redact(
      await _record(
        const SafeLogEvent(
          'chat_failed',
          code: 'network',
          requestId: '019a0000-0000-7000-8000-000000000001',
        ),
      ),
    );
    expect(safe.message, 'chat_failed:network');
    final private = redactor.redact(
      await _record(
        const SafeLogEvent(
          'chat_failed',
          code: '用户A 午饭68 synthetic-access',
          requestId: '用户A',
        ),
      ),
    );
    expect(private.message, 'chat_failed');
    expect(private.requestId, isNull);
  });
}
