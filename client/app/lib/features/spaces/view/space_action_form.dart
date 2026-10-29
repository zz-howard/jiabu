import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jiabu/app/c4_providers.dart';
import 'package:jiabu/domain/spaces.dart';
import 'package:jiabu/l10n/generated/app_localizations.dart';
import 'package:jiabu/shared/c4/c4_form.dart';
import 'package:jiabu/shared/c4/c4_scope_fence.dart';
import 'package:jiabu/shared/c4/c4_view_model.dart';
import 'package:jiabu_design/jiabu_design.dart';

Future<void> openSpaceAction(
  BuildContext context,
  SpaceInfo space,
  String action, {
  String? target,
  int pending = 0,
}) => JiabuSheet.show<void>(
  context: context,
  builder: (_) => SpaceActionForm(
    space: space,
    action: action,
    target: target,
    pending: pending,
  ),
  wrapperBuilder: (_, child) => C4ScopeFence(child: child),
);

class SpaceActionForm extends ConsumerWidget {
  const SpaceActionForm({
    required this.space,
    required this.action,
    this.target,
    this.pending = 0,
    super.key,
  });
  final SpaceInfo space;
  final String action;
  final String? target;
  final int pending;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final id = '${space.id}:$action:${target ?? ''}';
    final state = ref.watch(c4ViewModelProvider(id));
    final vm = ref.read(c4ViewModelProvider(id).notifier);
    final blocked = action == 'leave' && space.lastOwner;
    final title = switch (action) {
      'invite' => l.c4Invite,
      'display_name' => l.c4DisplayName,
      'remove' => l.c4Remove,
      'transfer' => l.c4Transfer,
      'delete' => l.c4Delete,
      _ => l.c4Leave,
    };
    return C4Form(
      id: id,
      title: title,
      enabled:
          !blocked &&
          (action != 'delete' || state.values['name'] == space.name),
      submitLabel: l.c4Confirm,
      onSubmit: () async {
        final repository = ref.read(spacesRepositoryProvider);
        final body = switch (action) {
          'invite' => {'username': state.values['username'] ?? ''},
          'display_name' => {
            'display_name':
                state.values['display_name'] ??
                space.members
                    .where((m) => m.id == space.memberId)
                    .firstOrNull
                    ?.name ??
                '',
            'expected_version':
                space.members
                    .where((m) => m.id == space.memberId)
                    .firstOrNull
                    ?.version ??
                0,
          },
          'transfer' => {'member_id': target},
          'delete' => {'name': state.values['name']},
          _ => null,
        };
        final success = await vm.run(
          () => repository.change(
            space,
            action,
            vm.operationId,
            body: body,
            target: target,
          ),
        );
        if (success && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      children: [
        Text(space.name),
        if (target != null)
          Text(
            space.members
                    .where((member) => member.id == target)
                    .firstOrNull
                    ?.name ??
                '',
          ),
        if (action == 'leave') ...[
          Text(l.c4LeaveWarning),
          if (pending > 0) Text(l.c4PendingWarning(pending)),
          if (blocked) Text(l.c4LastOwner),
        ],
        if (action == 'remove') Text(l.c4RemoveWarning),
        if (action == 'transfer') Text(l.c4TransferWarning),
        if (action == 'delete') ...[
          Text(l.c4DeleteWarning),
          C4Field(id: id, field: 'name', label: l.c4Name),
        ],
        if (action == 'invite')
          C4Field(id: id, field: 'username', label: l.c4Username),
        if (action == 'display_name')
          C4Field(
            id: id,
            field: 'display_name',
            label: l.c4DisplayName,
            initial:
                space.members
                    .where((m) => m.id == space.memberId)
                    .firstOrNull
                    ?.name ??
                '',
          ),
      ],
    );
  }
}
