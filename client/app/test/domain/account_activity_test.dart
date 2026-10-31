import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/domain/account_activity.dart';
import 'package:jiabu/domain/ledger.dart';
import 'package:jiabu/domain/result.dart';

void main() {
  const spaceId = 'space-a';

  LedgerRow account(String id, String kind, {int opening = 0}) => LedgerRow({
    'id': id,
    'space_id': spaceId,
    'kind': kind,
    'name': id,
    'opening_balance_minor': opening,
    'version': 1,
  });

  LedgerRow record(
    String id,
    String kind,
    int amount, {
    String? real,
    String? toReal,
    String? purpose,
    String? toPurpose,
    String date = '2026-10-10',
    String created = '2026-10-10T10:00:00Z',
    String status = 'active',
    String recordSpace = spaceId,
  }) => LedgerRow({
    'id': id,
    'space_id': recordSpace,
    'kind': kind,
    'status': status,
    'amount_minor': amount,
    'account_id': ?real,
    'to_account_id': ?toReal,
    'purpose_id': ?purpose,
    'to_purpose_id': ?toPurpose,
    'occurred_on': date,
    'created_at': created,
  });

  LedgerSnapshot snapshot(List<LedgerRow> records) => LedgerSnapshot(
    spaceId: spaceId,
    space: LedgerRow({
      'id': spaceId,
      'space_id': spaceId,
      'currency': 'CNY',
      'modules': {'ledger': 'write'},
    }),
    records: records,
  );

  group('accountMovement', () {
    test(
      'real account covers income expense refund and both transfer sides',
      () {
        final selected = account('real-a', 'real');
        final cases = <LedgerRow, int>{
          record('income', 'income', 100, real: 'real-a'): 100,
          record('expense', 'expense', 20, real: 'real-a'): -20,
          record('refund', 'refund', 5, real: 'real-a'): 5,
          record(
            'transfer-out',
            'transfer',
            30,
            real: 'real-a',
            toReal: 'real-b',
          ): -30,
          record(
            'transfer-in',
            'transfer',
            40,
            real: 'real-b',
            toReal: 'real-a',
          ): 40,
        };
        for (final entry in cases.entries) {
          final movement = accountMovement(selected, entry.key);
          expect(movement?.signedMinor, entry.value, reason: entry.key.id);
          expect(
            movement?.direction,
            entry.value > 0
                ? AccountFlowDirection.incoming
                : AccountFlowDirection.outgoing,
            reason: entry.key.id,
          );
        }
      },
    );

    test(
      'purpose account covers allocation expense refund and reallocations',
      () {
        final selected = account('purpose-a', 'purpose');
        final cases = <LedgerRow, int>{
          record('allocation', 'allocation', 100, purpose: 'purpose-a'): 100,
          record('expense', 'expense', 20, purpose: 'purpose-a'): -20,
          record('refund', 'refund', 5, purpose: 'purpose-a'): 5,
          record(
            'reallocation-out',
            'reallocation',
            30,
            purpose: 'purpose-a',
            toPurpose: 'purpose-b',
          ): -30,
          record(
            'reallocation-in',
            'reallocation',
            40,
            purpose: 'purpose-b',
            toPurpose: 'purpose-a',
          ): 40,
        };
        for (final entry in cases.entries) {
          expect(
            accountMovement(selected, entry.key)?.signedMinor,
            entry.value,
            reason: entry.key.id,
          );
        }
      },
    );

    test('ignores void, another account, and another space', () {
      final selected = account('real-a', 'real');
      expect(
        accountMovement(
          selected,
          record('void', 'expense', 10, real: 'real-a', status: 'voided'),
        ),
        isNull,
      );
      expect(
        accountMovement(
          selected,
          record('other', 'expense', 10, real: 'real-b'),
        ),
        isNull,
      );
      expect(
        accountMovement(
          selected,
          record(
            'foreign',
            'expense',
            10,
            real: 'real-a',
            recordSpace: 'space-b',
          ),
        ),
        isNull,
      );
    });
  });

  test(
    'month flows include boundaries but exclude adjacent months and opening',
    () {
      final selected = account('real-a', 'real', opening: 5000);
      final normal = accountMonthFlows(
        snapshot([
          record(
            'first-day',
            'income',
            100,
            real: 'real-a',
            date: '2026-10-01',
          ),
          record('last-day', 'expense', 25, real: 'real-a', date: '2026-10-31'),
          record('before', 'income', 999, real: 'real-a', date: '2026-09-30'),
          record('after', 'expense', 888, real: 'real-a', date: '2026-11-01'),
        ]),
        selected,
        '2026-10',
      );
      expect(normal, isA<Ok<AccountMonthFlows>>());
      final flows = (normal as Ok<AccountMonthFlows>).value;
      expect((flows.incoming, flows.outgoing), (100, 25));

      final overflow = accountMonthFlows(
        snapshot([
          record('max', 'income', 9007199254740991, real: 'real-a'),
          record('one', 'income', 1, real: 'real-a'),
        ]),
        selected,
        '2026-10',
      );
      expect(overflow, isA<Failure<AccountMonthFlows>>());
      expect(
        (overflow as Failure<AccountMonthFlows>).code,
        'aggregate_out_of_range',
      );
    },
  );

  test('recent records include destinations and cap after sorting', () {
    final rows = [
      record('older', 'expense', 1, real: 'real-a', date: '2026-10-09'),
      record('same-a', 'transfer', 2, real: 'real-b', toReal: 'real-a'),
      record('same-b', 'income', 3, real: 'real-a'),
      record(
        'newest',
        'income',
        4,
        real: 'real-a',
        created: '2026-10-10T11:00:00Z',
      ),
      record('void', 'income', 5, real: 'real-a', status: 'voided'),
    ];
    expect(
      accountRecentRecords(snapshot(rows), 'real-a').map((row) => row.id),
      ['newest', 'same-b', 'same-a'],
    );
  });

  test(
    'purpose recent records include source and destination reallocations',
    () {
      final rows = [
        record(
          'reallocation-out',
          'reallocation',
          10,
          purpose: 'purpose-a',
          toPurpose: 'purpose-b',
        ),
        record(
          'reallocation-in',
          'reallocation',
          20,
          purpose: 'purpose-b',
          toPurpose: 'purpose-a',
          created: '2026-10-10T11:00:00Z',
        ),
      ];
      expect(
        accountRecentRecords(snapshot(rows), 'purpose-a').map((row) => row.id),
        ['reallocation-in', 'reallocation-out'],
      );
    },
  );
}
