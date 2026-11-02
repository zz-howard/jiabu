import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:jiabu/data/api/dto/meta_dto.dart';
import 'package:jiabu/data/services/version_handshake_service.dart';
import 'package:jiabu/domain/partition.dart';
import 'package:jiabu/domain/required_value.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class SettingsStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String? value);
}

final class PreferencesStorage implements SettingsStorage {
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();
  @override
  Future<String?> read(String key) => _preferences.getString(key);
  @override
  Future<void> write(String key, String? value) async {
    if (value == null) {
      await _preferences.remove(key);
    } else {
      await _preferences.setString(key, value);
    }
  }
}

final class AppSettingsService {
  AppSettingsService(this.storage);
  final SettingsStorage storage;

  Future<String> clientChannel() async =>
      switch (await storage.read('client_channel')) {
        'beta' => 'beta',
        _ => 'stable',
      };

  Future<void> setClientChannel(String channel) {
    if (!const {'stable', 'beta'}.contains(channel)) {
      throw ArgumentError('invalid_client_channel');
    }
    return storage.write('client_channel', channel);
  }

  Future<List<String>> servers() async =>
      (jsonDecode(await storage.read('servers') ?? '[]') as List<Object?>)
          .cast<String>();
  Future<void> rememberServer(String server) async {
    final addresses = await servers();
    await storage.write(
      'servers',
      jsonEncode({normalizeServer(server), ...addresses}.toList()),
    );
  }

  Future<Partition?> current() async {
    final value = await storage.read('current_partition');
    return value == null
        ? null
        : Partition.fromJson(
            (jsonDecode(value) as Map<String, Object?>).cast<String, Object?>(),
          );
  }

  Future<void> setCurrent(Partition? partition) => storage.write(
    'current_partition',
    partition == null ? null : jsonEncode(partition.toJson()),
  );
  Future<String?> lastSpace(Partition partition) =>
      storage.read('space:${partition.prefix}');
  Future<void> setLastSpace(Partition partition, String spaceId) =>
      storage.write('space:${partition.prefix}', spaceId);
  String _metaKey(String server) =>
      'meta:'
      '${sha256.convert(utf8.encode(normalizeServer(server)))}';
  Future<MetaCache?> meta(String server) async {
    final value = await storage.read(_metaKey(server));
    if (value == null) {
      return null;
    }
    final json = (jsonDecode(value) as Map<String, Object?>)
        .cast<String, Object?>();
    return MetaCache(
      MetaDto.fromJson(
        requireValue<Map<String, Object?>>(json['meta'])
            .cast<String, Object?>(),
      ),
      DateTime.fromMillisecondsSinceEpoch(
        requireValue<int>(json['at']),
        isUtc: true,
      ),
    );
  }

  Future<void> saveMeta(String server, MetaCache cache) => storage.write(
    _metaKey(server),
    jsonEncode({
      'meta': cache.meta.toJson(),
      'at': cache.at.millisecondsSinceEpoch,
    }),
  );
  Future<void> clearMeta(String server) =>
      storage.write(_metaKey(server), null);

  String _updateServerKey(String server, String channel) =>
      'update:last_checked:'
      '${sha256.convert(utf8.encode(normalizeServer(server)))}:$channel';
  Future<DateTime?> updateLastChecked(String server, String channel) async {
    final value = await storage.read(_updateServerKey(server, channel));
    final millis = int.tryParse(value ?? '');
    return millis == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
  }

  Future<void> setUpdateLastChecked(
    String server,
    String channel,
    DateTime value,
  ) => storage.write(
    _updateServerKey(server, channel),
    value.toUtc().millisecondsSinceEpoch.toString(),
  );

  Future<({int build, DateTime at})?> dismissedUpdate(String channel) async {
    final value = await storage.read('update:dismissed:$channel');
    if (value == null) return null;
    final json = (jsonDecode(value) as Map<String, Object?>)
        .cast<String, Object?>();
    return (
      build: requireValue<int>(json['build']),
      at: DateTime.fromMillisecondsSinceEpoch(
        requireValue<int>(json['at']),
        isUtc: true,
      ),
    );
  }

  Future<void> dismissUpdate(String channel, int build, DateTime at) =>
      storage.write(
        'update:dismissed:$channel',
        jsonEncode({'build': build, 'at': at.toUtc().millisecondsSinceEpoch}),
      );
}
