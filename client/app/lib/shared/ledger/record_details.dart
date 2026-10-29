import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:jiabu/app/ledger_providers.dart';
import 'package:jiabu/domain/history_filter.dart';
import 'package:jiabu/domain/ledger.dart';
import 'package:jiabu/domain/result.dart';
import 'package:jiabu/l10n/generated/app_localizations.dart';
import 'package:jiabu/shared/ledger/ledger_forms.dart';
import 'package:jiabu/shared/ledger/ledger_labels.dart';
import 'package:jiabu/shared/ledger/ledger_sheet.dart';
import 'package:jiabu/shared/ledger/ledger_view_model.dart';
import 'package:jiabu_design/jiabu_design.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'record_details.g.dart';

@riverpod
Future<Result<List<int>>> recordImage(
  Ref ref,
  String spaceId,
  String hash, {
  bool download = false,
}) => ref
    .watch(ledgerRepositoryProvider)
    .image(spaceId, hash, download: download);

Future<void> openRecordDetails(
  BuildContext context,
  String spaceId,
  String id,
) async {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  await LedgerSheet.show<void>(
    context: context,
    spaceId: spaceId,
    builder: (_) => RecordDetails(spaceId: spaceId, recordId: id),
    footerBuilder: (_) => RecordActions(spaceId: spaceId, recordId: id),
  );
}

Future<void> openConflict(
  BuildContext context,
  String spaceId,
  String kind,
  String id,
) async {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  await LedgerSheet.show<void>(
    context: context,
    spaceId: spaceId,
    builder: (_) =>
        ConflictSheet(spaceId: spaceId, entityKind: kind, entityId: id),
  );
}

Future<void> changeRecordStatus(
  BuildContext context,
  WidgetRef ref,
  String spaceId,
  LedgerRow row, {
  required bool restore,
}) async {
  final l = AppLocalizations.of(context);
  if (!restore) {
    final confirmed = await LedgerSheet.show<bool>(
      context: context,
      spaceId: spaceId,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.ledgerVoidConfirm),
          FilledButton(
            onPressed: () => Navigator.of(sheetContext).pop(true),
            child: Text(l.ledgerVoid),
          ),
          TextButton(
            onPressed: () => Navigator.of(sheetContext).pop(false),
            child: Text(l.ledgerCancel),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
  }
  final ok = await ref
      .read(ledgerViewModelProvider(spaceId).notifier)
      .command((repo) => repo.recordStatus(spaceId, row.id, restore: restore));
  if (ok && context.mounted) {
    PaperSnackBar.show(
      context: context,
      message: restore ? l.ledgerRestored : l.ledgerEntrySaved,
      actionLabel: restore ? null : l.ledgerRestore,
      onAction: restore
          ? null
          : () {
              unawaited(
                ref
                    .read(ledgerViewModelProvider(spaceId).notifier)
                    .command(
                      (repo) =>
                          repo.recordStatus(spaceId, row.id, restore: true),
                    ),
              );
            },
    );
  }
}

class RecordActions extends ConsumerWidget {
  const RecordActions({
    required this.spaceId,
    required this.recordId,
    super.key,
  });
  final String spaceId;
  final String recordId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ledgerViewModelProvider(spaceId));
    final data = state.snapshot;
    final l = AppLocalizations.of(context);
    final row = data?.find(data.records, recordId);
    if (data == null || row == null || !data.writable) {
      return const SizedBox.shrink();
    }
    final busy =
        state.busy ||
        data
            .operations('record', row.id)
            .any((op) => op.text('state') == 'sending');
    if (row.syncState == 'conflict') {
      return FilledButton(
        onPressed: () => openConflict(context, spaceId, 'record', row.id),
        child: Text(l.ledgerConflict),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        formError(context, state.error),
        if (row.active && row.text('kind') == 'expense')
          TextButton(
            onPressed: busy
                ? null
                : () {
                    final account = data.find(
                      data.accounts,
                      row.text('account_id'),
                    );
                    final purpose = data.find(
                      data.accounts,
                      row.text('purpose_id'),
                    );
                    final reserve = data.accounts
                        .where((a) => a.flag('is_reserve') && !a.archived)
                        .firstOrNull;
                    unawaited(
                      openManualEntry(
                        context,
                        spaceId,
                        initial: {
                          'kind': 'refund',
                          'refund_of_id': row.id,
                          if (account != null && !account.archived)
                            'account_id': account.id,
                          if (purpose != null && !purpose.archived)
                            'purpose_id': purpose.id
                          else if (reserve != null)
                            'purpose_id': reserve.id,
                        },
                      ),
                    );
                  },
            child: Text(l.ledgerRefund),
          ),
        if (row.active)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(
                      JiabuLedgerMetrics.actionExtent,
                      JiabuLedgerMetrics.actionExtent,
                    ),
                  ),
                  onPressed: busy
                      ? null
                      : () => changeRecordStatus(
                          context,
                          ref,
                          spaceId,
                          row,
                          restore: false,
                        ),
                  child: Text(l.ledgerVoid),
                ),
              ),
              const SizedBox(width: JiabuSpacing.cardGap),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(
                      JiabuLedgerMetrics.actionExtent,
                      JiabuLedgerMetrics.actionExtent,
                    ),
                    textStyle: context.jiabu.type.listTitle.copyWith(
                      shadows: const [],
                      decoration: TextDecoration.none,
                    ),
                  ),
                  onPressed: busy
                      ? null
                      : () => openEditRecord(context, spaceId, row),
                  child: Text(l.ledgerEdit),
                ),
              ),
            ],
          )
        else
          FilledButton(
            onPressed: busy
                ? null
                : () => changeRecordStatus(
                    context,
                    ref,
                    spaceId,
                    row,
                    restore: true,
                  ),
            child: Text(l.ledgerRestore),
          ),
      ],
    );
  }
}

