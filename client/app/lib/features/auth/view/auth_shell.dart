import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jiabu/features/auth/view/change_password_screen.dart';
import 'package:jiabu/features/auth/view/login_screen.dart';
import 'package:jiabu/features/auth/view/server_address_screen.dart';
import 'package:jiabu/features/auth/view/session_status_screen.dart';
import 'package:jiabu/features/auth/view/welcome_screen.dart';
import 'package:jiabu/features/auth/view_model/auth_ui_state.dart';
import 'package:jiabu/features/auth/view_model/auth_view_model.dart';
import 'package:jiabu/features/auth/widgets/switch_partition_prompt.dart';
import 'package:jiabu_design/jiabu_design.dart';

class AuthShell extends ConsumerStatefulWidget {
  const AuthShell({this.signedInChild, super.key});
  final Widget? signedInChild;
  @override
  ConsumerState<AuthShell> createState() => _AuthShellState();
}

class _AuthShellState extends ConsumerState<AuthShell> {
  @override
  void initState() {
    super.initState();
    scheduleMicrotask(() {
      if (mounted) {
        unawaited(ref.read(authViewModelProvider.notifier).initialize());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authViewModelProvider);
    final model = ref.read(authViewModelProvider.notifier);
    if (state.switchCount case final int count) {
      return Scaffold(
        body: SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: SwitchPartitionPrompt(
              count: count,
              onContinue: () {
                unawaited(model.confirmSwitch());
              },
              onCancel: model.cancelSwitch,
            ),
          ),
        ),
      );
    }
    return switch (state.page) {
      AuthPage.loading => const Material(
        child: PaperBackground(child: Center(child: JiabuLogo())),
      ),
      AuthPage.welcome => WelcomeScreen(
        busy: state.busy,
        onStart: model.startSetup,
        onLogin: () {
          unawaited(model.useDefaultServer());
        },
      ),
      AuthPage.server => ServerAddressScreen(
        state: state,
        onSelect: (server) {
          unawaited(model.selectServer(server));
        },
      ),
      AuthPage.login => LoginScreen(
        state: state,
        onLogin: (username, password) {
          unawaited(model.login(username, password));
        },
        onServer: () {
          unawaited(model.requestSwitch());
        },
      ),
      AuthPage.password => ChangePasswordScreen(
        state: state,
        onSave: (current, next, repeat) {
          unawaited(model.changePassword(current, next, repeat));
        },
        onBack: model.backFromPassword,
      ),
      AuthPage.session =>
        widget.signedInChild ??
            SessionStatusScreen(
              state: state,
              onPassword: model.showPassword,
              onSwitch: () {
                unawaited(model.requestSwitch());
              },
              onDismissNotice: () {
                unawaited(model.dismissNotice());
              },
              onLogout: () {
                unawaited(model.logout());
              },
            ),
    };
  }
}
