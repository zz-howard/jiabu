import 'dart:io';

import 'package:drift/native.dart';
import 'package:jiabu/data/db/daos/local_store.dart';
import 'package:jiabu/data/db/database.dart';
import 'package:jiabu/domain/partition.dart';
import 'package:path/path.dart' as p;

final class PartitionDatabase {
  PartitionDatabase(this.partition, this.database, this.directory)
    : store = LocalStore(database);
  final Partition partition;
  final JiabuDatabase database;
  final LocalStore store;
  final Directory directory;
  Directory get blobs => Directory(p.join(directory.path, 'blobs'));
}

final class DatabaseManager {
  DatabaseManager(this.root);
  final Directory root;
  final _opened = <String, PartitionDatabase>{};

  Future<PartitionDatabase> open(Partition partition) async {
    final previous = _opened[partition.prefix];
    if (previous != null) {
      return previous;
    }
    await root.create(recursive: true);
    final directory = await Directory(
      p.join(root.path, partition.directoryName),
    ).create(recursive: true);
    await Directory(p.join(directory.path, 'blobs')).create(recursive: true);
    final database = JiabuDatabase(
      NativeDatabase.createInBackground(
        File(p.join(root.path, partition.databaseName)),
      ),
    );
    final opened = PartitionDatabase(partition, database, directory);
    // Force migration before another isolate can start a round.
    await opened.store.runtime();
    _opened[partition.prefix] = opened;
    return opened;
  }

  Future<int> pendingCount(PartitionDatabase handle) async {
    var total = 0;
    for (final spaceId in await handle.store.spaceIds()) {
      total += (await handle.store.outbox(spaceId)).length;
    }
    return total;
  }

  Future<void> close() async {
    for (final handle in _opened.values) {
      await handle.database.close();
    }
    _opened.clear();
  }
}
