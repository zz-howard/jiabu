import 'package:flutter/painting.dart';

import 'package:jiabu_design/src/tokens/decor.dart';

enum PaperElevation { sticker, tile, card, hero, sheet }

List<BoxShadow> paperShadows(JiabuDecor decor, PaperElevation elevation) =>
    switch (elevation) {
      PaperElevation.sticker => decor.stickerShadow,
      PaperElevation.tile => decor.tileShadow,
      PaperElevation.card => decor.cardShadow,
      PaperElevation.hero => decor.heroShadow,
      PaperElevation.sheet => decor.sheetShadow,
    };
