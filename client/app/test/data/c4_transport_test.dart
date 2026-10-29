import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/data/api/api_error.dart';
import 'package:jiabu/data/api/dio_api_client.dart';

import 'api_contract_test.dart' show CapturingAdapter;

void main() {
  test(
    'management_transport_preserves_proxy_prefix_headers_and_null_expiry',
    () async {
      final adapter = CapturingAdapter()
        ..body = {
          'id': 'fictional-key',
          'created': true,
          'plaintext_available': false,
        };
      final dio = Dio()..httpClientAdapter = adapter;
      final api = DioApiClient(
        server: 'https://example.invalid/proxy',
        clientHeader: 'android/0.1.0+1; channel=beta',
        token: () async => 'fictional-session',
        dio: dio,
      );
      await api.accountRequest(
        'v1/me/api-keys',
        method: 'POST',
        body: {'name': '用户A', 'scope': 'read', 'expires_at': null},
        operationId: 'fictional-operation',
      );
      await api.accountRequest(
        'v1/spaces/space-a/invitations',
        method: 'POST',
        body: {'username': '用户B'},
        operationId: 'fictional-invitation',
        joinEpoch: 7,
      );
      final request = adapter.requests.first;
      expect(request.uri.path, '/proxy/v1/me/api-keys');
      expect(request.headers['Idempotency-Key'], 'fictional-operation');
      expect(request.headers['X-Request-Id'], isNotEmpty);
      expect(
        (request.data as Map<String, Object?>).containsKey('expires_at'),
        isTrue,
      );
      expect((request.data as Map<String, Object?>)['expires_at'], isNull);
      expect(adapter.requests.last.headers['X-Jiabu-Join-Epoch'], 7);
      await expectLater(
        api.accountRequest('/v1/me/api-keys'),
        throwsA(
          isA<ApiError>().having(
            (error) => error.code,
            'code',
            'absolute_api_path',
          ),
        ),
      );
      dio.close(force: true);
    },
  );
}
