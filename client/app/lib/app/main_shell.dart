import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jiabu/app/ledger_providers.dart';
import 'package:jiabu/app/providers.dart';
import 'package:jiabu/domain/sync_state.dart';
import 'package:jiabu/features/spaces/view/spaces_screen.dart';
import 'package:jiabu/l10n/generated/app_localizations.dart';
import 'package:jiabu/shared/ledger/ledger_forms.dart';
import 'package:jiabu/shared/ledger/ledger_view_model.dart';
import 'package:jiabu/shared/ledger/main_frame.dart';
import 'package:jiabu_design/jiabu_design.dart';

class MainShell extends ConsumerWidget {
  const MainShell({required this.child, required this.path, super.key});
  final Widget child;
  final String path;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    ref.watch(ledgerRuntimeEventsProvider);
    final spaceId = ref.watch(currentLedgerSpaceProvider).asData?.value;
    final data = spaceId == null
        ? null
        : ref.watch(ledgerViewModelProvider(spaceId)).snapshot;
    final runtime = ref.watch(appRuntimeProvider);
    final settingsRoute =
        path.startsWith('/settings') ||
        path.startsWith('/spaces') ||
        path == '/invitations';
    final selected = settingsRoute
        ? ref.watch(mainNavigationProvider)
        : path.startsWith('/overview')
        ? 1
        : path.startsWith('/history')
        ? 2
        : 0;
    final manual =
        (path == '/overview' || path == '/history') && spaceId != null;
    return MainFrame(
      spaceName: data?.space.text('name') ?? l.ledgerNoSpace,
      accent:
          context.jiabu.colors.spaceAccents[data?.space.text('accent_color')] ??
          context.jiabu.colors.primaryText,
      settingsLabel: l.ledgerMySettings,
      onSpace: () => openSpaceSwitcher(context),
      labels: [l.ledgerChat, l.ledgerOverview, l.ledgerHistory],
      selected: selected,
      onSelect: (index) {
        ref.read(mainNavigationProvider.notifier).selectedIndex = index;
        context.go(['/chat', '/overview', '/history'][index]);
      },
      onSettings: () {
        ref.read(mainNavigationProvider.notifier).selectedIndex = selected;
        unawaited(context.push<void>('/settings'));
      },
      status: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (runtime.status == SyncStatus.offline) Text(l.authOffline),
          if (runtime.status == SyncStatus.clientTooOld)
            Text(l.authClientTooOld),
          if (runtime.spaceCleared)
            Wrap(
              children: [
                Text(l.authSpaceCleared(runtime.clearedCount)),
                TextButton(
                  onPressed: () => unawaited(runtime.dismissRemovalNotice()),
                  child: Text(l.ledgerAcknowledge),
                ),
              ],
            ),
        ],
      ),
      manual: manual
          ? ManualEntryButton(
              label: l.ledgerManual,
              semanticLabel: l.ledgerManualSemantics,
              onPressed: data?.writable == true
                  ? () => openManualEntry(context, spaceId)
                  : null,
            )
          : null,
      child: TweenAnimationBuilder<double>(
        key: ValueKey('${runtime.currentSpace}:${runtime.spaceRevision}'),
        tween: Tween(begin: 0, end: 1),
        duration: context.jiabu.motion.space,
        builder: (context, opacity, child) =>
            Opacity(opacity: opacity, child: child),
        child: runtime.currentSpace == spaceId
            ? child
            : const SizedBox.shrink(),
      ),
    );
  }
}
