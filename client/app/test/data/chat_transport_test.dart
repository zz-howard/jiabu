import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/data/api/api_error.dart';
import 'package:jiabu/data/api/dio_api_client.dart';
import 'package:jiabu/data/chat/chat_capabilities.dart';
import 'package:jiabu/shared/chatweave/jiabu_chat_registry.dart';

import 'api_contract_test.dart' show CapturingAdapter;

void main() {
  test(
    'capabilities_are_registry_derived_and_stream_headers_are_correct',
    () async {
      final registry = jiabuChatRegistry(
        recordBuilder: (_, _) => const SizedBox(),
      );
      final header = chatCapabilitiesHeader(registry.capabilities());
      expect(header, contains('x-jiabu.record_card:1'));
      expect(header, isNot(contains('x-jiabu.document_card')));
      for (final feature in [
        'stream.resume',
        'stream.snapshot',
        'stream.activity',
        'stream.steps',
      ]) {
        expect(header, contains(feature));
      }
      final adapter = CapturingAdapter()
        ..body = Uint8List.fromList(utf8.encode(': heartbeat\n\n'))
        ..headers = {
          'content-type': ['text/event-stream'],
          'chatweave-protocol': ['0.1'],
        };
      final api = DioApiClient(
        server: 'https://example.invalid/base/',
        clientHeader: 'android/1',
        token: () async => 'synthetic-token',
        dio: Dio()..httpClientAdapter = adapter,
      );
      final response = await api.chatStream(
        'space',
        'reply',
        afterSeq: 23,
        capabilities: header,
      );
      expect(
        await response.bytes.expand((chunk) => chunk).toList(),
        utf8.encode(': heartbeat\n\n'),
      );
      final request = adapter.requests.single;
      expect(
        request.uri.path,
        '/base/v1/spaces/space/chat/messages/reply/stream',
      );
      expect(request.headers['Accept'], 'text/event-stream');
      expect(request.headers['Last-Event-ID'], '23');
      expect(request.headers['ChatWeave-Capabilities'], header);
      expect(request.headers['Authorization'], 'Bearer synthetic-token');
      expect(request.headers['X-Request-Id'], isNotNull);
      api.dio.close();
    },
  );
  test('stream_problem_body_preserves_error_code_and_401_callback', () async {
    final adapter = CapturingAdapter()
      ..status = 401
      ..body = {'code': 'unauthenticated', 'request_id': 'synthetic-request'};
    var unauthorized = 0;
    final api = DioApiClient(
      server: 'https://example.invalid/',
      clientHeader: 'android/1',
      token: () async => null,
      dio: Dio()..httpClientAdapter = adapter,
      onUnauthorized: () async {
        unauthorized++;
      },
    );
    await expectLater(
      api.chatStream('s', 'm', capabilities: 'v=0.1'),
      throwsA(
        isA<ApiError>().having(
          (error) => error.code,
          'code',
          'unauthenticated',
        ),
      ),
    );
    expect(unauthorized, 1);
    api.dio.close();
  });
  test('chat_mutations_preserve_outbox_ids_and_epoch', () async {
    final adapter = CapturingAdapter()..body = {'status': 'accepted'};
    final api = DioApiClient(
      server: 'https://example.invalid/',
      clientHeader: 'android/1',
      token: () async => null,
      dio: Dio()..httpClientAdapter = adapter,
    );
    await api.chatWrite(
      spaceId: 's',
      endpoint: 'actions',
      payload: {'id': 'action'},
      joinEpoch: 4,
      opId: 'action',
      requestId: 'request',
    );
    expect(adapter.requests.single.headers['Idempotency-Key'], 'action');
    expect(adapter.requests.single.headers['X-Jiabu-Join-Epoch'], 4);
    expect(adapter.requests.single.headers['X-Request-Id'], 'request');
    api.dio.close();
  });
}
