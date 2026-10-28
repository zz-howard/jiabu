import 'package:flutter/material.dart';
import 'package:jiabu/l10n/generated/app_localizations.dart';
import 'package:jiabu_design/jiabu_design.dart';

class AuthFrame extends StatelessWidget {
  const AuthFrame({
    required this.title,
    required this.children,
    this.errorCode,
    this.busy = false,
    super.key,
  });
  final String title;
  final List<Widget> children;
  final String? errorCode;
  final bool busy;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(context.jiabu.decor.cardInset),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: SizedBox(
                  width: double.infinity,
                  child: PaperCard(
                    child: Column(
                      spacing: context.jiabu.decor.cardGap,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        if (busy) const LinearProgressIndicator(),
                        ...children,
                        if (errorCode != null)
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              authError(context, errorCode),
                              textWidthBasis: TextWidthBasis.parent,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

String authError(BuildContext context, String? code) {
  final l10n = AppLocalizations.of(context);
  return switch (code) {
    'invalid_server_address' => l10n.authInvalidAddress,
    'credentials_required' => l10n.authCredentialsRequired,
    'unauthenticated' => l10n.authInvalidCredentials,
    'rate_limited' => l10n.authRateLimited,
    'invalid_new_password' => l10n.authPasswordValidation,
    'network' => l10n.authOffline,
    'account_disabled' => l10n.authAccountDisabled,
    'session_expired' => l10n.authSessionExpired,
    'client_too_old' => l10n.authClientTooOld,
    'server_too_old' => l10n.authServerTooOld,
    _ => l10n.authRequestFailed,
  };
}
