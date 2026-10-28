import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:jiabu/data/api/api_client.dart';
import 'package:jiabu/data/api/api_error.dart';
import 'package:jiabu/data/db/daos/local_store.dart';
import 'package:jiabu/data/sync/sync_engine.dart';
import 'package:jiabu/data/sync/sync_policy.dart';
import 'package:workmanager/workmanager.dart';

final class SyncTriggers {
  SyncTriggers(
    this.engine,
    this.api,
    this.store, {
    this.connectivity,
    this.scheduleTask,
    this.observeLifecycle = true,
    this.onDatabaseChanged,
    Timer Function(Duration, void Function())? timer,
  }) : timer = timer ?? Timer.new;
  final SyncEngine engine;
  final ApiClient api;
  final LocalStore store;
  final Stream<List<ConnectivityResult>>? connectivity;
  final Future<void> Function()? scheduleTask;
  final bool observeLifecycle;
  final Future<void> Function(Map<String, Object?>)? onDatabaseChanged;
  final Timer Function(Duration, void Function()) timer;
  AppLifecycleListener? _lifecycle;
  StreamSubscription<List<ConnectivityResult>>? _connectivity;
  final _outbox = <StreamSubscription<int>>[];
  Timer? _debounce;
  Timer? _databasePoll;
  Object? _lastRevision;
  Object? _lastGeneration;
  bool _polling = false;
  bool _inForeground = true;
  bool _wasOnline = false;
  bool _disposed = false;

  Future<void> start() async {
    if (observeLifecycle) {
      _lifecycle = AppLifecycleListener(
        onResume: () {
          unawaited(foreground());
        },
        onPause: _pause,
        onInactive: _pause,
      );
      _startPoll();
    }
    _connectivity = (connectivity ?? Connectivity().onConnectivityChanged)
        .listen((results) {
          unawaited(networkChanged(results));
        });
    await refreshSpaces();
    await _schedule();
    // TODO(C4): vendor battery/autostart guidance, no interface in C2.
  }

  Future<void> foreground() async {
    if (_disposed) {
      return;
    }
    _inForeground = true;
    if (observeLifecycle) {
      _startPoll();
    }
    await refreshDatabase();
    if (!_disposed) {
      await engine.runRound();
    }
  }

  void _pause() {
    _inForeground = false;
    _databasePoll?.cancel();
    _databasePoll = null;
  }

  void _startPoll() {
    _databasePoll ??= Timer.periodic(SyncPolicy.databasePoll, (_) {
      unawaited(refreshDatabase());
    });
  }

  /// Separate SQLite connections cannot broadcast drift notifications. Poll a
  /// tiny revision row only while foregrounded, then requery scoped streams.
  Future<void> refreshDatabase() async {
    if (_disposed || _polling) {
      return;
    }
    _polling = true;
    try {
      final row = await store.runtime();
      if (_disposed) {
        return;
      }
      if (row['change_revision'] != _lastRevision ||
          row['generation'] != _lastGeneration) {
        _lastRevision = row['change_revision'];
        _lastGeneration = row['generation'];
        store.invalidateStreams();
        await onDatabaseChanged?.call(row);
      }
    } on Object {
      /* A disposed partition must not create an unhandled timer error. */
    } finally {
      _polling = false;
    }
  }

  Future<void> networkChanged(List<ConnectivityResult> results) async {
    final online = results.any((result) => result != ConnectivityResult.none);
    final recovered = online && !_wasOnline;
    _wasOnline = online;
    if (recovered && !_disposed && _inForeground) {
      try {
        await api.health();
        if (!_disposed) {
          await engine.runRound();
        }
      } on ApiError {
        /* A network interface is not proof of reachability. */
      }
    }
  }

  Future<void> _schedule() async {
    final custom = scheduleTask;
    if (custom != null) {
      await custom();
      return;
    }
    await Workmanager().registerOneOffTask(
      'outbox',
      'outbox',
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingWorkPolicy.keep,
      backoffPolicy: BackoffPolicy.exponential,
    );
  }

  Future<void> refreshSpaces() async {
    for (final subscription in _outbox) {
      await subscription.cancel();
    }
    _outbox.clear();
    for (final spaceId in await store.spaceIds()) {
      int? previous;
      _outbox.add(
        store.watchOutboxCount(spaceId).listen((count) {
          if (previous != null && count > (previous ?? 0)) {
            enqueued();
          }
          previous = count;
        }),
      );
    }
  }

  void enqueued() {
    if (_disposed) {
      return;
    }
    _debounce?.cancel();
    _debounce = timer(SyncPolicy.debounce, () {
      unawaited(engine.runRound());
    });
    unawaited(_schedule());
  }

  Future<void> dispose() async {
    _disposed = true;
    _debounce?.cancel();
    _databasePoll?.cancel();
    _lifecycle?.dispose();
    await _connectivity?.cancel();
    for (final subscription in _outbox) {
      await subscription.cancel();
    }
    _outbox.clear();
  }
}
