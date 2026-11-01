import 'package:drift/drift.dart';

/// Upgrade steps are written to run again safely: on a schema they already
/// reached (a downgrade and re-upgrade) or after an interrupted attempt.
Future<bool> hasColumn(
  GeneratedDatabase db,
  String table,
  String column,
) async => (await db.customSelect('PRAGMA table_info($table)').get()).any(
  (row) => row.data['name'] == column,
);

/// `ALTER TABLE ... ADD COLUMN` unless [table] already has [column].
Future<void> addColumn(
  GeneratedDatabase db,
  String table,
  String column,
  String definition,
) async {
  if (!await hasColumn(db, table, column)) {
    await db.customStatement(
      'ALTER TABLE $table ADD COLUMN $column $definition',
    );
  }
}
