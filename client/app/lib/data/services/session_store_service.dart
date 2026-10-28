import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jiabu/domain/partition.dart';

abstract interface class SessionStore {
  Future<String?> read(Partition partition);
  Future<void> write(Partition partition, String token);
  Future<void> delete(Partition partition);
}

final class SecureSessionStore implements SessionStore {
  const SecureSessionStore();
  static const _storage = FlutterSecureStorage();
  @override
  Future<String?> read(Partition partition) =>
      _storage.read(key: partition.tokenKey);
  @override
  Future<void> write(Partition partition, String token) =>
      _storage.write(key: partition.tokenKey, value: token);
  @override
  Future<void> delete(Partition partition) =>
      _storage.delete(key: partition.tokenKey);
}
