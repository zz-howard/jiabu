import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:jiabu/data/api/api_client.dart';
import 'package:jiabu/data/api/api_error.dart';
import 'package:jiabu/data/api/chat_api.dart';
import 'package:jiabu/data/api/dio_api_client.dart';
import 'package:jiabu/data/db/database_manager.dart';
import 'package:jiabu/data/repositories/api_keys_repository.dart';
import 'package:jiabu/data/repositories/auth_repository.dart';
import 'package:jiabu/data/repositories/chat_repository.dart';
import 'package:jiabu/data/repositories/ledger_repository.dart';
import 'package:jiabu/data/repositories/local_mutations_repository.dart';
import 'package:jiabu/data/repositories/records_repository.dart';
import 'package:jiabu/data/repositories/spaces_repository.dart';
import 'package:jiabu/data/services/app_lock_service.dart';
import 'package:jiabu/data/services/app_settings_service.dart';
import 'package:jiabu/data/services/biometric_auth_service.dart';
import 'package:jiabu/data/services/blob_cache_service.dart';
import 'package:jiabu/data/services/crash_reporter_service.dart';
import 'package:jiabu/data/services/device_context_service.dart';
import 'package:jiabu/data/services/file_log_sink_service.dart';
import 'package:jiabu/data/services/lock_credentials_service.dart';
import 'package:jiabu/data/services/media_service.dart';
import 'package:jiabu/data/services/network_status_service.dart';
import 'package:jiabu/data/services/secure_clipboard_service.dart';
import 'package:jiabu/data/services/session_store_service.dart';
import 'package:jiabu/data/services/version_handshake_service.dart';
import 'package:jiabu/data/services/window_privacy_service.dart';
import 'package:jiabu/data/sync/conflict_service.dart';
import 'package:jiabu/data/sync/membership_reconciler.dart';
import 'package:jiabu/data/sync/outbox_processor.dart';
import 'package:jiabu/data/sync/pull_applier.dart';
import 'package:jiabu/data/sync/sync_engine.dart';
import 'package:jiabu/data/sync/sync_triggers.dart';
import 'package:jiabu/domain/api_keys.dart';
import 'package:jiabu/domain/chat.dart';
import 'package:jiabu/domain/ledger.dart';
import 'package:jiabu/domain/partition.dart';
import 'package:jiabu/domain/required_value.dart';
import 'package:jiabu/domain/spaces.dart';
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
    this.createDio,
    this.beforeSessionInitialization,
    BiometricAuthService? biometricAuth,
    WindowPrivacyService? windowPrivacy,
  }) : privacy = windowPrivacy ?? WindowPrivacyService() {
    lock = AppLockService(
      settings: settings.storage,
      credentials: LockCredentialsService(const SecureLockStorage()),
      biometrics: biometricAuth ?? PlatformBiometricAuth(),
      privacy: privacy,
    );
    network = NetworkStatusService(
      probe: () async {
        final partition = await settings.current();
        if (partition == null) {
          throw StateError('no_server');
        }
        await api(partition.server, null).health();
      },
      onChanged: notify,
    );
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
  final Dio Function()? createDio;

  /// Allows tests to pause after auth commits and before runtime
  /// initialization.
  final Future<void> Function(AuthSession)? beforeSessionInitialization;
  late final LocalAuthRepository auth;
  final StreamController<void> _events = StreamController<void>.broadcast();
  Stream<void> get events => _events.stream;
  final WindowPrivacyService privacy;
  final clipboard = const SecureClipboardService();
  late final AppLockService lock;
  late final NetworkStatusService network;
  SpacesRepository? spaces;
  ApiKeysRepository? apiKeys;
  int spaceRevision = 0;
  int revision = 0;
  int clearedCount = 0;
  bool spaceCleared = false;
  String? currentSpace;
  SyncStatus status = SyncStatus.idle;
  bool get managementOnline =>
      network.online && status != SyncStatus.clientTooOld;
  SyncEngine? engine;
  SyncTriggers? triggers;
  RecordsRepository? records;
  LedgerRepository? ledger;
  MediaService? media;
  ChatRepository? chat;
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

  ApiClient api(String server, Partition? partition, {int? sessionGeneration}) {
    final capturedRevision = revision;
    final handleFuture = partition == null ? null : databases.open(partition);
    final generationFuture = handleFuture?.then(
      (handle) async =>
          sessionGeneration ?? (await handle.store.runtime())['generation'],
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
      dio: createDio?.call(),
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
    final oldChat = chat;
    chat = null;
    final oldTriggers = triggers;
    triggers = null;
    engine = null;
    spaces = null;
    apiKeys = null;
    records = null;
    ledger = null;
    media = null;
    conflicts = null;
    notify();
    if (!background) {
      await lock.load(session?.partition.prefix);
    }
    final oldLogs = _logs;
    final startupLogs = _startupLogs;
    _logs = null;
    _startupLogs = null;
    await oldTriggers?.dispose();
    await oldChat?.dispose();
    await oldLogs?.close();
    await startupLogs?.close();
    if (capturedRevision != revision) {
      return;
    }
    if (session == null || session.passwordChangeRequired) {
      installStartupLogging();
      return;
    }
    await beforeSessionInitialization?.call(session);
    if (capturedRevision != revision) {
      return;
    }
    final handle = auth.handle;
    if (handle == null) {
      return;
    }
    final store = handle.store;
    final generation = session.generation;
    Future<void> authenticationLost() async {
      if (capturedRevision != revision) {
        return;
      }
      status = SyncStatus.loginRequired;
      await auth.invalidate(session.partition, expectedGeneration: generation);
      if (capturedRevision == revision) {
        // Another instance changed the generation. Only detach this runtime;
        // its captured credentials no longer own the shared session.
        auth.clearLocalSession();
      }
    }

    final client = api(
      session.partition.server,
      session.partition,
      sessionGeneration: generation,
    );
    currentSpace = await settings.lastSpace(session.partition);
    final cache = BlobCacheService(store, handle.blobs);
    await cache.cleanPending();
    await cache.expireUploaded(DateTime.now());
    if (capturedRevision != revision) {
      return;
    }
    void notifyEnqueued() => triggers?.enqueued();
    final conflictService = ConflictService(store, onEnqueued: notifyEnqueued);
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
          spaceRevision++;
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
      outbox: OutboxProcessor(
        store,
        client,
        conflictService,
        chatApi: client as ChatApi,
      ),
      pull: PullApplier(store),
      currentSpace: () => currentSpace,
      onStatus: (next) {
        if (capturedRevision != revision) {
          return;
        }
        status = next;
        if (next == SyncStatus.idle) {
          network.reached();
        }
        if (next == SyncStatus.offline) {
          network.failed();
        }
        notify();
      },
      onAuthenticationLost: authenticationLost,
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
    spaces = LocalSpacesRepository(
      api: client,
      store: store,
      online: () => network.online && status != SyncStatus.clientTooOld,
      valid: () => revision == capturedRevision,
      selectSpace: switchSpace,
      refresh: () async {
        // Reuse C2's transaction, purge/outbox/blob cleanup and join_epoch rules.
        final requestedIds = await store.spaceIds();
        final fences = [for (final id in requestedIds) await store.fence(id)];
        final directory = await client.spaces();
        await store.transaction(() async {
          if (revision != capturedRevision) {
            throw const ApiError('stale_response');
          }
          final ids = await store.spaceIds();
          if (ids.length != requestedIds.length ||
              !ids.toSet().containsAll(requestedIds)) {
            throw const ApiError('stale_response');
          }
          for (final fence in fences) {
            if (fence == null || !await store.accepts(fence)) {
              throw const ApiError('stale_response');
            }
          }
          await memberships.reconcile(directory);
        });
        final ids = await store.spaceIds();
        if (!ids.contains(currentSpace)) {
          currentSpace =
              directory.spaces
                  .where((space) => space.isDefault)
                  .firstOrNull
                  ?.id ??
              ids.firstOrNull;
          spaceRevision++;
        }
        if (currentSpace case final String id) {
          await settings.setLastSpace(session.partition, id);
        }
        await triggers?.refreshSpaces();
        notify();
        unawaited(sync.runRound());
      },
    );
    apiKeys = OnlineApiKeysRepository(
      client,
      online: () => network.online && status != SyncStatus.clientTooOld,
    );
    final mutations = LocalMutationsRepository(
      store,
      canWrite: () => status != SyncStatus.clientTooOld,
      onEnqueued: notifyEnqueued,
    );
    final recordRepository = RecordsRepository(store, mutations);
    records = recordRepository;
    ledger = LocalLedgerRepository(
      store,
      mutations,
      recordRepository,
      conflictService,
      api: client,
    );
    final mediaService = MediaService(
      store: store,
      directory: handle.blobs,
      picker: PlatformImagePicker(),
      compressor: PlatformImageCompressor(),
      onEnqueued: notifyEnqueued,
    );
    media = mediaService;
    chat = LocalChatRepository(
      dao: store,
      api: client as ChatApi,
      sync: (spaceId) async {
        await sync.runRound();
        if (sync.status != SyncStatus.idle) throw const ApiError('unavailable');
        await sync.refreshChat(spaceId);
      },
      media: mediaService,
      memberForSpace: (id) async =>
          (await store.entity(id, 'space', id))?.data['member_id'] as String?,
      onEnqueued: notifyEnqueued,
    );
    if (capturedRevision != revision) {
      await chat?.dispose();
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
        onChatForeground: () async {
          await chat?.foreground();
        },
        onChatDisconnect: () async {
          await chat?.disconnect();
        },
        onDatabaseChanged: (row) async {
          if (capturedRevision != revision) {
            return;
          }
          if (row['authenticated'] != 1) {
            await authenticationLost();
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

  Future<void> switchSpace(String id) async {
    final session = auth.current;
    final store = auth.handle?.store;
    if (session == null ||
        store == null ||
        !(await store.spaceIds()).contains(id)) {
      return;
    }
    currentSpace = id;
    spaceRevision++;
    notify();
    await settings.setLastSpace(session.partition, id);
    unawaited(engine?.runRound() ?? Future<void>.value());
  }

  Future<void> close() async {
    await network.dispose();
    await lock.dispose();
    await sessionWork;
    await auth.logoutWork;
    await triggers?.dispose();
    await chat?.dispose();
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
    DatabaseManager? databases,
    AppSettingsService? settings,
    SessionStore? sessions,
    Future<DeviceContext> Function(String channel)? loadDevice,
    Dio Function()? createDio,
  }) async {
    final appSettings = settings ?? AppSettingsService(PreferencesStorage());
    if (!background) {
      // Persist before bootstrap registers any background work.
      await appSettings.setClientChannel(channel);
    }
    final runtimeChannel = background
        ? await appSettings.clientChannel()
        : channel;
    final manager =
        databases ??
        DatabaseManager(
          Directory(
            p.join((await getApplicationSupportDirectory()).path, 'jiabu'),
          ),
        );
    return AppRuntime(
      databases: manager,
      settings: appSettings,
      sessions: sessions ?? const SecureSessionStore(),
      device:
          await (loadDevice?.call(runtimeChannel) ??
              DeviceContext.load(channel: runtimeChannel)),
      background: background,
      createDio: createDio,
    );
  }
}
