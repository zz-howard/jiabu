import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/data/db/database_manager.dart';
import 'package:jiabu/domain/ledger.dart';
import 'package:jiabu/domain/required_value.dart';
import 'package:jiabu/features/catalog/c4_cases.dart';
import 'package:jiabu/shared/ledger/ledger_pages.dart';
import 'package:jiabu/shared/ledger/ledger_view_model.dart';

import '../support/c4_harness.dart';
import '../support/ledger_fake.dart';
import '../support/sync_harness.dart';

LedgerSnapshot snapshot(String id, String label, int amount) => LedgerSnapshot(
  spaceId: id,
  space: LedgerRow(sampleSpace(id: id).toJson()),
  accounts: [
    LedgerRow({
      'id': 'account',
      'space_id': id,
      'kind': 'real',
      'name': '$label账户',
      'opening_balance_minor': amount * 10,
      'opening_on': '2026-01-01',
    }),
  ],
  members: [
    LedgerRow({
      'id': 'member-$id',
      'display_name': '$label成员',
      'status': 'active',
    }),
  ],
  records: [
    LedgerRow({
      ...sampleRecord('record', spaceId: id, amount: amount),
      'account_id': 'account',
      'note': '$label账目',
      'created_by_member_id': 'member-$id',
    }),
  ],
);

class TrackingSpacesLedger extends FakeLedgerRepository {
  TrackingSpacesLedger(this.snapshots) : super(snapshots.values.first);
  final Map<String, LedgerSnapshot> snapshots;
  final active = <String>{};
  final cancelled = <String>[];
  final controllers = <String, StreamController<LedgerSnapshot>>{};
  @override
  Stream<LedgerSnapshot> watch(String spaceId) {
    late StreamController<LedgerSnapshot> controller;
    controller = StreamController<LedgerSnapshot>(
      onListen: () {
        active.add(spaceId);
        controller.add(requireValue<LedgerSnapshot>(snapshots[spaceId]));
      },
      onCancel: () {
        active.remove(spaceId);
        cancelled.add(spaceId);
      },
    );
    controllers[spaceId] = controller;
    return controller.stream;
  }

  Future<void> close() async {
    for (final controller in controllers.values) {
      await controller.close();
    }
    await changes.close();
  }
}

Future<void> pumpUntil(WidgetTester tester, bool Function() complete) async {
  for (var attempt = 0; attempt < 20; attempt++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (complete()) {
      return;
    }
  }
  fail('space switch did not settle after 20 finite pumps');
}

void main() {
  for (final page in ['overview', 'history', 'accounts']) {
    testWidgets(
      'switch_${page}_contains_only_new_space_and_closes_old_subscription',
      (tester) async {
        final h = requireValue<SyncHarness>(
          await tester.runAsync(SyncHarness.create),
        );
        final runtime = c4Runtime()..currentSpace = 's';
        final ledger = TrackingSpacesLedger({
          's': snapshot('s', '用户A', 100),
          't': snapshot('t', '用户B', 900),
        });
        try {
          await tester.runAsync(
            () => h.memberships.reconcile(
              h.api.spaceResponse.copyWith(
                spaces: [
                  sampleSpace(),
                  sampleSpace(id: 't'),
                ],
              ),
            ),
          );
          runtime.ledger = ledger;
          final partition =
              runtime.auth.current?.partition ??
              (throw StateError('fictional session missing'));
          runtime.auth.handle = PartitionDatabase(partition, h.db, h.directory);
          final container = await pumpC4Widget(
            tester,
            runtime: runtime,
            spaces: C4FakeSpaces(),
            keys: C4FakeKeys(),
            child: LedgerRoutePage(page: page),
          );
          expect(
            find.text(page == 'history' ? '用户A账目' : '用户A账户'),
            findsWidgets,
          );
          await tester.runAsync(() => runtime.switchSpace('t'));
          await pumpUntil(
            tester,
            () =>
                ledger.active.contains('t') &&
                ledger.cancelled.contains('s') &&
                find
                    .text(page == 'history' ? '用户B账目' : '用户B账户')
                    .evaluate()
                    .isNotEmpty,
          );
          expect(find.text('用户A账目'), findsNothing);
          expect(find.text('用户A账户'), findsNothing);
          expect(
            find.text(page == 'history' ? '用户B账目' : '用户B账户'),
            findsWidgets,
          );
          final current = container.read(ledgerViewModelProvider('t')).snapshot;
          expect(current?.records.single.number('amount_minor'), 900);
          expect(
            current?.accounts.single.number('opening_balance_minor'),
            9000,
          );
          expect(current?.members.single.text('display_name'), '用户B成员');
          expect(ledger.active, {'t'});
          expect(ledger.cancelled, contains('s'));
          expect(await runtime.settings.lastSpace(partition), 't');
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await pumpUntil(tester, () => ledger.active.isEmpty);
          await tester.runAsync(() async {
            await ledger.close();
            await h.close();
          });
        }
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );
  }
}
