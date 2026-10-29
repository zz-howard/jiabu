import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/data/db/database.dart';

import '../generated_migrations/schema_v1.dart' as v1;
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
      2,
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
}
