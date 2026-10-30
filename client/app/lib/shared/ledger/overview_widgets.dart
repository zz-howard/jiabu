import 'package:flutter/material.dart';
import 'package:jiabu/domain/ledger.dart';
import 'package:jiabu/domain/ledger_balance.dart';
import 'package:jiabu/domain/record_presentation.dart';
import 'package:jiabu/l10n/generated/app_localizations.dart';
import 'package:jiabu/shared/ledger/ledger_labels.dart';
import 'package:jiabu/shared/ledger/record_card.dart';
import 'package:jiabu/shared/ledger/record_details.dart';
import 'package:jiabu_design/jiabu_design.dart';

/// Top block of the overview, the original design's hero card: tilted
/// −0.6° with two tapes, the purpose-account total as the big highlighted
/// number, then real money and this month's spending on one meta line.
/// The only heavy-shadow card on the page (design-spec 4.12a).
///
/// When the space has no purpose accounts the big number falls back to the
/// real-money total (labelled 总余额) and the real-money item is dropped.
class OverviewSummary extends StatelessWidget {
  const OverviewSummary({
    required this.currency,
    required this.purposeTotal,
    required this.realTotal,
    required this.monthSpent,
    super.key,
  });
  final String currency;

  /// Null when the space has no purpose accounts.
  final int? purposeTotal;

  /// Null when the space has no real accounts.
  final int? realTotal;
  final int monthSpent;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final tokens = context.jiabu;
    final decor = tokens.decor;
    final label = purposeTotal == null
        ? l.ledgerTotalBalance
        : l.ledgerPurposeTotal;
    final big = purposeTotal ?? realTotal ?? 0;
    final labelStyle = tokens.type.secondary.copyWith(
      color: tokens.colors.ink2,
      fontWeight: FontWeight.w600,
    );
    Widget meta(String text, int amount, Key key) => Wrap(
      key: key,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: JiabuSpacing.xs,
      children: [
        Text(text, style: labelStyle),
        ledgerAmount(
          context,
          amount,
          currency,
          role: AmountRole.inline,
          kind: text,
        ),
      ],
    );
    return Tilt(
      degrees: decor.heroTilt,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          PaperCard(
            key: const Key('overview-summary'),
            elevation: PaperElevation.hero,
            padding: EdgeInsetsDirectional.fromSTEB(
              decor.heroInsetX,
              decor.heroInsetY,
              decor.heroInsetX,
              decor.heroInsetX,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(label, style: labelStyle),
                const SizedBox(height: JiabuSpacing.sm),
                // One line at any text size: the amount shrinks to fit rather
                // than wrapping under its own highlighter.
                FittedBox(
                  key: const Key('overview-hero-amount'),
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: ledgerAmount(
                    context,
                    big,
                    currency,
                    role: AmountRole.hero,
                    kind: label,
                    highlighted: true,
                  ),
                ),
                const SizedBox(height: JiabuSpacing.md),
                Wrap(
                  spacing: JiabuSpacing.lg,
                  runSpacing: JiabuSpacing.xs,
                  children: [
                    if (purposeTotal != null && realTotal != null)
                      meta(
                        l.ledgerRealMoney,
                        realTotal!,
                        const Key('overview-hero-real'),
                      ),
                    meta(
                      l.ledgerMonthSpent,
                      monthSpent,
                      const Key('overview-hero-month'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          PositionedDirectional(
            start: JiabuLedgerMetrics.heroTapeInset,
            top: JiabuLedgerMetrics.heroTapeTop,
            child: Tape(degrees: decor.tapeTilt),
          ),
          const PositionedDirectional(
            end: JiabuLedgerMetrics.heroTapeInset,
            top: JiabuLedgerMetrics.heroTapeTop,
            child: Tape(
              pattern: TapePattern.dots,
              degrees: JiabuLedgerMetrics.heroTapeEndTilt,
            ),
          ),
        ],
      ),
    );
  }
}

/// The purpose accounts as the original design's two-column sticker grid
/// (one column once a tile would get narrower than
/// [JiabuLedgerMetrics.purposeTileMinWidth] × text scale). Tiles in a row
/// share one height.
class OverviewPurposeGrid extends StatelessWidget {
  const OverviewPurposeGrid({
    required this.snapshot,
    required this.accounts,
    required this.balances,
    super.key,
  });
  final LedgerSnapshot snapshot;
  final List<LedgerRow> accounts;
  final Map<String, int> balances;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(1);
      final twoUp =
          (constraints.maxWidth - JiabuSpacing.md) / 2 >=
          JiabuLedgerMetrics.purposeTileMinWidth * scale;
      final columns = twoUp ? 2 : 1;
      final rows = <Widget>[];
      for (var index = 0; index < accounts.length; index += columns) {
        if (rows.isNotEmpty) {
          rows.add(const SizedBox(height: JiabuSpacing.gridGap));
        }
        final cells = <Widget>[];
        for (var column = 0; column < columns; column++) {
          if (column > 0) {
            cells.add(const SizedBox(width: JiabuSpacing.md));
          }
          final at = index + column;
          cells.add(
            Expanded(
              child: at < accounts.length
                  ? OverviewPurposeTile(
                      snapshot: snapshot,
                      account: accounts[at],
                      balance: balances[accounts[at].id] ?? 0,
                    )
                  : const SizedBox.shrink(),
            ),
          );
        }
        rows.add(
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: cells,
            ),
          ),
        );
      }
      return Column(
        key: const Key('overview-purpose-grid'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rows,
      );
    },
  );
}

/// One purpose account tile: name, handwritten balance (34, red below zero),
/// and the enabled monthly allocation. Light tile shadow, 0°.
class OverviewPurposeTile extends StatelessWidget {
  const OverviewPurposeTile({
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
    final tokens = context.jiabu;
    final name =
        '${account.text('name')}'
        '${account.archived ? ' · ${l.ledgerArchived}' : ''}';
    final monthly = monthlyAllocation(snapshot, account.id);
    final monthlyStyle = tokens.type.caption.copyWith(
      color: tokens.colors.ink3,
    );
    return PaperCard(
      key: Key('overview-purpose-${account.id}'),
      elevation: PaperElevation.tile,
      padding: const EdgeInsets.all(JiabuSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: tokens.type.listTitle,
          ),
          const SizedBox(height: JiabuSpacing.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: ledgerAmount(
              context,
              balance,
              snapshot.currency,
              role: AmountRole.balance,
              kind: account.text('name'),
            ),
          ),
          if (monthly != null) ...[
            const SizedBox(height: JiabuSpacing.xs),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: JiabuSpacing.xs,
              children: [
                Text(l.ledgerMonthlyIn, style: monthlyStyle),
                ledgerAmount(
                  context,
                  monthly,
                  snapshot.currency,
                  role: AmountRole.inline,
                  kind: l.ledgerMonthlyIn,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// One real account: name on the left, balance on the right,
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
      valueWidget: recordAmount(context, row, snapshot.currency),
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
