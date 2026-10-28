import 'dart:convert';

/// Only user changes relative to the opened/refreshed baseline go on the wire.
Map<String, Object?> changedRecordFields(
  Map<String, Object?> values,
  Map<String, Object?> baseline,
) => {
  for (final entry in values.entries)
    if (jsonEncode(entry.value) != jsonEncode(baseline[entry.key]))
      entry.key: entry.value,
};
