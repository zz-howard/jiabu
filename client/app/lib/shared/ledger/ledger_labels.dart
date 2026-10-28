import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jiabu/domain/history_filter.dart';
import 'package:jiabu/domain/ledger.dart';
import 'package:jiabu/domain/money.dart';
import 'package:jiabu/l10n/generated/app_localizations.dart';
import 'package:jiabu_design/jiabu_design.dart';

Map<String, String> ledgerLabels(AppLocalizations l) => {
  'expense': l.ledgerExpense,
  'income': l.ledgerIncome,
  'transfer': l.ledgerTransfer,
  'reallocation': l.ledgerReallocation,
  'refund': l.ledgerRefund,
  'allocation': l.ledgerAllocation,
  'dining': l.ledgerTagFood,
  'groceries': l.ledgerTagGroceries,
  'transport': l.ledgerTagTransport,
  'shopping': l.ledgerTagShopping,
  'housing': l.ledgerTagHousing,
  'daily': l.ledgerTagDaily,
  'medical': l.ledgerTagMedical,
  'education': l.ledgerTagEducation,
  'entertainment': l.ledgerTagEntertainment,
  'social': l.ledgerTagGifts,
  'other': l.ledgerTagOther,
};
String ledgerError(AppLocalizations l, String code) => switch (code) {
  'validation_failed' => l.ledgerInvalid,
  'aggregate_out_of_range' => l.ledgerAggregateRange,
  'same_endpoints' => l.ledgerSameEndpoints,
  'refund_exceeds_original' => l.ledgerRefundExceeded,
  'has_refunds' => l.ledgerHasRefunds,
  'parent_voided' => l.ledgerParentVoided,
  'balance_not_zero' => l.ledgerArchiveGuide,
  'account_archived' => l.ledgerArchivedChoice,
  'resolve_conflict_first' => l.ledgerResolveFirst,
  'explicit_restore_required' => l.ledgerAlreadyVoided,
  'unarchive_not_supported' => l.ledgerUnsupportedUnarchive,
  'restore_tag_not_supported' => l.ledgerUnsupportedTag,
  'local_read_failed' => l.ledgerLocalReadFailed,
  'client_too_old' => l.authClientTooOld,
  _ => l.ledgerGenericError,
};
String recordTitle(LedgerSnapshot snapshot, LedgerRow row, AppLocalizations l) {
  if (row.text('note').isNotEmpty) {
    return row.text('note');
  }
  final kind = row.text('kind');
  if (kind == 'transfer' || kind == 'reallocation') {
    final from = kind == 'transfer' ? 'account_id' : 'purpose_id';
    final to = kind == 'transfer' ? 'to_account_id' : 'to_purpose_id';
    final fromName =
        snapshot.find(snapshot.accounts, row.text(from))?.text('name') ?? '';
    final toName =
        snapshot.find(snapshot.accounts, row.text(to))?.text('name') ?? '';
    return '$fromName → $toName';
  }
  return recordSearchTitle(snapshot, row, ledgerLabels(l));
}

String memberLabel(LedgerSnapshot snapshot, LedgerRow row, AppLocalizations l) {
  final member = snapshot.find(
    snapshot.members,
    row.text('created_by_member_id'),
  );
  if (member == null) {
    return l.ledgerSystem;
  }
  return memberName(member, l);
}

String memberName(LedgerRow member, AppLocalizations l) {
  final left =
      member.text('status') == 'left' || member.data['left_at'] != null;
  return '${member.text('display_name')}${left ? ' · ${l.ledgerLeft}' : ''}';
}

String refundLabel(LedgerRow refund, LedgerSnapshot data, AppLocalizations l) {
  final amount = formatMinor(
    refund.number('amount_minor'),
    data.currency,
    l.localeName,
  );
  return '${l.ledgerRefund} $amount';
}

