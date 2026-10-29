import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jiabu/features/auth/view_model/auth_ui_state.dart';
import 'package:jiabu/features/auth/widgets/auth_frame.dart';
import 'package:jiabu/features/auth/widgets/invite_signup_sheet.dart';
import 'package:jiabu/l10n/generated/app_localizations.dart';
import 'package:jiabu_design/jiabu_design.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    required this.state,
    required this.onLogin,
    required this.onServer,
    super.key,
  });

  final AuthUiState state;
  final void Function(String username, String password) onLogin;
  final VoidCallback onServer;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _username.dispose();
    _password
      ..clear()
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final chinese = Localizations.localeOf(context).languageCode == 'zh';
    final onDefault =
        widget.state.defaultServer.isNotEmpty &&
        widget.state.server == widget.state.defaultServer;
    return AuthFrame(
      title: l.authLoginTitle,
      step: 3,
      subtitle: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        children: [
          HandText(l.handAuthWelcomeHome),
          if (chinese) HandText(l.handAuthWelcomeHomeEnglish, english: true),
        ],
      ),
      busy: widget.state.busy,
      errorCode: widget.state.errorCode,
      card: false,
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              onDefault
                  ? l.authConnectedDefaultServer
                  : l.authConnectedServer(widget.state.server),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: context.jiabu.type.caption.copyWith(
                color: context.jiabu.colors.ink3,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: context.jiabu.colors.ink3,
                shape: BoxShape.circle,
              ),
              child: const SizedBox.square(dimension: 3),
            ),
          ),
          TextButton(
            key: const Key('change-server'),
            onPressed: widget.state.busy ? null : widget.onServer,
            child: Text(l.authChange),
          ),
        ],
      ),
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            PaperCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    key: const Key('username'),
                    controller: _username,
                    autocorrect: false,
                    decoration: InputDecoration(labelText: l.authUsername),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    key: const Key('password'),
                    controller: _password,
                    obscureText: _obscurePassword,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: l.authPassword,
                      suffixIcon: IconButton(
                        key: const Key('toggle-password'),
                        tooltip: _obscurePassword
                            ? l.authShowPassword
                            : l.authHidePassword,
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                        icon: const JiabuIcon(JiabuIcons.uiEye),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    key: const Key('login-submit'),
                    onPressed: widget.state.busy
                        ? null
                        : () {
                            final password = _password.text;
                            _password.clear();
                            widget.onLogin(_username.text, password);
                          },
                    child: Text(l.authLogin),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l.authForgotPassword,
                    textAlign: TextAlign.center,
                    style: context.jiabu.type.secondary.copyWith(
                      color: context.jiabu.colors.ink2,
                    ),
                  ),
                ],
              ),
            ),
            const Positioned(
              left: -10,
              top: -10,
              child: Tape(pattern: TapePattern.grid),
            ),
            if (widget.state.serverProbeSucceeded)
              Positioned(
                right: 14,
                top: -12,
                child: Stamp(
                  key: const Key('server-connected'),
                  label: l.authConnected,
                  state: StampState.recorded,
                ),
              ),
          ],
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(child: Divider(color: context.jiabu.colors.lineStrong)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                l.authNoAccount,
                style: context.jiabu.type.secondary.copyWith(
                  color: context.jiabu.colors.ink3,
                ),
              ),
            ),
            Expanded(child: Divider(color: context.jiabu.colors.lineStrong)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const JiabuMascot(pose: JiabuMascotPose.pen, size: 74),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton(
                    key: const Key('invite-signup'),
                    onPressed: widget.state.busy
                        ? null
                        : () {
                            unawaited(showInviteSignupSheet(context));
                          },
                    child: Text(l.authJoinFamily),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l.authInviteHint,
                    textAlign: TextAlign.center,
                    style: context.jiabu.type.caption.copyWith(
                      color: context.jiabu.colors.ink3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
