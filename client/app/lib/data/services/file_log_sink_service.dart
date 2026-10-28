import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:jiabu/data/api/dto/client_logs_dto.dart';
import 'package:jiabu/data/services/log_redactor_service.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

final class FileLogSink {
  FileLogSink(
    this.directory, {
    this.maxBytes = 1024 * 1024,
    this.fileCount = 5,
  });
  final Directory directory;
  final int maxBytes;
  final int fileCount;
  Future<void> _tail = Future<void>.value();
  StreamSubscription<LogRecord>? _subscription;

  void attach() {
    _subscription = Logger.root.onRecord.listen((record) {
      unawaited(
        append(LogRedactorService().redact(record)).catchError((Object _) {
          // Logging failures must never recursively invoke the error handler.
        }),
      );
    });
  }

  File _file(int index) => File(p.join(directory.path, 'client.$index.jsonl'));

  Future<void> append(LogEntryDto entry) {
    final next = _tail.then(
      (_) => _locked(() async {
        final line = '${jsonEncode(entry.toJson())}\n';
        final size = utf8.encode(line).length;
        if (size > maxBytes) {
          return;
        }
        final current = _file(0);
        if (current.existsSync() && await current.length() + size > maxBytes) {
          final oldest = _file(fileCount - 1);
          if (oldest.existsSync()) {
            await oldest.delete();
          }
          for (var i = fileCount - 2; i >= 0; i--) {
            final file = _file(i);
            if (file.existsSync()) {
              await file.rename(_file(i + 1).path);
            }
          }
        }
        await _file(0).writeAsString(line, mode: FileMode.append, flush: true);
      }),
    );
    _tail = next.catchError((Object _) {});
    return next;
  }

  Future<T> _locked<T>(Future<T> Function() action) async {
    await directory.create(recursive: true);
    final lock = await File(p.join(directory.path, '.writer.lock'))
        .open(mode: FileMode.append);
    try {
      await lock.lock(FileLock.blockingExclusive);
      return await action();
    } finally {
      await lock.unlock();
      await lock.close();
    }
  }

  Future<List<LogEntryDto>> pending() async {
    await _tail;
    return await _locked(() async {
      final result = <LogEntryDto>[];
      for (var i = fileCount - 1; i >= 0; i--) {
        if (!_file(i).existsSync()) {
          continue;
        }
        for (final line in await _file(i).readAsLines()) {
          try {
            result.add(
              LogEntryDto.fromJson(
                (jsonDecode(line) as Map<String, Object?>)
                    .cast<String, Object?>(),
              ),
            );
          } on FormatException {
            /* Interrupted final line; no raw data is logged. */
          }
        }
      }
      return result;
    });
  }

  /// Remove only the exact snapshot accepted by the server. New crash records
  /// appended during upload remain available for the next startup.
  Future<void> acknowledge(List<LogEntryDto> accepted) => _locked(() async {
    final counts = <String, int>{};
    for (final entry in accepted) {
      final key = jsonEncode(entry.toJson());
      counts[key] = (counts[key] ?? 0) + 1;
    }
    for (var i = 0; i < fileCount; i++) {
      final file = _file(i);
      if (!file.existsSync()) {
        continue;
      }
      final keep = <String>[];
      for (final line in await file.readAsLines()) {
        if ((counts[line] ?? 0) > 0) {
          counts[line] = (counts[line] ?? 0) - 1;
        } else {
          keep.add(line);
        }
      }
      await file.writeAsString(
        keep.isEmpty ? '' : '${keep.join('\n')}\n',
        flush: true,
      );
    }
  });

  Future<void> close() async {
    await _subscription?.cancel();
    await _tail;
  }
}
