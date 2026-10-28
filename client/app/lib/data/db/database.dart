import 'package:drift/drift.dart';

part 'database.g.dart';

@DriftDatabase(include: {'schema.drift'})
class JiabuDatabase extends _$JiabuDatabase {
  JiabuDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await customStatement('INSERT INTO sync_runtime (id) VALUES (1)');
    },
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await customStatement('PRAGMA busy_timeout = 5000');
    },
  );
}
