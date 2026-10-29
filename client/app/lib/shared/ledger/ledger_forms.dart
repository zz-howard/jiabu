import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:jiabu/app/ledger_providers.dart';
import 'package:jiabu/domain/ledger.dart';
import 'package:jiabu/domain/ledger_balance.dart';
import 'package:jiabu/domain/ledger_validation.dart';
import 'package:jiabu/domain/money.dart';
import 'package:jiabu/domain/record_edit.dart';
import 'package:jiabu/domain/result.dart';
import 'package:jiabu/l10n/generated/app_localizations.dart';
import 'package:jiabu/shared/ledger/ledger_labels.dart';
import 'package:jiabu/shared/ledger/ledger_sheet.dart';
import 'package:jiabu/shared/ledger/ledger_ui_state.dart';
import 'package:jiabu/shared/ledger/ledger_view_model.dart';
import 'package:jiabu_design/jiabu_design.dart';

String todayInput(BuildContext context) => DateFormat('yyyy-MM-dd').format(
  ProviderScope.containerOf(context, listen: false).read(ledgerClockProvider)(),
);

Future<void> openManualEntry(
  BuildContext context,
  String spaceId, {
  Map<String, Object?> initial = const {},
}) async {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  final occurredOn = todayInput(context);
  await LedgerSheet.show<void>(
    context: context,
    spaceId: spaceId,
    requireWrite: true,
    builder: (_) => RecordForm(
      spaceId: spaceId,
      initial: {'kind': 'expense', 'occurred_on': occurredOn, ...initial},
    ),
  );
}

Future<void> openEditRecord(
  BuildContext context,
  String spaceId,
  LedgerRow record,
) async {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  await LedgerSheet.show<void>(
    context: context,
    spaceId: spaceId,
    requireWrite: true,
    builder: (_) => RecordForm(spaceId: spaceId, record: record),
  );
}

Future<void> openAccountForm(
  BuildContext context,
  String spaceId, {
  LedgerRow? account,
}) async {
  await LedgerSheet.show<void>(
    context: context,
    spaceId: spaceId,
    requireWrite: true,
    builder: (_) => AccountForm(spaceId: spaceId, account: account),
  );
}

Future<void> openPlan(
  BuildContext context,
  String spaceId,
  String accountId,
) async {
  await LedgerSheet.show<void>(
    context: context,
    spaceId: spaceId,
    requireWrite: true,
    builder: (_) => AllocationPlanForm(spaceId: spaceId, accountId: accountId),
  );
}

typedef LedgerFormBuilder = Widget Function(
  BuildContext,
  WidgetRef,
  LedgerFormState,
  LedgerFormViewModel,
);

class FormScope extends ConsumerStatefulWidget {
  const FormScope({
    required this.spaceId,
    required this.formId,
    required this.initial,
    required this.builder,
    super.key,
  });
  final String spaceId;
  final String formId;
  final Map<String, Object?> initial;
  final LedgerFormBuilder builder;
  @override
  ConsumerState<FormScope> createState() => _FormScopeState();
}

