/// Calendar parity with domain/src/allocation.rs. Today is explicitly supplied
/// in the SPACE timezone; this function never converts the phone timezone.
DateTime dueInMonth(int year, int month, int day) {
  if (day < 1 || day > 31) {
    throw ArgumentError.value(day);
  }
  final last = DateTime.utc(year, month + 1, 0).day;
  return DateTime.utc(year, month, day > last ? last : day);
}

DateTime nextAllocation(
  DateTime today,
  int day, {
  String? lastMonth,
  bool continuing = false,
}) {
  var due = dueInMonth(today.year, today.month, day);
  String month(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}';
  if (continuing) {
    if (lastMonth == month(today)) {
      due = dueInMonth(today.year, today.month + 1, day);
    }
  } else {
    if (!due.isAfter(today) || lastMonth == month(due)) {
      due = dueInMonth(due.year, due.month + 1, day);
    }
    if (lastMonth == month(due)) {
      due = dueInMonth(due.year, due.month + 1, day);
    }
  }
  return due;
}