class RecordDetails extends ConsumerWidget {
  const RecordDetails({
    required this.spaceId,
    required this.recordId,
    super.key,
  });
  final String spaceId;
  final String recordId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(ledgerViewModelProvider(spaceId)).snapshot;
    final l = AppLocalizations.of(context);
    if (data == null) {
      return Text(l.ledgerLoading);
    }
    final allowed = const ['read', 'write', 'manage'].contains(
      (data.space.data['modules'] as Map<String, Object?>?)?['ledger'],
    );
    if (!allowed) {
      return Text(l.ledgerDenied);
    }
    final row = data.find(data.records, recordId);
    if (row == null) {
      return Text(l.ledgerLoading);
    }
    final events =
        data.events
            .where(
              (event) =>
                  event.text('entity_kind') == 'record' &&
                  event.text('entity_id') == recordId,
            )
            .toList()
          ..sort((a, b) {
            final at = a.text('at').compareTo(b.text('at'));
            return at == 0 ? a.number('id').compareTo(b.number('id')) : at;
          });
    final keyName = creationEvent(data, row.id)?.text('via_api_key_name') ?? '';
    final refunds = data.records
        .where((r) => r.active && r.text('refund_of_id') == row.id)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l.ledgerDetails, style: context.jiabu.type.cardTitle),
        Text(ledgerLabels(l)[row.text('kind')] ?? ''),
        ledgerAmount(
          context,
          row.number('amount_minor'),
          data.currency,
          role: AmountRole.detail,
        ),
        Text(recordTitle(data, row, l), style: context.jiabu.type.body),
        for (final field in [
          'account_id',
          'to_account_id',
          'purpose_id',
          'to_purpose_id',
        ])
          if (row.text(field).isNotEmpty)
            DottedFieldRow(
              label: field == 'account_id'
                  ? l.ledgerReal
                  : field == 'to_account_id' || field == 'to_purpose_id'
                  ? l.ledgerTo
                  : l.ledgerPurposeField,
              value:
                  data.find(data.accounts, row.text(field))?.text('name') ?? '',
            ),
        DottedFieldRow(
          label: l.ledgerMember,
          value:
              '${memberLabel(data, row, l)}'
              '${keyName.isEmpty ? '' : ' · ${l.ledgerApiKey(keyName)}'}',
        ),
        DottedFieldRow(
          label: l.ledgerDate,
          value: ledgerDate(row.text('occurred_on'), l),
        ),
        DottedFieldRow(
          label: l.ledgerTags,
          value: row
              .strings('tag_ids')
              .map((id) => tagName(data.find(data.tags, id), ledgerLabels(l)))
              .join(' · '),
        ),
        if (row.syncState == 'pending') Text(l.ledgerLocalPending),
        for (final op
            in data
                .operations('record', recordId)
                .where((op) => op.text('state') == 'failed')) ...[
          Text(ledgerError(l, op.text('error'))),
          TextButton(
            onPressed: () => ref
                .read(ledgerViewModelProvider(spaceId).notifier)
                .command((repo) => repo.retry(spaceId, op.id)),
            child: Text(l.ledgerRetry),
          ),
        ],
        if (refunds.isNotEmpty) ...[
          Text(l.ledgerHasRefunds),
          for (final refund in refunds)
            TextButton(
              onPressed: () => openRecordDetails(context, spaceId, refund.id),
              child: Text(refundLabel(refund, data, l)),
            ),
        ],
        for (final hash in row.strings('attachments'))
          LedgerImage(spaceId: spaceId, hash: hash),
        Text(l.ledgerEvents, style: context.jiabu.type.sectionTitle),
        if (events.isEmpty) Text(l.ledgerEventsPending),
        for (final event in events) EventRow(snapshot: data, event: event),
      ],
    );
  }
}