class _FormScopeState extends ConsumerState<FormScope> {
  @override
  void initState() {
    super.initState();
    scheduleMicrotask(() {
      if (mounted) {
        ref
            .read(
              ledgerFormViewModelProvider(
                widget.spaceId,
                widget.formId,
              ).notifier,
            )
            .initialize(widget.initial);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(
      ledgerFormViewModelProvider(widget.spaceId, widget.formId),
    );
    final model = ref.read(
      ledgerFormViewModelProvider(widget.spaceId, widget.formId).notifier,
    );
    if (state.values.isEmpty) {
      return const SizedBox.shrink();
    }
    return widget.builder(context, ref, state, model);
  }
}

Widget formField(
  BuildContext context,
  LedgerFormState state,
  LedgerFormViewModel model,
  String key,
  String label, {
  bool numeric = false,
  int? maxLength,
}) => Padding(
  padding: const EdgeInsets.only(bottom: JiabuSpacing.cardGap),
  child: const ['occurred_on', 'opening_on', 'from', 'through'].contains(key)
      ? LedgerDateField(
          value: state.values[key]?.toString() ?? '',
          label: label,
          onChanged: (value) => model.patch(key, value),
        )
      : TextFormField(
          key: ValueKey(
            '${state.values['kind'] ?? ''}-$key-'
            '${state.values['_refresh'] ?? 0}',
          ),
          initialValue: state.values[key]?.toString() ?? '',
          decoration: InputDecoration(labelText: label),
          maxLength: maxLength,
          keyboardType: numeric
              ? const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                )
              : TextInputType.text,
          onChanged: (text) => model.patch(key, text),
        ),
);
Widget formError(BuildContext context, String? code) => code == null
    ? const SizedBox.shrink()
    : Semantics(
        liveRegion: true,
        child: Padding(
          padding: const EdgeInsets.all(JiabuSpacing.cardGap),
          child: Text(
            ledgerError(AppLocalizations.of(context), code),
            style: context.jiabu.type.secondary.copyWith(
              color: context.jiabu.colors.neg,
            ),
          ),
        ),
      );

Widget accountChoices(
  BuildContext context,
  LedgerSnapshot snapshot,
  LedgerFormState state,
  LedgerFormViewModel model,
  String field,
  String label,
  String kind, {
  LedgerRow? original,
}) {
  final l = AppLocalizations.of(context);
  final excluded = switch (field) {
    'to_account_id' => state.values['account_id'],
    'to_purpose_id' => state.values['purpose_id'],
    _ => null,
  };
  final rows = snapshot.accounts
      .where(
        (a) =>
            a.text('kind') == kind &&
            a.id != excluded &&
            (!a.archived || original?.text(field) == a.id),
      )
      .toList();
  return Column(
    key: ValueKey('account-choices-$field'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(label, style: context.jiabu.type.listTitle),
      if (rows.isEmpty) Text(l.ledgerSelectAccount),
      Wrap(
        spacing: JiabuSpacing.cardGap,
        children: [
          for (final a in rows)
            ChoiceChip(
              label: Text(
                '${a.text('name')}'
                '${a.archived ? ' · ${l.ledgerArchived}' : ''}',
              ),
              selected: state.values[field] == a.id,
              onSelected: (_) => model.patch(field, a.id),
            ),
        ],
      ),
    ],
  );
}

class RecordForm extends ConsumerWidget {
  const RecordForm({
    required this.spaceId,
    this.record,
    this.initial = const {},
    super.key,
  });
  final String spaceId;
  final LedgerRow? record;
  final Map<String, Object?> initial;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(ledgerViewModelProvider(spaceId)).snapshot;
    final l = AppLocalizations.of(context);
    if (snapshot == null) {
      return Text(l.ledgerLoading);
    }
    final original = record;
    final isRefund =
        initial['kind'] == 'refund' || original?.text('kind') == 'refund';
    final formId = original == null
        ? (isRefund ? 'refund:${initial['refund_of_id']}' : 'manual')
        : 'edit:${original.id}';
    return FormScope(
      spaceId: spaceId,
      formId: formId,
      initial: original == null
          ? {
              'kind': 'expense',
              'occurred_on': todayInput(context),
              'tag_ids': <String>[],
              ...initial,
            }
          : {
              ...original.data,
              '_opened_record': original.data,
              '_opened_version': original.number('version'),
              'amount_text': minorInput(
                original.number('amount_minor'),
                snapshot.currency,
              ),
            },
      builder: (context, ref, state, model) {
        final kind = state.values['kind'] as String? ?? 'expense';
        final labels = ledgerLabels(l);
        final hasTags = const ['expense', 'income'].contains(kind);
        final selectedTags =
            (state.values['tag_ids'] as List<Object?>? ?? const [])
                .cast<String>();
        final parent = snapshot.find(
          snapshot.records,
          state.values['refund_of_id']?.toString() ?? '',
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              original != null
                  ? l.ledgerEdit
                  : isRefund
                  ? l.ledgerRefund
                  : l.ledgerManual,
              style: context.jiabu.type.cardTitle,
            ),
            if (original == null && !isRefund)
              Wrap(
                spacing: JiabuSpacing.cardGap,
                children: [
                  for (final type in [
                    'expense',
                    'income',
                    'transfer',
                    'reallocation',
                  ])
                    ChoiceChip(
                      key: ValueKey('kind-$type'),
                      label: Text(labels[type] ?? ''),
                      selected: type == kind,
                      onSelected: (_) => model.kind(type),
                    ),
                ],
              ),
            if (isRefund && parent != null)
              DottedFieldRow(
                label: l.ledgerRefundRemaining,
                value: formatMinor(
                  parent.number('amount_minor') -
                      refundedMinor(
                        snapshot,
                        parent.id,
                        excluding: original?.id,
                      ),
                  snapshot.currency,
                  l.localeName,
                ),
              ),
            formField(
              context,
              state,
              model,
              'amount_text',
              l.ledgerAmount,
              numeric: true,
            ),
            if (const [
              'expense',
              'income',
              'refund',
              'transfer',
            ].contains(kind))
              accountChoices(
                context,
                snapshot,
                state,
                model,
                'account_id',
                kind == 'transfer'
                    ? l.ledgerFrom
                    : kind == 'income' || kind == 'refund'
                    ? l.ledgerReceiveAccount
                    : l.ledgerPayAccount,
                'real',
                original: original,
              ),
            if (kind == 'transfer')
              accountChoices(
                context,
                snapshot,
                state,
                model,
                'to_account_id',
                l.ledgerTo,
                'real',
                original: original,
              ),
            if (const [
              'expense',
              'refund',
              'allocation',
              'reallocation',
            ].contains(kind))
              accountChoices(
                context,
                snapshot,
                state,
                model,
                'purpose_id',
                kind == 'reallocation' ? l.ledgerFrom : l.ledgerPurposeField,
                'purpose',
                original: original,
              ),
            if (kind == 'reallocation')
              accountChoices(
                context,
                snapshot,
                state,
                model,
                'to_purpose_id',
                l.ledgerTo,
                'purpose',
                original: original,
              ),
            if (hasTags) ...[
              Text(l.ledgerTags, style: context.jiabu.type.listTitle),
              Wrap(
                spacing: JiabuSpacing.cardGap,
                children: [
                  for (final tag in snapshot.tags.where(
                    (tag) =>
                        tag.data['deleted_at'] == null ||
                        selectedTags.contains(tag.id),
                  ))
                    FilterChip(
                      label: Text(
                        tag.text('name').isNotEmpty
                            ? tag.text('name')
                            : labels[tag.text('preset_key')] ?? '',
                      ),
                      selected: selectedTags.contains(tag.id),
                      onSelected:
                          tag.data['deleted_at'] != null &&
                              !selectedTags.contains(tag.id)
                          ? null
                          : (selected) {
                              model.patch(
                                'tag_ids',
                                selected
                                    ? [...selectedTags, tag.id]
                                    : selectedTags
                                          .where((id) => id != tag.id)
                                          .toList(),
                              );
                            },
                    ),
                  ActionChip(
                    label: Text(l.ledgerAddTag),
                    onPressed: state.busy
                        ? null
                        : () => model.patch('show_new_tag', true),
                  ),
                ],
              ),
              if (state.values['show_new_tag'] == true) ...[
                formField(
                  context,
                  state,
                  model,
                  'new_tag',
                  l.ledgerNewTag,
                  maxLength: 30,
                ),
                OutlinedButton(
                  onPressed: state.busy
                      ? null
                      : () async {
                          final name =
                              state.values['new_tag']?.toString() ?? '';
                          final ok = await model.submit(
                            (repo, _) => repo.createTag(spaceId, name),
                          );
                          if (ok && context.mounted) {
                            model
                              ..patch('new_tag', '')
                              ..patch('show_new_tag', false);
                          }
                        },
                  child: Text(l.ledgerSave),
                ),
              ],
            ],
            formField(context, state, model, 'occurred_on', l.ledgerDate),
            formField(
              context,
              state,
              model,
              'note',
              l.ledgerNote,
              maxLength: 500,
            ),
            formError(context, state.error),
            FilledButton(
              onPressed: state.busy || !snapshot.writable
                  ? null
                  : () async {
                      final baseline =
                          state.values['_opened_record']
                              as Map<String, Object?>?;
                      final amount = parseMinor(
                        state.values['amount_text']?.toString() ?? '',
                        snapshot.currency,
                        decimal: NumberFormat.decimalPattern(l.localeName)
                            .symbols
                            .DECIMAL_SEP,
                      );
                      if (amount == null || amount <= 0) {
                        model.fail('validation_failed');
                        return;
                      }
                      final values = <String, Object?>{
                        for (final key in [
                          'kind',
                          'occurred_on',
                          'account_id',
                          'to_account_id',
                          'purpose_id',
                          'to_purpose_id',
                          'refund_of_id',
                          'note',
                        ])
                          if (state.values.containsKey(key))
                            key: state.values[key],
                        'amount_minor': amount,
                        if (hasTags)
                          'tag_ids': selectedTags
                        else if (original == null)
                          'tag_ids': <String>[],
                      };
                      final ok = await model.submit((repo, _) async {
                        if (original == null) {
                          return await repo.createRecord(spaceId, values);
                        }
                        final editable = {...values}
                          ..remove('kind')
                          ..remove('refund_of_id');
                        final changes = changedRecordFields(
                          editable,
                          baseline ?? original.data,
                        );
                        final result = await repo.editRecord(
                          spaceId,
                          original.id,
                          changes,
                          openedVersion:
                              state.values['_opened_version'] as int? ??
                              original.number('version'),
                        );
                        if (result is Failure<String> &&
                            result.code == 'record_changed_elsewhere') {
                          final latest = await repo.watch(spaceId).first;
                          final row = latest.find(latest.records, original.id);
                          if (row != null && context.mounted) {
                            model.refreshRecord(row, latest.currency);
                          }
                        }
                        return result;
                      });
                      if (ok && context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
              child: Text(l.ledgerSave),
            ),
          ],
        );
      },
    );
  }
}

class AccountForm extends ConsumerWidget {
  const AccountForm({
    required this.spaceId,
    this.account,
    this.initialDate,
    super.key,
  });
  final String spaceId;
  final LedgerRow? account;
  final String? initialDate;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = this.account;
    final snapshot = ref.watch(ledgerViewModelProvider(spaceId)).snapshot;
    final l = AppLocalizations.of(context);
    if (snapshot == null) {
      return Text(l.ledgerLoading);
    }
    return FormScope(
      spaceId: spaceId,
      formId: 'account:${account?.id ?? 'new'}',
      initial: {
        'kind': 'real',
        'name': '',
        'opening_text': '0',
        'opening_on': initialDate ?? todayInput(context),
        'is_reserve': false,
        ...?account?.data,
      },
      builder: (context, ref, state, model) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            account == null ? l.ledgerNewAccount : l.ledgerRename,
            style: context.jiabu.type.cardTitle,
          ),
          if (account == null)
            Wrap(
              spacing: JiabuSpacing.cardGap,
              children: [
                for (final kind in ['real', 'purpose'])
                  ChoiceChip(
                    label: Text(
                      kind == 'real' ? l.ledgerReal : l.ledgerPurpose,
                    ),
                    selected: state.values['kind'] == kind,
                    onSelected: (_) {
                      model.patch('kind', kind);
                      if (kind == 'real') {
                        model.patch('is_reserve', false);
                      }
                    },
                  ),
              ],
            ),
          formField(context, state, model, 'name', l.ledgerName, maxLength: 30),
          if (account == null) ...[
            DottedFieldRow(label: l.ledgerCurrency, value: snapshot.currency),
            formField(
              context,
              state,
              model,
              'opening_text',
              l.ledgerOpening,
              numeric: true,
            ),
            formField(context, state, model, 'opening_on', l.ledgerOpeningOn),
            if (state.values['kind'] == 'purpose')
              PaperRow(
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.ledgerReserve),
                  value: state.values['is_reserve'] == true,
                  onChanged: (value) => model.patch('is_reserve', value),
                ),
              ),
          ],
          formError(context, state.error),
          FilledButton(
            onPressed: state.busy || !snapshot.writable
                ? null
                : () async {
                    final name = state.values['name']?.toString() ?? '';
                    final opening = parseMinor(
                      state.values['opening_text']?.toString() ?? '0',
                      snapshot.currency,
                      signed: true,
                      decimal: NumberFormat.decimalPattern(l.localeName)
                          .symbols
                          .DECIMAL_SEP,
                    );
                    if (name.trim().isEmpty ||
                        opening == null ||
                        !validLedgerDate(
                          state.values['opening_on']?.toString() ?? '',
                        )) {
                      model.fail('validation_failed');
                      return;
                    }
                    final ok = await model.submit(
                      (repo, _) => account != null
                          ? repo.renameAccount(spaceId, account.id, name)
                          : repo.createAccount(spaceId, {
                              'kind': state.values['kind'],
                              'name': name,
                              'opening_balance_minor': opening,
                              'opening_on': state.values['opening_on'],
                              'is_reserve': state.values['is_reserve'] == true,
                            }),
                    );
                    if (ok && context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
            child: Text(l.ledgerSave),
          ),
        ],
      ),
    );
  }
}

