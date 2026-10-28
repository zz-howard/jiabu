const currencyDecimals = <String, int>{
  'CNY': 2,
  'HKD': 2,
  'USD': 2,
  'EUR': 2,
  'GBP': 2,
  'JPY': 0,
};

/// Parse a user amount without a floating-point round trip. Decimal separators
/// are supplied by the locale; grouping is intentionally not accepted in input.
int? parseMinor(
  String input,
  String currency, {
  String decimal = '.',
  bool signed = false,
}) {
  final digits = currencyDecimals[currency];
  if (digits == null) {
    return null;
  }
  final source = input.trim().replaceAll('−', '-');
  final parts = source.split(decimal);
  if (parts.length > 2 || (digits == 0 && parts.length != 1)) {
    return null;
  }
  final whole = parts.first;
  if (!RegExp(signed ? r'^-?\d+$' : r'^\d+$').hasMatch(whole)) {
    return null;
  }
  final fraction = parts.length == 2 ? parts.last : '';
  if (fraction.length > digits ||
      (parts.length == 2 &&
          (fraction.isEmpty || !RegExp(r'^\d+$').hasMatch(fraction)))) {
    return null;
  }
  final magnitude =
      BigInt.parse(whole.replaceFirst('-', '')) *
          BigInt.from(digits == 0 ? 1 : 100) +
      BigInt.parse(
        fraction.padRight(digits, '0').isEmpty
            ? '0'
            : fraction.padRight(digits, '0'),
      );
  if (magnitude > BigInt.from(1000000000000)) {
    return null;
  }
  return (whole.startsWith('-') ? -magnitude : magnitude).toInt();
}

String minorInput(int minor, String currency) {
  if (currencyDecimals[currency] == 0) {
    return minor.toString();
  }
  final magnitude = minor.abs();
  final whole = magnitude ~/ 100;
  final fraction = (magnitude % 100).toString().padLeft(2, '0');
  return '${minor < 0 ? '-' : ''}$whole.$fraction';
}
