import 'dart:async';

import 'package:jiabu/data/api/api_client.dart';
import 'package:jiabu/data/api/api_error.dart';
import 'package:jiabu/data/api/dto/sync_dto.dart';
import 'package:jiabu/data/db/daos/local_store.dart';
import 'package:jiabu/data/services/log_redactor_service.dart';
import 'package:jiabu/data/services/version_handshake_service.dart';
import 'package:jiabu/data/sync/membership_reconciler.dart';
import 'package:jiabu/data/sync/outbox_processor.dart';
import 'package:jiabu/data/sync/pull_applier.dart';
import 'package:jiabu/data/sync/sync_policy.dart';
import 'package:jiabu/domain/outbox_operation.dart';
import 'package:jiabu/domain/sync_state.dart';
import 'package:logging/logging.dart';
import 'package:uuid/uuid.dart';

final class SyncEngine {
  SyncEngine({
    required this.store,
    required this.api,
    required this.handshake,
    required this.memberships,
    required this.outbox,
    required this.pull,
    this.currentSpace,
    this.onStatus,
    this.onAuthenticationLost,
    this.onMembershipsRefreshed,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;
  final LocalStore store;
  final ApiClient api;
  final VersionHandshakeService handshake;
  final MembershipReconciler memberships;
  final OutboxProcessor outbox;
  final PullApplier pull;
  final String? Function()? currentSpace;
  final void Function(SyncStatus)? onStatus;
  final Future<void> Function()? onAuthenticationLost;
  final Future<void> Function()? onMembershipsRefreshed;
  final DateTime Function() now;
  Future<void>? _running;
  SyncStatus status = SyncStatus.idle;

  void _status(SyncStatus next) {
    status = next;
    onStatus?.call(next);
  }

  Future<void> runRound() => _running ??= _run().whenComplete(() {
    _running = null;
  });

  /// CW authoritative refresh must contact the server even when another isolate
  /// owns the upload round. Cursor compare-and-set prevents a late read from
  /// overwriting a newer committed pull page.
  Future<void> refreshChat(String spaceId) async {
    while (true) {
      final captured = await store.fence(spaceId);
      if (captured == null) {
        throw const ApiError('stale_response');
      }
      final cursor = await store.cursor(spaceId);
      final response = await api.pull(
        PullRequestDto(spaces: {spaceId: cursor}),
      );
      if (response.unavailable.contains(spaceId)) {
        throw const ApiError('not_found', status: 404);
      }
      final page = response.spaces
          .where((page) => page.spaceId == spaceId)
          .single;
      final accepted = await store.transaction(() async {
        await store.lockRuntime();
        if (!await store.accepts(captured)) {
          throw const ApiError('stale_response');
        }
        if (await store.cursor(spaceId) != cursor) {
          return false;
        }
        await pull.applyPage(page, requestedCursor: cursor);
        return true;
      });
      if (accepted && !page.hasMore) {
        return;
      }
    }
  }

  Future<void> _run() async {
    if ((await store.runtime())['authenticated'] != 1) {
      _status(SyncStatus.loginRequired);
      await onAuthenticationLost?.call();
      return;
    }
    final owner = const Uuid().v7();
    if (!await store.acquireRound(
      owner,
      now().millisecondsSinceEpoch,
      now().add(SyncPolicy.lease).millisecondsSinceEpoch,
    )) {
      return;
    }
    final generation = (await store.runtime())['generation'];
    final forcedAtStart = handshake.forcedGeneration;
    Timer? heartbeat;
    try {
      heartbeat = Timer.periodic(SyncPolicy.heartbeat, (_) {
        unawaited(
          store
              .renewRound(
                owner,
                now().add(SyncPolicy.lease).millisecondsSinceEpoch,
              )
              .catchError((Object _) => false),
        );
      });
      _status(SyncStatus.syncing);
      final compatible = await handshake.check();
      if (!await _active(owner, generation)) {
        return;
      }
      await store.setWriteAllowed(
        allowed: compatible != SyncStatus.clientTooOld,
      );
      if (compatible != SyncStatus.idle) {
        _status(compatible);
        return;
      }
      var membersFresh = false;
      Future<void> reconcile() async {
        membersFresh = false;
        final requestedIds = await store.spaceIds();
        final requestedFences = <String, RequestFence>{};
        for (final id in requestedIds) {
          final fence = await store.fence(id);
          if (fence == null) {
            return;
          }
          requestedFences[id] = fence;
        }
        final spaces = await api.spaces();
        await store.transaction(() async {
          if (!await _active(owner, generation)) {
            return;
          }
          final currentIds = await store.spaceIds();
          if (currentIds.length != requestedIds.length ||
              !currentIds.toSet().containsAll(requestedIds)) {
            return;
          }
          for (final fence in requestedFences.values) {
            if (!await store.accepts(fence)) {
              return;
            }
          }
          await memberships.reconcile(spaces);
          membersFresh = true;
        });
        if (membersFresh && await _active(owner, generation)) {
          await onMembershipsRefreshed?.call();
        }
      }

      await reconcile();
      if (!membersFresh || !await _active(owner, generation)) {
        return;
      }
      await outbox.drain(owner, reconcile: reconcile);
      if (!membersFresh) {
        return;
      }
      if ((await store.runtime())['write_allowed'] == 0) {
        _status(SyncStatus.clientTooOld);
        return;
      }
      final ids = await store.spaceIds();
      final current = currentSpace?.call();
      if (ids.remove(current)) {
        ids.insert(0, current ?? '');
      }
      for (final spaceId in ids) {
        while (await _active(owner, generation)) {
          final fence = await store.fence(spaceId);
          if (fence == null) {
            break;
          }
          final cursor = await store.cursor(spaceId);
          final response = await api.pull(
            PullRequestDto(spaces: {spaceId: cursor}),
          );
          var more = false;
          var unavailable = false;
          await store.transaction(() async {
            if (!await _active(owner, generation) ||
                !await store.accepts(fence)) {
              return;
            }
            if (response.unavailable.contains(spaceId)) {
              unavailable = true;
              return;
            }
            if (response.spaces.length != 1 ||
                response.spaces.single.spaceId != spaceId) {
              throw const ApiError('invalid_pull_response');
            }
            final page = response.spaces.single;
            await pull.applyPage(page, requestedCursor: cursor);
            more = page.hasMore;
          });
          if (unavailable) {
            await reconcile();
          }
          if (!more) {
            break;
          }
        }
      }
      if (await _active(owner, generation)) {
        await memberships.cache.expireUploaded(now());
        Logger('sync').info(const SafeLogEvent('sync_complete'));
        _status(SyncStatus.idle);
      }
    } on ApiError catch (error) {
      if (!await _active(owner, generation)) {
        return;
      }
      Logger('sync').warning(
        SafeLogEvent(
          'sync_failed',
          code: error.code,
          requestId: error.requestId,
        ),
      );
      if (error.status == 401) {
        _status(SyncStatus.loginRequired);
        await onAuthenticationLost?.call();
        if ((await store.runtime())['generation'] == generation) {
          await store.activate(authenticated: false);
        }
      } else if (error.status == 426) {
        await store.setWriteAllowed(allowed: false);
        _status(SyncStatus.clientTooOld);
        try {
          final result = handshake.forcedGeneration != forcedAtStart
              ? handshake.lastForcedStatus
              : await handshake.on426();
          if (await _active(owner, generation)) {
            _status(
              result == SyncStatus.idle
                  ? SyncStatus.clientTooOld
                  : result ?? SyncStatus.clientTooOld,
            );
          }
        } on Object {
          /* Keep the 426 gate when /meta cannot be refreshed. */
        }
      } else {
        _status(
          (await store.runtime())['write_allowed'] == 0
              ? SyncStatus.clientTooOld
              : error.code == 'network'
              ? SyncStatus.offline
              : SyncStatus.retryLater,
        );
      }
    } on Object catch (error, stack) {
      if (await _active(owner, generation)) {
        _status(SyncStatus.retryLater);
      }
      Logger('sync').severe(const SafeLogEvent('sync_failed'), error, stack);
      // Never stringify a database/transport error: it can contain user
      // content.
    } finally {
      heartbeat?.cancel();
      if (status == SyncStatus.syncing && await _active(owner, generation)) {
        _status(SyncStatus.retryLater);
      }
      await store.releaseRound(owner);
    }
  }

  Future<bool> _active(String owner, Object? generation) async =>
      (await store.runtime())['generation'] == generation &&
      await store.ownsRound(owner, now().millisecondsSinceEpoch);
}
