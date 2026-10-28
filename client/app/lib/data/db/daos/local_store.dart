import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:jiabu/data/db/daos/dao_scope.dart';
import 'package:jiabu/data/db/database.dart';
import 'package:jiabu/data/db/tables.dart';
import 'package:jiabu/domain/outbox_operation.dart';
import 'package:jiabu/domain/required_value.dart';

Variable<Object> _variable(Object? value) => switch (value) {
  final int v => Variable<int>(v),
  final String v => Variable<String>(v),
  null => const Variable<String>(null),
  _ => throw ArgumentError('Unsupported SQL parameter'),
};

/// All space content SQL lives here. Callers never pass table names or SQL.
/// Runtime is the only partition-wide table; its space index avoids unscoped
/// enumeration/counting of business tables, including outbox.
final class LocalStore {
  LocalStore(this.db);
  final JiabuDatabase db;

  Future<T> transaction<T>(Future<T> Function() action) =>
      db.transaction(action);

  Set<TableInfo<Table, Object?>> _tables(String name) =>
      db.allTables.where((table) => table.actualTableName == name).toSet();

  Future<List<Map<String, Object?>>> _read(
    String sql,
    List<Object?> args,
  ) async {
    DaoScope.verify(
      sql,
      infrastructure: sql == 'SELECT * FROM sync_runtime WHERE id = 1',
    );
    final query = db.customSelect(sql, variables: args.map(_variable).toList());
    return (await query.get()).map((row) => row.data).toList();
  }

  Future<void> _write(String table, String sql, List<Object?> args) =>
      transaction(() async {
        DaoScope.verify(sql, infrastructure: table == 'sync_runtime');
        await db.customStatement(sql, args);
        if (table != 'sync_runtime') {
          await db.customStatement(
            'UPDATE sync_runtime SET change_revision = '
            'change_revision + 1 WHERE id = 1',
          );
        }
        db.notifyUpdates({
          for (final info in _tables(table)) TableUpdate.onTable(info),
        });
      });

  Future<Map<String, Object?>> runtime() async =>
      (await _read('SELECT * FROM sync_runtime WHERE id = 1', [])).single;

  void invalidateStreams() => db.notifyUpdates({
    for (final table in db.allTables) TableUpdate.onTable(table),
  });

  Future<void> recordRemoval(String spaceId, int count) async {
    final notices = (jsonDecode(
      requireValue<String>((await runtime())['notices_json']),
    ) as List<Object?>)..add({'space_id': spaceId, 'count': count});
    await _write(
      'sync_runtime',
      'UPDATE sync_runtime SET notices_json = ? WHERE id = 1',
      [jsonEncode(notices)],
    );
  }

  Future<void> clearNotices() => _write(
    'sync_runtime',
    'UPDATE sync_runtime SET notices_json = ? WHERE id = 1',
    ['[]'],
  );

  Future<void> setWriteAllowed({required bool allowed}) => _write(
    'sync_runtime',
    'UPDATE sync_runtime SET write_allowed = ? WHERE id = 1',
    [if (allowed) 1 else 0],
  );

  Future<void> saveIdentity(Map<String, Object?> user, String kind) => _write(
    'sync_runtime',
    'UPDATE sync_runtime SET identity_json = ?, '
        'session_kind = ? WHERE id = 1',
    [jsonEncode(user), kind],
  );

  Future<List<String>> spaceIds() async => (jsonDecode(
    requireValue<String>((await runtime())['space_ids_json']),
  ) as List<Object?>).cast<String>();

  Future<void> setSpaceIds(List<String> ids) => _write(
    'sync_runtime',
    'UPDATE sync_runtime SET space_ids_json = ? WHERE id = 1',
    [jsonEncode(ids)],
  );

  Future<int> activate({required bool authenticated}) => transaction(() async {
    await _write(
      'sync_runtime',
      'UPDATE sync_runtime SET generation = generation '
          '+ 1, authenticated = ?, '
          'round_owner = NULL, round_lease_until = NULL '
          'WHERE id = 1',
      [if (authenticated) 1 else 0],
    );
    for (final spaceId in await spaceIds()) {
      await _write(
        'outbox',
        'UPDATE outbox SET state = ?, lease_until = NULL '
            'WHERE space_id = ? AND state = ?',
        ['pending', spaceId, 'sending'],
      );
    }
    return requireValue<int>((await runtime())['generation']);
  });

