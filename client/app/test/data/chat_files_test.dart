import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/data/api/api_error.dart';
import 'package:jiabu/data/chat/chat_capabilities.dart';
import 'package:jiabu/data/chat/chat_session.dart';
import 'package:jiabu/data/services/media_service.dart';
import 'package:jiabu/domain/chat.dart';
import 'package:jiabu/domain/chat_files.dart';
import 'package:jiabu/domain/result.dart';

import '../support/chat_harness.dart';

/// A minimal fictional PDF: valid header and trailer, [pad] filler bytes.
Uint8List pdf(String body, {int pad = 0, String trailer = '\n'}) =>
    Uint8List.fromList([
      ...ascii.encode('%PDF-1.7\n'),
      ...ascii.encode(body),
      ...List.filled(pad, 0x20),
      ...ascii.encode('\n%%EOF$trailer'),
    ]);

String hashOf(List<int> bytes) => sha256.convert(bytes).toString();

class FakeDocuments implements DocumentPickerPort {
  List<PickedDocument> documents = [];
  Exception? error;
  final requests = <({int limit, int maxBytes})>[];
  @override
  Future<List<PickedDocument>> pickPdfs({
    required int limit,
    required int maxBytes,
  }) async {
    requests.add((limit: limit, maxBytes: maxBytes));
    if (error case final Exception thrown) {
      throw thrown;
    }
    return documents;
  }
}

PickedDocument picked(String name, Uint8List bytes) =>
    PickedDocument(name: name, size: bytes.length, bytes: bytes);

