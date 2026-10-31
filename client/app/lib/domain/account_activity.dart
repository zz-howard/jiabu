import 'package:jiabu/domain/history_filter.dart';
import 'package:jiabu/domain/ledger.dart';
import 'package:jiabu/domain/result.dart';

const _maxSafeMinor = 9007199254740991;

enum AccountFlowDirection { incoming, outgoing }

final class AccountMovement {
  const AccountMovement({required this.signedMinor, required this.direction});

  final int signedMinor;
  final AccountFlowDirection direction;
}

final class AccountMonthFlows {
  const AccountMonthFlows({required this.incoming, required this.outgoing});

  final int incoming;
  final int outgoing;
}

/// Returns this record's signed movement relative to [account], or null when
/// the record does not affect it. The matrix mirrors ledgerBalances.
AccountMovement? accountMovement(LedgerRow account, LedgerRow record) {
  if (!record.active || record.text('space_id') != account.text('space_id')) {
    return null;
  }
  final amount = record.number('amount_minor').abs();
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
  if (sign == 0) return null;
  return AccountMovement(
    signedMinor: amount * sign,
    direction: sign > 0
        ? AccountFlowDirection.incoming
        : AccountFlowDirection.outgoing,
  );
}

Result<AccountMonthFlows> accountMonthFlows(
  LedgerSnapshot snapshot,
  LedgerRow account,
  String month,
) {
  var incoming = BigInt.zero;
  var outgoing = BigInt.zero;
  for (final record in snapshot.records) {
    if (!record.text('occurred_on').startsWith('$month-')) continue;
    final movement = accountMovement(account, record);
    if (movement == null) continue;
    final amount = BigInt.from(movement.signedMinor.abs());
    if (movement.direction == AccountFlowDirection.incoming) {
      incoming += amount;
    } else {
      outgoing += amount;
    }
  }
  final max = BigInt.from(_maxSafeMinor);
  if (incoming > max || outgoing > max) {
    return const Failure('aggregate_out_of_range');
  }
  return Ok(
    AccountMonthFlows(incoming: incoming.toInt(), outgoing: outgoing.toInt()),
  );
}

List<LedgerRow> accountRecentRecords(
  LedgerSnapshot snapshot,
  String accountId, {
  int limit = 3,
}) => filterHistory(
  snapshot,
  HistoryFilter(account: accountId),
).where((row) => row.active).take(limit).toList(growable: false);
