import 'package:jiabu/data/services/app_settings_service.dart';
import 'package:jiabu/data/services/session_store_service.dart';
import 'package:jiabu/domain/partition.dart';

class MemorySettings implements SettingsStorage {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String? value) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }
}

class MemorySessions implements SessionStore {
  final values = <String, String>{};
  @override
  Future<String?> read(Partition partition) async => values[partition.tokenKey];
  @override
  Future<void> write(Partition partition, String token) async {
    values[partition.tokenKey] = token;
  }

  @override
  Future<void> delete(Partition partition) async {
    values.remove(partition.tokenKey);
  }
}
