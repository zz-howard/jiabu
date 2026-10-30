import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/domain/sync_state.dart';
import 'package:jiabu/features/auth/view/change_password_screen.dart';
import 'package:jiabu/features/auth/view/login_screen.dart';
import 'package:jiabu/features/auth/view/server_address_screen.dart';
import 'package:jiabu/features/auth/view/session_status_screen.dart';
import 'package:jiabu/features/auth/view/welcome_screen.dart';
import 'package:jiabu/features/auth/view_model/auth_ui_state.dart';
import 'package:jiabu/features/auth/widgets/auth_frame.dart';
import 'package:jiabu/features/auth/widgets/auth_progress.dart';
import 'package:jiabu/features/auth/widgets/switch_partition_prompt.dart';
import 'package:jiabu/l10n/generated/app_localizations.dart';
import 'package:jiabu_design/jiabu_design.dart';

import '../support/auth_test_cases.dart';
import '../support/image_harness.dart';
import '../support/vertical_spacing.dart';

Future<void> pumpAuth(
  WidgetTester tester,
  Widget child, {
  double width = 360,
  double scale = 1,
  String locale = 'zh',
  String accent = 'pine',
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, width >= 400 ? 932 : 800);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final theme = JiabuTheme.light();
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
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
  await settleImages(tester);
}

