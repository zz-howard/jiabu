import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jiabu/app/providers.dart';
import 'package:jiabu/app/router.dart';
import 'package:jiabu/features/auth/view_model/auth_view_model.dart';
import 'package:jiabu/l10n/generated/app_localizations.dart';
import 'package:jiabu_design/jiabu_design.dart';
import 'package:riverpod_annotation/experimental/scope.dart';

class PartitionHost extends ConsumerWidget {
  const PartitionHost({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final revision = ref.watch(
      authViewModelProvider.select((state) => state.partitionRevision),
    );
    final store = ref.read(appRuntimeProvider).auth.handle?.store;
    return ProviderScope(
      key: ValueKey(revision),
      overrides: [
        routerProvider.overrideWith(router),
        if (store != null) partitionStoreProvider.overrideWith((ref) => store),
      ],
      child: const _RoutedApp(),
    );
  }
}

@Dependencies([router])
class _RoutedApp extends ConsumerWidget {
  const _RoutedApp();
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    debugShowCheckedModeBanner: false,
    theme: JiabuTheme.light(),
    locale: switch (ref.watch(appRuntimeProvider).auth.current?.user.locale) {
      'en' => const Locale('en'),
      'zh-Hans' => const Locale('zh'),
      _ => null,
    },
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    routerConfig: ref.watch(routerProvider),
  );
}
