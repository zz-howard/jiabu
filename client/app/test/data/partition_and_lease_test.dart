import 'dart:io';
import 'dart:isolate';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/data/db/daos/local_store.dart';
import 'package:jiabu/data/db/database.dart';
import 'package:jiabu/data/db/database_manager.dart';
import 'package:jiabu/domain/partition.dart';

import '../support/sync_harness.dart';

Future<void> attemptLeaseInWorker((String, int, SendPort) request) async {
  final database = JiabuDatabase(NativeDatabase(File(request.$1)));
  Object result;
  try {
    result = await LocalStore(database)
        .acquireRound('background', request.$2, request.$2 + 60000);
  } on Object {
    result = 'worker_failed';
  } finally {
    await database.close();
  }
  request.$3.send(result);
}

void main() {
  test('server_normalization_preserves_proxy_path_case_a'
      'nd_reserved_escapes', () {
    expect(
      normalizeServer(' HTTPS://EXAMPLE.INVALID:443/Family/ '),
      'https://example.invalid/Family/',
    );
    expect(
      normalizeServer('https://example.invalid/a%2fb'),
      'https://example.invalid/a%2Fb/',
    );
    expect(
      normalizeServer('https://example.invalid/a%2Fb'),
      isNot(normalizeServer('https://example.invalid/a/b')),
    );
    expect(
      () => normalizeServer('https://user@example.invalid/'),
      throwsFormatException,
    );
    expect(
      () => normalizeServer('https://example.invalid/?query=1'),
      throwsFormatException,
    );
  });
  test('partition_files_tokens_and_blob_directories_are_isolated', () async {
    final directory = await Directory.systemTemp.createTemp(
      'jiabu-partitions-',
    );
    final manager = DatabaseManager(directory);
    addTearDown(() async {
      await manager.close();
      await directory.delete(recursive: true);
    });
    final a = Partition('https://example.invalid/proxy/', 'one');
    final same = Partition('HTTPS://EXAMPLE.INVALID:443/proxy', 'one');
    final b = Partition('https://example.invalid/proxy/', 'two');
    final otherServer = Partition('https://other.invalid/', 'one');
    expect(a.prefix, same.prefix);
    expect(a.prefix, isNot(b.prefix));
    expect(a.prefix, isNot(otherServer.prefix));
    expect(a.tokenKey, 'session:${a.prefix}');
    final first = await manager.open(a);
    final second = await manager.open(b);
    await first.store.putEntity('s', 'record', sampleRecord('r', amount: 123));
    await second.store.putEntity('s', 'record', sampleRecord('r', amount: 456));
    expect(
      (await first.store.entity('s', 'record', 'r'))?.data['amount_minor'],
      123,
    );
    expect(
      (await second.store.entity('s', 'record', 'r'))?.data['amount_minor'],
      456,
    );
    expect(first.blobs.path, isNot(second.blobs.path));
  });

  test('space_scoped_read_update_watch_and_purge_do_not_'
      'cross_boundaries', () async {
    final h = await SyncHarness.create();
    addTearDown(h.close);
    await h.store.putEntity('s', 'record', sampleRecord('r', amount: 123));
    await h.store.putEntity(
      'other',
      'record',
      sampleRecord('r', amount: 456, spaceId: 'other'),
    );
    final watched = await h.store.watchEntities('s', 'record').first;
    expect(watched.single.data['amount_minor'], 123);
    await h.store.purgeSpace('s');
    expect(await h.store.entities('s', 'record'), isEmpty);
    expect(
      (await h.store.entity('other', 'record', 'r'))?.data['amount_minor'],
      456,
    );
  });

  test('two_isolates_cannot_upload_same_entity', () async {
    final directory = await Directory.systemTemp.createTemp('jiabu-lease-');
    final file = File('${directory.path}/shared.db');
    final h = await SyncHarness.create(
      database: JiabuDatabase(NativeDatabase(file)),
      directory: directory,
    );
    addTearDown(h.close);
    await h.seed('r');
    await h.records.update('s', 'r', {'amount_minor': 123});
    final now = h.clock.millisecondsSinceEpoch;
    expect(await h.store.acquireRound('front', now, now + 60000), isTrue);
    final front = await h.processor.selectAndLeaseBatch('front');
    expect(front, hasLength(1));
    final path = file.path;
    final replies = ReceivePort();
    addTearDown(replies.close);
    final worker = await Isolate.spawn(attemptLeaseInWorker, (
      path,
      now,
      replies.sendPort,
    ));
    addTearDown(() => worker.kill(priority: Isolate.immediate));
    final result = await replies.first.timeout(const Duration(seconds: 5));
    expect(result, isFalse);
    expect(await h.processor.selectAndLeaseBatch('front'), isEmpty);
  });

  test('expired_lease_is_reclaimed_old_owner_cannot_rele'
      'ase_or_apply', () async {
    final h = await SyncHarness.create();
    addTearDown(h.close);
    await h.seed('r');
    await h.records.update('s', 'r', {'amount_minor': 123});
    final now = h.clock.millisecondsSinceEpoch;
    await h.store.acquireRound('old', now, now + 1000);
    final old = await h.processor.selectAndLeaseBatch('old');
    h.clock = h.clock.add(const Duration(minutes: 13));
    final later = h.clock.millisecondsSinceEpoch;
    expect(await h.store.acquireRound('new', later, later + 60000), isTrue);
    final next = await h.processor.selectAndLeaseBatch('new');
    expect(next, hasLength(1));
    await h.store.releaseRound('old');
    expect(await h.store.ownsRound('new', later), isTrue);
    await h.processor.applyPushBatch(
      'old',
      old,
      h.api.apply(old.map((op) => op.wire!).toList()),
    );
    expect((await h.store.entity('s', 'record', 'r'))?.baseVersion, 1);
    expect(await h.store.outbox('s'), hasLength(1));
  });
}
