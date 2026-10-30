import 'package:flutter/material.dart';
import 'package:jiabu/features/auth/widgets/auth_progress.dart';
import 'package:jiabu/l10n/generated/app_localizations.dart';
import 'package:jiabu_design/jiabu_design.dart';

class AuthFrame extends StatelessWidget {
  const AuthFrame({
    required this.title,
    required this.children,
    this.step,
    this.subtitle,
    this.footer,
    this.card = true,
    this.errorCode,
    this.busy = false,
    super.key,
  });
  final String title;
  final List<JiabuStackItem> children;
  final int? step;
  final Widget? subtitle;
  final Widget? footer;
  final bool card;
  final String? errorCode;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final content = JiabuStack(
      children: [
        ...children,
        if (errorCode != null)
          JiabuStackItem.captionAfter(
            child: Semantics(
              liveRegion: true,
              child: Text(
                authError(context, errorCode),
                textWidthBasis: TextWidthBasis.parent,
                style: context.jiabu.type.secondary.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          ),
      ],
    );
    return Scaffold(
      body: PaperBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: EdgeInsets.all(context.jiabu.spacing.page),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: SizedBox(
                        width: double.infinity,
                        child: JiabuStack(
                          children: [
                            if (step case final int value)
                              JiabuStackItem.content(
                                child: AuthProgress(step: value),
                              ),
                            JiabuStackItem.content(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    title,
                                    style: context.jiabu.type.pageTitle,
                                  ),
                                  const JiabuIcon(JiabuIcons.squig, size: 112),
                                ],
                              ),
                            ),
                            if (subtitle != null)
                              JiabuStackItem.captionAfter(child: subtitle!),
                            if (busy)
                              const JiabuStackItem.content(
                                child: LinearProgressIndicator(),
                              ),
                            JiabuStackItem.content(
                              child: card
                                  ? PaperCard(child: content)
                                  : SizedBox(
                                      width: double.infinity,
                                      child: content,
                                    ),
                            ),
                            if (footer != null)
                              JiabuStackItem.content(
                                child: SizedBox(
                                  width: double.infinity,
                                  child: footer,
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
      ),
    );
  }
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
