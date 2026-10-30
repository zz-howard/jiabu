/// Lets `**bold**` work when it touches CJK punctuation.
///
/// CommonMark only lets a `*` run open or close emphasis when it is
/// "flanking": a run with punctuation on its inner side must have whitespace
/// or punctuation on its outer side. Chinese has no spaces, so model replies
/// like `**记账：**后面` or `点**「编辑」**修改` showed the asterisks raw
/// (the `**记` in the 2026-10-30 audit). Putting a zero-width space between
/// such a run and the punctuation makes it flanking without changing what is
/// shown. Code spans and fenced code are left byte-for-byte.
String cjkEmphasis(String source) {
  if (!source.contains('*')) return source;
  final output = StringBuffer();
  var fenced = false;
  final lines = source.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (i > 0) output.write('\n');
    if (RegExp(r'^\s*(```|~~~)').hasMatch(line)) {
      fenced = !fenced;
      output.write(line);
    } else if (fenced) {
      output.write(line);
    } else {
      output.write(_line(line));
    }
  }
  return output.toString();
}

const _zeroWidthSpace = '​';
final _punctuation = RegExp(r'[\p{P}\p{S}]', unicode: true);
final _space = RegExp(r'\s');

bool _isPunctuation(String? char) =>
    char != null && char != '*' && _punctuation.hasMatch(char);
bool _isWord(String? char) =>
    char != null &&
    char != _zeroWidthSpace &&
    !_space.hasMatch(char) &&
    !_punctuation.hasMatch(char);

String _line(String line) {
  final output = StringBuffer();
  var offset = 0;
  // Code spans pass through untouched.
  for (final code in RegExp(r'(`+)(.*?)\1').allMatches(line)) {
    output
      ..write(_text(line.substring(offset, code.start)))
      ..write(code[0]);
    offset = code.end;
  }
  return (output..write(_text(line.substring(offset)))).toString();
}

String _text(String text) {
  final chars = text.split('');
  final output = StringBuffer();
  var i = 0;
  while (i < chars.length) {
    if (chars[i] != '*' || (i > 0 && chars[i - 1] == r'\')) {
      output.write(chars[i]);
      i++;
      continue;
    }
    var end = i;
    while (end < chars.length && chars[end] == '*') {
      end++;
    }
    final before = i > 0 ? chars[i - 1] : null;
    final after = end < chars.length ? chars[end] : null;
    // A closing run after punctuation, directly followed by text.
    if (_isPunctuation(before) && _isWord(after)) {
      output.write(_zeroWidthSpace);
    }
    output.write(chars.sublist(i, end).join());
    // An opening run before punctuation, directly after text.
    if (_isPunctuation(after) && _isWord(before)) {
      output.write(_zeroWidthSpace);
    }
    i = end;
  }
  return output.toString();
}
