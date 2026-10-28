import 'package:jiabu/data/api/api_client.dart';
import 'package:jiabu/data/api/dto/meta_dto.dart';
import 'package:jiabu/data/sync/sync_policy.dart';
import 'package:jiabu/domain/sync_state.dart';

final class MetaCache {
  const MetaCache(this.meta, this.at);
  final MetaDto meta;
  final DateTime at;
}

final class VersionHandshakeService {
  VersionHandshakeService(
    this.api, {
    this.build = 1,
    this.channel = 'beta',
    DateTime Function()? now,
    this.readCache,
    this.writeCache,
    this.clearCache,
  }) : now = now ?? DateTime.now;
  final ApiClient api;
  final int build;
  final String channel;
  final DateTime Function() now;
  final Future<MetaCache?> Function()? readCache;
  final Future<void> Function(MetaCache)? writeCache;
  final Future<void> Function()? clearCache;
  MetaCache? _cached;
  bool _invalidated = false;
  bool _refreshing = false;
  int forcedGeneration = 0;
  SyncStatus lastForcedStatus = SyncStatus.clientTooOld;

  void invalidate() {
    _cached = null;
    _invalidated = true;
  }

  Future<SyncStatus> check({bool force = false}) async {
    // Check shared persistence when present: another isolate may have received
    // 426 and invalidated a cache that is still in this isolate's memory.
    var cached = _invalidated
        ? null
        : readCache != null
        ? await readCache?.call()
        : _cached;
    final age = cached == null ? null : now().difference(cached.at);
    if (force ||
        cached == null ||
        age == null ||
        age.isNegative ||
        age >= SyncPolicy.metaTtl) {
      cached = MetaCache(await api.meta(), now());
      _cached = cached;
      _invalidated = false;
      await writeCache?.call(cached);
    }
    final meta = cached.meta;
    if (!meta.apiVersions.contains(1) ||
        !_atLeast(meta.serverVersion, [0, 1, 0])) {
      return SyncStatus.serverTooOld;
    }
    if (build < (meta.minClientBuild[channel] ?? 0)) {
      return SyncStatus.clientTooOld;
    }
    return SyncStatus.idle;
  }

  /// Called by the 426 interceptor; refresh only /meta, never retry the write.
  Future<SyncStatus?> on426() async {
    invalidate();
    await clearCache?.call();
    if (_refreshing) {
      return null;
    }
    _refreshing = true;
    forcedGeneration++;
    lastForcedStatus = SyncStatus.clientTooOld;
    try {
      final result = await check(force: true);
      lastForcedStatus = result == SyncStatus.idle
          ? SyncStatus.clientTooOld
          : result;
      return result;
    } finally {
      _refreshing = false;
    }
  }

  bool _atLeast(String version, List<int> minimum) {
    final match = RegExp(r'^(\d+)\.(\d+)\.(\d+)(?:[-+].*)?$')
        .firstMatch(version);
    if (match == null) {
      return false;
    }
    for (var i = 0; i < 3; i++) {
      final part = int.parse(match.group(i + 1) ?? '0');
      if (part != minimum[i]) {
        return part > minimum[i];
      }
    }
    return !version.contains('-');
  }
}
