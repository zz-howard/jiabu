import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/data/db/daos/local_store.dart';
import 'package:jiabu/data/db/database.dart';

import '../generated_migrations/schema_v1.dart' as v1;
import '../generated_migrations/schema_v2.dart' as v2;
import '../support/chat_harness.dart';

void main() {
  test('chat_v1_to_v2_preserves_two_spaces_queue_and_checkpoints', () async {
    final directory = await Directory.systemTemp.createTemp(
      'jiabu-chat-migration-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/db');
    final old = v1.DatabaseAtV1(NativeDatabase(file));
    await old.customStatement(
      'INSERT INTO sync_runtime (id, space_ids_json) VALUES (1, ?)',
      ['["a","b"]'],
    );
    for (final space in ['a', 'b']) {
      final payload = chatRow(
        chatMessage(text: space, rev: space == 'a' ? 1 : 0, seq: 12),
      );
      await old.customStatement(
        'INSERT INTO chat_entries (space_id, id, data_json, member_id, '
        'conversation_id) VALUES (?, ?, ?, ?, ?)',
        [space, 'reply', jsonEncode(payload), 'm', 'conversation'],
      );
    }
    await old.customStatement(
      "INSERT INTO chat_entries (space_id, id, data_json) VALUES ('a', "
      "'legacy', '{}')",
    );
    await old.customStatement(
      'INSERT INTO outbox (id, space_id, join_epoch, kind, payload_json, '
      'entity_ids, depends_on, request_id, created_at) VALUES (?, ?, ?, ?, '
      '?, ?, ?, ?, ?)',
      ['op', 'a', 1, 'chat_send', '{}', '[]', '[]', 'request', 1],
    );
    await old.close();
    final db = JiabuDatabase(NativeDatabase(file));
    expect(
      (await db.customSelect('PRAGMA user_version').getSingle())
          .data
          .values
          .single,
      3,
    );
    final rows = await db
        .customSelect(
          'SELECT message_json, last_seq, authoritative FROM chat_entries '
          "WHERE id = 'reply' ORDER BY space_id",
        )
        .get();
    expect(rows.map((row) => row.data['last_seq']), [12, 12]);
    expect(rows.map((row) => row.data['authoritative']), [1, 0]);
    expect(
      jsonDecode(rows.first.data['message_json']! as String),
      chatMessage(text: 'a', rev: 1, seq: 12).json,
    );
    expect(
      (await db.customSelect('SELECT id FROM outbox').get()).single.data['id'],
      'op',
    );
    await db.close();
    final reopened = JiabuDatabase(NativeDatabase(file));
    expect(
      (await reopened.customSelect('PRAGMA integrity_check').getSingle())
          .data
          .values
          .single,
      'ok',
    );
    await reopened.close();
  });
  test('chat_v2_to_v3_keeps_rows_and_pages_them_by_timeline', () async {
    final directory = await Directory.systemTemp.createTemp(
      'jiabu-chat-migration-v3-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/db');
    final old = v2.DatabaseAtV2(NativeDatabase(file));
    await old.customStatement(
      'INSERT INTO sync_runtime (id, space_ids_json) VALUES (1, ?)',
      ['["s"]'],
    );
    for (var i = 0; i < 3; i++) {
      final message = timelineMessage(i);
      await old.customStatement(
        'INSERT INTO chat_entries (space_id, id, data_json, member_id, '
        'conversation_id, role, created_at, stream_status, message_json, '
        'rev, authoritative) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          's',
          message.id,
          jsonEncode(timelineRow(message)),
          'm',
          'conversation',
          message['role'],
          message['createdAt'],
          'complete',
          jsonEncode(message.json),
          1,
          1,
        ],
      );
    }
    await old.customStatement(
      'INSERT INTO chat_client_states (space_id, message_id, state_json) '
      'VALUES (?, ?, ?)',
      ['s', timelineId(0), '{"manual":true}'],
    );
    await old.close();
    final db = JiabuDatabase(NativeDatabase(file));
    addTearDown(db.close);
    expect(
      (await db.customSelect('PRAGMA user_version').getSingle())
          .data
          .values
          .single,
      3,
    );
    final indexes =
        (await db
                .customSelect(
                  "SELECT name FROM sqlite_master WHERE type = 'index'",
                )
                .get())
            .map((row) => row.data['name'])
            .toSet();
    expect(
      indexes,
      containsAll([
        'chat_entries_timeline',
        'chat_entries_revision',
        'chat_entries_reply',
        'chat_entries_stream',
        'chat_client_states_revision',
      ]),
    );
    final store = LocalStore(db);
    final page = await store.chatPage('s', 'm', limit: 2);
    expect(page.map((row) => row['id']), [timelineId(1), timelineId(2)]);
    expect(await store.chatClientStates('s', [timelineId(0)]), {
      timelineId(0): {'manual': true},
    });
    // Legacy rows carry revision 0: only later writes count as changes.
    expect(await store.chatEntriesChangedSince('s', 'm', 0), isEmpty);
    expect(
      (await db.customSelect('PRAGMA integrity_check').getSingle())
          .data
          .values
          .single,
      'ok',
    );
  });
}
