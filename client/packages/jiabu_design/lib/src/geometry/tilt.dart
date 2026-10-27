double tiltFor(String id, {double amp = 1}) {
  var hash = 7;
  for (final code in id.codeUnits) {
    hash = (hash * 31 + code) % 997;
  }
  return ((hash % 5) - 2) * .45 * amp;
}
