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
    final balance = ledgerAccountBalance(snapshot, account);
    if (balance case Failure<int>(:final code)) {
      return Failure(code);
    }
    result[account.id] = (balance as Ok<int>).value;
  }
  return Ok(Map.unmodifiable(result));
}

/// Calculates one account without allowing an unrelated account's overflow to
/// suppress a detail view for this account.
Result<int> ledgerAccountBalance(LedgerSnapshot snapshot, LedgerRow account) {
  if (account.text('space_id') != snapshot.spaceId) {
    return const Failure('account_space_mismatch');
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
        if (const ['income', 'refund'].contains(kind)) sign = 1;
        if (const ['expense', 'transfer'].contains(kind)) sign = -1;
      } else if (kind == 'transfer' &&
          record.text('to_account_id') == account.id) {
        sign = 1;
      }
    } else if (account.text('kind') == 'purpose') {
      if (record.text('purpose_id') == account.id) {
        if (const ['allocation', 'refund'].contains(kind)) sign = 1;
        if (const ['expense', 'reallocation'].contains(kind)) sign = -1;
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
  return Ok(amount.toInt());
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

/// Sum of every real (money) account balance in the space, archived accounts
/// included because their remaining balance is still money the space holds.
/// Purpose accounts split the same money, so they are never added in.
/// Returns null when the sum leaves the safe integer range.
int? realAccountsTotal(LedgerSnapshot snapshot, Map<String, int> balances) =>
    _kindTotal(snapshot, balances, 'real');

/// Sum of every purpose account balance in the space (the overview hero's
/// 「用途账户合计」), archived ones included while they still hold a balance.
/// Negative balances count as they are. Null outside the safe integer range.
int? purposeAccountsTotal(LedgerSnapshot snapshot, Map<String, int> balances) =>
    _kindTotal(snapshot, balances, 'purpose');

int? _kindTotal(
  LedgerSnapshot snapshot,
  Map<String, int> balances,
  String kind,
) {
  var total = BigInt.zero;
  for (final account in snapshot.accounts) {
    if (account.text('space_id') == snapshot.spaceId &&
        account.text('kind') == kind) {
      total += BigInt.from(balances[account.id] ?? 0);
    }
  }
  return total.abs() > BigInt.from(9007199254740991) ? null : total.toInt();
}

/// The enabled monthly allocation of a purpose account (minor units), or null
/// when it has no plan, the plan is switched off or allocates nothing.
int? monthlyAllocation(LedgerSnapshot snapshot, String accountId) {
  final plan = snapshot.find(snapshot.plans, accountId);
  if (plan == null || !plan.flag('enabled')) {
    return null;
  }
  final amount = plan.number('amount_minor');
  return amount > 0 ? amount : null;
}

/// Consumption on days of `month` ("yyyy-MM", in the space calendar) using the
/// same expense-minus-refund rule as the daily history totals.
int monthExpense(LedgerSnapshot snapshot, String month) => dailyExpense(
  snapshot.records.where(
    (r) =>
        r.text('space_id') == snapshot.spaceId &&
        r.text('occurred_on').startsWith('$month-'),
  ),
);
