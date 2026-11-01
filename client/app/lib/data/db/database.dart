import 'package:drift/drift.dart';
import 'package:jiabu/data/db/migrations/chat_v2.dart';
import 'package:jiabu/data/db/migrations/chat_v3.dart';

part 'database.g.dart';

@DriftDatabase(include: {'schema.drift'})
class JiabuDatabase extends _$JiabuDatabase {
  JiabuDatabase(super.e);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await customStatement('INSERT INTO sync_runtime (id) VALUES (1)');
    },
    onUpgrade: (migrator, from, to) async {
      if (from < 2 && to >= 2) await migrateChatV2(this);
      if (from < 3 && to >= 3) await migrateChatV3(this);
    },
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await customStatement('PRAGMA busy_timeout = 5000');
    },
  );
}
