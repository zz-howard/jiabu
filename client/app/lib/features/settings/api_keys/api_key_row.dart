import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jiabu/app/ledger_providers.dart';
import 'package:jiabu/features/settings/api_keys/api_key_labels.dart';
import 'package:jiabu/l10n/generated/app_localizations.dart';
import 'package:jiabu_design/jiabu_design.dart';

class ApiKeyRow extends ConsumerWidget {
  const ApiKeyRow({required this.row, this.onTap, super.key});
  final Map<String, Object?> row;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final expiry = DateTime.tryParse(row['expires_at'] as String? ?? '');
    final status = row['status'] as String?;
    final days = expiry?.difference(ref.watch(ledgerClockProvider)()).inDays;
    return PaperCard(
      pattern: PaperPattern.ruled,
      revoked: status != 'active',
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
          leading: const ApiKeySticker(),
          onTap: onTap,
          title: Text(
            row['name'] as String? ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                row['display_prefix'] as String? ?? '',
                style: context.jiabu.type.mono,
              ),
              Text(row['scope'] == 'read' ? l.c4Read : l.c4ReadWrite),
              if (status != 'active')
                Stamp(
                  label: status == 'revoked' ? l.c4Revoked : l.c4Expired,
                  state: StampState.revoked,
                  degrees: 0,
                )
              else
                Text(
                  days == null
                      ? l.c4Never
                      : l.c4RemainingDays(days < 0 ? 0 : days),
                  style: context.jiabu.type.caption.copyWith(
                    color: days == null || days <= 7
                        ? context.jiabu.colors.warn
                        : context.jiabu.colors.ink2,
                  ),
                ),
              Text(keyTime(l, row['last_used_at'], l.c4NeverUsed)),
            ],
          ),
        ),
      ),
    );
  }
}
