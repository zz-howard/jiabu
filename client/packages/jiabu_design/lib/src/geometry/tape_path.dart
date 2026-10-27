import 'package:flutter/painting.dart';

Path tapePath(Size size) => Path()
  ..moveTo(0, 0)
  ..lineTo(size.width, 0)
  ..lineTo(size.width * .96, size.height * .22)
  ..lineTo(size.width, size.height * .44)
  ..lineTo(size.width * .96, size.height * .66)
  ..lineTo(size.width, size.height * .84)
  ..lineTo(size.width * .97, size.height)
  ..lineTo(0, size.height)
  ..lineTo(size.width * .035, size.height * .8)
  ..lineTo(0, size.height * .6)
  ..lineTo(size.width * .04, size.height * .4)
  ..lineTo(0, size.height * .2)
  ..close();
