import 'package:flutter/widgets.dart';
import 'package:jiabu_design/src/components/hand_text.dart';
import 'package:jiabu_design/src/components/jiabu_icon.dart';
import 'package:jiabu_design/src/components/tape.dart';
import 'package:jiabu_design/src/components/tilt.dart';
import 'package:jiabu_design/src/icons/jiabu_icons.g.dart';
import 'package:jiabu_design/src/theme_context.dart';

class Polaroid extends StatelessWidget {
  const new({
    required this.image,
    required this.caption,
    this.degrees = -2,
    this.onTap,
    super.key,
  }) : assert(
         degrees == -2 || degrees == 2,
         'Polaroid tilt is -2 or 2 degrees',
       );

  final Widget image;
  final String caption;
  final double degrees;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final d = context.jiabu.decor;
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return GestureDetector(
      onTap: onTap,
      child: Tilt(
        degrees: degrees,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Container(
              padding: EdgeInsets.only(
                left: d.photoBorder,
                top: d.photoBorder,
                right: d.photoBorder,
              ),
              decoration: BoxDecoration(
                color: context.jiabu.colors.white,
                borderRadius: BorderRadius.circular(d.photoRadius),
                boxShadow: d.cardShadow,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  image,
                  ConstrainedBox(
                    key: const Key('polaroid-caption'),
                    constraints: BoxConstraints(minHeight: d.photoBottom),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: scale <= 1 ? 0 : 6,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const JiabuIcon(JiabuIcons.uiCheck, size: 14),
                          const SizedBox(width: 4),
                          Flexible(child: HandText(caption)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Positioned(
              top: -10,
              child: Tape(pattern: TapePattern.dots, degrees: -2.5),
            ),
          ],
        ),
      ),
    );
  }
}