  Future<bool> acquireRound(String owner, int now, int until) =>
      transaction(() async {
        await _write(
          'sync_runtime',
          'UPDATE sync_runtime SET round_owner = ?, '
              'round_lease_until = ? WHERE id = 1 '
              'AND authenticated = 1 AND (round_owner IS NULL '
              'OR round_lease_until <= ?)',
          [owner, until, now],
        );
        return (await runtime())['round_owner'] == owner;
      });

  Future<bool> renewRound(String owner, int until) => transaction(() async {
    await _write(
      'sync_runtime',
      'UPDATE sync_runtime SET round_lease_until = ? '
          'WHERE id = 1 AND round_owner = ?',
      [until, owner],
    );
    return (await runtime())['round_owner'] == owner;
  });

  Future<void> releaseRound(String owner) => _write(
    'sync_runtime',
    'UPDATE sync_runtime SET round_owner = NULL, '
        'round_lease_until = NULL '
        'WHERE id = 1 AND round_owner = ?',
    [owner],
  );

  Future<bool> ownsRound(String owner, int now) async {
    final row = await runtime();
    return row['round_owner'] == owner &&
        ((row['round_lease_until'] as int?) ?? 0) > now;
  }

  Future<RequestFence?> fence(String spaceId) async {
    final row = await entity(spaceId, 'space', spaceId);
    if (row == null) {
      return null;
    }
    final runtimeRow = await runtime();
    if (runtimeRow['authenticated'] != 1) {
      return null;
    }
    return RequestFence(
      generation: requireValue<int>(runtimeRow['generation']),
      spaceId: spaceId,
      joinEpoch: requireValue<int>(row.data['join_epoch']),
      localGeneration: (row.data['local_generation'] as int?) ?? 0,
    );
  }

  Future<bool> accepts(RequestFence captured) async {
    final current = await fence(captured.spaceId);
    return current != null &&
        current.generation == captured.generation &&
        current.joinEpoch == captured.joinEpoch &&
        current.localGeneration == captured.localGeneration;
  }

  String _table(String kind) =>
      entityTables[kind] ??
      (throw ArgumentError.value(kind, 'kind', 'Unknown sync entity'));
  List<String> _columns(String table) =>
      entityColumns[table] ?? (throw ArgumentError('Unknown sync table'));
  List<String> _keys(String kind) => switch (kind) {
    'allocation_plan' => ['account_id'],
    'space_member_grant' => ['member_id', 'module'],
    _ => ['id'],
  };
  Object keyOf(String kind, Map<String, Object?> data) =>
      kind == 'space_member_grant'
      ? '${data['member_id']}|${data['module']}'
      : data[_keys(kind).first] ??
            (throw const FormatException('missing_entity_key'));

  Future<LocalEntity?> entity(String spaceId, String kind, Object id) async {
    final table = _table(kind);
    final keys = _keys(kind);
    final parts = kind == 'space_member_grant'
        ? id.toString().split('|')
        : [id];
    final version = _columns(table).contains('base_version')
        ? 'base_version'
        : 'NULL AS base_version';
    final rows = await _read(
      'SELECT data_json, sync_state, $version '
      'FROM $table WHERE space_id = ? AND '
      '${keys.map((k) => '"$k" = ?').join(' AND ')}',
      [spaceId, ...parts],
    );
    if (rows.isEmpty) {
      return null;
    }
    final row = rows.single;
    return LocalEntity(
      (jsonDecode(
        requireValue<String>(row['data_json']),
      ) as Map<String, Object?>).cast<String, Object?>(),
      requireValue<String>(row['sync_state']),
      row['base_version'] as int?,
    );
  }

  Future<List<LocalEntity>> entities(String spaceId, String kind) async {
    final table = _table(kind);
    final rows = await _read('SELECT * FROM $table WHERE space_id = ?', [
      spaceId,
    ]);
    return rows
        .map(
          (row) => LocalEntity(
            (jsonDecode(
              requireValue<String>(row['data_json']),
            ) as Map<String, Object?>).cast<String, Object?>(),
            requireValue<String>(row['sync_state']),
            row['base_version'] as int?,
          ),
        )
        .toList();
  }

