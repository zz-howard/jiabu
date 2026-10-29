import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jiabu/domain/required_value.dart';

abstract interface class LockStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

final class SecureLockStorage implements LockStorage {
  const SecureLockStorage();
  static const _storage = FlutterSecureStorage();
  @override
  Future<String?> read(String key) => _storage.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

abstract interface class LockCredentials {
  Future<void> save(String scope, String kind, String value);
  Future<bool> verify(String scope, String kind, String value);
}

final class LockCredentialsService implements LockCredentials {
  LockCredentialsService(this.storage, {Random? random})
    : random = random ?? Random.secure();
  final LockStorage storage;
  final Random random;
  static const iterations = 100000;

  // PBKDF2-HMAC-SHA256, one 32-byte block.
  // Persist the version and work factor alongside the digest.
  static List<int> derive(String value, List<int> salt, int rounds) {
    final hmac = Hmac(sha256, utf8.encode(value));
    var block = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
    final result = List<int>.of(block);
    for (var i = 1; i < rounds; i++) {
      block = hmac.convert(block).bytes;
      for (var j = 0; j < result.length; j++) {
        result[j] ^= block[j];
      }
    }
    return result;
  }

  @override
  Future<void> save(String scope, String kind, String value) async {
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    final digest = await compute(_deriveCredential, (value, salt, iterations));
    await storage.write(
      'lock:$scope:$kind',
      jsonEncode({
        'version': 1,
        'rounds': iterations,
        'salt': base64Encode(salt),
        'digest': base64Encode(digest),
      }),
    );
  }

  @override
  Future<bool> verify(String scope, String kind, String value) async {
    final encoded = await storage.read('lock:$scope:$kind');
    if (encoded == null) {
      return false;
    }
    final record = jsonDecode(encoded) as Map<String, Object?>;
    if (record['version'] != 1 || record['rounds'] != iterations) {
      return false;
    }
    final expected = base64Decode(requireValue<String>(record['digest']));
    final actual = await compute(_deriveCredential, (
      value,
      base64Decode(requireValue<String>(record['salt'])),
      requireValue<int>(record['rounds']),
    ));
    var difference = expected.length ^ actual.length;
    for (var i = 0; i < actual.length; i++) {
      difference |= actual[i] ^ (i < expected.length ? expected[i] : 0);
    }
    return difference == 0;
  }
}

List<int> _deriveCredential((String, List<int>, int) input) =>
    LockCredentialsService.derive(input.$1, input.$2, input.$3);
