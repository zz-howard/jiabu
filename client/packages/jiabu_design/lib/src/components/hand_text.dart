import 'package:flutter/widgets.dart';

import 'package:jiabu_design/src/theme_context.dart';
import 'package:jiabu_design/src/tokens/type.dart';

class HandText extends StatelessWidget {
  const new(this.text, {this.style, this.english, this.textAlign, super.key});

  final String text;
  final TextStyle? style;
  final bool? english;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final useEnglish =
        english ?? Localizations.localeOf(context).languageCode == 'en';
    final base =
        (useEnglish
                ? context.jiabu.type.englishSubtitle
                : context.jiabu.type.subtitle)
            .merge(style);
    final size = base.fontSize ?? 14;
    final height = base.height ?? 1.25;
    final fallback = useEnglish
        ? const [JiabuType.systemSansFamily]
        : const [JiabuType.handFamily, JiabuType.systemSansFamily];
    return Text(
      text,
      locale: const Locale('zh', 'CN'),
      textAlign: textAlign,
      style: base.copyWith(
        fontFamily: JiabuType.numeralsFamily,
        fontFamilyFallback: fallback,
        fontWeight: FontWeight.w600,
      ),
      strutStyle: StrutStyle(
        fontFamily: useEnglish
            ? JiabuType.numeralsFamily
            : JiabuType.handFamily,
        fontFamilyFallback: const [JiabuType.systemSansFamily],
        fontSize: size,
        height: height,
        fontWeight: useEnglish ? FontWeight.w600 : FontWeight.w500,
        forceStrutHeight: true,
      ),
    );
  }
}
