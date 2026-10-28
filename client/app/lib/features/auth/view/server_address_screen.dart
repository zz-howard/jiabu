import 'package:flutter/material.dart';
import 'package:jiabu/features/auth/view_model/auth_ui_state.dart';
import 'package:jiabu/features/auth/widgets/auth_frame.dart';
import 'package:jiabu/l10n/generated/app_localizations.dart';

class ServerAddressScreen extends StatefulWidget {
  const ServerAddressScreen({
    required this.state,
    required this.onSelect,
    super.key,
  });
  final AuthUiState state;
  final ValueChanged<String> onSelect;
  @override
  State<ServerAddressScreen> createState() => _ServerAddressScreenState();
}

class _ServerAddressScreenState extends State<ServerAddressScreen> {
  late final TextEditingController _address = TextEditingController(
    text: widget.state.server,
  );
  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AuthFrame(
      title: l10n.authServerTitle,
      busy: widget.state.busy,
      errorCode: widget.state.errorCode,
      children: [
        for (final server in widget.state.servers)
          TextButton(
            onPressed: widget.state.busy ? null : () => widget.onSelect(server),
            child: Text(server, overflow: TextOverflow.visible),
          ),
        TextField(
          key: const Key('server-address'),
          controller: _address,
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: InputDecoration(labelText: l10n.authServerAddress),
        ),
        FilledButton(
          onPressed: widget.state.busy
              ? null
              : () => widget.onSelect(_address.text),
          child: Text(l10n.authContinue),
        ),
      ],
    );
  }
}
