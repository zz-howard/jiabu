import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jiabu/app/c4_providers.dart';
import 'package:jiabu/app/ledger_providers.dart';
import 'package:jiabu/app/providers.dart';
import 'package:jiabu/l10n/generated/app_localizations.dart';
import 'package:jiabu/shared/c4/c4_confirmation.dart';
import 'package:jiabu/shared/c4/c4_form.dart';
import 'package:jiabu/shared/c4/c4_view_model.dart';
import 'package:jiabu/shared/navigation.dart';
import 'package:jiabu_design/jiabu_design.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({this.page = 'settings', super.key});
  final String page;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    ref
      ..watch(ledgerRuntimeEventsProvider)
      ..watch(lockEventsProvider);
    final runtime = ref.watch(appRuntimeProvider);
    final keyCount = page == 'settings'
        ? ref.watch(activeKeyCountProvider).asData?.value
        : null;
    final id = 'settings:$page';
    final state = ref.watch(c4ViewModelProvider(id));
    final vm = ref.read(c4ViewModelProvider(id).notifier);
    Widget row(String title, String route, {String? subtitle}) => JiabuListRow(
      title: title,
      subtitle: subtitle,
      showChevron: true,
      onTap: () => context.push<void>(route),
    );
    final title = switch (page) {
      'account' => l.c4Account,
      'password' => l.c4Password,
      'language' => l.c4Language,
      'about' => l.c4About,
      _ => l.ledgerSettings,
    };
    return JiabuPageScaffold(
      title: title,
      handEnglish: page == 'settings' ? l.handSettingsEnglish : null,
      subtitle: page == 'settings' ? l.handSettingsSubtitle : null,
      onBack: () => popOrGo(context, switch (page) {
        'settings' => '/chat',
        'password' => '/settings/account',
        _ => '/settings',
      }),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(context.jiabu.spacing.page),
        child: C4Form(
          id: id,
          title: title,
          showTitle: false,
          requiresOnline: page == 'password' || page == 'language',
          onSubmit: page != 'password'
              ? null
              : () async {
                  final current = state.values['current'] as String? ?? '';
                  final next = state.values['new'] as String? ?? '';
                  if (current.isEmpty || next.length < 8) {
                    vm.fail('validation_failed');
                    return;
                  }
                  if (await vm.run(
                        () => runtime.auth.changePassword(current, next),
                      ) &&
                      context.mounted) {
                    context.go('/settings/account');
                  }
                },
          children: [
            if (page == 'settings')
              JiabuStackItem.content(
                child: JiabuSettingsGroup(
                  children: [
                    // Keep C3's account management label and route.
                    row(l.ledgerAccounts, '/settings/accounts'),
                    row(
                      l.c4Account,
                      '/settings/account',
                      subtitle: runtime.auth.current?.user.username,
                    ),
                    row(
                      l.c4Lock,
                      '/settings/app-lock',
                      subtitle: runtime.lock.configuration.enabled
                          ? l.c4Enabled
                          : l.c4Disabled,
                    ),
                    row(
                      l.c4Keys,
                      '/settings/api-keys',
                      subtitle: keyCount == null
                          ? null
                          : l.c4KeyCount(keyCount),
                    ),
                    row(l.c4Language, '/settings/language'),
                    row(l.c4Received, '/invitations'),
                    row(l.c4About, '/settings/about'),
                  ],
                ),
              ),
            if (page == 'account') ...[
              JiabuStackItem.content(
                child: Text(runtime.auth.current?.user.username ?? ''),
              ),
              JiabuStackItem.content(
                child: JiabuSettingsGroup(
                  children: [row(l.c4Password, '/settings/account/password')],
                ),
              ),
              JiabuStackItem.action(
                child: OutlinedButton(
                  onPressed: () async {
                    final confirmed = await JiabuSheet.show<bool>(
                      context: context,
                      builder: (sheetContext) => C4Confirmation(
                        message: l.c4Logout,
                        onConfirm: () => Navigator.of(sheetContext).pop(true),
                      ),
                    );
                    if (confirmed == true) {
                      await runtime.auth.logout();
                    }
                  },
                  child: Text(l.c4Logout),
                ),
              ),
            ],
            if (page == 'password') ...[
              JiabuStackItem.content(
                child: C4Field(
                  id: id,
                  field: 'current',
                  label: l.c4CurrentPassword,
                  obscure: true,
                ),
              ),
              JiabuStackItem.content(
                child: C4Field(
                  id: id,
                  field: 'new',
                  label: l.c4NewPassword,
                  obscure: true,
                ),
              ),
            ],
            if (page == 'language')
              JiabuStackItem.content(
                child: JiabuSettingsGroup(
                  children: [
                    for (final entry in {
                      'system': l.c4System,
                      'zh-Hans': l.c4Chinese,
                      'en': l.c4English,
                    }.entries)
                      Semantics(
                        key: ValueKey('language-${entry.key}'),
                        selected:
                            runtime.auth.current?.user.locale == entry.key,
                        child: JiabuListRow(
                          title: entry.value,
                          enabled: state.online && !state.busy,
                          trailing:
                              runtime.auth.current?.user.locale == entry.key
                              ? const Text('✓')
                              : null,
                          onTap: !state.online || state.busy
                              ? null
                              : () async {
                                  if (await vm.run(
                                    () => runtime.auth.setLocale(entry.key),
                                  )) {
                                    runtime.notify();
                                  }
                                },
                        ),
                      ),
                  ],
                ),
              ),
            if (page == 'about') ...[
              JiabuStackItem.content(
                child: Text(
                  l.c4Version(runtime.device.appVersion, runtime.device.build),
                ),
              ),
              JiabuStackItem.action(
                child: TextButton(
                  onPressed: () => showLicensePage(
                    context: context,
                    applicationName: l.c4ProductName,
                    applicationVersion: runtime.device.appVersion,
                  ),
                  child: Text(l.c4Licenses),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
