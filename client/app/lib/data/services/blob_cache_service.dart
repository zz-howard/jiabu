import 'dart:io';

import 'package:jiabu/data/db/daos/local_store.dart';
import 'package:jiabu/data/sync/sync_policy.dart';
import 'package:jiabu/domain/entity_ref.dart';
import 'package:jiabu/domain/required_value.dart';
import 'package:path/path.dart' as p;

final class BlobCacheService {
  BlobCacheService(this.store, this.directory);
  final LocalStore store;
  final Directory directory;

  Future<void> cleanPending() => store.transaction(() async {
    await store.lockFilesystem();
    // Serialize the short check+delete with imports in both isolates. Never
    // delete a physical hash file still referenced by another active space.
    for (final path in await store.deletions()) {
      final root = p.normalize(p.absolute(directory.path));
      final target = p.normalize(p.absolute(path));
      if (!p.isWithin(root, target)) {
        throw const FileSystemException('invalid_cache_path');
      }
      var referenced = false;
      for (final spaceId in await store.spaceIds()) {
        if (await store.hasBlobPath(spaceId, target)) {
          referenced = true;
        }
      }
      if (!referenced) {
        final file = File(target);
        if (file.existsSync()) {
          await file.delete();
        }
      }
      await store.finishDeletion(path);
    }
    // Recover a crash after the JPEG rename but before the database commit.
    if (directory.existsSync()) {
      await for (final entry in directory.list(followLinks: false)) {
        if (entry is! File || !entry.path.endsWith('.jpg')) {
          continue;
        }
        var referenced = false;
        for (final spaceId in await store.spaceIds()) {
          if (await store.hasBlobPath(spaceId, p.absolute(entry.path))) {
            referenced = true;
          }
        }
        if (!referenced) {
          await entry.delete();
        }
      }
    }
  });

  Future<void> expireUploaded(DateTime now) async {
    final cutoff = now
        .subtract(SyncPolicy.originalRetention)
        .millisecondsSinceEpoch;
    await store.transaction(() async {
      for (final spaceId in await store.spaceIds()) {
        final queue = await store.outbox(spaceId);
        for (final blob in await store.blobs(spaceId)) {
          final module = requireValue<String>(blob['module']);
          final hash = requireValue<String>(blob['sha256']);
          // A failed/blocked edit may still need this upload receipt later.
          if (queue.any(
            (op) => op.references.contains(EntityRef.blob(module, hash)),
          )) {
            continue;
          }
          if (blob['uploaded'] == 1 &&
              ((blob['uploaded_at'] as int?) ?? cutoff + 1) <= cutoff) {
            await store.expireBlob(spaceId, module, hash);
          }
        }
      }
    });
    await cleanPending();
  }
}
