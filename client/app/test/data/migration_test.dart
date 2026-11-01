import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/data/db/database.dart';
import 'package:jiabu/data/db/tables.dart';

void main() {
  test('schema_v3_reopens_and_every_business_table_has_space_id', () async {
    final directory = await Directory.systemTemp.createTemp(
      'jiabu-migrations-',
    );
    final file = File('${directory.path}/schema.db');
    final first = JiabuDatabase(NativeDatabase(file));
    await first.customSelect('SELECT * FROM sync_runtime').get();
    expect(first.schemaVersion, 3);
    await first.close();
    final reopened = JiabuDatabase(NativeDatabase(file));
    addTearDown(() async {
      await reopened.close();
      await directory.delete(recursive: true);
    });
    expect(
      (await reopened.customSelect('PRAGMA user_version').getSingle())
          .data
          .values
          .single,
      3,
    );
    expect(
      (await reopened.customSelect('PRAGMA integrity_check').getSingle())
          .data
          .values
          .single,
      'ok',
    );
    for (final table in [
      ...entityTables.values,
      'outbox',
      'sync_cursors',
      'entity_conflicts',
      'blobs_local',
      'chat_client_states',
    ]) {
      final info = await reopened
          .customSelect('PRAGMA table_info($table)')
          .get();
      expect(
        info.map((row) => row.data['name']),
        contains('space_id'),
        reason: table,
      );
    }
    final tables = await reopened
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
        .get();
    expect(tables.map((row) => row.data['name']), isNot(contains('templates')));
    final chat = await reopened
        .customSelect('PRAGMA table_info(chat_entries)')
        .get();
    expect(chat.map((row) => row.data['name']), contains('message_json'));
  });
}
