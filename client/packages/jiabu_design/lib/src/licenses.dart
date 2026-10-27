import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

bool _registered = false;

void registerJiabuLicenses() {
  if (_registered) {
    return;
  }
  _registered = true;
  LicenseRegistry.addLicense(() async* {
    const names = {
      'OFL-Caveat.txt': 'Caveat',
      'OFL-LXGWWenKai.txt': 'JiabuHand · 基于 LXGW WenKai',
      'OFL-NotoSerifSC.txt': 'Noto Serif SC',
      'LUCIDE-LICENSE.txt': 'Lucide / Feather icons',
    };
    for (final entry in names.entries) {
      final text = await rootBundle.loadString(
        'packages/jiabu_design/assets/licenses/${entry.key}',
      );
      yield LicenseEntryWithLineBreaks([entry.value], text);
    }
  });
}