class EventRow extends StatelessWidget {
  const EventRow({required this.snapshot, required this.event, super.key});
  final LedgerSnapshot snapshot;
  final LedgerRow event;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final actor = snapshot.find(
      snapshot.members,
      event.text('actor_member_id'),
    );
    final kind = switch (event.text('kind')) {
      'create' => l.ledgerEventCreate,
      'update' => l.ledgerEventUpdate,
      'void' => l.ledgerEventVoid,
      'restore' => l.ledgerEventRestore,
      'archive' => l.ledgerEventArchive,
      _ => l.ledgerEventUpdate,
    };
    Map<String, Object?> object(String key) {
      final value = event.data[key];
      if (value is Map<String, Object?>) {
        return value;
      }
      return value is String ? jsonDecode(value) as Map<String, Object?> : {};
    }

    final before = object('before');
    final after = object('after');
    final removed = (before['attachments'] as List<Object?>? ?? const [])
        .where(
          (hash) => !(after['attachments'] as List<Object?>? ?? const [])
              .contains(hash),
        )
        .length;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: JiabuSpacing.cardGap),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: context.jiabu.colors.lineStrong),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: JiabuSpacing.cardGap),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ExcludeSemantics(
                    child: JiabuIcon(
                      JiabuIcons.circle,
                      size: JiabuLedgerMetrics.keyIcon,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '$kind · '
                      '${actor?.text('display_name') ?? l.ledgerSystem}',
                    ),
                  ),
                ],
              ),
              Text(
                DateTime.tryParse(event.text('at')) == null
                    ? ''
                    : DateFormat.yMMMd(l.localeName)
                          .add_Hm()
                          .format(DateTime.parse(event.text('at')).toLocal()),
                style: context.jiabu.type.caption,
              ),
              if (event.text('via_api_key_name').isNotEmpty)
                Text(l.ledgerApiKey(event.text('via_api_key_name'))),
              for (final field in [
                'amount_minor',
                'occurred_on',
                'note',
                'account_id',
                'to_account_id',
                'purpose_id',
                'to_purpose_id',
                'tag_ids',
              ])
                if (jsonEncode(before[field]) != jsonEncode(after[field]) &&
                    after.containsKey(field))
                  DottedFieldRow(
                    label: eventFieldLabel(l, field),
                    value: eventFieldChange(snapshot, before, after, field, l),
                  ),
              if (removed > 0) Text(l.ledgerRemovedPhotoCount(removed)),
            ],
          ),
        ),
      ),
    );
  }
}

