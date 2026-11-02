import 'package:jiabu/domain/required_value.dart';
import 'package:jiabu/domain/update.dart';

final class ReleaseInfoDto {
  const ReleaseInfoDto({
    required this.build,
    required this.version,
    required this.channel,
    required this.bytes,
    required this.sha256,
    required this.notes,
    required this.securityForce,
    required this.minServerApi,
  });

  factory ReleaseInfoDto.fromJson(Map<String, Object?> json) {
    final notes = requireValue<Map<String, Object?>>(json['notes']);
    return ReleaseInfoDto(
      build: requireValue<int>(json['build']),
      version: requireValue<String>(json['version']),
      channel: requireValue<String>(json['channel']),
      bytes: requireValue<int>(json['bytes']),
      sha256: requireValue<String>(json['sha256']).toLowerCase(),
      notes: {
        for (final locale in const ['zh-Hans', 'en'])
          if (notes[locale] case final String value) locale: value,
      },
      securityForce: requireValue<bool>(json['security_force']),
      minServerApi: requireValue<int>(json['min_server_api']),
    );
  }

  final int build;
  final String version;
  final String channel;
  final int bytes;
  final String sha256;
  final Map<String, String> notes;
  final bool securityForce;
  final int minServerApi;

  ReleaseInfo toDomain() => ReleaseInfo(
    build: build,
    version: version,
    channel: channel,
    bytes: bytes,
    sha256: sha256,
    notes: notes,
    securityForce: securityForce,
    minServerApi: minServerApi,
  );
}
