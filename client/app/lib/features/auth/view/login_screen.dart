import 'package:flutter/material.dart';
import 'package:jiabu/features/auth/view_model/auth_ui_state.dart';
import 'package:jiabu/features/auth/widgets/auth_frame.dart';
import 'package:jiabu/l10n/generated/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context);
    return AuthFrame(
      title: l10n.authLoginTitle,
      busy: widget.state.busy,
      errorCode: widget.state.errorCode,
      children: [
        Text(widget.state.server),
        TextField(
          key: const Key('username'),
          controller: _username,
          autocorrect: false,
          decoration: InputDecoration(labelText: l10n.authUsername),
        ),
        TextField(
          key: const Key('password'),
          controller: _password,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(labelText: l10n.authPassword),
        ),
        FilledButton(
          onPressed: widget.state.busy
              ? null
              : () {
                  final password = _password.text;
                  _password.clear();
                  widget.onLogin(_username.text, password);
                },
          child: Text(l10n.authLogin),
        ),
        TextButton(
          onPressed: widget.state.busy ? null : widget.onServer,
          child: Text(l10n.authChangeServer),
        ),
      ],
    );
  }
}
