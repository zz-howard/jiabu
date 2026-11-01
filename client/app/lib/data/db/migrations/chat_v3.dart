import 'package:drift/drift.dart';
import 'package:jiabu/data/db/migrations/migration_guards.dart';

/// v3 (#70) pages the chat instead of reading the whole history. Rows written
/// before v3 keep local_revision 0: a session reads them through its page
/// queries and only uses revisions for later changes. Every step is a no-op
/// on a schema that already has it.
Future<void> migrateChatV3(GeneratedDatabase db) async {
  for (final table in ['chat_entries', 'chat_client_states']) {
    await addColumn(db, table, 'local_revision', 'INTEGER NOT NULL DEFAULT 0');
  }
  for (final (name, table, columns) in const [
    (
      'chat_entries_timeline',
      'chat_entries',
      'space_id, member_id, created_at, id',
    ),
    ('chat_entries_revision', 'chat_entries', 'space_id, local_revision'),
    ('chat_entries_reply', 'chat_entries', 'space_id, reply_to_id'),
    (
      'chat_entries_stream',
      'chat_entries',
      'space_id, member_id, stream_status',
    ),
    (
      'chat_client_states_revision',
      'chat_client_states',
      'space_id, local_revision',
    ),
  ]) {
    await db.customStatement(
      'CREATE INDEX IF NOT EXISTS $name ON $table ($columns)',
    );
  }
}
