import 'package:jiabu/domain/ledger.dart';

enum RecordDisplay {
  denied,
  loading,
  conflict,
  voided,
  failed,
  pending,
  changed,
  recorded,
}

RecordDisplay recordDisplay({
  required bool allowed,
  required LedgerRow? row,
  bool failed = false,
  int? versionAtReply,
}) {
  if (!allowed) {
    return RecordDisplay.denied;
  }
  if (row == null) {
    return RecordDisplay.loading;
  }
  if (row.syncState == 'conflict') {
    return RecordDisplay.conflict;
  }
  if (!row.active) {
    return RecordDisplay.voided;
  }
  if (failed) {
    return RecordDisplay.failed;
  }
  if (row.syncState == 'pending') {
    return RecordDisplay.pending;
  }
  if (versionAtReply != null && row.number('version') > versionAtReply) {
    return RecordDisplay.changed;
  }
  return RecordDisplay.recorded;
}
