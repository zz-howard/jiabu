import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/app/c4_providers.dart';
import 'package:jiabu/app/ledger_providers.dart';
import 'package:jiabu/app/providers.dart';
import 'package:jiabu/app/runtime.dart';
import 'package:jiabu/domain/spaces.dart';
import 'package:jiabu/features/catalog/c4_cases.dart';
import 'package:jiabu/l10n/generated/app_localizations.dart';
import 'package:jiabu_design/jiabu_design.dart';

const c4Boundary = Key('c4-boundary');
Future<ProviderContainer> pumpC4Widget(
  WidgetTester tester, {
  required Widget child,
  required AppRuntime runtime,
  required C4FakeSpaces spaces,
  required C4FakeKeys keys,
  Stream<List<SpaceInfo>>? directory,
}) async {
  late ProviderContainer container;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appRuntimeProvider.overrideWith((ref) => runtime),
        spacesRepositoryProvider.overrideWithValue(spaces),
        apiKeysRepositoryProvider.overrideWithValue(keys),
        spacesDirectoryProvider.overrideWith(
          (ref) => directory ?? spaces.watch(),
        ),
        ledgerPresentationSessionProvider.overrideWith(
          (ref) => (partition: 'fictional', spaceId: runtime.currentSpace),
        ),
      ],
      child: MaterialApp(
        theme: JiabuTheme.light(),
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              container = ProviderScope.containerOf(context);
              return child;
            },
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> pumpC4Preview(
  WidgetTester tester, {
  required String state,
  double width = 360,
  double scale = 1,
  String locale = 'zh',
  String accent = 'pine',
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 844);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: JiabuTheme.light(),
      locale: Locale(locale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          disableAnimations: true,
        ),
        child: RepaintBoundary(key: c4Boundary, child: child),
      ),
      home: Scaffold(
        body: PaperBackground(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: C4Preview(state: state, accent: accent),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
