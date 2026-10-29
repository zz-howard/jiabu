import 'package:jiabu/data/api/api_client.dart';
import 'package:jiabu/data/api/api_error.dart';
import 'package:jiabu/domain/api_keys.dart';
import 'package:jiabu/domain/required_value.dart';
import 'package:jiabu/domain/result.dart';

/// Online only. This repository has no database or logging dependency.
final class OnlineApiKeysRepository implements ApiKeysRepository {
  OnlineApiKeysRepository(this.api, {required this.online});
  final ApiClient api;
  final bool Function() online;

  Future<Result<Map<String, Object?>>> _request(
    String path, {
    String method = 'GET',
    Map<String, Object?>? body,
    String? operationId,
  }) async {
    if (!online()) {
      return const Failure('offline');
    }
    try {
      return Ok(
        await api.accountRequest(
          path,
          method: method,
          body: body,
          operationId: operationId,
        ),
      );
    } on ApiError catch (error) {
      return Failure(error.code, requestId: error.requestId);
    } on Object {
      return const Failure('invalid_response');
    }
  }

  @override
  Future<Result<List<Map<String, Object?>>>> list() async {
    final result = await _request('v1/me/api-keys');
    return switch (result) {
      Ok<Map<String, Object?>>(:final value) => Ok(
        requireValue<List<Object?>>(value['api_keys'])
            .cast<Map<String, Object?>>(),
      ),
      Failure<Map<String, Object?>>(:final code) => Failure(code),
    };
  }

  @override
  Future<Result<Map<String, Object?>>> create(
    Map<String, Object?> input,
    String operationId,
  ) => _request(
    'v1/me/api-keys',
    method: 'POST',
    body: input,
    operationId: operationId,
  );

  @override
  Future<Result<void>> change(
    String id,
    String operationId, {
    String? name,
  }) async {
    final result = await _request(
      'v1/me/api-keys/$id${name == null ? '/revoke' : ''}',
      method: name == null ? 'POST' : 'PATCH',
      body: name == null ? null : {'name': name},
      operationId: operationId,
    );
    return switch (result) {
      Ok<Map<String, Object?>>() => const Ok(null),
      Failure<Map<String, Object?>>(:final code) => Failure(code),
    };
  }
}
