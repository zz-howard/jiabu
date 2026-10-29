import 'package:flutter/widgets.dart';
import 'package:jiabu_design/src/components/tilt.dart';
import 'package:jiabu_design/src/theme_context.dart';

enum JiabuLogoVariant { standard, dark }

class JiabuLogo extends StatelessWidget {
  const JiabuLogo({
    this.size = 88,
    this.variant = JiabuLogoVariant.standard,
    this.degrees,
    this.semanticLabel = '家簿',
    super.key,
  });

  final double size;
  final JiabuLogoVariant variant;
  final double? degrees;
  final String semanticLabel;

  String get assetName => switch (variant) {
    JiabuLogoVariant.standard =>
      'packages/jiabu_design/assets/brand/logo-standard.png',
    JiabuLogoVariant.dark =>
      'packages/jiabu_design/assets/brand/logo-dark-disc.png',
  };

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: semanticLabel,
    child: ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: Tilt(
          degrees: degrees ?? context.jiabu.decor.logoTilt,
          child: Image.asset(assetName, fit: BoxFit.contain),
        ),
      ),
    ),
  );
}
