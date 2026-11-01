import 'dart:convert';
import 'dart:typed_data';

import 'package:chatweave_core/chatweave_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/app/chat_providers.dart';
import 'package:jiabu/data/services/media_service.dart';
import 'package:jiabu/domain/chat.dart';
import 'package:jiabu/domain/result.dart';
import 'package:jiabu/features/catalog/c5_cases.dart';
import 'package:jiabu/features/chat/view/chat_screen.dart';
import 'package:jiabu/features/chat/view_model/chat_view_model.dart';
import 'package:jiabu/l10n/generated/app_localizations_en.dart';
import 'package:jiabu/l10n/generated/app_localizations_zh.dart';
import 'package:jiabu/shared/chatweave/chat_composer.dart';
import 'package:jiabu/shared/chatweave/chat_file_chip.dart';
import 'package:jiabu/shared/chatweave/jiabu_chatweave_theme.dart';
import 'package:jiabu/shared/chatweave/user_message_note.dart';
import 'package:jiabu_design/jiabu_design.dart';

import '../fixtures/jpeg_fixture.dart';
import '../support/c3_harness.dart';
import '../support/chat_harness.dart';

class _Documents implements DocumentPickerPort {
  List<PickedDocument> documents = [];
  @override
  Future<List<PickedDocument>> pickDocuments({
    required int limit,
    required int maxBytes,
    required int maxImageBytes,
  }) async => documents;
}

class _Repository implements ChatRepository {
  _Repository(this.session);
  final ChatConversation session;
  @override
  Future<Result<ChatConversation>> open(
    String spaceId,
    ClientCapabilities caps,
  ) async => Ok(session);
  @override
  Future<void> foreground() async {}
  @override
  Future<void> disconnect() => session.disconnect();
  @override
  Future<void> dispose() async {}
}

Uint8List _pdf(String body) =>
    Uint8List.fromList(ascii.encode('%PDF-1.4\n$body\n%%EOF\n'));

