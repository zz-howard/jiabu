import 'dart:convert';

import 'package:jiabu/data/db/daos/local_store.dart';
import 'package:jiabu/domain/entity_ref.dart';
import 'package:jiabu/domain/outbox_operation.dart';
import 'package:jiabu/domain/required_value.dart';
import 'package:jiabu/domain/result.dart';
import 'package:uuid/uuid.dart';

final class ConflictService {
  ConflictService(
    this.store, {
    DateTime Function()? now,
    String Function()? newId,
  }) : now = now ?? DateTime.now,
       newId = newId ?? const Uuid().v7;
  final LocalStore store;
  final DateTime Function() now;
  final String Function() newId;

  Future<void> applySuccess(
    String spaceId,
    String kind,
    Object id,
    Map<String, Object?> server,
  ) async {
    final key = EntityRef(kind, id.toString()).key;
    final local = await store.entity(spaceId, kind, id);
    final remaining = (await store.outbox(spaceId))
        .any((op) => op.entityIds.contains(key));
    await store.putEntity(
      spaceId,
      kind,
      remaining && local != null ? local.data : server,
      state: remaining ? 'pending' : 'synced',
      baseVersion: server['version'] as int?,
    );
  }

  /// Called inside the whole batch transaction; mine includes edits made while
  /// the request was in flight, not merely the rejected operation's arguments.
  Future<void> captureConflict(
    String spaceId,
    String kind,
    String id,
    Map<String, Object?> current,
  ) async {
    final local = await store.entity(spaceId, kind, id);
    if (local == null) {
      throw const FormatException('conflict_missing_local');
    }
    await store.putConflict(
      spaceId,
      kind,
      id,
      local.data,
      requireValue<int>(current['version']),
      current['status'] as String?,
      now().millisecondsSinceEpoch,
    );
    final key = EntityRef(kind, id).key;
    for (final op in await store.outbox(spaceId)) {
      if (op.entityIds.contains(key)) {
        await store.removeOp(spaceId, op.id);
      } else if (op.dependsOn.contains(key)) {
        await store.setOutboxState(spaceId, op.id, 'blocked');
      }
    }
    await store.putEntity(
      spaceId,
      kind,
      current,
      state: 'conflict',
      baseVersion: requireValue<int>(current['version']),
    );
  }

  Future<Result<void>> resolveWithServer(
    String spaceId,
    String kind,
    String id,
  ) => _resolve(spaceId, kind, id, useMine: false, restore: false);
  Future<Result<void>> acknowledgeVoided(
    String spaceId,
    String kind,
    String id,
  ) => _resolve(spaceId, kind, id, useMine: false, restore: false);
  Future<Result<void>> resolveWithMine(
    String spaceId,
    String kind,
    String id,
  ) => _resolve(spaceId, kind, id, useMine: true, restore: false);
  Future<Result<void>> restoreAndApplyMine(String spaceId, String id) =>
      _resolve(spaceId, 'record', id, useMine: true, restore: true);

