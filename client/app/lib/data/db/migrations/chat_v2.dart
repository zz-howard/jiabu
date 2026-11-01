import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:jiabu/data/db/migrations/migration_guards.dart';

/// v1 retained the complete server projection in data_json. Preserve it and
/// backfill the dedicated CW columns; no generated migration code is edited.
/// Safe to run again: existing columns are kept and only rows still without
/// message_json are backfilled.
Future<void> migrateChatV2(GeneratedDatabase db) async {
  await addColumn(db, 'chat_entries', 'message_json', 'TEXT');
  await addColumn(db, 'chat_entries', 'rev', 'INTEGER NOT NULL DEFAULT 0');
  await addColumn(db, 'chat_entries', 'last_seq', 'INTEGER NOT NULL DEFAULT 0');
  await addColumn(
    db,
    'chat_entries',
    'authoritative',
    'INTEGER NOT NULL DEFAULT 0',
  );
  await db.customStatement(
    'CREATE TABLE IF NOT EXISTS chat_client_states (space_id TEXT NOT NULL, '
    "message_id TEXT NOT NULL, state_json TEXT NOT NULL DEFAULT '{}', "
    'PRIMARY KEY (space_id, message_id))',
  );
  await db.customStatement(
    'CREATE INDEX IF NOT EXISTS chat_entries_conversation ON chat_entries '
    '(space_id, member_id, conversation_id, created_at, id)',
  );
  final runtimeRows = await db
      .customSelect('SELECT space_ids_json FROM sync_runtime WHERE id = 1')
      .get();
  final spaces = runtimeRows.isEmpty
      ? <String>[]
      : (jsonDecode(
          runtimeRows.single.data['space_ids_json']! as String,
        ) as List<Object?>).cast<String>();
  for (final space in spaces) {
    final rows = await db
        .customSelect(
          // Only rows not backfilled yet: a re-upgrade keeps rows written
          // since, and an interrupted run finishes the rest.
          'SELECT id, data_json, sync_state FROM chat_entries WHERE space_id '
          '= ? AND message_json IS NULL',
          variables: [Variable<String>(space)],
        )
        .get();
    for (final row in rows) {
      final data =
          jsonDecode(row.data['data_json']! as String) as Map<String, Object?>;
      final message = data['message'];
      if (message is! Map<String, Object?>) continue;
      final rev = (data['rev'] as int?) ?? (message['rev'] as int?) ?? 0;
      await db.customStatement(
        'UPDATE chat_entries SET message_json = ?, rev = ?, last_seq = ?, '
        'authoritative = ? WHERE space_id = ? AND id = ?',
        [
          jsonEncode(message),
          rev,
          (data['last_seq'] as int?) ?? 0,
          if (row.data['sync_state'] == 'synced' && rev > 0) 1 else 0,
          space,
          row.data['id'],
        ],
      );
    }
  }
}
