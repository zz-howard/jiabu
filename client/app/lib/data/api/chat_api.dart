import 'package:chatweave_core/chatweave_core.dart';
import 'package:dio/dio.dart';

/// Session-only HTTP boundary. All paths remain relative to the server root.
abstract interface class ChatApi {
  Future<Map<String, Object?>> chatWrite({
    required String spaceId,
    required String endpoint,
    required Map<String, Object?> payload,
    required int joinEpoch,
    required String opId,
    required String requestId,
    String? capabilities,
  });
  Future<List<ActiveMessage>> chatActive(String spaceId);
  Future<StreamConnection> chatStream(
    String spaceId,
    String messageId, {
    required String capabilities,
    int? afterSeq,
    CancelToken? cancelToken,
  });
}