class LedgerImage extends ConsumerWidget {
  const LedgerImage({
    required this.spaceId,
    required this.hash,
    this.download = false,
    super.key,
  });
  final String spaceId;
  final String hash;
  final bool download;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final image = ref.watch(
      recordImageProvider(spaceId, hash, download: download),
    );
    return image.when(
      loading: () => Text(l.ledgerLoading),
      error: (error, stack) => Text(l.ledgerImageMissing),
      data: (result) {
        if (result is Ok<List<int>>) {
          final picture = Image.memory(
            Uint8List.fromList(result.value),
            fit: BoxFit.contain,
            semanticLabel: l.ledgerOriginal,
            errorBuilder: (_, error, stack) => Text(l.ledgerImageMissing),
          );
          if (download) {
            return picture;
          }
          return InkWell(
            onTap: () => LedgerSheet.show<void>(
              context: context,
              spaceId: spaceId,
              builder: (_) =>
                  LedgerImage(spaceId: spaceId, hash: hash, download: true),
            ),
            child: Polaroid(
              caption: l.handOriginalSaved,
              image: AspectRatio(aspectRatio: 1.8, child: picture),
            ),
          );
        }
        return TextButton(
          onPressed: download
              ? null
              : () => LedgerSheet.show<void>(
                  context: context,
                  spaceId: spaceId,
                  builder: (_) =>
                      LedgerImage(spaceId: spaceId, hash: hash, download: true),
                ),
          child: Text(l.ledgerImageMissing),
        );
      },
    );
  }
}

