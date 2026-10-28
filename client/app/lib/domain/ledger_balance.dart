import 'package:jiabu/domain/ledger.dart';
import 'package:jiabu/domain/result.dart';

/// Mirrors db/src/ledger/queries.rs BALANCE_SQL, including archived accounts,
/// no opening_on cutoff, exact numeric intermediates and the final safe range.
Result<Map<String, int>> ledgerBalances(LedgerSnapshot snapshot) {
  final result = <String, int>{};
  for (final account in snapshot.accounts) {
    if (account.text('space_id') != snapshot.spaceId) {
      continue;
    }
    var amount = BigInt.from(account.number('opening_balance_minor'));
    for (final record in snapshot.records) {
      if (record.text('space_id') != snapshot.spaceId || !record.active) {
        continue;
      }
      final kind = record.text('kind');
      var sign = 0;
      if (account.text('kind') == 'real') {
        if (record.text('account_id') == account.id) {
          if (const ['income', 'refund'].contains(kind)) {
            sign = 1;
          }
          if (const ['expense', 'transfer'].contains(kind)) {
            sign = -1;
          }
        } else if (kind == 'transfer' &&
            record.text('to_account_id') == account.id) {
          sign = 1;
        }
      } else if (account.text('kind') == 'purpose') {
        if (record.text('purpose_id') == account.id) {
          if (const ['allocation', 'refund'].contains(kind)) {
            sign = 1;
          }
          if (const ['expense', 'reallocation'].contains(kind)) {
            sign = -1;
          }
        } else if (kind == 'reallocation' &&
            record.text('to_purpose_id') == account.id) {
          sign = 1;
        }
      }
      amount += BigInt.from(record.number('amount_minor')) * BigInt.from(sign);
    }
    if (amount.abs() > BigInt.from(9007199254740991)) {
      return const Failure('aggregate_out_of_range');
    }
    result[account.id] = amount.toInt();
  }
  return Ok(Map.unmodifiable(result));
}

int refundedMinor(
  LedgerSnapshot snapshot,
  String parent, {
  String? excluding,
}) => snapshot.records
    .where(
      (row) =>
          row.text('space_id') == snapshot.spaceId &&
          row.active &&
          row.text('kind') == 'refund' &&
          row.text('refund_of_id') == parent &&
          row.id != excluding,
    )
    .fold(0, (sum, row) => sum + row.number('amount_minor'));

/// Refunds affect consumption on their own occurred_on.
/// Account associations never duplicate consumption.
int dailyExpense(Iterable<LedgerRow> records) => records
    .where((r) => r.active)
    .fold(
      0,
      (sum, r) =>
          sum +
          switch (r.text('kind')) {
            'expense' => r.number('amount_minor'),
            'refund' => -r.number('amount_minor'),
            _ => 0,
          },
    );
