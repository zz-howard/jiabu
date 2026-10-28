import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:jiabu/data/api/api_client.dart';
import 'package:jiabu/data/api/dio_api_client.dart';
import 'package:jiabu/data/db/database_manager.dart';
import 'package:jiabu/data/repositories/auth_repository.dart';
import 'package:jiabu/data/repositories/local_mutations_repository.dart';
import 'package:jiabu/data/repositories/records_repository.dart';
import 'package:jiabu/data/services/app_settings_service.dart';
import 'package:jiabu/data/services/blob_cache_service.dart';
import 'package:jiabu/data/services/crash_reporter_service.dart';
import 'package:jiabu/data/services/device_context_service.dart';
import 'package:jiabu/data/services/file_log_sink_service.dart';
import 'package:jiabu/data/services/media_service.dart';
import 'package:jiabu/data/services/session_store_service.dart';
import 'package:jiabu/data/services/version_handshake_service.dart';
import 'package:jiabu/data/sync/conflict_service.dart';
import 'package:jiabu/data/sync/membership_reconciler.dart';
import 'package:jiabu/data/sync/outbox_processor.dart';
import 'package:jiabu/data/sync/pull_applier.dart';
import 'package:jiabu/data/sync/sync_engine.dart';
import 'package:jiabu/data/sync/sync_triggers.dart';
import 'package:jiabu/domain/partition.dart';
import 'package:jiabu/domain/required_value.dart';
import 'package:jiabu/domain/sync_state.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// App settings/auth live above the replaceable partition ProviderScope.
final class AppRuntime {
  AppRuntime({
    required this.databases,
    required this.settings,
    required this.sessions,
    required this.device,
    this.background = false,
  }) {
    auth = LocalAuthRepository(
      databases: databases,
      settings: settings,
      sessions: sessions,
      apiFactory: api,
      activateOnResume: !background,
      onChanged: (session) {
        sessionWork = _sessionChanged(session);
      },
    );
  }
  final DatabaseManager databases;
  final AppSettingsService settings;
  final SessionStore sessions;
  final DeviceContext device;
  final bool background;
  late final LocalAuthRepository auth;
  final StreamController<void> _events = StreamController<void>.broadcast();
  Stream<void> get events => _events.stream;
  int revision = 0;
  int clearedCount = 0;
  bool spaceCleared = false;
  String? currentSpace;
  SyncStatus status = SyncStatus.idle;
  SyncEngine? engine;
  SyncTriggers? triggers;
  RecordsRepository? records;
  MediaService? media;
  ConflictService? conflicts;
  FileLogSink? _logs;
  FileLogSink? _startupLogs;
  Future<void> sessionWork = Future<void>.value();

  void installStartupLogging() {
    if (background) {
      return;
    }
    _startupLogs = FileLogSink(
      Directory(p.join(databases.root.path, 'startup-logs')),
    )..attach();
    // _startupLogs was assigned immediately above.
    CrashReporterService(_startupLogs!).install();
  }

  void notify() {
    if (!_events.isClosed) {
      _events.add(null);
    }
  }

  ApiClient api(String server, Partition? partition) {
    final capturedRevision = revision;
    final handleFuture = partition == null ? null : databases.open(partition);
    final generationFuture = handleFuture?.then(
      (handle) async => (await handle.store.runtime())['generation'],
    );
    Future<bool> valid() async {
      if (partition == null || capturedRevision != revision) {
        return false;
      }
      final generation = await generationFuture;
      final handle = await handleFuture;
      return handle != null &&
          (await handle.store.runtime())['generation'] == generation &&
          (await settings.current())?.prefix == partition.prefix;
    }

    late final DioApiClient client;
    VersionHandshakeService? directHandshake;
    return client = DioApiClient(
      server: server,
      clientHeader: device.clientHeader,
      acceptResponse: () async =>
          partition == null ? capturedRevision == revision : await valid(),
      token: () async {
        await generationFuture;
        return partition == null ? null : await sessions.read(partition);
      },
      onUnauthorized: () async {
        if (await valid() && partition != null) {
          status = SyncStatus.loginRequired;
          await auth.invalidate(
            partition,
            expectedGeneration: await generationFuture as int?,
          );
        }
      },
      onUpgradeRequired: () async {
        if (capturedRevision != revision) {
          return;
        }
        final handshake =
            engine?.handshake ??
            (directHandshake ??= VersionHandshakeService(
              client,
              build: device.build,
              channel: device.channel,
              clearCache: () => settings.clearMeta(server),
              readCache: () => settings.meta(server),
              writeCache: (meta) => settings.saveMeta(server, meta),
            ));
        final handle = await handleFuture;
        status = SyncStatus.clientTooOld;
        await handle?.store.setWriteAllowed(allowed: false);
        await settings.clearMeta(server);
        notify();
        try {
          final compatible = await handshake.on426();
          if (capturedRevision != revision ||
              (partition != null && !await valid())) {
            return;
          }
          status = compatible == SyncStatus.idle
              ? SyncStatus.clientTooOld
              : compatible ?? SyncStatus.clientTooOld;
          notify();
        } on Object {
          // The 426 remains authoritative when /meta is offline.
        }
      },
    );
  }

