import 'dart:convert';

import 'package:jiabu/data/db/daos/local_store.dart';
import 'package:jiabu/data/sync/tool_dependencies.dart';
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
    this.onEnqueued,
  }) : now = now ?? DateTime.now,
       newId = newId ?? const Uuid().v7;
  final LocalStore store;
  final DateTime Function() now;
  final String Function() newId;
  final void Function()? onEnqueued;

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
    if (useMine &&
        kind == 'record' &&
        conflict['server_status'] == 'voided' &&
        !restore) {
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
      final planned = _mineOperations(
        kind,
        id,
        row.data,
        mine,
        restore: restore,
      );
      if (planned case Failure<List<_ResolutionOperation>>(:final code)) {
        return Failure<void>(code);
      }
      final operations = (planned as Ok<List<_ResolutionOperation>>).value;
      var optimistic = row.data;
      for (var index = 0; index < operations.length; index++) {
        final operation = operations[index];
        await store.enqueue(
          OutboxOperation(
            id: newId(),
            spaceId: spaceId,
            joinEpoch: fence.joinEpoch,
            kind: 'tool',
            payload: {'tool': operation.tool, 'args': operation.args},
            entityIds: {key},
            dependsOn: toolDependencies(
              operation.tool,
              operation.args,
              previous: optimistic,
            ),
            requestId: newId(),
            createdAt: created + index,
          ),
        );
        optimistic = {...optimistic, ...operation.values};
      }
      await store.putEntity(
        spaceId,
        kind,
        optimistic,
        state: operations.isEmpty ? 'synced' : 'pending',
        baseVersion: requireValue<int>(conflict['server_version']),
      );
      // Refunds and later writes sharing their references follow the entire
      // resolution. Prerequisites independent of those writes stay ahead.
      if (operations.isNotEmpty) {
        await store.deferDependents(spaceId, key);
      }
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
    store.afterCommit(onEnqueued);
    return const Ok<void>(null);
  });

  Result<List<_ResolutionOperation>> _mineOperations(
    String kind,
    String id,
    Map<String, Object?> server,
    Map<String, Object?> mine, {
    required bool restore,
  }) {
    // These are the writable fields of the actual server tool schemas. There
    // are no subject/document tools in the current registry or OpenAPI.
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
      'account' => [
        'name',
        'is_reserve',
        'opening_balance_minor',
        'opening_on',
        'sort_key',
      ],
      'tag' => ['name'],
      'allocation_plan' => ['amount_minor', 'day_of_month', 'enabled'],
      _ => null,
    };
    if (editable == null) {
      return const Failure('unsupported_conflict_resolution');
    }
    if (kind == 'account' &&
        server['archived_at'] != null &&
        mine['archived_at'] == null) {
      return const Failure('unarchive_not_supported');
    }
    if (kind == 'tag' &&
        server['deleted_at'] != null &&
        mine['deleted_at'] == null) {
      return const Failure('restore_tag_not_supported');
    }
    final changes = <String, Object?>{
      for (final field in editable)
        if (mine.containsKey(field) &&
            jsonEncode(mine[field]) != jsonEncode(server[field]))
          field: mine[field],
    };
    final operations = <_ResolutionOperation>[];
    void add(
      String tool,
      Map<String, Object?> args,
      Map<String, Object?> values,
    ) => operations.add(_ResolutionOperation(tool, args, values));

    switch (kind) {
      case 'record':
        if (restore) {
          add(
            'restore_record',
            {'id': id},
            {'status': 'active', 'void_reason': null},
          );
        }
        if (changes.isNotEmpty || restore) {
          add('update_record', {'id': id, 'changes': changes}, changes);
        }
        if (!restore &&
            mine['status'] == 'voided' &&
            server['status'] == 'active') {
          // VersionedRecord accepts only id / expected_version. The server
          // assigns void_reason=user; do not send an unsupported reason.
          add(
            'void_record',
            {'id': id},
            {'status': 'voided', 'void_reason': mine['void_reason'] ?? 'user'},
          );
        }
      case 'tag':
        if (mine['deleted_at'] != null) {
          if (server['deleted_at'] == null) {
            add('delete_tag', {'id': id}, {'deleted_at': mine['deleted_at']});
          }
        } else if (changes.isNotEmpty) {
          add('rename_tag', {'id': id, ...changes}, changes);
        }
      case 'account':
        if (changes.isNotEmpty) {
          add('update_account', {'id': id, ...changes}, changes);
        }
        if (mine['archived_at'] != null && server['archived_at'] == null) {
          add(
            'archive_account',
            {'id': id},
            {'archived_at': mine['archived_at']},
          );
        }
      case 'allocation_plan':
        if (changes.isNotEmpty) {
          // The set tool requires all three values rather than a patch,
          // including when the sole difference is enabled=false.
          final values = {for (final field in editable) field: mine[field]};
          add('set_allocation_plan', {'account_id': id, ...values}, values);
        }
    }
    return Ok(operations);
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

/// Each step carries just its effect, so optimistic state follows the same
/// sequence as the server (e.g. deleting a tag does not also rename it).
final class _ResolutionOperation {
  const _ResolutionOperation(this.tool, this.args, this.values);
  final String tool;
  final Map<String, Object?> args;
  final Map<String, Object?> values;
}
