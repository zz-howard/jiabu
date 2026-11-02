import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jiabu/app/c4_providers.dart';
import 'package:jiabu/app/ledger_providers.dart';
import 'package:jiabu/app/providers.dart';
import 'package:jiabu/domain/spaces.dart';
import 'package:jiabu/domain/sync_state.dart';
import 'package:jiabu/features/spaces/view/spaces_screen.dart';
import 'package:jiabu/features/update/view_model/update_view_model.dart';
import 'package:jiabu/features/update/widgets/update_banner.dart';
import 'package:jiabu/features/update/widgets/update_sheet.dart';
import 'package:jiabu/l10n/generated/app_localizations.dart';
import 'package:jiabu/shared/ledger/ledger_forms.dart';
import 'package:jiabu/shared/ledger/ledger_labels.dart';
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
    final update = ref.watch(updateViewModelProvider);
    final updateRelease = update.release;
    final updateVm = ref.read(updateViewModelProvider.notifier);
    final mandatory = updateVm.mandatory;
    final settingsRoute =
        path.startsWith('/settings') ||
        path.startsWith('/spaces') ||
        path == '/invitations';
    // 我的 (index 3) is the settings tab; space and invitation pages keep the
    // tab they were opened from.
    final selected = path.startsWith('/settings')
        ? 3
        : settingsRoute
        ? ref.watch(mainNavigationProvider)
        : path.startsWith('/overview')
        ? 1
        : path.startsWith('/history')
        ? 2
        : 0;
    final manual =
        (path == '/overview' || path == '/history') && spaceId != null;
    final personal =
        (ref.watch(spacesDirectoryProvider).asData?.value ??
                const <SpaceInfo>[])
            .any((space) => space.id == spaceId && space.isDefault);
    // Settings (the 我的 tab), spaces and invitations bring their own page
    // header; only chat, overview and history get the shared title block here.
    final tab = settingsRoute ? null : selected;

    return MainFrame(
      title: switch (tab) {
        0 => l.ledgerChatTitle,
        1 => l.ledgerOverview,
        2 => l.ledgerHistory,
        _ => null,
      },
      handEnglish: switch (tab) {
        0 => l.handChatEnglish,
        1 => handDateAccent(ref.watch(ledgerClockProvider)()),
        2 => l.handHistoryEnglish,
        _ => null,
      },
      subtitle: switch (tab) {
        0 => personal ? l.handChatSubtitlePersonal : l.handChatSubtitleShared,
        1 => l.handSubtitle,
        2 => l.handHistorySubtitle,
        _ => null,
      },
      showMark: tab == 0,
      personalSpace: personal,
      spaceName: data?.space.text('name') ?? l.ledgerNoSpace,
      accent:
          context.jiabu.colors.spaceAccents[data?.space.text('accent_color')] ??
          context.jiabu.colors.primaryText,
      onSpace: () => openSpaceSwitcher(context),
      labels: [l.ledgerChat, l.ledgerOverview, l.ledgerHistory, l.ledgerMe],
      selected: selected,
      onSelect: (index) {
        ref.read(mainNavigationProvider.notifier).selectedIndex = index;
        context.go(['/chat', '/overview', '/history', '/settings'][index]);
      },
      status: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (runtime.status == SyncStatus.offline) Text(l.authOffline),
          if (runtime.status == SyncStatus.clientTooOld &&
              (!runtime.updatesEnabled || updateRelease == null))
            Text(l.authClientTooOld),
          if (runtime.updatesEnabled &&
              update.bannerVisible &&
              updateRelease != null)
            UpdateBanner(
              message: mandatory
                  ? l.c7ForcedBanner(updateRelease.version)
                  : l.c7Banner(updateRelease.version),
              actionLabel: l.c7Update,
              mandatory: mandatory,
              onOpen: () async {
                updateVm.open();
                await JiabuSheet.show<void>(
                  context: context,
                  dismissible: !mandatory,
                  builder: (sheetContext) => Consumer(
                    builder: (context, ref, _) {
                      final current = ref.watch(updateViewModelProvider);
                      final vm = ref.read(updateViewModelProvider.notifier);
                      return UpdateSheet(
                        state: current,
                        locale:
                            Localizations.localeOf(context).languageCode == 'en'
                            ? 'en'
                            : 'zh-Hans',
                        mandatory: vm.mandatory,
                        onDownload: () => unawaited(vm.download()),
                        onCancel: vm.cancelDownload,
                        onRetry: () => unawaited(vm.retry()),
                        onSettings: () => unawaited(vm.openSettings()),
                        onInstall: () => unawaited(vm.install()),
                        onLater: () {
                          unawaited(vm.dismiss());
                          Navigator.of(sheetContext).pop();
                        },
                      );
                    },
                  ),
                );
                updateVm.closeSheet();
              },
              onDismiss: () => unawaited(updateVm.dismiss()),
            ),
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
