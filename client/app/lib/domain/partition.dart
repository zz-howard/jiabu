import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:jiabu/domain/required_value.dart';

String normalizeServer(String address) {
  final uri = Uri.parse(address.trim());
  if (!const {'http', 'https'}.contains(uri.scheme.toLowerCase()) ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment) {
    throw const FormatException('invalid_server_address');
  }
  // Retain the serialized path: decoding/re-encoding can turn an encoded slash
  // into a different reverse-proxy route. Uri.origin normalizes default ports.
  final serialized = uri.toString();
  final pathStart = serialized.indexOf('/', serialized.indexOf('://') + 3);
  final encodedPath = pathStart < 0 ? '' : serialized.substring(pathStart);
  final path = encodedPath
      .replaceFirst(RegExp(r'/+$'), '')
      .replaceAllMapped(
        RegExp('%[a-fA-F0-9]{2}'),
        (match) => match.group(0)?.toUpperCase() ?? '',
      );
  return '${uri.origin.toLowerCase()}$path/';
}

final class Partition {
  Partition(String address, this.userId) : server = normalizeServer(address);
  factory Partition.fromJson(Map<String, Object?> json) => Partition(
    requireValue<String>(json['server']),
    requireValue<String>(json['user_id']),
  );
  final String server;
  final String userId;
  String get prefix => sha256
      .convert(utf8.encode('$server|$userId'))
      .toString()
      .substring(0, 16);
  String get directoryName => 'jiabu-$prefix';
  String get databaseName => '$directoryName.db';
  String get tokenKey => 'session:$prefix';
  Map<String, Object?> toJson() => {'server': server, 'user_id': userId};
}
