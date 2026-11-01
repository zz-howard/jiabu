import 'dart:typed_data';

import 'package:jiabu/data/api/dto/auth_dto.dart';
import 'package:jiabu/data/api/dto/client_logs_dto.dart';
import 'package:jiabu/data/api/dto/meta_dto.dart';
import 'package:jiabu/data/api/dto/spaces_dto.dart';
import 'package:jiabu/data/api/dto/sync_dto.dart';

/// Transport failures are normalized to ApiError at this boundary. Repositories
/// return Result; the sync coordinator applies retry/auth policy centrally.
abstract interface class ApiClient {
  Future<Map<String, Object?>> accountRequest(
    String path, {
    String method = 'GET',
    Map<String, Object?>? body,
    String? operationId,
    int? joinEpoch,
  });
  Future<MetaDto> meta();
  Future<void> health();
  Future<LoginResponseDto> login(LoginRequestDto request);
  Future<void> logout({String? token});
  Future<UserDto> me();
  Future<void> changePassword(ChangePasswordDto request);
  Future<SpacesDto> spaces();
  Future<PushResponseDto> push(List<PushOpDto> ops);
  Future<PullResponseDto> pull(PullRequestDto request);
  Future<void> uploadBlob({
    required String spaceId,
    required int joinEpoch,
    required String module,
    required String hash,
    required Uint8List bytes,
    required String opId,
    required String requestId,
  });
  Future<Uint8List> downloadBlob(String spaceId, String hash, String variant);

  /// Generic space file (PDF) upload; raw bytes under their SHA-256.
  Future<void> uploadFile({
    required String spaceId,
    required int joinEpoch,
    required String hash,
    required Uint8List bytes,
    required String opId,
    required String requestId,
  });
  Future<void> uploadLogs(ClientLogsDto logs);
}
