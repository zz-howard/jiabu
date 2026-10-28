import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/app/ledger_providers.dart';
import 'package:jiabu/domain/ledger.dart';
import 'package:jiabu/features/catalog/c3_cases.dart';
import 'package:jiabu/l10n/generated/app_localizations.dart';
import 'package:jiabu_design/jiabu_design.dart';

const c3Boundary = Key('c3-boundary');
Future<void> pumpC3(
  WidgetTester tester, {
  String state = 'card_recorded',
  double width = 360,
  double scale = 1,
  double keyboard = 0,
  String locale = 'zh',
  String accent = 'pine',
  Widget? child,
  LedgerRepository? repository,
  bool settle = true,
  String sessionSpaceId = 'fictional-c3',
  LedgerPresentationSession? Function()? session,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 844);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ledgerClockProvider.overrideWithValue(
          () => DateTime.utc(2026, 10, 28, 12),
        ),
        ledgerPresentationSessionProvider.overrideWith(
          (ref) => session == null
              ? (partition: 'test', spaceId: sessionSpaceId)
              : session(),
        ),
        if (repository != null)
          ledgerRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        theme: JiabuTheme.light(),
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            viewInsets: EdgeInsets.only(bottom: keyboard),
            disableAnimations: true,
          ),
          child: RepaintBoundary(key: c3Boundary, child: child),
        ),
        home: Scaffold(
          body: child ?? C3Preview(state: state, accent: accent),
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await pumpDatabaseFrames(tester);
  }
}

/// Give real SQLite futures time to complete without waiting for all animation
/// or stream work to become idle. Each call has a fixed, small upper bound.
Future<void> pumpDatabaseFrames(WidgetTester tester) async {
  for (var frame = 0; frame < 12; frame++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
}
