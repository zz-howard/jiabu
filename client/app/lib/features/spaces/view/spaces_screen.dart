import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jiabu/app/c4_providers.dart';
import 'package:jiabu/app/ledger_providers.dart';
import 'package:jiabu/app/providers.dart';
import 'package:jiabu/domain/result.dart';
import 'package:jiabu/domain/spaces.dart';
import 'package:jiabu/features/spaces/view/invitations_body.dart';
import 'package:jiabu/features/spaces/view/space_action_form.dart';
import 'package:jiabu/features/spaces/view/space_form.dart';
import 'package:jiabu/l10n/generated/app_localizations.dart';
import 'package:jiabu/shared/ledger/ledger_view_model.dart';
import 'package:jiabu_design/jiabu_design.dart';

export 'package:jiabu/features/spaces/view/invitations_body.dart';
export 'package:jiabu/features/spaces/view/space_action_form.dart';
export 'package:jiabu/features/spaces/view/space_form.dart';

Future<void> openSpaceSwitcher(BuildContext context) => PaperSheet.show<void>(
  context: context,
  builder: (_) => const SpacesScreen(page: 'switcher'),
);

class SpacesScreen extends ConsumerWidget {
  const SpacesScreen({required this.page, this.spaceId, super.key});
  final String page;
  final String? spaceId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    ref.watch(ledgerRuntimeEventsProvider);
    final runtime = ref.watch(appRuntimeProvider);
    final directory = ref.watch(spacesDirectoryProvider);
    final spaces = directory.asData?.value ?? <SpaceInfo>[];
    final currentId = spaceId ?? runtime.currentSpace;
    final space = spaces.where((space) => space.id == currentId).firstOrNull;
    if (page == 'received') {
      return const InvitationsBody();
    }
    if (page == 'switcher') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l.c4Spaces, style: context.jiabu.type.sectionTitle),
          if (directory.isLoading) Text(l.c4Loading),
          if (directory.hasError) Text(l.c4Error),
          SpaceSwitcher(
            currentId: runtime.currentSpace,
            personalLabel: l.handC4Personal,
            spaces: [
              for (final item in spaces)
                (
                  id: item.id,
                  name: item.name,
                  accent:
                      context.jiabu.colors.spaceAccents[item.accent] ??
                      context.jiabu.colors.primaryText,
                  personal: item.isDefault,
                ),
            ],
            onSelect: (id) async {
              final repository = ref.read(spacesRepositoryProvider);
              final router = GoRouter.of(context);
              final path = router.routeInformationProvider.value.uri.path;
              ref
                ..invalidate(ledgerViewModelProvider)
                ..invalidate(ledgerFormViewModelProvider);
              Navigator.of(context).pop();
              final result = await repository.select(id);
              if (result is Ok<void> && path.startsWith('/spaces/')) {
                final page = path.split('/').last;
                router.go('/spaces/$id/$page');
              }
            },
          ),
          TextButton(
            onPressed: runtime.managementOnline
                ? () {
                    final host = Navigator.of(context).context;
                    Navigator.of(context).pop();
                    unawaited(openSpaceForm(host));
                  }
                : null,
            child: Text(l.c4CreateSpace),
          ),
          TextButton(
            onPressed: space == null
                ? null
                : () {
                    final router = GoRouter.of(context);
                    Navigator.of(context).pop();
                    unawaited(
                      router.push<void>('/spaces/${space.id}/settings'),
                    );
                  },
            child: Text(l.c4SpaceSettings),
          ),
          TextButton(
            onPressed: () {
              final router = GoRouter.of(context);
              Navigator.of(context).pop();
              unawaited(router.push<void>('/invitations'));
            },
            child: Text(l.c4Received),
          ),
          if (!runtime.managementOnline) Text(l.c4Offline),
        ],
      );
    }
    if (space == null || runtime.currentSpace != currentId) {
      if (!directory.isLoading && !directory.hasError) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            context.go('/overview');
          }
        });
      }
      return Center(
        child: Text(directory.isLoading ? l.c4Loading : l.c4NotFound),
      );
    }
    if (page == 'invitations') {
      return InvitationsBody(space: space);
    }
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.jiabu.decor.pageInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            page == 'members' ? l.c4Members : l.c4SpaceSettings,
            style: context.jiabu.type.pageTitle,
          ),
          Text(space.name),
          if (!runtime.managementOnline) Text(l.c4Offline),
          if (page == 'settings') ...[
            if (space.owner)
              _action(
                context,
                l.c4Edit,
                runtime.managementOnline,
                () => openSpaceForm(context, space: space),
              ),
            _action(
              context,
              l.c4DisplayName,
              runtime.managementOnline,
              () => openSpaceAction(context, space, 'display_name'),
            ),
            _action(
              context,
              l.c4Members,
              true,
              () => context.push<void>('/spaces/${space.id}/members'),
            ),
            if (space.canInvite) ...[
              _action(
                context,
                l.c4Invite,
                runtime.managementOnline,
                () => openSpaceAction(context, space, 'invite'),
              ),
              _action(
                context,
                l.c4Invitations,
                true,
                () => context.push<void>('/spaces/${space.id}/invitations'),
              ),
            ],
            // TODO(S9): photo storage totals. Deliberately no visible row until
            // GET /spaces/{id}/storage exists; do not infer totals locally.
          ],
          for (final member in space.members)
            PaperCard(
              pattern: PaperPattern.ruled,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(member.name, style: context.jiabu.type.listTitle),
                  Text(
                    !member.active
                        ? l.c4Left
                        : member.role == 'owner'
                        ? l.c4Owner
                        : l.c4Member,
                  ),
                  if (space.owner &&
                      member.active &&
                      member.id != space.memberId)
                    Wrap(
                      children: [
                        TextButton(
                          onPressed: runtime.managementOnline
                              ? () => openSpaceAction(
                                  context,
                                  space,
                                  'remove',
                                  target: member.id,
                                )
                              : null,
                          child: Text(l.c4Remove),
                        ),
                        TextButton(
                          onPressed: runtime.managementOnline
                              ? () => openSpaceAction(
                                  context,
                                  space,
                                  'transfer',
                                  target: member.id,
                                )
                              : null,
                          child: Text(l.c4Transfer),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          if (!space.isDefault) ...[
            _action(context, l.c4Leave, runtime.managementOnline, () async {
              final count = await ref
                  .read(spacesRepositoryProvider)
                  .pendingCount(space.id);
              if (context.mounted) {
                await openSpaceAction(context, space, 'leave', pending: count);
              }
            }),
            if (space.canDelete)
              _action(
                context,
                l.c4Delete,
                runtime.managementOnline,
                () => openSpaceAction(context, space, 'delete'),
              ),
          ],
        ],
      ),
    );
  }
}

Widget _action(
  BuildContext context,
  String label,
  bool enabled,
  Future<void> Function() action,
) => OutlinedButton(onPressed: enabled ? action : null, child: Text(label));