  Stream<List<LocalEntity>> watchEntities(String spaceId, String kind) {
    final table = _table(kind);
    return db
        .customSelect(
          'SELECT * FROM $table WHERE space_id = ?',
          variables: [Variable<String>(spaceId)],
          readsFrom: _tables(table),
        )
        .watch()
        .map(
          (rows) => rows
              .map(
                (row) => LocalEntity(
                  (jsonDecode(
                    row.data['data_json'] as String,
                  ) as Map<String, Object?>).cast<String, Object?>(),
                  row.data['sync_state'] as String,
                  row.data['base_version'] as int?,
                ),
              )
              .toList(),
        );
  }

  Future<void> putEntity(
    String spaceId,
    String kind,
    Map<String, Object?> data, {
    String state = 'synced',
    int? baseVersion,
  }) async {
    if (data['space_id'] != null && data['space_id'] != spaceId) {
      throw const FormatException('cross_space_entity');
    }
    final table = _table(kind);
    final payload = {...data, 'space_id': spaceId};
    final columns = _columns(table);
    final values = <String, Object?>{
      for (final column in columns)
        if (payload.containsKey(column)) column: _sqlValue(payload[column]),
      'space_id': spaceId,
      'data_json': jsonEncode(payload),
      'sync_state': state,
      if (columns.contains('base_version'))
        'base_version': baseVersion ?? data['version'],
      if (columns.contains('server_payload_json'))
        'server_payload_json': jsonEncode(data),
    };
    keyOf(kind, payload);
    final names = values.keys.toList();
    final keys = ['space_id', ..._keys(kind)];
    final assignments = names
        .where((name) => !keys.contains(name))
        .map((name) => '"$name" = excluded."$name"')
        .join(',');
    await _write(
      table,
      'INSERT INTO $table '
      '(${names.map((n) => '"$n"').join(',')}) '
      'VALUES (${names.map((_) => '?').join(',')}) '
      'ON CONFLICT (${keys.join(',')}) DO UPDATE SET '
      '$assignments',
      values.values.toList(),
    );
  }

  Object? _sqlValue(Object? value) => switch (value) {
    final bool v => v ? 1 : 0,
    final Map<Object?, Object?> v => jsonEncode(v),
    final List<Object?> v => jsonEncode(v),
    _ => value,
  };

  Future<List<OutboxOperation>> outbox(String spaceId) async => (await _read(
    'SELECT * FROM outbox WHERE space_id = ? ORDER '
    'BY created_at, id',
    [spaceId],
  )).map(OutboxOperation.fromRow).toList();

  Stream<int> watchOutboxCount(String spaceId) => db
      .customSelect(
        'SELECT COUNT(*) AS n FROM outbox WHERE space_id = ?',
        variables: [Variable<String>(spaceId)],
        readsFrom: _tables('outbox'),
      )
      .watchSingle()
      .map((row) => row.read<int>('n'));

  Future<void> enqueue(OutboxOperation op) => transaction(() async {
    final earlier = await outbox(op.spaceId);
    final next = earlier.isEmpty || earlier.last.createdAt < op.createdAt
        ? op.createdAt
        : earlier.last.createdAt + 1;
    await _write(
      'outbox',
      'INSERT INTO outbox (id, space_id, join_epoch, '
          'kind, payload_json, entity_ids, '
          'depends_on, request_id, created_at) VALUES (?, '
          '?, ?, ?, ?, ?, ?, ?, ?)',
      [
        op.id,
        op.spaceId,
        op.joinEpoch,
        op.kind,
        jsonEncode(op.payload),
        jsonEncode(op.entityIds.toList()),
        jsonEncode(op.dependsOn.toList()),
        op.requestId,
        next,
      ],
    );
  });

  Future<void> deferDependents(String spaceId, String entityKey) async {
    final queue = await outbox(spaceId);
    var next = queue.isEmpty ? 0 : queue.last.createdAt;
    final deferredReferences = <String>{};
    for (final op in queue) {
      // The resolution itself stays ahead of its dependents. Unrelated
      // prerequisites (especially blobs required by it) keep their position.
      if (op.entityIds.contains(entityKey)) {
        continue;
      }
      final shouldDefer =
          op.dependsOn.contains(entityKey) ||
          op.references.intersection(deferredReferences).isNotEmpty;
      if (shouldDefer) {
        // Preserve order with every later write sharing any reference, even
        // when that reference is a dependency rather than the written entity.
        // For example refund(R, T) must remain ahead of a later delete(T).
        deferredReferences.addAll(op.references);
        await _write(
          'outbox',
          'UPDATE outbox SET created_at = ? WHERE space_id '
              '= ? AND id = ?',
          [++next, spaceId, op.id],
        );
      }
    }
  }