void main() {
  group('file chips', () {
    testWidgets('composer draft shows removable PDF chips', (tester) async {
      await pumpC3(tester, child: const C5Preview(state: 'composer_files'));
      expect(find.text('虚构发票.pdf'), findsOneWidget);
      expect(find.text('240 KB'), findsOneWidget);
      expect(find.text('1.5 MB'), findsOneWidget);
      for (final file in c5Files) {
        final remove = find.byKey(ValueKey('chat-file-remove-${file.sha256}'));
        expect(remove, findsOneWidget);
        expect(tester.getSize(remove).height, greaterThanOrEqualTo(44));
      }
      expect(find.byTooltip('移除文件'), findsNWidgets(2));
      // Long names end in an ellipsis inside the chip's maximum width.
      final long = find.byKey(ValueKey('chat-file-${c5Files.last.sha256}'));
      expect(
        tester.getSize(long).width,
        lessThanOrEqualTo(JiabuChatMetrics.fileChip),
      );
    });

    testWidgets('removing a chip reports its hash', (tester) async {
      final removed = <String>[];
      await pumpC3(
        tester,
        child: JiabuChatWeaveTheme(
          child: ChatDraftAttachments(
            images: const ['photo'],
            files: c5Files,
            onRemoveImage: removed.add,
            onRemoveFile: removed.add,
          ),
        ),
      );
      await tester.tap(
        find.byKey(ValueKey('chat-file-remove-${c5Files.first.sha256}')),
      );
      expect(removed, [c5Files.first.sha256]);
    });

    testWidgets('files alone make the message sendable', (tester) async {
      final store = BlockStore();
      final actions = InteractionController(
        store: store,
        persistence: CatalogChatStore(),
        nextId: () => '00000000-0000-7000-8000-000000000002',
        transport: CatalogQueuedAction(),
      );
      final composer = InterruptComposerController(
        store: store,
        interactions: actions,
        conversationId: 'conversation',
      );
      addTearDown(() async {
        await composer.dispose();
        await actions.dispose();
        await store.dispose();
      });
      final sent = <String>[];
      await pumpC3(
        tester,
        settle: false,
        child: JiabuChatWeaveTheme(
          child: JiabuChatComposer(
            composer: composer,
            draft: '',
            onDraft: (_) {},
            onSend: (text) async {
              sent.add(text);
              return true;
            },
            onAttach: () {},
            fileCount: 1,
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('chat-send')));
      await tester.pump();
      expect(sent, ['']);
    });

    testWidgets('sent note shows non-interactive PDF chips', (tester) async {
      await pumpC3(tester, child: const C5Preview(state: 'user_files'));
      expect(find.text('虚构发票.pdf'), findsOneWidget);
      expect(find.text('240 KB'), findsOneWidget);
      expect(find.text('1.5 MB'), findsOneWidget);
      expect(find.byType(ChatFileChip), findsNWidgets(2));
      expect(find.byTooltip('移除文件'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(ChatFileChip),
          matching: find.byType(IconButton),
        ),
        findsNothing,
      );
    });

    testWidgets('a files-only note has no empty text line', (tester) async {
      await pumpC3(
        tester,
        child: JiabuChatWeaveTheme(
          child: UserMessageNote(
            message: Message.fromJson({
              'id': 'user',
              'role': 'user',
              'rev': 1,
              'status': 'complete',
              'conversationId': 'conversation',
              'createdAt': '2026-10-29T12:00:00Z',
              'blocks': <Object?>[],
              'fallbackText': '',
              'metadata': {
                'input': {
                  'text': '',
                  'images': <String>[],
                  'files': [
                    {
                      'sha256': c5Files.first.sha256,
                      'name': c5Files.first.name,
                      'mime': 'application/pdf',
                      'bytes': c5Files.first.bytes,
                    },
                  ],
                },
              },
            }),
            delivery: ChatDelivery.complete,
          ),
        ),
      );
      expect(find.byType(ChatFileChip), findsOneWidget);
      expect(find.text(''), findsNothing);
    });
  });

  test('sizes are rounded for display', () {
    final zh = AppLocalizationsZh();
    expect(chatFileSize(zh, 1), '1 KB');
    expect(chatFileSize(zh, 1024), '1 KB');
    expect(chatFileSize(zh, 1025), '2 KB');
    expect(chatFileSize(zh, 1024 * 1024), '1.0 MB');
    expect(chatFileSize(AppLocalizationsEn(), 10 * 1024 * 1024), '10.0 MB');
  });

  test('error codes have their own messages', () {
    final zh = AppLocalizationsZh();
    expect(chatErrorLabel(zh, 'chat_files_too_many'), zh.chatFilesTooMany);
    expect(chatErrorLabel(zh, 'chat_file_too_large'), zh.chatFileTooLarge);
    expect(chatErrorLabel(zh, 'chat_files_too_large'), zh.chatFilesTooLarge);
    expect(chatErrorLabel(zh, 'chat_file_not_pdf'), zh.chatFileNotPdf);
    expect(chatErrorLabel(zh, 'chat_file_unsupported'), zh.chatFileUnsupported);
    expect(chatErrorLabel(zh, 'image_too_large'), zh.chatImageTooLarge);
    expect(chatErrorLabel(zh, 'chat_too_large'), zh.chatLimit);
  });

  test('view model attaches, removes and sends files', () async {
    final documents = _Documents();
    final h = await ChatHarness.create(documents: documents);
    final container = ProviderContainer(
      overrides: [
        chatRepositoryProvider.overrideWithValue(_Repository(h.session)),
      ],
    );
    final provider = chatViewModelProvider('s', 'zh');
    final subscription = container.listen(provider, (_, _) {});
    for (
      var i = 0;
      i < 100 && container.read(provider).conversation == null;
      i++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    final vm = container.read(provider.notifier);
    // One 文件-tab selection: a photo file and two PDFs.
    documents.documents = [
      PickedDocument(
        mime: 'image/jpeg',
        size: 1,
        name: 'a.jpg',
        bytes: testJpeg(),
      ),
      PickedDocument(name: 'a.pdf', size: 1, bytes: _pdf('a')),
      PickedDocument(name: 'b.pdf', size: 1, bytes: _pdf('b')),
    ];
    await vm.attachDocuments();
    var state = container.read(provider);
    expect(state.files.map((file) => file.name), ['a.pdf', 'b.pdf']);
    expect(state.images, hasLength(1));
    expect(h.session.draftImages, state.images);
    expect(state.error, isNull);
    expect(h.session.draftFiles, state.files);
    // Too many in total: nothing more is attached, the error says why.
    documents.documents = [
      for (final name in ['c', 'd', 'e'])
        PickedDocument(name: '$name.pdf', size: 1, bytes: _pdf(name)),
    ];
    await vm.attachDocuments();
    state = container.read(provider);
    expect(state.files, hasLength(2));
    expect(state.error, 'chat_files_too_many');
    vm.removeFile(state.files.first.sha256);
    state = container.read(provider);
    expect(state.files.map((file) => file.name), ['b.pdf']);
    await Future<void>.delayed(Duration.zero);
    expect((await h.h.store.chatClientState('s', '@draft:m'))['files'], [
      state.files.single.toJson(),
    ]);
    expect(await vm.send(''), isTrue);
    expect(container.read(provider).files, isEmpty);
    expect(h.session.draftFiles, isEmpty);
    final send = (await h.h.store.outbox('s'))
        .singleWhere((op) => op.kind == 'chat_send');
    expect(send.payload['files'], [
      {'sha256': state.files.single.sha256, 'name': 'b.pdf'},
    ]);
    expect(send.payload['images'], state.images);
    expect(
      (await h.h.store.outbox('s')).where((op) => op.kind == 'blob'),
      hasLength(3),
    );
    subscription.close();
    container.dispose();
    await h.close();
  });
}
