import 'dart:convert';
import 'dart:typed_data';

import 'package:chatweave_core/chatweave_core.dart';
import 'package:dio/dio.dart';
import 'package:jiabu/data/api/api_client.dart';
import 'package:jiabu/data/api/api_error.dart';
import 'package:jiabu/data/api/chat_api.dart';
import 'package:jiabu/data/api/dto/auth_dto.dart';
import 'package:jiabu/data/api/dto/client_logs_dto.dart';
import 'package:jiabu/data/api/dto/meta_dto.dart';
import 'package:jiabu/data/api/dto/problem_dto.dart';
import 'package:jiabu/data/api/dto/spaces_dto.dart';
import 'package:jiabu/data/api/dto/sync_dto.dart';
import 'package:jiabu/data/sync/sync_policy.dart';
import 'package:jiabu/domain/partition.dart';
import 'package:uuid/uuid.dart';

final class DioApiClient implements ApiClient, ChatApi {
  DioApiClient({
    required String server,
    required String clientHeader,
    required Future<String?> Function() token,
    Dio? dio,
    this.onUnauthorized,
    this.onUpgradeRequired,
    this.acceptResponse,
  }) : dio = dio ?? Dio() {
    this.dio.options = BaseOptions(
      baseUrl: normalizeServer(server),
      connectTimeout: SyncPolicy.requestTimeout,
      receiveTimeout: SyncPolicy.requestTimeout,
      sendTimeout: SyncPolicy.requestTimeout,
    );
    this.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (options.path.startsWith('/') ||
              Uri.parse(options.path).hasScheme) {
            handler.reject(
              DioException(
                requestOptions: options,
                error: const ApiError('absolute_api_path'),
              ),
            );
            return;
          }
          options.headers['X-Jiabu-Client'] = clientHeader;
          options.headers.putIfAbsent('X-Request-Id', () => const Uuid().v7());
          if (options.method != 'GET') {
            options.headers.putIfAbsent(
              'Idempotency-Key',
              () => const Uuid().v7(),
            );
          }
          if (options.extra['anonymous'] != true) {
            try {
              final secret = await token();
              if (secret != null) {
                options.headers['Authorization'] = 'Bearer $secret';
              }
            } on Object {
              handler.reject(
                DioException(
                  requestOptions: options,
                  error: const ApiError('token_unavailable'),
                ),
              );
              return;
            }
          }
          handler.next(options);
        },
      ),
    );
  }

  final Dio dio;
  final Future<void> Function()? onUnauthorized;
  final Future<void> Function()? onUpgradeRequired;
  final Future<bool> Function()? acceptResponse;

  Future<Response<T>> _request<T>(
    String path, {
    String method = 'GET',
    Object? data,
    Map<String, Object?>? query,
    Map<String, Object?> headers = const {},
    bool anonymous = false,
    ResponseType responseType = ResponseType.json,
    bool blob = false,
    bool stream = false,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await dio.request<T>(
        path,
        data: data,
        queryParameters: query,
        cancelToken: cancelToken,
        options: Options(
          method: method,
          headers: headers,
          extra: {'anonymous': anonymous},
          responseType: responseType,
          sendTimeout: blob ? SyncPolicy.blobTimeout : null,
          receiveTimeout: blob
              ? SyncPolicy.blobTimeout
              : stream
              ? SyncPolicy.chatStreamTimeout
              : null,
        ),
      );
      final guard = acceptResponse;
      if (guard != null && !await guard()) {
        throw const ApiError('stale_response');
      }
      return response;
    } on DioException catch (error) {
      final guard = acceptResponse;
      if (guard != null && !await guard()) {
        throw const ApiError('stale_response');
      }
      final status = error.response?.statusCode;
      if (status == 401 && !anonymous) {
        await onUnauthorized?.call();
      }
      if (status == 426) {
        await onUpgradeRequired?.call();
      }
      Object? body = error.response?.data;
      if (body is ResponseBody) {
        body = await body.stream.fold<List<int>>(
          <int>[],
          (all, chunk) => all..addAll(chunk),
        );
      }
      if (body is List<int>) {
        try {
          body = jsonDecode(utf8.decode(body));
        } on FormatException {
          body = null;
        }
      }
      if (body is Map<String, Object?> && body['code'] is String) {
        final parsed = ApiError.problem(ProblemDto.fromJson(body), status);
        throw ApiError(
          parsed.code,
          status: parsed.status,
          requestId: parsed.requestId,
          retryAfter:
              parsed.retryAfter ??
              int.tryParse(error.response?.headers.value('retry-after') ?? ''),
        );
      }
      if (error.error case final ApiError normalized) {
        throw normalized;
      }
      throw ApiError(status == null ? 'network' : 'http_error', status: status);
    }
  }

  Map<String, Object?> _json(Response<Object?> response) {
    final body = response.data;
    if (body is! Map<String, Object?>) {
      throw const ApiError('invalid_response');
    }
    return body;
  }

  @override
  Future<Map<String, Object?>> chatWrite({
    required String spaceId,
    required String endpoint,
    required Map<String, Object?> payload,
    required int joinEpoch,
    required String opId,
    required String requestId,
    String? capabilities,
  }) async {
    final response = await _request<Map<String, Object?>>(
      'v1/spaces/$spaceId/chat/$endpoint',
      method: 'POST',
      data: payload,
      headers: {
        'X-Jiabu-Join-Epoch': joinEpoch,
        'Idempotency-Key': opId,
        'X-Request-Id': requestId,
        'ChatWeave-Capabilities': ?capabilities,
      },
    );
    return response.data ?? <String, Object?>{};
  }

  @override
  Future<List<ActiveMessage>> chatActive(String spaceId) async {
    final response = await _request<Map<String, Object?>>(
      'v1/spaces/$spaceId/chat/active-messages',
    );
    return (response.data?['messages'] as List<Object?>? ?? const [])
        .map((item) => ActiveMessage.fromJson(item! as Map<String, Object?>))
        .toList();
  }

  @override
  Future<StreamConnection> chatStream(
    String spaceId,
    String messageId, {
    required String capabilities,
    int? afterSeq,
    CancelToken? cancelToken,
  }) async {
    final response = await _request<ResponseBody>(
      'v1/spaces/$spaceId/chat/messages/$messageId/stream',
      responseType: ResponseType.stream,
      stream: true,
      cancelToken: cancelToken,
      headers: {
        'Accept': 'text/event-stream',
        'ChatWeave-Capabilities': capabilities,
        if (afterSeq != null) 'Last-Event-ID': afterSeq.toString(),
      },
    );
    final body = response.data;
    return StreamConnection(
      status: response.statusCode ?? 200,
      headers: response.headers.map.map(
        (key, value) => MapEntry(key.toLowerCase(), value.join(',')),
      ),
      bytes: body == null ? const Stream<List<int>>.empty() : body.stream,
    );
  }

  @override
  Future<Map<String, Object?>> accountRequest(
    String path, {
    String method = 'GET',
    Map<String, Object?>? body,
    String? operationId,
    int? joinEpoch,
  }) async => _json(
    await _request<Object?>(
      path,
      method: method,
      data: body,
      headers: {
        'Idempotency-Key': ?operationId,
        'X-Jiabu-Join-Epoch': ?joinEpoch,
      },
    ),
  );

  @override
  Future<MetaDto> meta() async => MetaDto.fromJson(
    _json(await _request<Object?>('v1/meta', anonymous: true)),
  );
  @override
  Future<void> health() async {
    await _request<Object?>(
      'healthz',
      anonymous: true,
      responseType: ResponseType.plain,
    );
  }

  @override
  Future<LoginResponseDto> login(LoginRequestDto request) async =>
      LoginResponseDto.fromJson(
        _json(
          await _request<Object?>(
            'v1/auth/login',
            method: 'POST',
            data: request.toJson(),
            anonymous: true,
          ),
        ),
      );
  @override
  Future<void> logout({String? token}) async {
    await _request<Object?>(
      'v1/auth/logout',
      method: 'POST',
      anonymous: token != null,
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    );
  }

  @override
  Future<UserDto> me() async =>
      UserDto.fromJson(_json(await _request<Object?>('v1/me')));
  @override
  Future<void> changePassword(ChangePasswordDto request) async {
    await _request<Object?>(
      'v1/me/password',
      method: 'POST',
      data: request.toJson(),
    );
  }

  @override
  Future<SpacesDto> spaces() async =>
      SpacesDto.fromJson(_json(await _request<Object?>('v1/spaces')));
  @override
  Future<PushResponseDto> push(List<PushOpDto> ops) async =>
      PushResponseDto.fromJson(
        _json(
          await _request<Object?>(
            'v1/sync/push',
            method: 'POST',
            data: PushRequestDto(ops: ops).toJson(),
            headers: ops.isEmpty
                ? const {}
                : {
                    'Idempotency-Key': ops.first.opId,
                    'X-Request-Id': ops.first.requestId,
                  },
          ),
        ),
      );
  @override
  Future<PullResponseDto> pull(PullRequestDto request) async =>
      PullResponseDto.fromJson(
        _json(
          await _request<Object?>(
            'v1/sync/pull',
            method: 'POST',
            data: request.toJson(),
          ),
        ),
      );
  @override
  Future<void> uploadBlob({
    required String spaceId,
    required int joinEpoch,
    required String module,
    required String hash,
    required Uint8List bytes,
    required String opId,
    required String requestId,
  }) async {
    await _request<Object?>(
      'v1/spaces/$spaceId/blobs/$hash',
      method: 'PUT',
      query: {'module': module},
      data: bytes,
      blob: true,
      headers: {
        'Content-Type': 'image/jpeg',
        'X-Jiabu-Join-Epoch': joinEpoch,
        'Idempotency-Key': opId,
        'X-Request-Id': requestId,
      },
    );
  }

  @override
  Future<void> uploadFile({
    required String spaceId,
    required int joinEpoch,
    required String hash,
    required Uint8List bytes,
    required String opId,
    required String requestId,
  }) async {
    // 204 for both new and repeated uploads; 413/415/422 are permanent.
    await _request<Object?>(
      'v1/spaces/$spaceId/files/$hash',
      method: 'PUT',
      data: bytes,
      blob: true,
      headers: {
        'Content-Type': 'application/pdf',
        'X-Jiabu-Join-Epoch': joinEpoch,
        'Idempotency-Key': opId,
        'X-Request-Id': requestId,
      },
    );
  }

  @override
  Future<Uint8List> downloadBlob(
    String spaceId,
    String hash,
    String variant,
  ) async {
    // Do not verify the body against `hash`: the server stores a cleaned copy
    // (GPS/XMP/APP13/trailing data removed) under the uploaded bytes' SHA-256.
    final result = await _request<List<int>>(
      'v1/spaces/$spaceId/blobs/$hash',
      query: {'variant': variant},
      responseType: ResponseType.bytes,
      blob: true,
    );
    return Uint8List.fromList(result.data ?? const []);
  }

  @override
  Future<void> uploadLogs(ClientLogsDto logs) async {
    await _request<Object?>(
      'v1/client-logs',
      method: 'POST',
      data: logs.toJson(),
    );
  }
}
