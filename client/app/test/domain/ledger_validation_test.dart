import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/domain/allocation_calendar.dart';
import 'package:jiabu/domain/ledger_validation.dart';
import 'package:jiabu/domain/money.dart';

import '../support/ledger_fixture.dart';

void main() {
  test('transfer_same_endpoints_is_rejected_before_enqueue', () {
    expect(
      validateRecord(ledgerFixture(), {
        'kind': 'transfer',
        'amount_minor': 10,
        'occurred_on': '2026-10-01',
        'account_id': 'real-a',
        'to_account_id': 'real-a',
      }),
      'same_endpoints',
    );
  });
  test('reallocation_same_endpoints_is_rejected_before_enqueue', () {
    expect(
      validateRecord(ledgerFixture(), {
        'kind': 'reallocation',
        'amount_minor': 10,
        'occurred_on': '2026-10-01',
        'purpose_id': 'purpose-a',
        'to_purpose_id': 'purpose-a',
      }),
      'same_endpoints',
    );
  });
  test('refund_rejects_one_minor_unit_above_remaining', () {
    Map<String, Object?> refund(int amount) => {
      'kind': 'refund',
      'amount_minor': amount,
      'occurred_on': '2026-10-05',
      'account_id': 'real-a',
      'purpose_id': 'purpose-a',
      'refund_of_id': 'expense-a',
    };
    expect(validateRecord(ledgerFixture(), refund(3800)), isNull);
    expect(
      validateRecord(ledgerFixture(), refund(3801)),
      'refund_exceeds_original',
    );
    expect(
      validateRecord(ledgerFixture(), {
        ...refund(5000),
        'id': 'refund-a',
      }, editing: 'refund-a'),
      isNull,
    );
  });
  test('expense_cannot_be_reduced_below_active_refunds', () {
    final data = ledgerFixture();
    final expense = data.find(data.records, 'expense-a')!;
    expect(
      validateRecord(data, {
        ...expense.data,
        'amount_minor': 1199,
      }, editing: expense.id),
      'refund_exceeds_original',
    );
  });
  test('money_parsing_is_exact_and_currency_aware', () {
    expect(parseMinor('0.01', 'CNY'), 1);
    expect(parseMinor('42', 'JPY'), 42);
    expect(parseMinor('42.00', 'JPY'), isNull);
    expect(parseMinor('1.001', 'CNY'), isNull);
    expect(parseMinor('−2.30', 'CNY', signed: true), -230);
    expect(parseMinor('1,25', 'EUR', decimal: ','), 125);
    expect(parseMinor('10000000000.01', 'CNY'), isNull);
    expect(minorInput(123, 'JPY'), '123');
  });
  test('allocation_calendar_matches_first_and_continuing_rules', () {
    expect(
      nextAllocation(DateTime.utc(2026, 10, 20), 15),
      DateTime.utc(2026, 11, 15),
    );
    expect(
      nextAllocation(DateTime.utc(2026, 10, 20), 15, continuing: true),
      DateTime.utc(2026, 10, 15),
    );
    expect(
      nextAllocation(
        DateTime.utc(2026, 10, 20),
        15,
        continuing: true,
        lastMonth: '2026-10',
      ),
      DateTime.utc(2026, 11, 15),
    );
    expect(dueInMonth(2027, 2, 31), DateTime.utc(2027, 2, 28));
    expect(dueInMonth(2028, 2, 31), DateTime.utc(2028, 2, 29));
    expect(
      nextAllocation(DateTime.utc(2026, 12, 31), 31),
      DateTime.utc(2027, 1, 31),
    );
  });
}