  Future<Result<void>> _resolve(
    String spaceId,
    String kind,
    String id, {
    required bool useMine,
    required bool restore,
  }) => store.transaction(() async {
    final conflict = await store.conflict(spaceId, kind, id);
    final row = await store.entity(spaceId, kind, id);
    final fence = await store.fence(spaceId);
    if (conflict == null || row == null) {
      return const Failure<void>('not_found');
    }
    if (fence == null) {
      return const Failure<void>('unauthenticated');
    }
    if (useMine && (await store.runtime())['write_allowed'] != 1) {
      return const Failure<void>('client_too_old');
    }
    if (useMine && conflict['server_status'] == 'voided' && !restore) {
      return const Failure<void>('explicit_restore_required');
    }
    if (restore &&
        (kind != 'record' || conflict['server_status'] != 'voided')) {
      return const Failure<void>('restore_not_required');
    }
    final mine = (jsonDecode(
      requireValue<String>(conflict['mine_json']),
    ) as Map<String, Object?>).cast<String, Object?>();
    final key = EntityRef(kind, id).key;
    final created = now().microsecondsSinceEpoch;
    if (useMine) {
      final voidMine =
          kind == 'record' &&
          mine['status'] == 'voided' &&
          conflict['server_status'] == 'active' &&
          !restore;
      if (restore) {
        await store.enqueue(
          OutboxOperation(
            id: newId(),
            spaceId: spaceId,
            joinEpoch: fence.joinEpoch,
            kind: 'tool',
            payload: {
              'tool': 'restore_record',
              'args': {'id': id},
            },
            entityIds: {key},
            dependsOn: const {},
            requestId: newId(),
            createdAt: created,
          ),
        );
      }
      await store.enqueue(
        OutboxOperation(
          id: newId(),
          spaceId: spaceId,
          joinEpoch: fence.joinEpoch,
          kind: 'tool',
          payload: {
            'tool': voidMine
                ? 'void_record'
                : switch (kind) {
                    'tag' => 'rename_tag',
                    'allocation_plan' => 'set_allocation_plan',
                    _ => 'update_$kind',
                  },
            // The current void_record schema only accepts id / version; the
            // server assigns void_reason=user. Keep mine intact locally until
            // acknowledgement, without sending an unsupported argument.
            'args': voidMine ? {'id': id} : _updateArgs(kind, id, mine),
          },
          entityIds: {key},
          dependsOn: {
            if (!voidMine)
              for (final hash
                  in (mine['attachments'] as List<Object?>? ?? const []))
                if (!(row.data['attachments'] as List<Object?>? ?? const [])
                    .contains(hash))
                  EntityRef.blob('ledger', hash as String),
          },
          requestId: newId(),
          createdAt: created + (restore ? 1 : 0),
        ),
      );
      await store.putEntity(
        spaceId,
        kind,
        {
          ...mine,
          if (restore) 'status': 'active',
          if (restore) 'void_reason': null,
        },
        state: 'pending',
        baseVersion: requireValue<int>(conflict['server_version']),
      );
      // A pre-existing refund must wait behind this newly queued resolution,
      // especially restore -> update. Preserve its operation identity/payload.
      await store.deferDependents(spaceId, key);
    } else {
      await store.putEntity(
        spaceId,
        kind,
        row.data,
        baseVersion: requireValue<int>(conflict['server_version']),
      );
    }
    await store.removeConflict(spaceId, kind, id);
    await unblockResolvedDependents(spaceId);
    return const Ok<void>(null);
  });

  Map<String, Object?> _updateArgs(
    String kind,
    String id,
    Map<String, Object?> mine,
  ) {
    final editable = switch (kind) {
      'record' => [
        'amount_minor',
        'occurred_on',
        'account_id',
        'to_account_id',
        'purpose_id',
        'to_purpose_id',
        'tag_ids',
        'note',
        'attachments',
      ],
      'account' => ['name', 'opening_balance_minor', 'opening_on', 'sort_key'],
      'tag' => ['name'],
      'subject' => ['name', 'member_id'],
      'document' => ['title', 'event_date', 'subject_ids', 'content'],
      'allocation_plan' => ['amount_minor', 'day_of_month', 'enabled'],
      _ => throw ArgumentError('unsupported_conflict_entity'),
    };
    final values = {
      for (final field in editable)
        if (mine.containsKey(field)) field: mine[field],
    };
    return kind == 'record' || kind == 'document'
        ? {'id': id, 'changes': values}
        : {
            if (kind == 'allocation_plan') 'account_id': id else 'id': id,
            ...values,
          };
  }

  Future<void> unblockResolvedDependents(String spaceId) async {
    for (final op in await store.outbox(spaceId)) {
      if (op.state != 'blocked') {
        continue;
      }
      var blocked = false;
      for (final ref in op.dependsOn) {
        final split = ref.indexOf(':');
        if (split > 0 &&
            ref.substring(0, split) != 'blob' &&
            await store.conflict(
                  spaceId,
                  ref.substring(0, split),
                  ref.substring(split + 1),
                ) !=
                null) {
          blocked = true;
        }
      }
      if (!blocked) {
        await store.setOutboxState(spaceId, op.id, 'pending');
      }
    }
  }
}
