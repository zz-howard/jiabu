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
import 'package:jiabu/shared/navigation.dart';
import 'package:jiabu_design/jiabu_design.dart';

export 'package:jiabu/features/spaces/view/invitations_body.dart';
export 'package:jiabu/features/spaces/view/space_action_form.dart';
export 'package:jiabu/features/spaces/view/space_form.dart';

Future<void> openSpaceSwitcher(BuildContext context) => JiabuSheet.show<void>(
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
      return JiabuPageScaffold(
        title: l.c4Received,
        onBack: () => popOrGo(context, '/settings'),
        body: const InvitationsBody(),
      );
    }
    if (page == 'switcher') {
      return JiabuStack(
        children: [
          JiabuStackItem.content(
            child: Text(l.c4Spaces, style: context.jiabu.type.sectionTitle),
          ),
          if (directory.isLoading)
            JiabuStackItem.captionBefore(child: Text(l.c4Loading)),
          if (directory.hasError)
            JiabuStackItem.captionBefore(child: Text(l.c4Error)),
          JiabuStackItem.content(
            child: SpaceSwitcher(
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
          ),
          JiabuStackItem.action(
            child: TextButton(
              onPressed: runtime.managementOnline
                  ? () {
                      final host = Navigator.of(context).context;
                      Navigator.of(context).pop();
                      unawaited(openSpaceForm(host));
                    }
                  : null,
              child: Text(l.c4CreateSpace),
            ),
          ),
          JiabuStackItem.action(
            child: TextButton(
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
          ),
          JiabuStackItem.action(
            child: TextButton(
              onPressed: () {
                final router = GoRouter.of(context);
                Navigator.of(context).pop();
                unawaited(router.push<void>('/invitations'));
              },
              child: Text(l.c4Received),
            ),
          ),
          if (!runtime.managementOnline)
            JiabuStackItem.captionAfter(child: Text(l.c4Offline)),
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
      final title = switch (page) {
        'members' => l.c4Members,
        'invitations' => l.c4Invitations,
        _ => l.c4SpaceSettings,
      };
      return JiabuPageScaffold(
        title: title,
        onBack: () => popOrGo(
          context,
          page == 'settings' ? '/settings' : '/spaces/$currentId/settings',
        ),
        body: Center(
          child: Text(directory.isLoading ? l.c4Loading : l.c4NotFound),
        ),
      );
    }
    if (page == 'invitations') {
      return JiabuPageScaffold(
        title: l.c4Invitations,
        onBack: () => popOrGo(context, '/spaces/$currentId/settings'),
        body: InvitationsBody(space: space),
      );
    }
    final title = page == 'members' ? l.c4Members : l.c4SpaceSettings;
    return JiabuPageScaffold(
      title: title,
      onBack: () => popOrGo(
        context,
        page == 'settings' ? '/settings' : '/spaces/$currentId/settings',
      ),
      action: page == 'settings' && !space.isDefault
          ? PopupMenuButton<String>(
              icon: JiabuIcon(
                JiabuIcons.uiMore,
                color: runtime.managementOnline
                    ? null
                    : context.jiabu.colors.ink.withValues(alpha: .38),
              ),
              enabled: runtime.managementOnline,
              onSelected: (value) async {
                if (value == 'leave') {
                  final count = await ref
                      .read(spacesRepositoryProvider)
                      .pendingCount(space.id);
                  if (context.mounted) {
                    await openSpaceAction(
                      context,
                      space,
                      'leave',
                      pending: count,
                    );
                  }
                } else if (value == 'delete') {
                  await openSpaceAction(context, space, 'delete');
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'leave', child: Text(l.c4Leave)),
                if (space.canDelete)
                  PopupMenuItem(value: 'delete', child: Text(l.c4Delete)),
              ],
            )
          : null,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(context.jiabu.spacing.page),
        child: JiabuStack(
          children: [
            JiabuStackItem.content(
              child: Text(space.name, style: context.jiabu.type.secondary),
            ),
            if (!runtime.managementOnline)
              JiabuStackItem.captionAfter(child: Text(l.c4Offline)),
            JiabuStackItem.content(
              child: JiabuSettingsGroup(
                children: [
                  if (page == 'settings') ...[
                    if (space.owner)
                      JiabuListRow(
                        title: l.c4Edit,
                        showChevron: true,
                        enabled: runtime.managementOnline,
                        onTap: () => openSpaceForm(context, space: space),
                      ),
                    JiabuListRow(
                      title: l.c4DisplayName,
                      showChevron: true,
                      enabled: runtime.managementOnline,
                      onTap: () =>
                          openSpaceAction(context, space, 'display_name'),
                    ),
                    JiabuListRow(
                      title: l.c4Members,
                      showChevron: true,
                      onTap: () =>
                          context.push<void>('/spaces/${space.id}/members'),
                    ),
                    if (space.canInvite)
                      JiabuListRow(
                        title: l.c4Invite,
                        showChevron: true,
                        enabled: runtime.managementOnline,
                        onTap: () => openSpaceAction(context, space, 'invite'),
                      ),
                    if (space.canInvite)
                      JiabuListRow(
                        title: l.c4Invitations,
                        showChevron: true,
                        onTap: () => context.push<void>(
                          '/spaces/${space.id}/invitations',
                        ),
                      ),
                  ],
                  // TODO(S9): photo storage totals. Deliberately no visible row
                  // until GET /spaces/{id}/storage exists; do not infer locally.
                  for (final member in space.members)
                    JiabuListRow(
                      title: member.name,
                      subtitle: !member.active
                          ? l.c4Left
                          : member.role == 'owner'
                          ? l.c4Owner
                          : l.c4Member,
                      trailing:
                          space.owner &&
                              member.active &&
                              member.id != space.memberId
                          ? PopupMenuButton<String>(
                              icon: JiabuIcon(
                                JiabuIcons.uiMore,
                                color: runtime.managementOnline
                                    ? null
                                    : context.jiabu.colors.ink.withValues(
                                        alpha: .38,
                                      ),
                              ),
                              enabled: runtime.managementOnline,
                              onSelected: (value) => openSpaceAction(
                                context,
                                space,
                                value,
                                target: member.id,
                              ),
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                  value: 'remove',
                                  child: Text(l.c4Remove),
                                ),
                                PopupMenuItem(
                                  value: 'transfer',
                                  child: Text(l.c4Transfer),
                                ),
                              ],
                            )
                          : null,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
