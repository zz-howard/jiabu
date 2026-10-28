import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/data/api/dto/spaces_dto.dart';
import 'package:jiabu/data/db/daos/local_store.dart';
import 'package:jiabu/data/db/database.dart';
import 'package:jiabu/data/sync/sync_triggers.dart';

import '../support/sync_harness.dart';

void main() {
  test('background_connection_changes_refresh_foreground'
      '_scoped_streams', () async {
    final directory = await Directory.systemTemp.createTemp(
      'jiabu-cross-connection-',
    );
    final file = File('${directory.path}/shared.db');
    final h = await SyncHarness.create(
      database: JiabuDatabase(NativeDatabase(file)),
      directory: directory,
    );
    addTearDown(h.close);
    await h.seed('r');
    final worker = JiabuDatabase(NativeDatabase(file));
    addTearDown(worker.close);
    final triggers = SyncTriggers(
      h.engine,
      h.api,
      h.store,
      observeLifecycle: false,
    );
    addTearDown(triggers.dispose);
    await triggers.refreshDatabase();
    final initial = Completer<void>();
    final updated = Completer<void>();
    final subscription = h.store.watchEntities('s', 'record').listen((rows) {
      if (!initial.isCompleted) {
        initial.complete();
      }
      if (rows.any((row) => row.data['amount_minor'] == 999) &&
          !updated.isCompleted) {
        updated.complete();
      }
    });
    addTearDown(subscription.cancel);
    await initial.future;
    await LocalStore(worker)
        .putEntity('s', 'record', sampleRecord('r', amount: 999, version: 2));
    await triggers.refreshDatabase();
    await updated.future.timeout(const Duration(seconds: 5));
    expect((await h.store.entity('s', 'record', 'r'))?.baseVersion, 2);
  });

  test('membership_clear_notice_is_persisted_in_original'
      '_partition_until_ack', () async {
    final h = await SyncHarness.create();
    addTearDown(h.close);
    await h.seed('r');
    await h.records.update('s', 'r', {'amount_minor': 123});
    await h.memberships.reconcile(SpacesDto(spaces: [sampleSpace(epoch: 2)]));
    expect((await h.store.runtime())['notices_json'], contains('"count":1'));
    await h.store.activate(authenticated: false);
    await h.store.activate(authenticated: true);
    expect((await h.store.runtime())['notices_json'], contains('"count":1'));
    await h.store.clearNotices();
    expect((await h.store.runtime())['notices_json'], '[]');
  });
}
