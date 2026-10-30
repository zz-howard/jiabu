import 'package:flutter/material.dart';
import 'package:jiabu/l10n/generated/app_localizations.dart';
import 'package:jiabu_design/jiabu_design.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({
    required this.busy,
    required this.onStart,
    required this.onLogin,
    super.key,
  });

  final bool busy;
  final VoidCallback onStart;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 400;
    final logoSize = wide ? 212.0 : 184.0;
    final mascotSize = wide ? 132.0 : 112.0;
    final chinese = Localizations.localeOf(context).languageCode == 'zh';
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
                      child: JiabuStack(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          JiabuStackItem.content(
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                JiabuLogo(size: logoSize),
                                const Positioned(
                                  left: -24,
                                  top: 8,
                                  child: Tape(
                                    pattern: TapePattern.dots,
                                    degrees: -32,
                                    width: 64,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          JiabuStackItem.content(
                            child: HandText(
                              l.handAuthWelcomeTagline,
                              textAlign: TextAlign.center,
                              style: context.jiabu.type.subtitle.copyWith(
                                fontSize: wide ? 22 : 20,
                                letterSpacing: 2.4,
                              ),
                            ),
                          ),
                          if (chinese)
                            JiabuStackItem.caption(
                              child: HandText(
                                l.handAuthBrandEnglish,
                                english: true,
                                textAlign: TextAlign.center,
                                style: context.jiabu.type.englishSubtitle
                                    .copyWith(fontSize: 18),
                              ),
                            ),
                          JiabuStackItem.content(
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.end,
                              spacing: 6,
                              runSpacing: 12,
                              children: [
                                JiabuMascot(
                                  pose: JiabuMascotPose.greet,
                                  size: mascotSize,
                                ),
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: wide ? 220 : 190,
                                  ),
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      NoteBubble(
                                        id: 'auth-welcome',
                                        child: HandText(
                                          l.handAuthWelcomeGreeting,
                                          style: context.jiabu.type.subtitle
                                              .copyWith(
                                                fontSize: wide ? 17 : 16,
                                              ),
                                        ),
                                      ),
                                      const Positioned(
                                        top: -10,
                                        left: 56,
                                        child: Tape(width: 60, degrees: 3),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          JiabuStackItem.action(
                            child: SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: busy ? null : onStart,
                                child: Text(l.authWelcomeStart),
                              ),
                            ),
                          ),
                          JiabuStackItem.action(
                            child: TextButton(
                              onPressed: busy ? null : onLogin,
                              child: Text.rich(
                                TextSpan(
                                  text: '${l.authWelcomeExisting} ',
                                  children: [
                                    TextSpan(
                                      text: l.authWelcomeDirectLogin,
                                      style: context.jiabu.type.secondary
                                          .copyWith(
                                            color: context
                                                .jiabu
                                                .colors
                                                .primaryText,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ],
                                ),
                                style: context.jiabu.type.secondary.copyWith(
                                  color: context.jiabu.colors.ink2,
                                ),
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
}
