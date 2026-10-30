import 'package:flutter/material.dart';
import 'package:jiabu_design/src/components/hand_underline.dart';
import 'package:jiabu_design/src/components/jiabu_icon.dart';
import 'package:jiabu_design/src/components/tilt.dart';
import 'package:jiabu_design/src/icons/jiabu_icons.g.dart';
import 'package:jiabu_design/src/theme_context.dart';
import 'package:jiabu_design/src/tokens/spacing.dart';
import 'package:jiabu_design/src/tokens/type.dart';

/// The page title of the four main pages (chat, overview, history, settings):
/// a Serif title with the hand-drawn wavy underline, and under it a short
/// handwritten subtitle — an English Caveat accent (`Diary Log`, `Oct. 30 ·
/// Fri`) followed by the Kai-style Chinese line.
///
/// It only draws the title. The space badge and the "me" entry live in the
/// frame that hosts it (design-spec 4.0a).
class JiabuPageTitleBlock extends StatelessWidget {
  const JiabuPageTitleBlock({
    required this.title,
    this.handEnglish,
    this.subtitle,
    this.leading,
    this.showSubtitle = true,
    super.key,
  });

  final String title;

  /// The Caveat accent in front of [subtitle].
  final String? handEnglish;

  /// The Chinese (or, in the English UI, English) subtitle line.
  final String? subtitle;

  /// Optional round mark before the title (the chat page's home emblem).
  final Widget? leading;

  /// Draw the subtitle line. When false it is still part of the reading
  /// order (semantics), only not painted — used at very large text sizes.
  final bool showSubtitle;

  @override
  Widget build(BuildContext context) {
    final tokens = context.jiabu;
    final hasSubtitle =
        showSubtitle && (handEnglish != null || subtitle != null);
    final english = Localizations.localeOf(context).languageCode == 'en';
    final subtitleStyle = tokens.type.subtitle;
    final accentStyle = tokens.type.englishSubtitle.copyWith(
      color: tokens.colors.primaryText,
    );
    final lineHeight = subtitleStyle.height ?? 1.25;
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        HandUnderline(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tokens.type.pageTitle,
          ),
        ),
        if (hasSubtitle)
          Padding(
            padding: const EdgeInsets.only(top: JiabuSpacing.xs),
            child: Text.rich(
              TextSpan(
                children: [
                  if (handEnglish != null)
                    TextSpan(
                      text: handEnglish,
                      style: accentStyle.copyWith(
                        fontFamilyFallback: const [JiabuType.systemSansFamily],
                      ),
                    ),
                  if (handEnglish != null && subtitle != null)
                    const TextSpan(text: ' '),
                  if (subtitle != null)
                    TextSpan(
                      text: subtitle,
                      style: english
                          ? accentStyle.copyWith(
                              fontFamilyFallback: const [
                                JiabuType.systemSansFamily,
                              ],
                            )
                          : subtitleStyle.copyWith(
                              color: tokens.colors.ink2,
                              fontFamily: JiabuType.handFamily,
                              fontWeight: FontWeight.w500,
                              fontFamilyFallback: const [
                                JiabuType.systemSansFamily,
                              ],
                            ),
                    ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              locale: const Locale('zh', 'CN'),
              strutStyle: StrutStyle(
                fontFamily: JiabuType.handFamily,
                fontFamilyFallback: const [JiabuType.systemSansFamily],
                fontSize: subtitleStyle.fontSize,
                height: lineHeight,
                fontWeight: FontWeight.w500,
                forceStrutHeight: true,
              ),
            ),
          ),
      ],
    );
    return Semantics(
      container: true,
      header: true,
      label: [title, ?handEnglish, ?subtitle].join(', '),
      child: ExcludeSemantics(
        child: leading == null
            ? column
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  leading!,
                  const SizedBox(width: JiabuSpacing.md),
                  Flexible(child: column),
                ],
              ),
      ),
    );
  }
}

/// The round home emblem in front of the chat page title: a primary disc with
/// a hand-drawn house, white ring, tilted like a sticker.
class JiabuHomeMark extends StatelessWidget {
  const JiabuHomeMark({super.key});

  static const double size = 40;
  static const double ring = 2.5;
  static const double glyph = 20;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Tilt(
      degrees: context.jiabu.decor.logoTilt,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: context.jiabu.colors.primary,
          shape: BoxShape.circle,
          border: Border.all(color: context.jiabu.colors.white, width: ring),
          boxShadow: context.jiabu.decor.stickerShadow,
        ),
        child: JiabuIcon(
          JiabuIcons.doodleHome,
          size: glyph,
          color: context.jiabu.colors.onPrimary,
        ),
      ),
    ),
  );
}
