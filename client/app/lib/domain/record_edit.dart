import 'dart:convert';

import 'package:jiabu/domain/ledger.dart';

/// Only user changes relative to the opened/refreshed baseline go on the wire.
Map<String, Object?> changedRecordFields(
  Map<String, Object?> values,
  Map<String, Object?> baseline,
) => {
  for (final entry in values.entries)
    if (jsonEncode(entry.value) != jsonEncode(baseline[entry.key]))
      entry.key: entry.value,
};

bool recordEditIsStale(
  LedgerRow latest,
  int openedVersion,
  Map<String, Object?> baseline,
) =>
    latest.number('version') != openedVersion ||
    changedRecordFields(latest.data, baseline).isNotEmpty;
