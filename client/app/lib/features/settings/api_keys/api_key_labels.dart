import 'package:intl/intl.dart';
import 'package:jiabu/l10n/generated/app_localizations.dart';

String keyTime(AppLocalizations l, Object? value, String fallback) {
  final date = value is String ? DateTime.tryParse(value) : null;
  return date == null
      ? fallback
      : DateFormat.yMd(l.localeName).add_Hm().format(date.toLocal());
}
