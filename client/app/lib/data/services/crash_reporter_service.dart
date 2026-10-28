import 'package:flutter/foundation.dart';
import 'package:jiabu/data/api/api_client.dart';
import 'package:jiabu/data/api/api_error.dart';
import 'package:jiabu/data/api/dto/client_logs_dto.dart';
import 'package:jiabu/data/services/device_context_service.dart';
import 'package:jiabu/data/services/file_log_sink_service.dart';
import 'package:jiabu/data/services/log_redactor_service.dart';
import 'package:logging/logging.dart';

final class CrashReporterService {
  CrashReporterService(this.sink);
  final FileLogSink sink;

  void install() {
    FlutterError.onError = (details) {
      Logger('crash').severe(
        const SafeLogEvent('flutter_error'),
        details.exception,
        details.stack,
      );
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      Logger('crash')
          .severe(const SafeLogEvent('uncaught_error'), error, stack);
      return true;
    };
  }

  Future<void> uploadPrevious(
    ApiClient api,
    DeviceContext device, {
    required Future<bool> Function() stillActive,
  }) async {
    final snapshot = await sink.pending();
    for (var offset = 0; offset < snapshot.length; offset += 100) {
      if (!await stillActive()) {
        return;
      }
      final end = (offset + 100).clamp(0, snapshot.length);
      final entries = snapshot.sublist(offset, end);
      try {
        await api.uploadLogs(
          ClientLogsDto(
            entries: entries,
            appVersion: device.appVersion,
            build: device.build,
            deviceModel: device.model,
            osVersion: device.osVersion,
          ),
        );
        if (!await stillActive()) {
          return;
        }
        await sink.acknowledge(entries);
      } on ApiError {
        return;
      }
    }
  }
}
