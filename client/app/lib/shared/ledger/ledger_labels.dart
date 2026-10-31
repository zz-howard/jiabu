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
  'record_changed_elsewhere' => l.ledgerRecentlyChanged,
  'account_name_taken' => l.ledgerAccountNameTaken,
  'reserve_account_exists' => l.ledgerReserveExists,
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
    final fromName = snapshot.account(row.text(from))?.text('name') ?? '';
    final toName = snapshot.account(row.text(to))?.text('name') ?? '';
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
  AmountTone tone = AmountTone.auto,
  bool showPlus = false,
  bool highlighted = false,
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
    tone: tone,
    showPlus: showPlus,
    highlighted: highlighted,
  );
}

/// The amount of one record as a signed movement, the way the original design
/// shows it: an expense is `−¥68.00` in the ordinary ink (never red, spending
/// is normal); money coming in (income, refund, monthly allocation) is
/// `+¥3,000.00` in green; transfers and reallocations move money between
/// accounts and carry no sign.
Widget recordAmount(
  BuildContext context,
  LedgerRow row,
  String currency, {
  AmountRole role = AmountRole.list,
  String? kind,
  bool highlighted = false,
}) {
  final minor = row.number('amount_minor').abs();
  final recordKind = row.text('kind');
  final out = recordKind == 'expense';
  final incoming = const [
    'income',
    'refund',
    'allocation',
  ].contains(recordKind);
  return ledgerAmount(
    context,
    out ? -minor : minor,
    currency,
    role: role,
    kind: kind,
    tone: incoming ? AmountTone.positive : AmountTone.plain,
    showPlus: incoming,
    highlighted: highlighted,
  );
}

/// The Caveat accent of the overview subtitle, `Oct. 30 · Fri`. Month names of
/// four letters or fewer (May, June, July) are written out, the rest take a
/// dot.
String handDateAccent(DateTime date) {
  final month = DateFormat.MMMM('en').format(date);
  final short = month.length <= 4 ? month : '${month.substring(0, 3)}.';
  return '$short ${date.day} · ${DateFormat.E('en').format(date)}';
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
      labels.add(data.account(id)?.text('name') ?? l.ledgerAccounts);
    } else if (kind == 'tag') {
      labels.add(tagName(data.find(data.tags, id), ledgerLabels(l)));
    }
  }
  return labels.isEmpty ? l.ledgerPending : labels.join(' · ');
}

/// The round sticker of a record. Expenses take the sticker of their first
/// preset tag when the [snapshot] is known (dining → food, transport →
/// travel, …); everything else keeps the kind's sticker.
String recordStickerCategory(LedgerRow row, {LedgerSnapshot? snapshot}) {
  final kind = row.text('kind');
  if (kind == 'expense' && snapshot != null) {
    for (final id in row.strings('tag_ids')) {
      final preset = snapshot.find(snapshot.tags, id)?.text('preset_key');
      final category = _tagStickers[preset];
      if (category != null) {
        return category;
      }
    }
  }
  return switch (kind) {
    'reallocation' => 'move',
    'transfer' => 'transfer',
    'income' => 'income',
    'allocation' => 'alloc',
    'refund' => 'income',
    _ => 'food',
  };
}

const _tagStickers = <String, String>{
  'dining': 'food',
  'groceries': 'food',
  'transport': 'travel',
  'housing': 'home',
  'daily': 'home',
  'medical': 'health',
  'education': 'edu',
  'entertainment': 'hobby',
};

/// The history row's second line, the original 「招行卡 · 日常餐饮」: the
/// real account and the purpose account (or, without a purpose, the first
/// tag). Transfers and reallocations already name both ends in their title,
/// so they show their kind.
String recordAccountLine(
  LedgerSnapshot snapshot,
  LedgerRow row,
  AppLocalizations l,
) {
  final kind = row.text('kind');
  final labels = ledgerLabels(l);
  if (kind == 'transfer' || kind == 'reallocation') {
    return labels[kind] ?? '';
  }
  String name(String field) =>
      snapshot.account(row.text(field))?.text('name') ?? '';
  final account = name('account_id');
  var category = name('purpose_id');
  if (category.isEmpty) {
    category = name('to_purpose_id');
  }
  if (category.isEmpty) {
    final tags = row.strings('tag_ids');
    category = tags.isEmpty
        ? ''
        : tagName(snapshot.find(snapshot.tags, tags.first), labels);
  }
  final parts = [account, category].where((part) => part.isNotEmpty);
  return parts.isEmpty ? labels[kind] ?? '' : parts.join(' · ');
}

/// The small time under a history row's amount: when the record was written
/// down (`created_at`, local 24-hour clock). Records carry only a day for
/// when the money moved, so this is the entry time, never a guessed one; a
/// record without `created_at` shows no time.
String recordEntryTime(LedgerRow row, AppLocalizations l) {
  final at = DateTime.tryParse(row.text('created_at'))?.toLocal();
  return at == null ? '' : DateFormat.Hm(l.localeName).format(at);
}

/// The history day tape, the original 「10月25日 周日」 (`Oct 25 Sun`); a
/// day from another year than [now] keeps its year.
String ledgerDayLabel(String value, DateTime now, AppLocalizations l) {
  final date = DateTime.tryParse(value);
  if (date == null) {
    return value;
  }
  final format = date.year == now.year
      ? DateFormat.MMMd(l.localeName)
      : DateFormat.yMMMd(l.localeName);
  return format.add_E().format(date);
}

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