  Future<void> lease(
    OutboxOperation op,
    Map<String, Object?> payload,
    int until,
  ) => _write(
    'outbox',
    'UPDATE outbox SET state = ?, payload_json = ?, '
        'lease_until = ?, attempts = attempts + 1 WHERE '
        'space_id = ? AND id = ?',
    ['sending', jsonEncode(payload), until, op.spaceId, op.id],
  );

  Future<void> setOutboxState(
    String spaceId,
    String id,
    String state, {
    Map<String, Object?>? error,
  }) => _write(
    'outbox',
    'UPDATE outbox SET state = ?, lease_until = NULL, '
        'last_error = ? WHERE space_id = ? AND id = ?',
    [state, if (error == null) null else jsonEncode(error), spaceId, id],
  );

  Future<void> removeOp(String spaceId, String id) => _write(
    'outbox',
    'DELETE FROM outbox WHERE space_id = ? AND id = ?',
    [spaceId, id],
  );

  Future<int> cursor(String spaceId) async {
    final rows = await _read(
      'SELECT cursor FROM sync_cursors WHERE space_id = ?',
      [spaceId],
    );
    return rows.isEmpty ? 0 : requireValue<int>(rows.single['cursor']);
  }

  Future<void> setCursor(String spaceId, int cursor) => _write(
    'sync_cursors',
    'INSERT INTO sync_cursors (space_id, cursor) '
        'VALUES (?, ?) '
        'ON CONFLICT (space_id) DO UPDATE SET cursor = '
        'excluded.cursor',
    [spaceId, cursor],
  );

  Future<Map<String, Object?>?> conflict(
    String spaceId,
    String kind,
    String id,
  ) async {
    final rows = await _read(
      'SELECT * FROM entity_conflicts WHERE space_id = ? '
      'AND entity_kind = ? AND entity_id = ?',
      [spaceId, kind, id],
    );
    return rows.isEmpty ? null : rows.single;
  }

  Future<void> putConflict(
    String spaceId,
    String kind,
    String id,
    Map<String, Object?> mine,
    int version,
    String? status,
    int now,
  ) => _write(
    'entity_conflicts',
    'INSERT INTO entity_conflicts '
        '(space_id, entity_kind, entity_id, mine_json, '
        'server_version, server_status, detected_at) '
        'VALUES (?, ?, ?, ?, ?, ?, ?) ON CONFLICT '
        '(space_id, entity_kind, entity_id) '
        'DO UPDATE SET mine_json = excluded.mine_json, '
        'server_version = excluded.server_version, '
        'server_status = excluded.server_status, '
        'detected_at = excluded.detected_at',
    [spaceId, kind, id, jsonEncode(mine), version, status, now],
  );
  Future<void> removeConflict(String spaceId, String kind, String id) => _write(
    'entity_conflicts',
    'DELETE FROM entity_conflicts WHERE space_id = ? '
        'AND entity_kind = ? AND entity_id = ?',
    [spaceId, kind, id],
  );

  Future<List<Map<String, Object?>>> blobs(String spaceId) =>
      _read('SELECT * FROM blobs_local WHERE space_id = ?', [spaceId]);
  Future<void> putBlob(
    String spaceId,
    String module,
    String hash,
    String path,
    int bytes,
  ) => _write(
    'blobs_local',
    'INSERT INTO blobs_local (space_id, module, '
        'sha256, path, bytes) '
        'VALUES (?, ?, ?, ?, ?) ON CONFLICT (space_id, '
        'module, sha256) DO NOTHING',
    [spaceId, module, hash, path, bytes],
  );
  Future<void> uploadedBlob(
    String spaceId,
    String module,
    String hash,
    int now,
  ) => _write(
    'blobs_local',
    'UPDATE blobs_local SET uploaded = 1, uploaded_at = ? '
        'WHERE space_id = ? AND module = ? AND sha256 = ?',
    [now, spaceId, module, hash],
  );

