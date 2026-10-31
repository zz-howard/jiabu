import 'package:jiabu/domain/ledger.dart';
import 'package:jiabu/domain/ledger_balance.dart';

String? validateRecord(
  LedgerSnapshot snapshot,
  Map<String, Object?> values, {
  String? editing,
}) {
  final kind = values['kind'];
  final amount = values['amount_minor'];
  if (amount is! int ||
      amount <= 0 ||
      amount > 1000000000000 ||
      !validLedgerDate(values['occurred_on']?.toString() ?? '')) {
    return 'validation_failed';
  }
  final shape = switch (kind) {
    'expense' => ['account_id', 'purpose_id'],
    'income' => ['account_id'],
    'transfer' => ['account_id', 'to_account_id'],
    'reallocation' => ['purpose_id', 'to_purpose_id'],
    'refund' => ['account_id', 'purpose_id', 'refund_of_id'],
    'allocation' when editing != null => ['purpose_id'],
    _ => <String>[],
  };
  if (shape.isEmpty ||
      shape.any((field) => values[field] is! String || values[field] == '')) {
    return 'validation_failed';
  }
  if (kind == 'transfer' && values['account_id'] == values['to_account_id']) {
    return 'same_endpoints';
  }
  if (kind == 'reallocation' &&
      values['purpose_id'] == values['to_purpose_id']) {
    return 'same_endpoints';
  }
  final original = editing == null
      ? null
      : snapshot.find(snapshot.records, editing);
  for (final field in [
    'account_id',
    'to_account_id',
    'purpose_id',
    'to_purpose_id',
  ]) {
    final id = values[field];
    if (id == null) {
      continue;
    }
    if (!shape.contains(field)) {
      return 'validation_failed';
    }
    final account = snapshot.account(id.toString());
    if (account == null ||
        account.text('kind') !=
            (field.contains('purpose') ? 'purpose' : 'real')) {
      return 'validation_failed';
    }
    if (account.archived && original?.data[field] != id) {
      return 'account_archived';
    }
  }
  if (kind == 'refund') {
    final parent = snapshot.find(
      snapshot.records,
      values['refund_of_id'].toString(),
    );
    if (parent == null || parent.text('kind') != 'expense' || !parent.active) {
      return 'parent_voided';
    }
    if (refundedMinor(snapshot, parent.id, excluding: editing) + amount >
        parent.number('amount_minor')) {
      return 'refund_exceeds_original';
    }
  }
  if (kind == 'expense' &&
      editing != null &&
      refundedMinor(snapshot, editing) > amount) {
    return 'refund_exceeds_original';
  }
  final tags = (values['tag_ids'] as List<Object?>? ?? const []).cast<String>();
  if (tags.length > 20 || tags.toSet().length != tags.length) {
    return 'validation_failed';
  }
  for (final id in tags) {
    final tag = snapshot.find(snapshot.tags, id);
    if (tag == null ||
        (tag.data['deleted_at'] != null &&
            !(original?.strings('tag_ids').contains(id) ?? false))) {
      return 'validation_failed';
    }
  }
  if ((values['note']?.toString().runes.length ?? 0) > 500) {
    return 'validation_failed';
  }
  return null;
}

bool validLedgerDate(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    return false;
  }
  final parsed = DateTime.tryParse(value);
  return parsed != null &&
      parsed.year.toString().padLeft(4, '0') == value.substring(0, 4) &&
      parsed.month.toString().padLeft(2, '0') == value.substring(5, 7) &&
      parsed.day.toString().padLeft(2, '0') == value.substring(8, 10);
}