LedgerRow? creationEvent(LedgerSnapshot snapshot, String id) {
  final events =
      snapshot.events
          .where(
            (row) =>
                row.text('entity_kind') == 'record' &&
                row.text('entity_id') == id &&
                row.text('kind') == 'create',
          )
          .toList()
        ..sort((a, b) => a.number('id').compareTo(b.number('id')));
  return events.firstOrNull;
}

String formatMinor(int amount, String currency, String locale) {
  final symbols = NumberFormat.decimalPattern(locale).symbols;
  final scale = currencyDecimals[currency] == 0 ? 1 : 100;
  final whole = (amount.abs() ~/ scale).toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]}${symbols.GROUP_SEP}',
  );
  final sign = amount < 0 ? '−' : '';
  final symbol = NumberFormat.simpleCurrency(
    locale: locale,
    name: currency,
  ).currencySymbol;
  final fraction = scale == 1
      ? ''
      : '${symbols.DECIMAL_SEP}'
            '${(amount.abs() % 100).toString().padLeft(2, '0')}';
  return '$sign$symbol$whole$fraction';
}

Widget ledgerAmount(
  BuildContext context,
  int minor,
  String currency, {
  AmountRole role = AmountRole.list,
  String? kind,
}) {
  final l = AppLocalizations.of(context);
  final symbols = NumberFormat.decimalPattern(l.localeName).symbols;
  return AmountText(
    minorUnits: minor,
    currencySymbol: NumberFormat.simpleCurrency(
      locale: l.localeName,
      name: currency,
    ).currencySymbol,
    decimalDigits: currencyDecimals[currency] ?? 2,
    groupSeparator: symbols.GROUP_SEP,
    decimalSeparator: symbols.DECIMAL_SEP,
    semanticLabel: l.ledgerAmountLabel(
      kind ?? '',
      formatMinor(minor, currency, l.localeName),
    ),
    role: role,
  );
}

String ledgerDate(String value, AppLocalizations l) {
  final date = DateTime.tryParse(value);
  return date == null ? value : DateFormat.yMMMd(l.localeName).format(date);
}

String operationTitle(LedgerSnapshot data, LedgerRow op, AppLocalizations l) {
  final labels = <String>[];
  for (final ref in op.strings('entity_ids')) {
    final separator = ref.indexOf(':');
    if (separator < 0) {
      continue;
    }
    final kind = ref.substring(0, separator);
    final id = ref.substring(separator + 1);
    if (kind == 'record') {
      final record = data.find(data.records, id);
      if (record != null) {
        labels.add(recordTitle(data, record, l));
      }
    } else if (kind == 'account' || kind == 'allocation_plan') {
      labels.add(
        data.find(data.accounts, id)?.text('name') ?? l.ledgerAccounts,
      );
    } else if (kind == 'tag') {
      labels.add(tagName(data.find(data.tags, id), ledgerLabels(l)));
    }
  }
  return labels.isEmpty ? l.ledgerPending : labels.join(' · ');
}

String recordStickerCategory(LedgerRow row) => switch (row.text('kind')) {
  'reallocation' => 'move',
  'transfer' => 'transfer',
  'income' => 'income',
  'allocation' => 'alloc',
  'refund' => 'income',
  _ => 'food',
};

String formatCompactMinor(int amount, String currency, String locale) {
  final formatted = formatMinor(amount, currency, locale);
  final decimal = NumberFormat.decimalPattern(locale).symbols.DECIMAL_SEP;
  final suffix = '${decimal}00';
  return formatted.endsWith(suffix)
      ? formatted.substring(0, formatted.length - suffix.length)
      : formatted;
}

String ledgerHistoryTime(LedgerRow row, AppLocalizations l) {
  final occurred = row.text('occurred_on');
  final date = DateTime.tryParse(occurred);
  if (date == null) {
    return occurred;
  }
  // Ledger dates are day precision. Never invent a time from created_at.
  return occurred.contains('T')
      ? DateFormat.Hm(l.localeName).format(date)
      : DateFormat.Md(l.localeName).format(date);
}