void main() {
  test('auth geometry table covers every C4b golden state', () {
    expect(allAuthTestCases.map((sample) => sample.state).toSet(), {
      'welcome',
      'server_collapsed',
      'server_expanded',
      'server_unreachable',
      'login_connected',
      'login_invalid',
      'login_busy',
      'invite_placeholder',
      'password_forced',
      'password_invalid',
      'session_idle',
      'session_admin_reset',
      'session_space_cleared',
      'switch_pending',
    });
  });

  testWidgets('space accent never changes the auth primary color', (
    tester,
  ) async {
    await pumpAuth(
      tester,
      WelcomeScreen(busy: false, onStart: () {}, onLogin: () {}),
    );
    final context = tester.element(find.byType(WelcomeScreen));
    expect(Theme.of(context).colorScheme.primary, context.jiabu.colors.primary);
  });

  testWidgets('welcome logo stays centered at approved viewport sizes', (
    tester,
  ) async {
    for (final config in [(360.0, 1.0), (430.0, 2.0)]) {
      await pumpAuth(
        tester,
        WelcomeScreen(busy: false, onStart: () {}, onLogin: () {}),
        width: config.$1,
        scale: config.$2,
      );
      expect(
        tester.getRect(find.byType(JiabuLogo)).center.dx,
        closeTo(config.$1 / 2, 1),
        reason: '${config.$1} at ${config.$2}x',
      );
      expect(
        tester.getRect(find.byKey(const Key('welcome-tagline'))).center.dx,
        closeTo(config.$1 / 2, 1),
      );
      expect(
        tester.getRect(find.byKey(const Key('welcome-mascot-note'))).center.dx,
        closeTo(config.$1 / 2, 1),
      );
      final logoTape = find.descendant(
        of: find.byKey(const Key('welcome-logo-group')),
        matching: find.byType(Tape),
      );
      expect(tester.getRect(logoTape).left, greaterThanOrEqualTo(0));
      expect(tester.getRect(logoTape).right, lessThanOrEqualTo(config.$1));
      final stack = tester.getRect(find.byType(JiabuStack).first);
      final logo = tester.getRect(find.byKey(const Key('welcome-logo-group')));
      final tagline = tester.getRect(find.byKey(const Key('welcome-tagline')));
      final mascot = tester.getRect(
        find.byKey(const Key('welcome-mascot-note')),
      );
      final action = tester.getRect(
        find.byKey(const Key('welcome-primary-action')),
      );
      expect(
        logo.top - stack.top,
        greaterThanOrEqualTo(JiabuSpacing.xl - geometryTolerance),
      );
      expect(
        tagline.top - logo.bottom,
        greaterThanOrEqualTo(JiabuSpacing.sm - geometryTolerance),
      );
      expect(
        action.top - mascot.bottom,
        greaterThanOrEqualTo(JiabuSpacing.xxl - geometryTolerance),
      );
    }
  });

  testWidgets('C4b primary screens preserve approved block gaps', (
    tester,
  ) async {
    for (final config in [(360.0, 1.0), (430.0, 2.0)]) {
      for (final sample in <({String name, Widget screen})>[
        (
          name: 'server',
          screen: ServerAddressScreen(
            key: const ValueKey('server-collapsed-gap-check'),
            state: const AuthUiState(
              page: AuthPage.server,
              defaultServer: 'https://example.invalid/',
            ),
            onSelect: (_) {},
          ),
        ),
        (
          name: 'server-expanded',
          screen: ServerAddressScreen(
            key: const ValueKey('server-expanded-gap-check'),
            state: const AuthUiState(page: AuthPage.server),
            onSelect: (_) {},
          ),
        ),
        (
          name: 'login',
          screen: LoginScreen(
            state: const AuthUiState(
              page: AuthPage.login,
              server: 'https://example.invalid/',
              defaultServer: 'https://example.invalid/',
            ),
            onLogin: (_, _) {},
            onServer: () {},
          ),
        ),
      ]) {
        await pumpAuth(
          tester,
          sample.screen,
          width: config.$1,
          scale: config.$2,
        );
        final progress = tester.getRect(find.byKey(const Key('auth-progress')));
        final title = tester.getRect(find.byKey(const Key('auth-title-block')));
        final subtitle = tester.getRect(find.byKey(const Key('auth-subtitle')));
        final card = tester.getRect(find.byType(PaperCard).first);
        final body = tester.getRect(find.byKey(const Key('auth-body')));
        final footer = tester.getRect(find.byKey(const Key('auth-footer')));
        expect(
          title.top - progress.bottom,
          greaterThanOrEqualTo(JiabuSpacing.sectionTop - geometryTolerance),
          reason: '${sample.name} title ${config.$1}/${config.$2}',
        );
        expect(
          card.top - subtitle.bottom,
          greaterThanOrEqualTo(JiabuSpacing.sectionTop - geometryTolerance),
          reason: '${sample.name} body ${config.$1}/${config.$2}',
        );
        expect(
          footer.top - body.bottom,
          greaterThanOrEqualTo(JiabuSpacing.actionGap - geometryTolerance),
          reason: '${sample.name} footer ${config.$1}/${config.$2}',
        );
        if (sample.name == 'login') {
          final accountSection = tester.getRect(
            find.byKey(const Key('login-account-section')),
          );
          expect(
            accountSection.top - card.bottom,
            greaterThanOrEqualTo(JiabuSpacing.sectionTop - geometryTolerance),
            reason: 'login account section ${config.$1}/${config.$2}',
          );
        }
      }
    }
  });

  for (final locale in ['zh', 'en']) {
    for (final width in [360.0, 430.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('auth layout $locale $width $scale has no overflow', (
          tester,
        ) async {
          await pumpAuth(
            tester,
            LoginScreen(
              state: const AuthUiState(
                page: AuthPage.login,
                server: 'https://example.invalid/',
              ),
              onLogin: (_, _) {},
              onServer: () {},
            ),
            locale: locale,
            width: width,
            scale: scale,
          );
          expect(tester.takeException(), isNull);
          expect(
            expectJiabuVerticalRhythm(
              tester,
              reason: 'auth login $locale $width $scale',
            ),
            greaterThanOrEqualTo(2),
          );
          expect(
            expectJiabuChipSpacing(
              tester,
              reason: 'auth login $locale $width $scale',
            ),
            0,
          );
          final pageInset = width <= 380 ? 14.0 : 18.0;
          expect(
            tester.getRect(find.byType(PaperCard).first).left,
            closeTo(pageInset, .1),
          );
        });
      }
    }
  }

  testWidgets('auth_progress_has_three_dots_and_active_geometry', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpAuth(
      tester,
      ServerAddressScreen(
        state: const AuthUiState(defaultServer: 'https://example.invalid/'),
        onSelect: (_) {},
      ),
    );
    final dots = find.descendant(
      of: find.byKey(const Key('auth-progress')),
      matching: find.byType(AnimatedContainer),
    );
    expect(dots, findsNWidgets(3));
    expect(List.generate(3, (index) => tester.getSize(dots.at(index)).width), [
      7,
      18,
      7,
    ]);
    expect(find.bySemanticsLabel('2 / 3'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('auth_error_is_live_and_login_uses_the_new_frame', (
    tester,
  ) async {
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
    final error = find.text(authError(context, 'unauthenticated'));
    final text = tester.widget<Text>(error);
    expect(text.style?.fontFamily, JiabuType.systemSansFamily);
    expect(text.style?.color, Theme.of(context).colorScheme.error);
    expect(find.byType(PaperBackground), findsWidgets);
    expect(find.byType(AuthProgress), findsOneWidget);
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
    // JiabuSheet already owns its handle gap; the prompt adds a form gap.
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

  testWidgets('server_default_collapses_expands_and_restores', (tester) async {
    String? selected;
    await pumpAuth(
      tester,
      ServerAddressScreen(
        state: const AuthUiState(defaultServer: 'https://example.invalid/'),
        onSelect: (value) => selected = value,
      ),
    );
    expect(find.text('使用默认服务端'), findsOneWidget);
    expect(find.byKey(const Key('server-address')), findsNothing);
    await tester.tap(find.byKey(const Key('server-continue')));
    expect(selected, 'https://example.invalid/');
    await tester.tap(find.byKey(const Key('advanced-settings')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('server-address')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('server-address')),
      'https://custom.example.invalid/',
    );
    await tester.tap(find.byKey(const Key('restore-default')));
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('server-address')))
          .controller
          ?.text,
      'https://example.invalid/',
    );
  });

  testWidgets('server_without_default_is_open_and_has_no_default_controls', (
    tester,
  ) async {
    await pumpAuth(
      tester,
      ServerAddressScreen(state: const AuthUiState(), onSelect: (_) {}),
    );
    expect(find.byKey(const Key('server-address')), findsOneWidget);
    expect(find.byKey(const Key('advanced-settings')), findsNothing);
    expect(find.byKey(const Key('restore-default')), findsNothing);
  });

  testWidgets('insecure_server_is_rejected_before_callback', (tester) async {
    var calls = 0;
    await pumpAuth(
      tester,
      ServerAddressScreen(state: const AuthUiState(), onSelect: (_) => calls++),
    );
    await tester.enterText(
      find.byKey(const Key('server-address')),
      'http://example.invalid/',
    );
    await tester.tap(find.byKey(const Key('server-continue')));
    await tester.pump();
    expect(calls, 0);
    expect(find.textContaining('https://'), findsWidgets);
  });

  testWidgets('connection_stamp_requires_successful_probe', (tester) async {
    for (final connected in [false, true]) {
      await pumpAuth(
        tester,
        LoginScreen(
          state: AuthUiState(
            server: 'https://example.invalid/',
            serverProbeSucceeded: connected,
          ),
          onLogin: (_, _) {},
          onServer: () {},
        ),
      );
      expect(
        find.byKey(const Key('server-connected')),
        connected ? findsOneWidget : findsNothing,
      );
    }
  });

  testWidgets('login_without_default_displays_the_actual_server', (
    tester,
  ) async {
    await pumpAuth(
      tester,
      LoginScreen(
        state: const AuthUiState(server: 'https://custom.example.invalid/'),
        onLogin: (_, _) {},
        onServer: () {},
      ),
    );
    expect(
      find.textContaining('https://custom.example.invalid/'),
      findsOneWidget,
    );
    expect(find.textContaining('默认服务端'), findsNothing);
  });

  testWidgets('change_server_and_invite_placeholder_are_ui_only', (
    tester,
  ) async {
    var serverCalls = 0;
    var fakeApiCalls = 0;
    await pumpAuth(
      tester,
      LoginScreen(
        state: const AuthUiState(server: 'https://example.invalid/'),
        onLogin: (_, _) => fakeApiCalls++,
        onServer: () => serverCalls++,
      ),
    );
    await tester.tap(find.byKey(const Key('change-server')));
    expect(serverCalls, 1);
    await tester.tap(find.byKey(const Key('invite-signup')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('invite-signup-placeholder')), findsOneWidget);
    expect(fakeApiCalls, 0, reason: 'the placeholder must not send a request');
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

  testWidgets('password_visibility_toggle_changes_obscuring', (tester) async {
    await pumpAuth(
      tester,
      LoginScreen(
        state: const AuthUiState(server: 'https://example.invalid/'),
        onServer: () {},
        onLogin: (_, _) {},
      ),
    );
    TextField password() =>
        tester.widget<TextField>(find.byKey(const Key('password')));
    expect(password().obscureText, isTrue);
    await tester.tap(find.byKey(const Key('toggle-password')));
    await tester.pump();
    expect(password().obscureText, isFalse);
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

  for (final (status, text) in [
    (SyncStatus.clientTooOld, (AppLocalizations l) => l.authClientTooOld),
    (SyncStatus.serverTooOld, (AppLocalizations l) => l.authServerTooOld),
  ]) {
    testWidgets('session_status_shows_${status.name}_notice', (tester) async {
      await pumpAuth(
        tester,
        SessionStatusScreen(
          state: AuthUiState(page: AuthPage.session, syncStatus: status),
          onPassword: () {},
          onSwitch: () {},
          onLogout: () {},
        ),
      );
      final l = AppLocalizations.of(tester.element(find.byType(AuthFrame)));
      expect(find.text(text(l)), findsOneWidget);
    });
  }

  // Expected message per code, written out independently of authError so a
  // swapped or collapsed mapping fails.
  final expectedMessage = <String, String Function(AppLocalizations)>{
    'unauthenticated': (l) => l.authInvalidCredentials,
    'rate_limited': (l) => l.authRateLimited,
    'session_expired': (l) => l.authSessionExpired,
    'account_disabled': (l) => l.authAccountDisabled,
    'network': (l) => l.authOffline,
    'invalid_server_address': (l) => l.authInvalidAddress,
    'invalid_new_password': (l) => l.authPasswordValidation,
  };
  for (final (screen, codes) in [
    (
      'login',
      [
        'unauthenticated',
        'rate_limited',
        'session_expired',
        'account_disabled',
        'network',
      ],
    ),
    ('server', ['invalid_server_address', 'network']),
    ('password', ['invalid_new_password', 'network']),
  ]) {
    for (final code in codes) {
      testWidgets('${screen}_error_${code}_shows_its_message', (tester) async {
        final state = AuthUiState(
          server: 'https://example.invalid/',
          errorCode: code,
        );
        await pumpAuth(tester, switch (screen) {
          'login' => LoginScreen(
            state: state,
            onLogin: (_, _) {},
            onServer: () {},
          ),
          'server' => ServerAddressScreen(state: state, onSelect: (_) {}),
          _ => ChangePasswordScreen(
            state: state,
            onSave: (_, _, _) {},
            onBack: () {},
          ),
        });
        final l = AppLocalizations.of(tester.element(find.byType(AuthFrame)));
        final message = expectedMessage[code]!(l);
        expect(message, isNot(l.authRequestFailed));
        expect(find.text(message), findsOneWidget);
      });
    }
  }

  for (final width in [360.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final locale in ['zh', 'en']) {
        testWidgets('auth_layout_${width}_${scale}_$locale', (tester) async {
          final semantics = tester.ensureSemantics();
          for (final sample in allAuthTestCases) {
            // Start each state from a fresh tree: a sheet opened by the
            // previous state would otherwise stay on the Navigator and hide
            // this screen from semantics.
            await tester.pumpWidget(const SizedBox());
            await pumpAuth(
              tester,
              sample.builder(),
              width: width,
              scale: scale,
              locale: locale,
            );
            // Modal routes exclude their background fields from semantics.
            // Check the source screen before opening invite_placeholder.
            final fieldCount = find.byType(EditableText).evaluate().length;
            for (var index = 0; index < fieldCount; index++) {
              // Fields scrolled out of the viewport drop out of the
              // semantics tree, so bring each one into view first. Find by
              // index: scrolling rebuilds the widgets.
              final editable = find.byType(EditableText).at(index);
              await tester.ensureVisible(editable);
              await tester.pump();
              expect(
                tester.getSemantics(editable).getSemanticsData().label,
                isNotEmpty,
                reason: '${sample.state} TextField semantics label',
              );
            }
            if (sample.tapKey case final String key) {
              final target = find.byKey(Key(key));
              await tester.ensureVisible(target);
              await tester.tap(target);
              await tester.pumpAndSettle();
              if (sample.state != 'invite_placeholder') {
                for (final field in find.byType(TextField).evaluate()) {
                  final editable = find.descendant(
                    of: find.byWidget(field.widget),
                    matching: find.byType(EditableText),
                  );
                  expect(
                    tester.getSemantics(editable).getSemanticsData().label,
                    isNotEmpty,
                    reason: '${sample.state} expanded TextField label',
                  );
                }
              }
            }
            expect(tester.takeException(), isNull);
            expect(
              expectJiabuVerticalRhythm(
                tester,
                reason: '${sample.state} $locale $width $scale',
              ),
              greaterThanOrEqualTo(sample.minimumPairs),
            );
            expect(
              expectJiabuChipSpacing(
                tester,
                reason: '${sample.state} $locale $width $scale',
              ),
              0,
            );
            for (final element
                in find.bySubtype<ButtonStyleButton>().evaluate()) {
              final box = tester.renderObject<RenderBox>(
                find.byWidget(element.widget),
              );
              expect(
                box.size.width,
                greaterThanOrEqualTo(JiabuSpacing.minTapTarget),
              );
              expect(
                box.size.height,
                greaterThanOrEqualTo(JiabuSpacing.minTapTarget),
              );
            }
            final scroll = find.byType(SingleChildScrollView).first;
            await tester.drag(scroll, const Offset(0, -600));
            await tester.pump();
            expect(tester.takeException(), isNull);
          }
          semantics.dispose();
        });
      }
    }
  }
}
