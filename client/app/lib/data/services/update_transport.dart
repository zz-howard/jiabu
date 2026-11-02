import 'dart:async';

import 'package:dio/dio.dart';
import 'package:jiabu/data/api/dio_api_client.dart';
import 'package:jiabu/data/api/dto/release_info_dto.dart';
import 'package:jiabu/domain/update.dart';

final class UpdateDownloadResponse {
  const UpdateDownloadResponse({
    required this.statusCode,
    required this.totalBytes,
    required this.start,
    required this.bytes,
  });
  final int statusCode;
  final int? totalBytes;
  final int start;
  final Stream<List<int>> bytes;
}

abstract interface class UpdateTransport {
  Future<ReleaseInfo?> latest(String channel);
  Future<UpdateDownloadResponse> download({
    required int build,
    required int start,
    required UpdateCancellation cancellation,
  });
}

final class DioUpdateTransport implements UpdateTransport {
  DioUpdateTransport(this.client);
  final DioApiClient client;

  @override
  Future<ReleaseInfo?> latest(String channel) async {
    final response = await client.dio.get<Object?>(
      'v1/app/releases/latest',
      queryParameters: {'channel': channel},
      options: Options(
        validateStatus: (status) => const {200, 204, 404}.contains(status),
      ),
    );
    if (response.statusCode != 200) return null;
    final body = response.data;
    if (body is! Map<String, Object?>) throw const FormatException('release');
    return ReleaseInfoDto.fromJson(body).toDomain();
  }

  @override
  Future<UpdateDownloadResponse> download({
    required int build,
    required int start,
    required UpdateCancellation cancellation,
  }) async {
    final token = CancelToken();
    unawaited(
      cancellation.whenCancelled.then((_) => token.cancel('cancelled')),
    );
    final response = await client.dio.get<ResponseBody>(
      'v1/app/releases/$build/apk',
      cancelToken: token,
      options: Options(
        responseType: ResponseType.stream,
        headers: {if (start > 0) 'Range': 'bytes=$start-'},
        validateStatus: (status) => const {200, 206, 416}.contains(status),
      ),
    );
    var stream = response.data?.stream ?? const Stream<List<int>>.empty();
    stream = stream.map((chunk) {
      if (cancellation.cancelled) {
        token.cancel('cancelled');
        throw const UpdateCancelled();
      }
      return chunk;
    });
    final contentRange = response.headers.value('content-range');
    final range = contentRange == null
        ? null
        : RegExp(r'^bytes (\d+)-(\d+)/(\d+)$').firstMatch(contentRange);
    return UpdateDownloadResponse(
      statusCode: response.statusCode ?? 0,
      totalBytes: range == null
          ? int.tryParse(response.headers.value('content-length') ?? '')
          : int.parse(range.group(3) ?? '0'),
      start: range == null ? 0 : int.parse(range.group(1) ?? '0'),
      bytes: stream,
    );
  }
}
