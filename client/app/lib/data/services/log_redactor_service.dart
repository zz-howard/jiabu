import 'package:jiabu/data/api/dto/client_logs_dto.dart';
import 'package:logging/logging.dart';

final class SafeLogEvent {
  const SafeLogEvent(this.event, {this.code, this.requestId});
  final String event;
  final String? code;
  final String? requestId;
  @override
  String toString() => event;
}

final class LogRedactorService {
  static const _events = {
    'startup',
    'sync_complete',
    'sync_failed',
    'flutter_error',
    'uncaught_error',
    'log_upload_failed',
    'background_sync',
    'chat_failed',
  };
  static const _codes = {
    'network',
    'unauthenticated',
    'account_disabled',
    'version_conflict',
    'membership_changed',
    'rate_limited',
    'upload_busy',
    'client_too_old',
    'server_too_old',
    'internal',
    'unavailable',
  };

  LogEntryDto redact(LogRecord record) {
    final object = record.object;
    final event = object is SafeLogEvent && _events.contains(object.event)
        ? object.event
        : 'redacted_event';
    final code = object is SafeLogEvent && _codes.contains(object.code)
        ? object.code
        : null;
    final requestId =
        object is SafeLogEvent &&
            RegExp(
              '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0'
              r'-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
            ).hasMatch(object.requestId ?? '')
        ? object.requestId
        : null;
    final frames = RegExp(r'(?:package|dart):[a-zA-Z0-9_./-]+(?::\d+){0,2}')
        .allMatches(record.stackTrace?.toString() ?? '')
        .map((m) => m.group(0) ?? '')
        .where((line) => !line.contains('jiabu_pat_'))
        .take(30)
        .join('\n');
    final level =
        const {
          'FINEST',
          'FINER',
          'FINE',
          'CONFIG',
          'INFO',
          'WARNING',
          'SEVERE',
          'SHOUT',
        }.contains(record.level.name)
        ? record.level.name
        : 'INFO';
    return LogEntryDto(
      ts: record.time.toUtc(),
      level: level,
      logger: 'jiabu',
      message: code == null ? event : '$event:$code',
      errorType: record.error == null ? null : 'CapturedError',
      stack: frames.isEmpty
          ? null
          : frames.substring(0, frames.length > 8192 ? 8192 : frames.length),
      requestId: requestId,
    );
  }
}
