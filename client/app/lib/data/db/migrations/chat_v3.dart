import 'package:drift/drift.dart';

/// v3 (#70) pages the chat instead of reading the whole history. Rows written
/// before v3 keep local_revision 0: a session reads them through its page
/// queries and only uses revisions for later changes.
Future<void> migrateChatV3(GeneratedDatabase db) async {
  await db.customStatement(
    'ALTER TABLE chat_entries ADD COLUMN local_revision INTEGER NOT NULL '
    'DEFAULT 0',
  );
  await db.customStatement(
    'ALTER TABLE chat_client_states ADD COLUMN local_revision INTEGER NOT '
    'NULL DEFAULT 0',
  );
  await db.customStatement(
    'CREATE INDEX chat_entries_timeline ON chat_entries (space_id, '
    'member_id, created_at, id)',
  );
  await db.customStatement(
    'CREATE INDEX chat_entries_revision ON chat_entries (space_id, '
    'local_revision)',
  );
  await db.customStatement(
    'CREATE INDEX chat_entries_reply ON chat_entries (space_id, reply_to_id)',
  );
  await db.customStatement(
    'CREATE INDEX chat_entries_stream ON chat_entries (space_id, member_id, '
    'stream_status)',
  );
  await db.customStatement(
    'CREATE INDEX chat_client_states_revision ON chat_client_states '
    '(space_id, local_revision)',
  );
}
