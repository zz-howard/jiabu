import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/domain/result.dart';

import '../support/sync_harness.dart';

void main() {
  test('forced update keeps local data and existing outbox intact', () async {
    final harness = await SyncHarness.create();
    addTearDown(harness.close);
    await harness.seed('r');
    await harness.records.update('s', 'r', {'amount_minor': 120});
    final queued = (await harness.store.outbox('s')).single;
    await harness.store.setWriteAllowed(allowed: false);
    expect(
      (await harness.store.entity('s', 'record', 'r'))?.data['amount_minor'],
      120,
    );
    expect((await harness.store.outbox('s')).single.id, queued.id);
    expect(
      await harness.records.update('s', 'r', {'amount_minor': 130}),
      isA<Failure<String>>(),
    );
    expect((await harness.store.outbox('s')).single.id, queued.id);
  });
}