class AllocationPlanForm extends ConsumerWidget {
  const AllocationPlanForm({
    required this.spaceId,
    required this.accountId,
    super.key,
  });
  final String spaceId;
  final String accountId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(ledgerViewModelProvider(spaceId)).snapshot;
    final l = AppLocalizations.of(context);
    if (snapshot == null) {
      return Text(l.ledgerLoading);
    }
    final plan = snapshot.find(snapshot.plans, accountId);
    final account = snapshot.find(snapshot.accounts, accountId);
    return FormScope(
      spaceId: spaceId,
      formId: 'plan:$accountId',
      initial: {
        'amount_text': plan == null
            ? ''
            : minorInput(plan.number('amount_minor'), snapshot.currency),
        'day_text': plan?.text('day_of_month') ?? '1',
        'enabled': plan?.flag('enabled') ?? true,
      },
      builder: (context, ref, state, model) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l.ledgerPlan, style: context.jiabu.type.cardTitle),
          Text(account?.text('name') ?? ''),
          formField(
            context,
            state,
            model,
            'amount_text',
            l.ledgerAmount,
            numeric: true,
          ),
          formField(
            context,
            state,
            model,
            'day_text',
            l.ledgerDay,
            numeric: true,
          ),
          PaperRow(
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.ledgerEnabled),
              value: state.values['enabled'] == true,
              onChanged: (value) => model.patch('enabled', value),
            ),
          ),
          Text(
            l.ledgerPlanSchedule(state.values['day_text']?.toString() ?? '1'),
          ),
          Text(
            l.ledgerPlanStartHint,
            style: context.jiabu.type.caption.copyWith(
              color: context.jiabu.colors.ink3,
            ),
          ),
          if (plan == null || plan.syncState == 'pending')
            Text(l.ledgerPlanPending),
          if (plan != null && plan.text('next_run_on').isNotEmpty)
            DottedFieldRow(
              label: l.ledgerPlanNext,
              value: ledgerDate(plan.text('next_run_on'), l),
            ),
          formError(context, state.error),
          FilledButton(
            onPressed:
                state.busy ||
                    !snapshot.writable ||
                    account == null ||
                    account.archived
                ? null
                : () async {
                    final amount = parseMinor(
                      state.values['amount_text']?.toString() ?? '',
                      snapshot.currency,
                      decimal: NumberFormat.decimalPattern(l.localeName)
                          .symbols
                          .DECIMAL_SEP,
                    );
                    final day = int.tryParse(
                      state.values['day_text']?.toString() ?? '',
                    );
                    if (amount == null ||
                        amount <= 0 ||
                        day == null ||
                        day < 1 ||
                        day > 31) {
                      model.fail('validation_failed');
                      return;
                    }
                    final ok = await model.submit(
                      (repo, _) => repo.setPlan(spaceId, accountId, {
                        'amount_minor': amount,
                        'day_of_month': day,
                        'enabled': state.values['enabled'] == true,
                      }),
                    );
                    if (ok && context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
            child: Text(l.ledgerSave),
          ),
        ],
      ),
    );
  }
}

class LedgerDateField extends StatelessWidget {
  const LedgerDateField({
    required this.value,
    required this.label,
    required this.onChanged,
    super.key,
  });
  final String value;
  final String label;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return TextFormField(
      key: ValueKey('date-$value-${l.localeName}'),
      readOnly: true,
      initialValue: ledgerDate(value, l),
      decoration: InputDecoration(labelText: label),
      onTap: () async {
        final fence = context.findAncestorWidgetOfExactType<LedgerSheetFence>();
        final chosen = await showDatePicker(
          context: context,
          initialDate:
              DateTime.tryParse(value) ??
              ProviderScope.containerOf(
                context,
                listen: false,
              ).read(ledgerClockProvider)(),
          builder: (pickerContext, child) {
            if (fence == null) {
              return child ?? const SizedBox.shrink();
            }
            return LedgerSheetFence(
              spaceId: fence.spaceId,
              requireWrite: fence.requireWrite,
              child: child ?? const SizedBox.shrink(),
            );
          },
          firstDate: DateTime(1),
          lastDate: DateTime(9999, 12, 31),
        );
        if (chosen != null && context.mounted) {
          onChanged(DateFormat('yyyy-MM-dd').format(chosen));
        }
      },
    );
  }
}