  Future<void> purgeSpace(String spaceId) => transaction(() async {
    final paths = (await blobs(spaceId))
        .map((b) => requireValue<String>(b['path']));
    await scheduleDeletions(paths);
    for (final table in [
      ...entityTables.values,
      'outbox',
      'sync_cursors',
      'entity_conflicts',
      'blobs_local',
    ]) {
      await _write(table, 'DELETE FROM $table WHERE space_id = ?', [spaceId]);
    }
  });

  Future<void> purgeModule(String spaceId, String module) => transaction(
    () async {
      final kinds = module == 'ledger'
          ? ['account', 'allocation_plan', 'tag', 'record']
          : ['subject', 'document'];
      final entityKinds = kinds.toSet();
      for (final kind in kinds) {
        final table = _table(kind);
        await _write(table, 'DELETE FROM $table WHERE space_id = ?', [spaceId]);
      }
      for (final event in await entities(spaceId, 'entity_event')) {
        if (entityKinds.contains(event.data['entity_kind'])) {
          await _write(
            'entity_events',
            'DELETE FROM entity_events WHERE space_id = ? AND id = ?',
            [spaceId, event.data['id']],
          );
        }
      }
      for (final op in await outbox(spaceId)) {
        if (op.kind == 'blob'
            ? op.payload['module'] == module
            : op.references.any(
                (ref) => entityKinds.contains(ref.split(':').first),
              )) {
          await removeOp(spaceId, op.id);
        }
      }
      for (final kind in kinds) {
        await _write(
          'entity_conflicts',
          'DELETE FROM entity_conflicts '
              'WHERE space_id = ? AND entity_kind = ?',
          [spaceId, kind],
        );
      }
      final paths = (await blobs(spaceId))
          .where((b) => b['module'] == module)
          .map((b) => requireValue<String>(b['path']));
      await scheduleDeletions(paths);
      await _write(
        'blobs_local',
        'DELETE FROM blobs_local WHERE space_id = ? AND '
            'module = ?',
        [spaceId, module],
      );
      await setCursor(spaceId, 0);
    },
  );

  Future<void> scheduleDeletions(Iterable<String> paths) async {
    final existing = (jsonDecode(
      requireValue<String>((await runtime())['pending_deletions_json']),
    ) as List<Object?>).cast<String>();
    await _write(
      'sync_runtime',
      'UPDATE sync_runtime SET pending_deletions_json '
          '= ? WHERE id = 1',
      [
        jsonEncode({...existing, ...paths}.toList()),
      ],
    );
  }

  Future<List<String>> deletions() async => (jsonDecode(
    requireValue<String>((await runtime())['pending_deletions_json']),
  ) as List<Object?>).cast<String>();
  Future<void> finishDeletion(String path) async {
    final remaining = (await deletions())..remove(path);
    await _write(
      'sync_runtime',
      'UPDATE sync_runtime SET pending_deletions_json '
          '= ? WHERE id = 1',
      [jsonEncode(remaining)],
    );
  }

  Future<bool> hasBlobPath(String spaceId, String path) async => (await _read(
    'SELECT sha256 FROM blobs_local WHERE space_id = '
    '? AND path = ?',
    [spaceId, path],
  )).isNotEmpty;

  /// Acquire SQLite's writer lock before a filesystem check+rename/delete.
  /// This prevents a second connection from publishing a reference between
  /// a garbage collector's snapshot and its physical deletion.
  Future<void> lockFilesystem() => lockRuntime();
  Future<void> lockRuntime() =>
      db.customStatement('UPDATE sync_runtime SET id = id WHERE id = 1');

  Future<void> expireBlob(String spaceId, String module, String hash) =>
      transaction(() async {
        final matches = (await blobs(spaceId))
            .where((b) => b['module'] == module && b['sha256'] == hash);
        if (matches.isEmpty) {
          return;
        }
        await scheduleDeletions([requireValue<String>(matches.single['path'])]);
        await _write(
          'blobs_local',
          'DELETE FROM blobs_local WHERE space_id = ? AND '
              'module = ? AND sha256 = ?',
          [spaceId, module, hash],
        );
      });
}
