import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jiabu/app/c4_providers.dart';
import 'package:jiabu/domain/required_value.dart';
import 'package:jiabu/features/settings/api_keys/api_key_labels.dart';
import 'package:jiabu/l10n/generated/app_localizations.dart';
import 'package:jiabu/shared/c4/c4_confirmation.dart';
import 'package:jiabu/shared/c4/c4_form.dart';
import 'package:jiabu/shared/c4/c4_view_model.dart';
import 'package:jiabu_design/jiabu_design.dart';
import 'package:uuid/uuid.dart';

class ApiKeyDetails extends ConsumerWidget {
  const ApiKeyDetails({required this.row, super.key});
  final Map<String, Object?> row;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final id = 'key-detail:${row['id']}';
    final state = ref.watch(c4ViewModelProvider(id));
    final vm = ref.read(c4ViewModelProvider(id).notifier);
    return C4Form(
      id: id,
      title: row['name'] as String? ?? l.c4Keys,
      submitLabel: l.c4Rename,
      onSubmit: () async {
        final name =
            (state.values['name'] as String? ?? row['name'] as String? ?? '')
                .trim();
        if (name.isEmpty) {
          vm.fail('validation_failed');
          return;
        }
        final repository = ref.read(apiKeysRepositoryProvider);
        if (await vm.run(
              () => repository.change(
                requireValue<String>(row['id']),
                vm.operationId,
                name: name,
              ),
            ) &&
            context.mounted) {
          Navigator.of(context).pop();
        }
      },
      children: [
        JiabuStackItem.content(
          child: Text(
            row['display_prefix'] as String? ?? '',
            style: context.jiabu.type.mono,
          ),
        ),
        JiabuStackItem.content(
          child: Text(row['scope'] == 'read' ? l.c4Read : l.c4ReadWrite),
        ),
        JiabuStackItem.content(
          child: Text('${l.c4CreatedAt}: ${keyTime(l, row['created_at'], '')}'),
        ),
        JiabuStackItem.content(
          child: Text(
            '${l.c4Expiry}: ${keyTime(l, row['expires_at'], l.c4Never)}',
          ),
        ),
        JiabuStackItem.content(
          child: Text(
            '${l.c4LastUsed}: '
            '${keyTime(l, row['last_used_at'], l.c4NeverUsed)}',
          ),
        ),
        JiabuStackItem.captionAfter(child: Text(l.c4KeyImmutable)),
        JiabuStackItem.content(
          child: C4Field(
            id: id,
            field: 'name',
            label: l.c4Name,
            initial: row['name'] as String? ?? '',
          ),
        ),
        JiabuStackItem.action(
          child: OutlinedButton(
            onPressed: !state.online || state.busy
                ? null
                : () async {
                    final confirmed = await JiabuSheet.show<bool>(
                      context: context,
                      builder: (sheetContext) => C4Confirmation(
                        message: l.c4RevokeWarning,
                        onConfirm: () => Navigator.of(sheetContext).pop(true),
                      ),
                    );
                    if (confirmed == true && context.mounted) {
                      final repository = ref.read(apiKeysRepositoryProvider);
                      if (await vm.run(
                            () => repository.change(
                              requireValue<String>(row['id']),
                              const Uuid().v7(),
                            ),
                          ) &&
                          context.mounted) {
                        Navigator.of(context).pop();
                      }
                    }
                  },
            child: Text(l.c4Revoke),
          ),
        ),
      ],
    );
  }
}
