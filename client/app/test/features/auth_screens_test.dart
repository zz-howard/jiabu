import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/features/auth/view/change_password_screen.dart';
import 'package:jiabu/features/auth/view/login_screen.dart';
import 'package:jiabu/features/auth/view/server_address_screen.dart';
import 'package:jiabu/features/auth/view/session_status_screen.dart';
import 'package:jiabu/features/auth/view_model/auth_ui_state.dart';
import 'package:jiabu/features/auth/widgets/auth_frame.dart';
import 'package:jiabu/features/auth/widgets/switch_partition_prompt.dart';
import 'package:jiabu/l10n/generated/app_localizations.dart';
import 'package:jiabu_design/jiabu_design.dart';

Future<void> pumpAuth(
  WidgetTester tester,
  Widget child, {
  double width = 360,
  double scale = 1,
  String locale = 'zh',
  String accent = 'pine',
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final theme = JiabuTheme.light();
  final colors = theme.extension<JiabuColors>()!;
  await tester.pumpWidget(
    MaterialApp(
      theme: theme.copyWith(
        colorScheme: theme.colorScheme.copyWith(
          primary: colors.spaceAccents[accent],
        ),
      ),
      locale: Locale(locale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          disableAnimations: true,
        ),
        child: RepaintBoundary(key: const Key('auth-golden'), child: child),
      ),
      home: child,
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('auth_form_gaps_and_error_use_full_inner_width', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpAuth(
      tester,
      LoginScreen(
        state: const AuthUiState(
          errorCode: 'unauthenticated',
          server: 'https://example.invalid/',
        ),
        onLogin: (a, b) {},
        onServer: () {},
      ),
      scale: 2,
    );
    final context = tester.element(find.byType(AuthFrame));
    final gap = context.jiabu.decor.cardGap;
    final l10n = AppLocalizations.of(context);
    final title = tester.getRect(find.text(l10n.authLoginTitle));
    final server = tester.getRect(find.text('https://example.invalid/'));
    final username = tester.getRect(find.byKey(const Key('username')));
    final password = tester.getRect(find.byKey(const Key('password')));
    final button = tester.getRect(find.byType(FilledButton));
    final error = find.text(authError(context, 'unauthenticated'));
    final errorRect = tester.getRect(error);
    expect(server.top - title.bottom, closeTo(gap, .01));
    expect(username.top - server.bottom, closeTo(gap, .01));
    expect(password.top - username.bottom, closeTo(gap, .01));
    expect(button.top - password.bottom, closeTo(gap, .01));
    expect(errorRect.left, username.left);
    expect(errorRect.width, username.width);
    final card = tester.getRect(find.byType(PaperCard));
    expect(errorRect.width, card.width - 2 * context.jiabu.decor.cardInset);
    final text = tester.widget<Text>(error);
    expect(text.style?.color, Theme.of(context).colorScheme.error);
    expect(
      find.ancestor(
        of: error,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.liveRegion == true,
        ),
      ),
      findsOneWidget,
    );
    expect(
      tester.getSemantics(error).getSemanticsData().label,
      contains(text.data),
    );
    semantics.dispose();
  });

  testWidgets('switch_tape_has_clearance_at_large_text', (tester) async {
    await pumpAuth(
      tester,
      Scaffold(
        body: SwitchPartitionPrompt(
          count: 3,
          onContinue: () {},
          onCancel: () {},
        ),
      ),
      scale: 2,
    );
    final prompt = find.byType(SwitchPartitionPrompt);
    final context = tester.element(prompt);
    final tape = tester.getRect(find.byType(Tape));
    final text = tester.getRect(find.textContaining('还有 3 条没上传'));
    // PaperSheet already owns its handle gap; the prompt adds a form gap.
    expect(
      text.top - tape.bottom,
      greaterThanOrEqualTo(2 * context.jiabu.decor.cardGap),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('address_selection_uses_entered_value', (tester) async {
    String? selected;
    await pumpAuth(
      tester,
      ServerAddressScreen(
        state: const AuthUiState(),
        onSelect: (value) {
          selected = value;
        },
      ),
    );
    await tester.enterText(
      find.byKey(const Key('server-address')),
      'https://example.invalid/proxy',
    );
    await tester.tap(find.byType(FilledButton));
    expect(selected, 'https://example.invalid/proxy');
  });

  testWidgets('login_submits_once_and_clears_password_controller', (
    tester,
  ) async {
    var calls = 0;
    await pumpAuth(
      tester,
      LoginScreen(
        state: const AuthUiState(),
        onServer: () {},
        onLogin: (user, password) {
          expect(user, 'fictional');
          expect(password, 'fictional-test-password');
          calls++;
        },
      ),
    );
    await tester.enterText(find.byKey(const Key('username')), 'fictional');
    await tester.enterText(
      find.byKey(const Key('password')),
      'fictional-test-password',
    );
    await tester.tap(find.byType(FilledButton));
    expect(calls, 1);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('password')))
          .controller
          ?.text,
      isEmpty,
    );
  });

  testWidgets('forced_password_back_invokes_logout_path', (tester) async {
    var back = 0;
    await pumpAuth(
      tester,
      ChangePasswordScreen(
        state: const AuthUiState(forcedPassword: true),
        onSave: (a, b, c) {},
        onBack: () {
          back++;
        },
      ),
    );
    await tester.tap(find.byType(TextButton));
    expect(back, 1);
  });

  testWidgets('switch_prompt_has_exact_count_and_cancel_continu'
      'e_actions', (tester) async {
    var continued = false;
    var cancelled = false;
    await pumpAuth(
      tester,
      Scaffold(
        body: SwitchPartitionPrompt(
          count: 3,
          onContinue: () {
            continued = true;
          },
          onCancel: () {
            cancelled = true;
          },
        ),
      ),
    );
    expect(find.textContaining('还有 3 条没上传'), findsOneWidget);
    await tester.tap(find.byType(TextButton));
    expect(cancelled, isTrue);
    await tester.tap(find.byType(FilledButton));
    expect(continued, isTrue);
  });

  for (final width in [360.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final locale in ['zh', 'en']) {
        testWidgets('auth_layout_${width}_${scale}_$locale', (tester) async {
          final widgets = <Widget>[
            ServerAddressScreen(
              state: const AuthUiState(
                errorCode: 'invalid_server_address',
                servers: ['https://fictional.example.invalid/long/proxy/'],
              ),
              onSelect: (_) {},
            ),
            LoginScreen(
              state: const AuthUiState(errorCode: 'rate_limited'),
              onLogin: (a, b) {},
              onServer: () {},
            ),
            ChangePasswordScreen(
              state: const AuthUiState(
                forcedPassword: true,
                errorCode: 'invalid_new_password',
              ),
              onSave: (a, b, c) {},
              onBack: () {},
            ),
            SessionStatusScreen(
              state: const AuthUiState(),
              onPassword: () {},
              onSwitch: () {},
              onLogout: () {},
            ),
          ];
          for (final widget in widgets) {
            await pumpAuth(
              tester,
              widget,
              width: width,
              scale: scale,
              locale: locale,
            );
            expect(tester.takeException(), isNull);
            final scroll = find.byType(SingleChildScrollView).first;
            await tester.drag(scroll, const Offset(0, -600));
            await tester.pump();
            expect(tester.takeException(), isNull);
          }
        });
      }
    }
  }
}
