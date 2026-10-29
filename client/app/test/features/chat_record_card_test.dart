import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/domain/ledger.dart';
import 'package:jiabu/features/catalog/c3_cases.dart';
import 'package:jiabu/features/chat/blocks/record_card_block.dart';

import '../support/c3_harness.dart';
import '../support/ledger_fake.dart';

void main() {
  testWidgets(
    'record_block_watches_sync_then_changed_and_permission_priority',
    (tester) async {
      final base = c3Snapshot('card_recorded');
      final id = base.records.first.id;
      LedgerSnapshot snapshot({
        List<LedgerRow> records = const [],
        bool allowed = true,
      }) => LedgerSnapshot(
        spaceId: base.spaceId,
        space: LedgerRow({
          ...base.space.data,
          'modules': {'ledger': allowed ? 'write' : 'none'},
        }),
        records: records,
        accounts: base.accounts,
        members: base.members,
      );
      final repo = FakeLedgerRepository(snapshot());
      addTearDown(repo.changes.close);
      await pumpC3(
        tester,
        repository: repo,
        child: RecordCardBlock(
          spaceId: base.spaceId,
          recordId: id,
          versionAtReply: 1,
        ),
      );
      expect(find.text('记录同步中'), findsOneWidget);
      repo.emit(
        snapshot(
          records: [
            LedgerRow({...base.records.first.data, 'version': 2}),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('后来改过'), findsOneWidget);
      repo.emit(snapshot(records: [base.records.first], allowed: false));
      await tester.pumpAndSettle();
      expect(find.text('此内容你已无权查看'), findsOneWidget);
      expect(find.text('编辑'), findsNothing);
    },
  );
}
