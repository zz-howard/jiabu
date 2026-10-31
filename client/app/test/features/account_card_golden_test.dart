@Tags(['golden'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/domain/ledger.dart';
import 'package:jiabu/features/catalog/c5_cases.dart';

import '../support/c3_harness.dart';
import '../support/ledger_fake.dart';

const _otherRealId = '123e4567-e89b-42d3-a456-426614174003';
const _otherPurposeId = '123e4567-e89b-42d3-a456-426614174004';

final _goldens = <({String state, int width, int scale, String path})>[
  for (final state in [
    'account_card_real',
    'account_card_purpose',
    'account_card_archived_changed',
    'account_card_empty',
    'account_card_loading',
  ]) ...[
    (
      state: state,
      width: 360,
      scale: 100,
      path: '../goldens/chat/${state}_zh_pine_w360_text100.png',
    ),
    (
      state: state,
      width: 430,
      scale: 200,
      path: '../goldens/chat/${state}_zh_pine_w430_text200.png',
    ),
  ],
];

void main() {
  for (final item in _goldens) {
    testWidgets(item.path, (tester) async {
      final snapshot = _accountSnapshot(item.state);
      final repository = item.state == 'account_card_loading'
          ? _LoadingLedgerRepository(snapshot)
          : FakeLedgerRepository(snapshot);
      addTearDown(repository.changes.close);
      await pumpC3(
        tester,
        width: item.width.toDouble(),
        scale: item.scale / 100,
        repository: repository,
        sessionSpaceId: accountCardPreviewSpaceId,
        child: C5Preview(key: ValueKey(item.path), state: item.state),
      );
      if (item.scale == 200 && item.state != 'account_card_loading') {
        await Scrollable.ensureVisible(
          tester.element(find.byKey(const Key('account-card-history'))),
          alignment: 1,
        );
        await tester.pump();
        if (item.state == 'account_card_real') {
          await tester.drag(
            find.byKey(const Key('account-card-history')),
            const Offset(0, -80),
          );
          await tester.pump();
        }
      }
      expect(tester.takeException(), isNull);
      await expectLater(find.byKey(c3Boundary), matchesGoldenFile(item.path));
    });
  }
}

LedgerSnapshot _accountSnapshot(String state) {
  final empty = state == 'account_card_empty';
  final changed = state == 'account_card_archived_changed';
  final accounts = [
    LedgerRow({
      'id': accountCardPreviewRealId,
      'space_id': accountCardPreviewSpaceId,
      'name': changed ? '虚构银行卡新名字' : '虚构银行卡账户',
      'kind': 'real',
      'opening_balance_minor': 100000,
      'opening_on': '2026-10-01',
      'is_reserve': false,
      'version': changed ? 2 : 1,
      if (changed) 'archived_at': '2026-10-28T03:00:00Z',
    }),
    LedgerRow({
      'id': accountCardPreviewPurposeId,
      'space_id': accountCardPreviewSpaceId,
      'name': '虚构日常账户',
      'kind': 'purpose',
      'opening_balance_minor': 20000,
      'opening_on': '2026-10-01',
      'is_reserve': false,
      'version': 1,
    }),
    LedgerRow({
      'id': _otherRealId,
      'space_id': accountCardPreviewSpaceId,
      'name': '虚构备用账户',
      'kind': 'real',
      'opening_balance_minor': 0,
      'opening_on': '2026-10-01',
      'is_reserve': false,
      'version': 1,
    }),
    LedgerRow({
      'id': _otherPurposeId,
      'space_id': accountCardPreviewSpaceId,
      'name': '虚构旅行账户',
      'kind': 'purpose',
      'opening_balance_minor': 0,
      'opening_on': '2026-10-01',
      'is_reserve': false,
      'version': 1,
    }),
  ];
  return LedgerSnapshot(
    spaceId: accountCardPreviewSpaceId,
    space: LedgerRow({
      'id': accountCardPreviewSpaceId,
      'space_id': accountCardPreviewSpaceId,
      'name': '虚构家庭空间',
      'currency': 'CNY',
      'timezone': 'Asia/Singapore',
      'accent_color': 'pine',
      'modules': {'ledger': 'write'},
    }),
    accounts: accounts,
    records: empty
        ? const []
        : [
            _record(
              id: '123e4567-e89b-42d3-a456-426614174101',
              kind: 'refund',
              amount: 1200,
              note: '虚构午餐退款',
              date: '2026-10-28',
              createdAt: '2026-10-28T11:30:00Z',
            ),
            _record(
              id: '123e4567-e89b-42d3-a456-426614174102',
              kind: 'expense',
              amount: 6800,
              note: '虚构家庭晚餐',
              date: '2026-10-27',
              createdAt: '2026-10-27T12:10:00Z',
            ),
            _record(
              id: '123e4567-e89b-42d3-a456-426614174103',
              kind: 'income',
              amount: 50000,
              note: '虚构补贴收入',
              date: '2026-10-26',
              createdAt: '2026-10-26T08:00:00Z',
            ),
            _record(
              id: '123e4567-e89b-42d3-a456-426614174104',
              kind: 'allocation',
              amount: 40000,
              note: '虚构月度分配',
              date: '2026-10-05',
              createdAt: '2026-10-05T02:00:00Z',
              accountId: _otherRealId,
            ),
            _record(
              id: '123e4567-e89b-42d3-a456-426614174105',
              kind: 'transfer',
              amount: 12000,
              note: '虚构账户转账',
              date: '2026-10-03',
              createdAt: '2026-10-03T02:00:00Z',
              toAccountId: _otherRealId,
            ),
          ],
    members: [
      LedgerRow({
        'id': '123e4567-e89b-42d3-a456-426614174201',
        'space_id': accountCardPreviewSpaceId,
        'display_name': '虚构用户',
        'status': 'active',
      }),
    ],
  );
}

LedgerRow _record({
  required String id,
  required String kind,
  required int amount,
  required String note,
  required String date,
  required String createdAt,
  String accountId = accountCardPreviewRealId,
  String? toAccountId,
}) => LedgerRow({
  'id': id,
  'space_id': accountCardPreviewSpaceId,
  'kind': kind,
  'amount_minor': amount,
  'account_id': accountId,
  'to_account_id': ?toAccountId,
  'purpose_id': accountCardPreviewPurposeId,
  'tag_ids': <String>[],
  'attachments': <String>[],
  'status': 'active',
  'version': 1,
  'note': note,
  'occurred_on': date,
  'created_by_member_id': '123e4567-e89b-42d3-a456-426614174201',
  'created_at': createdAt,
});

final class _LoadingLedgerRepository extends FakeLedgerRepository {
  _LoadingLedgerRepository(super.snapshot);

  @override
  Stream<LedgerSnapshot> watch(String spaceId) => const Stream.empty();
}
