import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/app/c7_preview.dart';
import 'package:jiabu/domain/update.dart';
import 'package:jiabu/features/update/view_model/update_ui_state.dart';
import 'package:jiabu/features/update/widgets/update_sheet.dart';
import 'package:jiabu/l10n/generated/app_localizations.dart';

import '../support/c3_harness.dart';

void main() {
  testWidgets('ordinary banner opens and can close', (tester) async {
    await pumpC3(tester, child: const C7Preview(state: 'banner_available'));
    expect(find.byKey(const Key('update-banner')), findsOneWidget);
    expect(find.byType(IconButton), findsOneWidget);
  });

  testWidgets('forced banner has no close control', (tester) async {
    await pumpC3(tester, child: const C7Preview(state: 'banner_forced'));
    expect(find.byKey(const Key('update-banner-forced')), findsOneWidget);
    expect(find.byType(IconButton), findsNothing);
  });

  testWidgets('forced sheet has no later action', (tester) async {
    await pumpC3(
      tester,
      child: UpdateSheet(
        state: const UpdateUiState(release: C7Preview.release),
        locale: 'zh-Hans',
        mandatory: true,
        onDownload: () {},
        onCancel: () {},
        onRetry: () {},
        onSettings: () {},
        onInstall: () {},
        onLater: () {},
      ),
    );
    final context = tester.element(find.byType(UpdateSheet));
    expect(find.text(AppLocalizations.of(context).c7Later), findsNothing);
  });

  testWidgets('permission state explains before settings and install', (
    tester,
  ) async {
    await pumpC3(
      tester,
      child: const C7Preview(state: 'sheet_permission_required'),
    );
    final context = tester.element(find.byType(C7Preview));
    final l = AppLocalizations.of(context);
    expect(find.text(l.c7PermissionHelp), findsOneWidget);
    expect(find.text(l.c7GoSettings), findsOneWidget);
    expect(find.text(l.c7Install), findsOneWidget);
  });

  testWidgets('signature failure has tamper message and retry', (tester) async {
    await pumpC3(
      tester,
      child: UpdateSheet(
        state: const UpdateUiState(
          release: C7Preview.release,
          phase: UpdatePhase.failed,
          failure: UpdateFailure.signatureMismatch,
        ),
        locale: 'zh-Hans',
        mandatory: false,
        onDownload: () {},
        onCancel: () {},
        onRetry: () {},
        onSettings: () {},
        onInstall: () {},
        onLater: () {},
      ),
    );
    final context = tester.element(find.byType(UpdateSheet));
    final l = AppLocalizations.of(context);
    expect(find.text(l.c7Tampered), findsOneWidget);
    expect(find.text(l.c7Retry), findsOneWidget);
  });

  testWidgets('installing state always offers reinstall escape', (
    tester,
  ) async {
    await pumpC3(
      tester,
      child: UpdateSheet(
        state: const UpdateUiState(
          release: C7Preview.release,
          phase: UpdatePhase.installing,
        ),
        locale: 'zh-Hans',
        mandatory: true,
        onDownload: () {},
        onCancel: () {},
        onRetry: () {},
        onSettings: () {},
        onInstall: () {},
        onLater: () {},
      ),
    );
    final context = tester.element(find.byType(UpdateSheet));
    expect(find.text(AppLocalizations.of(context).c7Reinstall), findsOneWidget);
  });
}