  Future<void> _sessionChanged(AuthSession? session) async {
    final capturedRevision = ++revision;
    spaceCleared = false;
    clearedCount = 0;
    currentSpace = null;
    if (session != null) {
      status = SyncStatus.idle;
    }
    final oldTriggers = triggers;
    triggers = null;
    engine = null;
    records = null;
    media = null;
    conflicts = null;
    notify();
    final oldLogs = _logs;
    final startupLogs = _startupLogs;
    _logs = null;
    _startupLogs = null;
    await oldTriggers?.dispose();
    await oldLogs?.close();
    await startupLogs?.close();
    if (capturedRevision != revision) {
      return;
    }
    if (session == null || session.passwordChangeRequired) {
      installStartupLogging();
      return;
    }
    final handle = auth.handle;
    if (handle == null) {
      return;
    }
    final store = handle.store;
    final generation = (await store.runtime())['generation'];
    final client = api(session.partition.server, session.partition);
    currentSpace = await settings.lastSpace(session.partition);
    final cache = BlobCacheService(store, handle.blobs);
    await cache.cleanPending();
    await cache.expireUploaded(DateTime.now());
    if (capturedRevision != revision) {
      return;
    }
    final conflictService = ConflictService(store);
    conflicts = conflictService;
    final memberships = MembershipReconciler(
      store,
      cache,
      onRemoved: (id, count) {
        if (capturedRevision != revision) {
          return;
        }
        spaceCleared = true;
        clearedCount = count;
        if (currentSpace == id) {
          currentSpace = null;
        }
        notify();
      },
    );
    final sync = SyncEngine(
      store: store,
      api: client,
      handshake: VersionHandshakeService(
        client,
        build: device.build,
        channel: device.channel,
        clearCache: () => settings.clearMeta(session.partition.server),
        readCache: () => settings.meta(session.partition.server),
        writeCache: (meta) => settings.saveMeta(session.partition.server, meta),
      ),
      memberships: memberships,
      outbox: OutboxProcessor(store, client, conflictService),
      pull: PullApplier(store),
      currentSpace: () => currentSpace,
      onStatus: (next) {
        if (capturedRevision != revision) {
          return;
        }
        status = next;
        notify();
      },
      onAuthenticationLost: () async {
        final persisted = await store.runtime();
        if (capturedRevision == revision &&
            (persisted['generation'] == generation ||
                persisted['authenticated'] == 0)) {
          await auth.invalidate(
            session.partition,
            expectedGeneration: requireValue<int>(persisted['generation']),
          );
        }
      },
      onMembershipsRefreshed: () async {
        if (capturedRevision != revision) {
          return;
        }
        final ids = await store.spaceIds();
        if (!ids.contains(currentSpace)) {
          String? fallback;
          for (final id in ids) {
            if ((await store.entity(id, 'space', id))?.data['is_default'] ==
                true) {
              fallback = id;
              break;
            }
          }
          if (capturedRevision != revision) {
            return;
          }
          currentSpace = fallback ?? ids.firstOrNull;
        }
        if (currentSpace case final String id) {
          await settings.setLastSpace(session.partition, id);
        }
        await triggers?.refreshSpaces();
        notify();
      },
    );
    engine = sync;
    final mutations = LocalMutationsRepository(
      store,
      canWrite: () => status != SyncStatus.clientTooOld,
      onEnqueued: () => triggers?.enqueued(),
    );
    records = RecordsRepository(store, mutations);
    media = MediaService(
      store: store,
      directory: handle.blobs,
      picker: PlatformImagePicker(),
      compressor: PlatformImageCompressor(),
      onEnqueued: () => triggers?.enqueued(),
    );
    if (capturedRevision != revision) {
      return;
    }
    if (!background) {
      _logs = FileLogSink(Directory(p.join(handle.directory.path, 'logs')))
        ..attach();
      // _logs was assigned synchronously above.
      final reporter = CrashReporterService(_logs!)..install();
      if (startupLogs != null) {
        unawaited(
          CrashReporterService(startupLogs).uploadPrevious(
            client,
            device,
            stillActive: () async =>
                capturedRevision == revision &&
                (await store.runtime())['generation'] == generation,
          ),
        );
      }
      unawaited(
        reporter.uploadPrevious(
          client,
          device,
          stillActive: () async =>
              capturedRevision == revision &&
              (await store.runtime())['generation'] == generation,
        ),
      );
      final nextTriggers = SyncTriggers(
        sync,
        client,
        store,
        onDatabaseChanged: (row) async {
          if (capturedRevision != revision) {
            return;
          }
          if (row['authenticated'] != 1) {
            status = SyncStatus.loginRequired;
            await auth.invalidate(
              session.partition,
              expectedGeneration: requireValue<int>(row['generation']),
            );
            return;
          }
          final notices = (jsonDecode(
            requireValue<String>(row['notices_json']),
          ) as List<Object?>).cast<Map<String, Object?>>();
          spaceCleared = notices.isNotEmpty;
          clearedCount = notices.fold<int>(
            0,
            (sum, notice) => sum + requireValue<int>(notice['count']),
          );
          final ids = await store.spaceIds();
          if (!ids.contains(currentSpace)) {
            currentSpace = null;
            for (final id in ids) {
              if ((await store.entity(id, 'space', id))?.data['is_default'] ==
                  true) {
                currentSpace = id;
                break;
              }
            }
            currentSpace ??= ids.firstOrNull;
          }
          if (capturedRevision != revision) {
            return;
          }
          if (currentSpace case final String id) {
            await settings.setLastSpace(session.partition, id);
          }
          notify();
        },
      );
      triggers = nextTriggers;
      await nextTriggers.start();
      if (capturedRevision != revision) {
        await nextTriggers.dispose();
        return;
      }
      unawaited(
        sync.runRound().then((_) async {
          if (capturedRevision != revision) {
            return;
          }
          final ids = await store.spaceIds();
          if (!ids.contains(currentSpace)) {
            for (final id in ids) {
              if ((await store.entity(id, 'space', id))?.data['is_default'] ==
                  true) {
                currentSpace = id;
                break;
              }
            }
            currentSpace ??= ids.firstOrNull;
          }
          if (currentSpace case final String id) {
            await settings.setLastSpace(session.partition, id);
          }
          await nextTriggers.refreshSpaces();
          notify();
        }),
      );
    }
    notify();
  }

  Future<void> close() async {
    await triggers?.dispose();
    await _logs?.close();
    await _startupLogs?.close();
    await databases.close();
    await _events.close();
  }

  Future<void> dismissRemovalNotice() async {
    final handle = auth.handle;
    if (handle == null) {
      return;
    }
    final capturedRevision = revision;
    await handle.store.clearNotices();
    if (capturedRevision != revision) {
      return;
    }
    spaceCleared = false;
    clearedCount = 0;
    notify();
  }

  static Future<AppRuntime> create({
    bool background = false,
    String channel = 'beta',
  }) async {
    final directory = await getApplicationSupportDirectory();
    return AppRuntime(
      databases: DatabaseManager(Directory(p.join(directory.path, 'jiabu'))),
      settings: AppSettingsService(PreferencesStorage()),
      sessions: const SecureSessionStore(),
      device: await DeviceContext.load(channel: channel),
      background: background,
    );
  }
}