void main() {
  group('pdf signature', () {
    test('accepts the server shape', () {
      expect(looksLikePdf(pdf('fictional')), isTrue);
      expect(looksLikePdf(pdf('fictional', trailer: '\r\n\u0000 \t')), isTrue);
      // %%EOF only has to be in the last KiB; earlier ones do not count.
      expect(looksLikePdf(pdf('%%EOF', pad: 2000)), isTrue);
    });
    test('rejects other headers and trailers', () {
      expect(looksLikePdf(ascii.encode('%PDF-1.7')), isFalse);
      expect(looksLikePdf(ascii.encode('%PDF-x.7\n%%EOF')), isFalse);
      expect(looksLikePdf(ascii.encode('%PDF-17.\n%%EOF')), isFalse);
      expect(looksLikePdf(ascii.encode('GIF89a fictional %%EOF')), isFalse);
      expect(looksLikePdf(pdf('fictional', trailer: '\nx')), isFalse);
      expect(looksLikePdf(pdf('fictional', trailer: '\u000b')), isFalse);
      final early = Uint8List.fromList([
        ...ascii.encode('%PDF-1.7\n%%EOF\n'),
        ...List.filled(1100, 0x20),
      ]);
      expect(looksLikePdf(early), isFalse);
    });
  });

  group('file names', () {
    test('trims and replaces separators and control characters', () {
      expect(sanitizeChatFileName('  虚构发票.pdf \n'), '虚构发票.pdf');
      expect(sanitizeChatFileName(r'a/b\c.pdf'), 'a_b_c.pdf');
      expect(sanitizeChatFileName('a\u0000b\u007fc\u0085.pdf'), 'a_b_c_.pdf');
    });
    test('falls back for empty and dot names', () {
      for (final name in [null, '', '   ', '.', '..']) {
        expect(sanitizeChatFileName(name), ChatFileLimits.fallbackName);
      }
      expect(sanitizeChatFileName('...'), '...');
    });
    test('shortens to 255 UTF-8 bytes on a character boundary', () {
      final long = '${'账' * 120}.pdf';
      final name = sanitizeChatFileName(long);
      expect(utf8.encode(name).length, lessThanOrEqualTo(255));
      expect(name, endsWith('.pdf'));
      expect(name, startsWith('账'));
      expect(name.runes.where((rune) => rune == 0xfffd), isEmpty);
      expect(utf8.encode(sanitizeChatFileName('a' * 400)).length, 255);
    });
  });

  group('media import', () {
    late ChatHarness h;
    late FakeDocuments documents;
    setUp(() async {
      documents = FakeDocuments();
      h = await ChatHarness.create(documents: documents);
    });
    tearDown(() => h.close());

    test('stores raw bytes as hash.pdf with one queued upload', () async {
      final bytes = pdf('fictional invoice');
      final result = await h.session.media.importFile('s', '发票.pdf', bytes);
      final file = (result as Ok<ChatFile>).value;
      expect(
        file,
        ChatFile(sha256: hashOf(bytes), name: '发票.pdf', bytes: bytes.length),
      );
      final blob = (await h.h.store.blobs('s')).single;
      expect(blob['module'], chatFileModule);
      expect(blob['sha256'], file.sha256);
      expect(blob['path'], endsWith('${file.sha256}.pdf'));
      expect(File(blob['path']! as String).readAsBytesSync(), bytes);
      final op = (await h.h.store.outbox('s')).single;
      expect(op.kind, 'blob');
      expect(op.payload, {
        'module': chatFileModule,
        'sha256': file.sha256,
        'path': blob['path'],
      });
      expect(op.entityIds, {'blob:chat_file:${file.sha256}'});
      // Importing the same PDF again queues nothing new.
      await h.session.media.importFile('s', 'again.pdf', bytes);
      expect(await h.h.store.outbox('s'), hasLength(1));
    });

    test('orphaned PDFs are cleaned like orphaned JPEGs', () async {
      final kept = (await h.session.media.importFile(
        's',
        'a.pdf',
        pdf('a'),
      ) as Ok<ChatFile>).value;
      h.h.directory.createSync(recursive: true);
      final orphan = File('${h.h.directory.path}/${'0' * 64}.pdf')
        ..writeAsBytesSync(pdf('orphan'));
      await h.h.cache.cleanPending();
      expect(orphan.existsSync(), isFalse);
      expect(
        File('${h.h.directory.path}/${kept.sha256}.pdf').existsSync(),
        isTrue,
      );
    });

    test('pick validates limits before importing anything', () async {
      final a = pdf('a');
      final big = pdf('big', pad: 6 * 1024 * 1024);
      Future<String> fails(
        List<PickedDocument> picked, {
        List<ChatFile> attached = const [],
      }) async {
        documents.documents = picked;
        final result = await h.session.files(attached: attached);
        expect(await h.h.store.outbox('s'), isEmpty);
        return (result as Failure<List<ChatFile>>).code;
      }

      expect(
        await fails([for (var i = 0; i < 5; i++) picked('$i.pdf', a)]),
        'chat_files_too_many',
      );
      expect(documents.requests.last, (limit: 4, maxBytes: 10 * 1024 * 1024));
      const old = ChatFile(sha256: 'f', name: 'old.pdf', bytes: 1);
      expect(
        await fails(
          [picked('a.pdf', a), picked('b.pdf', pdf('b'))],
          attached: const [old, old, old],
        ),
        'chat_files_too_many',
      );
      expect(documents.requests.last.limit, 1);
      expect(
        await fails([
          picked('ok.pdf', a),
          const PickedDocument(name: 'huge.pdf', size: 11 * 1024 * 1024),
        ]),
        'chat_file_too_large',
      );
      expect(
        await fails([
          picked('photo.pdf', Uint8List.fromList([0xff, 0xd8])),
        ]),
        'chat_file_not_pdf',
      );
      expect(
        await fails(
          [picked('big.pdf', big)],
          attached: const [
            ChatFile(sha256: 'f', name: 'old.pdf', bytes: 15 * 1024 * 1024),
          ],
        ),
        'chat_files_too_large',
      );
      expect(
        await fails([picked('a.pdf', a)], attached: const [old, old, old, old]),
        'chat_files_too_many',
      );
    });

    test('pick imports and skips duplicates', () async {
      final a = pdf('a');
      documents.documents = [
        picked(' 账单/十月.pdf ', a),
        picked('copy.pdf', a),
        picked('', pdf('b')),
      ];
      final result = await h.session.files();
      final files = (result as Ok<List<ChatFile>>).value;
      expect(files.map((file) => file.name), ['账单_十月.pdf', 'document.pdf']);
      expect(await h.h.store.outbox('s'), hasLength(2));
      documents.documents = [picked('again.pdf', a)];
      expect(
        (await h.session.files(attached: files) as Ok<List<ChatFile>>).value,
        isEmpty,
      );
    });

    test('unsupported platforms say so', () async {
      documents.error = const DocumentPickerUnavailable();
      expect(
        (await h.session.files() as Failure<List<ChatFile>>).code,
        'chat_file_unsupported',
      );
      final bare = await ChatHarness.create();
      addTearDown(bare.close);
      expect(
        (await bare.session.files() as Failure<List<ChatFile>>).code,
        'chat_file_unsupported',
      );
    });
  });

  group('upload and send', () {
    late ChatHarness h;
    setUp(() async {
      h = await ChatHarness.create(offline: false);
    });
    tearDown(() => h.close());

    Future<ChatFile> attach(String name, String body) async {
      final result = await h.session.media.importFile('s', name, pdf(body));
      return (result as Ok<ChatFile>).value;
    }

    test('message waits for its file upload, then sends files', () async {
      final file = await attach('发票.pdf', 'invoice');
      expect(
        await h.session.send('看看这张发票', const [], files: [file]),
        isA<Ok<void>>(),
      );
      final send = (await h.h.store.outbox('s'))
          .singleWhere((op) => op.kind == 'chat_send');
      expect(send.dependsOn, {'blob:chat_file:${file.sha256}'});
      expect(send.payload['files'], [
        {'sha256': file.sha256, 'name': '发票.pdf'},
      ]);
      final entry = await h.h.store.chatEntry('s', send.id);
      final message = entry!['message_json'] is String
          ? jsonDecode(entry['message_json']! as String) as Map<String, Object?>
          : entry['message_json']! as Map<String, Object?>;
      final input =
          (message['metadata']! as Map<String, Object?>)['input']!
              as Map<String, Object?>;
      expect(input['files'], [
        {
          'sha256': file.sha256,
          'name': '发票.pdf',
          'mime': 'application/pdf',
          'bytes': file.bytes,
        },
      ]);
      // The upload goes first, through the file endpoint only.
      await h.processor.drain(await h.owner());
      expect(h.h.api.events, contains('file'));
      expect(h.h.api.events, isNot(contains('blob')));
      expect(h.h.api.files.single.hash, file.sha256);
      expect(h.h.api.files.single.joinEpoch, 1);
      expect((await h.h.store.blobs('s')).single['uploaded'], 1);
      await h.processor.drain(await h.owner());
      final write = h.api.writes.single;
      expect(write.endpoint, 'messages');
      expect(write.payload['files'], [
        {'sha256': file.sha256, 'name': '发票.pdf'},
      ]);
      expect(write.payload.containsKey(chatCapabilitiesEnvelopeKey), isFalse);
      expect(await h.h.store.outbox('s'), isEmpty);
    });

    test('images and files travel together; text is optional', () async {
      final file = await attach('a.pdf', 'a');
      expect(
        await h.session.send('', const ['photo'], files: [file]),
        isA<Ok<void>>(),
      );
      final send = (await h.h.store.outbox('s'))
          .singleWhere((op) => op.kind == 'chat_send');
      expect(send.dependsOn, {
        'blob:chat:photo',
        'blob:chat_file:${file.sha256}',
      });
      expect(send.payload['images'], ['photo']);
    });

    test('send enforces the file limits', () async {
      ChatFile file(int i, int bytes) =>
          ChatFile(sha256: '$i', name: '$i.pdf', bytes: bytes);
      expect(
        (await h.session.send(
          '',
          const [],
          files: [for (var i = 0; i < 5; i++) file(i, 1)],
        ) as Failure<void>).code,
        'chat_files_too_many',
      );
      expect(
        (await h.session.send(
          '',
          const [],
          files: [file(1, 1), file(1, 1)],
        ) as Failure<void>).code,
        'chat_files_too_many',
      );
      expect(
        (await h.session.send(
          '',
          const [],
          files: [file(1, 10 * 1024 * 1024), file(2, 10 * 1024 * 1024 + 1)],
        ) as Failure<void>).code,
        'chat_files_too_large',
      );
      expect(await h.h.store.outbox('s'), isEmpty);
    });

    for (final (status, code) in [
      (413, 'payload_too_large'),
      (415, 'unsupported_media_type'),
      (422, 'invalid'),
    ]) {
      test('upload $status fails permanently and blocks the message', () async {
        h.h.api.onFile = () async => throw ApiError(code, status: status);
        final file = await attach('a.pdf', 'a');
        await h.session.send('x', const [], files: [file]);
        await h.processor.drain(await h.owner());
        final ops = await h.h.store.outbox('s');
        final upload = ops.singleWhere((op) => op.kind == 'blob');
        expect(upload.state, 'failed');
        expect(upload.lastError?['status'], status);
        expect(h.api.writes, isEmpty);
        final user = ops.singleWhere((op) => op.kind == 'chat_send').id;
        // The note reads the failed upload as a failed delivery.
        for (
          var i = 0;
          i < 100 && h.session.delivery[user] != ChatDelivery.failed;
          i++
        ) {
          await h.session.recover();
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        expect(h.session.delivery[user], ChatDelivery.failed);
        // Retry resets the failed upload together with the message.
        h.h.api.onFile = null;
        expect(await h.session.retryUpload(user), isA<Ok<void>>());
        expect(
          (await h.h.store.outbox('s'))
              .singleWhere((op) => op.kind == 'blob')
              .state,
          'pending',
        );
        await h.processor.drain(await h.owner());
        await h.processor.drain(await h.owner());
        expect(h.api.writes.single.payload['files'], isNotEmpty);
      });
    }

    test('upload 503 stays pending and honours Retry-After', () async {
      h.h.api.onFile = () async =>
          throw const ApiError('upload_busy', status: 503, retryAfter: 7);
      await attach('a.pdf', 'a');
      await h.processor.drain(await h.owner());
      final upload = (await h.h.store.outbox('s')).single;
      expect(upload.state, 'pending');
      expect(upload.lastError?['code'], 'upload_busy');
      expect(
        upload.retryAt,
        greaterThanOrEqualTo(h.h.clock.millisecondsSinceEpoch + 7000),
      );
    });

    test('draft keeps attached files across sessions', () async {
      final file = await attach('草稿.pdf', 'draft');
      await h.session.saveDraft('稍后发送', const [], [file]);
      final raw = await h.h.store.chatClientState('s', '@draft:m');
      expect(raw['files'], [file.toJson()]);
      final reopened = LocalChatSession(
        dao: h.h.store,
        api: h.api,
        fence: h.session.fence,
        memberId: 'm',
        caps: h.session.caps,
        sync: () async {},
        media: h.session.media,
      );
      addTearDown(reopened.dispose);
      await reopened.initialize();
      expect(reopened.draftFiles, [file]);
      expect(reopened.draft, '稍后发送');
    });
  });
}
