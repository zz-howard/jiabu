import 'package:jiabu/domain/ledger.dart';

final class HistoryFilter {
  const HistoryFilter({
    this.text = '',
    this.member,
    this.account,
    this.tag,
    this.kind,
    this.from,
    this.through,
    this.labels = const {},
  });
  final String text;
  final String? member;
  final String? account;
  final String? tag;
  final String? kind;
  final String? from;
  final String? through;
  final Map<String, String> labels;
  bool get isFiltered =>
      text.isNotEmpty ||
      member != null ||
      account != null ||
      tag != null ||
      kind != null ||
      from != null ||
      through != null;
}

String recordSearchTitle(
  LedgerSnapshot snapshot,
  LedgerRow row,
  Map<String, String> labels,
) => [
  labels[row.text('kind')] ?? row.text('kind'),
  for (final field in [
    'account_id',
    'to_account_id',
    'purpose_id',
    'to_purpose_id',
  ])
    snapshot.find(snapshot.accounts, row.text(field))?.text('name') ?? '',
  for (final id in row.strings('tag_ids'))
    tagName(snapshot.find(snapshot.tags, id), labels),
].join(' ');

String tagName(LedgerRow? tag, Map<String, String> labels) => tag == null
    ? ''
    : (tag.text('name').isNotEmpty
          ? tag.text('name')
          : labels[tag.text('preset_key')] ?? tag.text('preset_key'));

List<LedgerRow> filterHistory(LedgerSnapshot snapshot, HistoryFilter filter) {
  final result =
      snapshot.records.where((row) {
        if (row.text('space_id') != snapshot.spaceId) {
          return false;
        }
        if (filter.member != null &&
            row.text('created_by_member_id') != filter.member) {
          return false;
        }
        if (filter.account != null &&
            ![
              'account_id',
              'to_account_id',
              'purpose_id',
              'to_purpose_id',
            ].any((key) => row.text(key) == filter.account)) {
          return false;
        }
        if (filter.tag != null &&
            !row.strings('tag_ids').contains(filter.tag)) {
          return false;
        }
        if (filter.kind != null && row.text('kind') != filter.kind) {
          return false;
        }
        final date = row.text('occurred_on');
        final from = filter.from;
        final through = filter.through;
        if (from != null && date.compareTo(from) < 0) {
          return false;
        }
        if (through != null && date.compareTo(through) > 0) {
          return false;
        }
        final title = recordSearchTitle(snapshot, row, filter.labels);
        return '${row.text('note')} $title'.toLowerCase().contains(
          filter.text.toLowerCase(),
        );
      }).toList()..sort((a, b) {
        final date = b.text('occurred_on').compareTo(a.text('occurred_on'));
        if (date != 0) {
          return date;
        }
        // Within a day, the latest entry first: rows show their entry time.
        final entered = b.text('created_at').compareTo(a.text('created_at'));
        return entered == 0 ? b.id.compareTo(a.id) : entered;
      });
  return result;
}