class ConflictSheet extends ConsumerWidget {
  const ConflictSheet({
    required this.spaceId,
    required this.entityKind,
    required this.entityId,
    super.key,
  });
  final String spaceId;
  final String entityKind;
  final String entityId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ledgerViewModelProvider(spaceId));
    final data = state.snapshot;
    final l = AppLocalizations.of(context);
    if (data == null) {
      return Text(l.ledgerLoading);
    }
    final mine = data.mine(entityKind, entityId);
    final rows = switch (entityKind) {
      'account' => data.accounts,
      'allocation_plan' => data.plans,
      'tag' => data.tags,
      _ => data.records,
    };
    final server = data.find(rows, entityId);
    if (mine == null || server == null) {
      return Text(l.ledgerRecorded);
    }
    final voided = entityKind == 'record' && !server.active;
    Future<void> choose(String choice) async {
      final ok = await ref
          .read(ledgerViewModelProvider(spaceId).notifier)
          .command(
            (repo) => repo.resolve(spaceId, entityKind, entityId, choice),
          );
      if (ok && context.mounted) {
        Navigator.of(context).pop();
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l.ledgerConflict, style: context.jiabu.type.cardTitle),
        if (voided) Text(l.ledgerAlreadyVoided),
        for (final pair in [
          (l.ledgerServerVersion, server),
          (l.ledgerMyVersion, mine),
        ])
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: JiabuSpacing.sectionBottom,
              horizontal: JiabuSpacing.cardGap,
            ),
            child: PaperCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(pair.$1, style: context.jiabu.type.sectionTitle),
                  if (pair.$2.data['amount_minor'] is int)
                    ledgerAmount(
                      context,
                      pair.$2.number('amount_minor'),
                      data.currency,
                    ),
                  if (pair.$2.text('name').isNotEmpty)
                    Text(pair.$2.text('name')),
                  if (pair.$2.text('occurred_on').isNotEmpty)
                    Text(ledgerDate(pair.$2.text('occurred_on'), l)),
                  for (final field in [
                    'account_id',
                    'to_account_id',
                    'purpose_id',
                    'to_purpose_id',
                  ])
                    if (pair.$2.text(field).isNotEmpty)
                      Text(
                        data
                                .find(data.accounts, pair.$2.text(field))
                                ?.text('name') ??
                            '',
                      ),
                  Text(
                    pair.$2
                        .strings('tag_ids')
                        .map(
                          (id) => tagName(
                            data.find(data.tags, id),
                            ledgerLabels(l),
                          ),
                        )
                        .join(' · '),
                  ),
                  Text(pair.$2.text('note')),
                  if (entityKind == 'record')
                    Text(pair.$2.active ? l.ledgerRecorded : l.ledgerVoided),
                  if (entityKind == 'account') ...[
                    DottedFieldRow(
                      label: l.ledgerOpening,
                      value: formatMinor(
                        pair.$2.number('opening_balance_minor'),
                        data.currency,
                        l.localeName,
                      ),
                    ),
                    if (pair.$2.archived) Text(l.ledgerArchived),
                  ],
                  if (entityKind == 'allocation_plan') ...[
                    DottedFieldRow(
                      label: l.ledgerDay,
                      value: pair.$2.text('day_of_month'),
                    ),
                    Text(
                      pair.$2.flag('enabled')
                          ? l.ledgerEnabled
                          : l.ledgerPlanDisabled,
                    ),
                  ],
                ],
              ),
            ),
          ),
        formError(context, state.error),
        if (voided) ...[
          OutlinedButton(
            onPressed: state.busy ? null : () => choose('acknowledge'),
            child: Text(l.ledgerAcknowledge),
          ),
          FilledButton(
            onPressed: state.busy || !data.writable
                ? null
                : () => choose('restore'),
            child: Text(l.ledgerRestoreMine),
          ),
        ] else ...[
          OutlinedButton(
            onPressed: state.busy ? null : () => choose('server'),
            child: Text(l.ledgerServer),
          ),
          FilledButton(
            onPressed: state.busy || !data.writable
                ? null
                : () => choose('mine'),
            child: Text(l.ledgerMine),
          ),
        ],
      ],
    );
  }
}

String eventFieldLabel(AppLocalizations l, String field) => switch (field) {
  'amount_minor' => l.ledgerAmount,
  'occurred_on' => l.ledgerDate,
  'note' => l.ledgerNote,
  'account_id' => l.ledgerReal,
  'to_account_id' => l.ledgerTo,
  'purpose_id' => l.ledgerPurposeField,
  'to_purpose_id' => l.ledgerTo,
  _ => l.ledgerTags,
};
String eventFieldValue(
  LedgerSnapshot data,
  Object? value,
  String field,
  AppLocalizations l,
) {
  if (value == null) {
    return '';
  }
  if (field == 'amount_minor' && value is int) {
    return formatMinor(value, data.currency, l.localeName);
  }
  if (field == 'occurred_on') {
    return ledgerDate(value.toString(), l);
  }
  if (field == 'tag_ids' && value is List<Object?>) {
    return value
        .map(
          (id) => tagName(data.find(data.tags, id.toString()), ledgerLabels(l)),
        )
        .join(' · ');
  }
  if (field.endsWith('_id')) {
    return data.find(data.accounts, value.toString())?.text('name') ?? '';
  }
  return value.toString();
}

String eventFieldChange(
  LedgerSnapshot snapshot,
  Map<String, Object?> before,
  Map<String, Object?> after,
  String field,
  AppLocalizations l,
) {
  final previous = eventFieldValue(snapshot, before[field], field, l);
  final current = eventFieldValue(snapshot, after[field], field, l);
  return '$previous → $current';
}
