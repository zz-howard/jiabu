import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/domain/ledger.dart';
import 'package:jiabu/domain/ledger_balance.dart';
import 'package:jiabu/domain/result.dart';

import '../support/ledger_fixture.dart';

void main() {
  test('ledger_fixture_matches_expected_balances', () {
    final expected = readLedgerFixture();
    for (final allocation in [false, true]) {
      final result = ledgerBalances(ledgerFixture(allocation: allocation));
      expect(result, isA<Ok<Map<String, int>>>());
      expect(
        (result as Ok<Map<String, int>>).value,
        expected[allocation ? 'expected' : 'expected_before_allocation'],
      );
    }
  });
  test('aggregate_range_and_cancellation_remain_exact', () {
    LedgerSnapshot data(List<int> amounts) => LedgerSnapshot(
      spaceId: 's',
      space: LedgerRow({}),
      accounts: [
        LedgerRow({
          'id': 'a',
          'space_id': 's',
          'kind': 'real',
          'opening_balance_minor': 0,
        }),
      ],
      records: [
        for (var i = 0; i < amounts.length; i++)
          LedgerRow({
            'id': 'r$i',
            'space_id': 's',
            'kind': amounts[i] < 0 ? 'expense' : 'income',
            'account_id': 'a',
            'amount_minor': amounts[i].abs(),
            'status': 'active',
          }),
      ],
    );
    expect(
      (ledgerBalances(
        data([9007199254740991, 2, -2]),
      ) as Ok<Map<String, int>>).value['a'],
      9007199254740991,
    );
    expect(
      ledgerBalances(data([9007199254740991, 1])),
      isA<Failure<Map<String, int>>>(),
    );
    expect(
      ledgerBalances(data([-9007199254740991, -1])),
      isA<Failure<Map<String, int>>>(),
    );
  });
  test(
    'balance_includes_archived_accounts_and_ignores_opening_date_cutoff',
    () {
      final fixture = ledgerFixture();
      final data = LedgerSnapshot(
        spaceId: fixture.spaceId,
        space: fixture.space,
        records: fixture.records,
        accounts: [
          for (final a in fixture.accounts)
            LedgerRow({
              ...a.data,
              'opening_on': '2099-01-01',
              'archived_at': '2026-10-06',
            }),
        ],
      );
      expect(
        (ledgerBalances(data) as Ok<Map<String, int>>).value,
        readLedgerFixture()['expected'],
      );
    },
  );
  test('unresolved_conflict_uses_server_balance', () {
    final base = ledgerFixture();
    final data = LedgerSnapshot(
      spaceId: base.spaceId,
      space: base.space,
      accounts: base.accounts,
      records: [
        for (final r in base.records)
          LedgerRow(
            r.data,
            syncState: r.id == 'expense-a' ? 'conflict' : r.syncState,
          ),
      ],
      conflicts: [
        LedgerRow({
          'entity_kind': 'record',
          'entity_id': 'expense-a',
          'mine_json': jsonEncode({
            ...base.records.singleWhere((r) => r.id == 'expense-a').data,
            'amount_minor': 99999,
          }),
        }),
      ],
    );
    expect(
      (ledgerBalances(data) as Ok<Map<String, int>>).value,
      readLedgerFixture()['expected'],
    );
  });
  test('daily_expense_counts_each_refund_on_its_own_day', () {
    final data = ledgerFixture();
    expect(
      dailyExpense(
        data.records.where((r) => r.text('occurred_on') == '2026-10-02'),
      ),
      5000,
    );
    expect(
      dailyExpense(
        data.records.where((r) => r.text('occurred_on') == '2026-10-04'),
      ),
      -1200,
    );
  });
}
