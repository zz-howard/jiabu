import 'package:flutter/material.dart';
import 'package:jiabu/features/auth/view_model/auth_ui_state.dart';
import 'package:jiabu/features/auth/widgets/auth_frame.dart';
import 'package:jiabu/l10n/generated/app_localizations.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({
    required this.state,
    required this.onSave,
    required this.onBack,
    super.key,
  });
  final AuthUiState state;
  final void Function(String current, String next, String repeated) onSave;
  final VoidCallback onBack;
  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _repeat = TextEditingController();
  @override
  void dispose() {
    for (final controller in [_current, _next, _repeat]) {
      controller
        ..clear()
        ..dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !widget.state.busy) {
          widget.onBack();
        }
      },
      child: AuthFrame(
        title: l10n.authChangePassword,
        busy: widget.state.busy,
        errorCode: widget.state.errorCode,
        children: [
          if (widget.state.forcedPassword) Text(l10n.authTemporaryPassword),
          for (final field in [
            (_current, l10n.authCurrentPassword, 'current-password'),
            (_next, l10n.authNewPassword, 'new-password'),
            (_repeat, l10n.authRepeatPassword, 'repeat-password'),
          ])
            TextField(
              key: Key(field.$3),
              controller: field.$1,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(labelText: field.$2),
            ),
          FilledButton(
            onPressed: widget.state.busy
                ? null
                : () {
                    final values = [_current.text, _next.text, _repeat.text];
                    for (final controller in [_current, _next, _repeat]) {
                      controller.clear();
                    }
                    widget.onSave(values[0], values[1], values[2]);
                  },
            child: Text(l10n.authSavePassword),
          ),
          TextButton(
            onPressed: widget.state.busy ? null : widget.onBack,
            child: Text(
              widget.state.forcedPassword ? l10n.authLogout : l10n.authBack,
            ),
          ),
        ],
      ),
    );
  }
}
