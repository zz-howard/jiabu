import 'package:flutter/material.dart';
import 'package:jiabu/domain/ledger.dart';
import 'package:jiabu/domain/record_presentation.dart';
import 'package:jiabu/l10n/generated/app_localizations.dart';
import 'package:jiabu/shared/ledger/ledger_labels.dart';
import 'package:jiabu/shared/ledger/record_card.dart';
import 'package:jiabu/shared/ledger/record_details.dart';
import 'package:jiabu_design/jiabu_design.dart';

/// Top block of the overview: all real money in the space and what was spent
/// this calendar month. One paper card, no per-account shadows.
class OverviewSummary extends StatelessWidget {
  const OverviewSummary({
    required this.currency,
    required this.total,
    required this.monthSpent,
    super.key,
  });
  final String currency;
  final int total;
  final int monthSpent;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return PaperCard(
      key: const Key('overview-summary'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.ledgerTotalBalance, style: context.jiabu.type.secondary),
          const SizedBox(height: JiabuSpacing.sm),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: ledgerAmount(
              context,
              total,
              currency,
              role: AmountRole.record,
              kind: l.ledgerTotalBalance,
            ),
          ),
          const SizedBox(height: JiabuSpacing.md),
          Divider(height: 1, color: context.jiabu.colors.line),
          const SizedBox(height: JiabuSpacing.md),
          Row(
            children: [
              Expanded(
                child: Text(
                  l.ledgerMonthSpent,
                  style: context.jiabu.type.secondary,
                ),
              ),
              const SizedBox(width: JiabuSpacing.md),
              ledgerAmount(
                context,
                monthSpent,
                currency,
                kind: l.ledgerMonthSpent,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One real or purpose account: name on the left, balance on the right,
/// inside a shared group so a kind of account is one card, not one per row.
class OverviewAccountRow extends StatelessWidget {
  const OverviewAccountRow({
    required this.snapshot,
    required this.account,
    required this.balance,
    super.key,
  });
  final LedgerSnapshot snapshot;
  final LedgerRow account;
  final int balance;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return JiabuListRow(
      title:
          '${account.text('name')}'
          '${account.archived ? ' · ${l.ledgerArchived}' : ''}',
      valueWidget: ledgerAmount(context, balance, snapshot.currency),
    );
  }
}

/// Compact one-line entry of the recent changes list: sticker, title,
/// member and date, amount on the right.
class OverviewRecentRow extends StatelessWidget {
  const OverviewRecentRow({
    required this.snapshot,
    required this.row,
    super.key,
  });
  final LedgerSnapshot snapshot;
  final LedgerRow row;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final failed = snapshot
        .operations('record', row.id)
        .any((op) => op.text('state') == 'failed');
    final display = recordDisplay(allowed: true, row: row, failed: failed);
    final keyName =
        creationEvent(snapshot, row.id)?.text('via_api_key_name') ?? '';
    final status = display != RecordDisplay.recorded
        ? displayLabel(l, display)
        : failed
        ? l.ledgerFailed
        : null;
    return JiabuListRow(
      key: Key('overview-recent-${row.id}'),
      leading: Sticker(category: recordStickerCategory(row), compact: true),
      title: recordTitle(snapshot, row, l),
      subtitle:
          '${memberLabel(snapshot, row, l)} · '
          '${ledgerDate(row.text('occurred_on'), l)}',
      status: status,
      valueWidget: ledgerAmount(
        context,
        row.number('amount_minor'),
        snapshot.currency,
      ),
      trailing: keyName.isEmpty
          ? null
          : Semantics(
              label: l.ledgerApiKey(keyName),
              child: const ExcludeSemantics(
                child: JiabuIcon(
                  JiabuIcons.uiKey,
                  size: JiabuLedgerMetrics.keyIcon,
                ),
              ),
            ),
      onTap: () => row.syncState == 'conflict'
          ? openConflict(context, snapshot.spaceId, 'record', row.id)
          : openRecordDetails(context, snapshot.spaceId, row.id),
    );
  }
}
