import 'package:flutter/widgets.dart';

enum JiabuMascotPose { greet, pen, idle }

class JiabuMascot extends StatelessWidget {
  const JiabuMascot({
    required this.pose,
    this.size = 112,
    this.semanticLabel,
    super.key,
  });

  final JiabuMascotPose pose;
  final double size;
  final String? semanticLabel;

  String get assetName =>
      'packages/jiabu_design/assets/brand/mascot/'
      'hamster-${pose.name}.png';

  @override
  Widget build(BuildContext context) {
    final image = SizedBox.square(
      dimension: size,
      child: Image.asset(assetName, fit: BoxFit.contain),
    );
    final label = semanticLabel;
    return label == null
        ? ExcludeSemantics(child: image)
        : Semantics(
            image: true,
            label: label,
            child: ExcludeSemantics(child: image),
          );
  }
}
