// Build-host prerequisite (do not hand-write either generated output):
// dart run drift_dev schema dump lib/data/db/database.dart test/drift_schemas
// Generate helpers with drift_dev schema generate:
// input test/drift_schemas, output test/generated_migrations.
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/data/db/database.dart';

import '../generated_migrations/schema.dart';

void main() {
  test('drift_schema_verifier_validates_v1_snapshot', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(1);
    final database = JiabuDatabase(schema.newConnection());
    addTearDown(database.close);
    await verifier.migrateAndValidate(database, 1);
  });
}
