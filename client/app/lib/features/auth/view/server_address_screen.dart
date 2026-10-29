import 'package:flutter/material.dart';
import 'package:jiabu/features/auth/view_model/auth_ui_state.dart';
import 'package:jiabu/features/auth/widgets/auth_frame.dart';
import 'package:jiabu/l10n/generated/app_localizations.dart';
import 'package:jiabu_design/jiabu_design.dart';

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
    text: widget.state.server.isNotEmpty
        ? widget.state.server
        : widget.state.defaultServer,
  );
  late bool _advanced = widget.state.defaultServer.isEmpty;
  String? _localErrorCode;

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  void _restoreDefault() {
    _address.text = widget.state.defaultServer;
    _address.selection = TextSelection.collapsed(offset: _address.text.length);
    setState(() => _localErrorCode = null);
  }

  void _submit() {
    final value = hasDefault && !_advanced
        ? widget.state.defaultServer
        : _address.text;
    final trimmed = value.trim();
    final uri = Uri.tryParse(trimmed);
    if (!trimmed.toLowerCase().startsWith('https://') ||
        uri == null ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      setState(() => _localErrorCode = 'invalid_server_address');
      return;
    }
    setState(() => _localErrorCode = null);
    widget.onSelect(value);
  }

  bool get hasDefault => widget.state.defaultServer.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AuthFrame(
      title: l.authServerTitle,
      step: 2,
      subtitle: HandText(l.handAuthServerHint),
      busy: widget.state.busy,
      errorCode: _localErrorCode ?? widget.state.errorCode,
      card: false,
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton(
            key: const Key('server-continue'),
            onPressed: widget.state.busy ? null : _submit,
            child: Text(l.authContinue),
          ),
          const SizedBox(height: JiabuSpacing.sm),
          Text(
            l.authServerLaterHint,
            textAlign: TextAlign.center,
            style: context.jiabu.type.caption.copyWith(
              color: context.jiabu.colors.ink3,
            ),
          ),
        ],
      ),
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            PaperCard(
              padding: const EdgeInsets.all(JiabuSpacing.cardInset),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Sticker(category: 'home'),
                      const SizedBox(width: JiabuSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _advanced
                                  ? l.authCustomServerTitle
                                  : l.authUseDefaultServer,
                              style: context.jiabu.type.listTitle,
                            ),
                            Text(
                              _advanced
                                  ? l.authCustomServerDescription
                                  : l.authDefaultServerDescription,
                              style: context.jiabu.type.secondary.copyWith(
                                color: context.jiabu.colors.ink2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (hasDefault) ...[
                    const SizedBox(height: JiabuSpacing.gap14),
                    Divider(color: context.jiabu.colors.lineStrong),
                    TextButton(
                      key: const Key('advanced-settings'),
                      onPressed: widget.state.busy
                          ? null
                          : () => setState(() => _advanced = !_advanced),
                      child: Row(
                        children: [
                          Expanded(child: Text(l.authAdvancedSettings)),
                          Tilt(
                            degrees: _advanced ? 180 : 0,
                            child: const JiabuIcon(JiabuIcons.uiDown, size: 16),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_advanced) ...[
                    const SizedBox(height: JiabuSpacing.xs),
                    TextField(
                      key: const Key('server-address'),
                      controller: _address,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        labelText: l.authServerAddress,
                        helperText: l.authHttpsHint,
                      ),
                    ),
                    const SizedBox(height: JiabuSpacing.sm),
                    Text(
                      l.authServerSelfHostedHint,
                      style: context.jiabu.type.caption.copyWith(
                        color: context.jiabu.colors.ink3,
                      ),
                    ),
                    if (hasDefault)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          key: const Key('restore-default'),
                          onPressed: widget.state.busy ? null : _restoreDefault,
                          child: Text(l.authRestoreDefault),
                        ),
                      ),
                  ],
                ],
              ),
            ),
            const Positioned(left: -10, top: -10, child: Tape()),
            const Positioned(
              right: 4,
              top: -70,
              child: JiabuMascot(pose: JiabuMascotPose.idle, size: 84),
            ),
          ],
        ),
      ],
    );
  }
}
