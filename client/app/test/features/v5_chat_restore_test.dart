import 'package:chatweave_flutter/chatweave_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:jiabu/data/services/media_service.dart';
import 'package:jiabu/domain/chat.dart';
import 'package:jiabu/features/catalog/c5_cases.dart';
import 'package:jiabu/l10n/generated/app_localizations.dart';
import 'package:jiabu/l10n/generated/app_localizations_en.dart';
import 'package:jiabu/l10n/generated/app_localizations_zh.dart';
import 'package:jiabu/shared/chatweave/chat_attachment_sheet.dart';
import 'package:jiabu/shared/chatweave/chat_day_tape.dart';
import 'package:jiabu/shared/chatweave/cjk_emphasis.dart';
import 'package:jiabu/shared/chatweave/user_message_note.dart';
import 'package:jiabu_design/jiabu_design.dart';

import '../support/c3_harness.dart';

/// Design-spec 4.9 / 4.10 / 4.17b / 4.7 as restored in V5 (chat page).

double _degrees(WidgetTester tester, Finder finder) =>
    tester.widget<Tilt>(finder).degrees;

Finder _icon(JiabuIconData icon, {Finder? within}) {
  final finder = find.byWidgetPredicate(
    (widget) => widget is JiabuIcon && widget.icon == icon,
  );
  return within == null
      ? finder
      : find.descendant(of: within, matching: finder);
}

Message _message(String id, String createdAt, {String conversation = 'c'}) =>
    Message.fromJson({
      'protocolVersion': '0.1',
      'id': id,
      'conversationId': conversation,
      'role': 'assistant',
      'status': 'complete',
      'rev': 1,
      'createdAt': createdAt,
      'fallbackText': id,
      'blocks': <Object?>[],
    });

void main() {
  group('date tapes', () {
    test('the oldest message of every local day opens it', () {
      final starts = ChatDayBreaks.dayStarts([
        _message('b', '2026-10-28T19:20:05Z'),
        _message('a', '2026-10-28T19:20:00Z'),
        _message('c', '2026-10-29T11:59:59Z'),
        _message('d', '2026-10-29T12:00:00Z'),
        _message('x', '2026-10-27T08:00:00Z', conversation: 'other'),
        _message('e', '2026-11-02T00:00:01Z'),
      ], 'c');
      expect(starts.keys, ['a', 'c', 'e']);
      expect(starts['c'], DateTime(2026, 10, 29));
    });

    test('labels say today / yesterday, then the plain date', () async {
      await initializeDateFormatting();
      final zh = AppLocalizationsZh();
      final en = AppLocalizationsEn();
      final now = DateTime(2026, 10, 29, 9);
      expect(chatDayLabel(DateTime(2026, 10, 29), now, zh), '今天 · 10月29日 周四');
      expect(chatDayLabel(DateTime(2026, 10, 28), now, zh), '昨天 · 10月28日 周三');
      expect(chatDayLabel(DateTime(2026, 10, 24), now, zh), '10月24日 周六');
      expect(
        chatDayLabel(DateTime(2026, 10, 29), now, en),
        startsWith('Today · Oct 29'),
      );
    });

    for (final locale in ['zh', 'en']) {
      testWidgets('conversation_shows_one_tape_per_day_$locale', (
        tester,
      ) async {
        await pumpC3(
          tester,
          locale: locale,
          child: const C5Preview(state: 'conversation'),
        );
        final tapes = find.byKey(const Key('chat-day-tape'));
        expect(tapes, findsNWidgets(2));
        final l = lookupAppLocalizations(Locale(locale));
        expect(
          find.descendant(
            of: tapes,
            matching: find.textContaining(l.handYesterday),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: tapes,
            matching: find.textContaining(l.handToday),
          ),
          findsOneWidget,
        );
        // Centred on the page, tilted like every date tape.
        final tape = tester.getRect(tapes.last);
        expect((tape.center.dx - 180).abs(), lessThan(2));
        expect(
          _degrees(
            tester,
            find.descendant(of: tapes.last, matching: find.byType(Tilt)).first,
          ),
          _ctx(tester).jiabu.decor.dateTilt,
        );
      });
    }
  });

  group('assistant seal', () {
    testWidgets('round primary seal at -10 before the name', (tester) async {
      await pumpC3(tester, child: const C5Preview(state: 'conversation'));
      final seal = find.byType(ChatAvatarSeal).last;
      expect(seal, findsOneWidget);
      final tilt = find.descendant(of: seal, matching: find.byType(Tilt));
      expect(_degrees(tester, tilt), JiabuChatMetrics.avatarTilt);
      expect(
        tester.getSize(
          find.descendant(of: tilt, matching: find.byType(Container)),
        ),
        const Size.square(JiabuChatMetrics.avatar),
      );
      expect(_icon(JiabuIcons.doodleStar, within: seal), findsOneWidget);
      final name = tester.getRect(find.text('家簿助手').last);
      final rect = tester.getRect(seal);
      expect(rect.right, lessThanOrEqualTo(name.left));
      expect((rect.center.dy - name.center.dy).abs(), lessThan(4));
    });
  });

  group('my sticky note', () {
    testWidgets('small note, handwritten time under it, 56 lead', (
      tester,
    ) async {
      await pumpC3(tester, child: const C5Preview(state: 'user_waiting_ai'));
      final note = find.byType(NoteBubble);
      final time = find.byKey(const Key('chat-note-time'));
      expect(tester.widget<Text>(time).data, '12:00');
      expect(
        tester.widget<Text>(time).style!.fontFamily,
        JiabuType.numeralsFamily,
      );
      expect(
        tester.getRect(time).top,
        greaterThan(tester.getRect(note).bottom),
      );
      // The note only carries what I wrote; a normal state says nothing.
      expect(
        find.descendant(of: note, matching: find.text('改为手动填写')),
        findsNothing,
      );
      expect(find.text('待 AI 处理'), findsNothing);
      expect(find.byKey(const Key('chat-note-status')), findsNothing);
      expect(
        tester.getRect(note).left,
        greaterThanOrEqualTo(JiabuChatMetrics.noteLead),
      );
    });

    testWidgets('retry is a small text link with a 44 tap area', (
      tester,
    ) async {
      var taps = 0;
      await pumpC3(
        tester,
        child: _NoteHost(
          child: UserMessageNote(
            message: Message.fromJson({
              'id': 'user',
              'role': 'user',
              'rev': 1,
              'status': 'complete',
              'conversationId': 'conversation',
              'createdAt': '2026-10-29T15:14:00Z',
              'blocks': <Object?>[],
              'fallbackText': '午饭 68',
              'metadata': {
                'input': {'text': '午饭 68', 'images': <String>[]},
              },
            }),
            delivery: ChatDelivery.failed,
            onRetry: () => taps++,
          ),
        ),
      );
      final link = find.text('重试');
      final style = tester.widget<Text>(link).style!;
      expect(style.fontSize, lessThanOrEqualTo(13));
      expect(style.decoration, TextDecoration.underline);
      expect(find.byType(TextButton), findsNothing);
      final tap = find.ancestor(of: link, matching: find.byType(InkWell));
      expect(tester.getSize(tap).height, greaterThanOrEqualTo(44));
      await tester.tap(link);
      expect(taps, 1);
      expect(find.text('15:14'), findsOneWidget);
    });

    testWidgets('a delivered note has no state line, only the time', (
      tester,
    ) async {
      await pumpC3(tester, child: const C5Preview(state: 'conversation'));
      expect(find.byKey(const Key('chat-note-status')), findsNothing);
      expect(find.byKey(const Key('chat-note-time')), findsNWidgets(2));
    });
  });

  group('answer pills', () {
    testWidgets(
      'pills alternate tilt; the answer gets primary-soft and a check',
      (tester) async {
        await pumpC3(tester, child: const C5Preview(state: 'conversation'));
        final pills = find.byType(ChatOptionPill);
        expect(pills, findsNWidgets(4));
        final decor = _ctx(tester).jiabu.decor;
        for (var i = 0; i < 4; i++) {
          final pill = pills.at(i);
          expect(
            _degrees(
              tester,
              find.descendant(of: pill, matching: find.byType(Tilt)).first,
            ),
            i.isEven ? decor.answerOddTilt : decor.answerEvenTilt,
          );
          expect(
            tester.getSize(pill).height,
            greaterThanOrEqualTo(JiabuChatMetrics.option),
          );
        }
        final chosen = find.byKey(const ValueKey('chat-option-credit'));
        expect(tester.widget<ChatOptionPill>(chosen).selected, isTrue);
        expect(_icon(JiabuIcons.uiCheck, within: chosen), findsOneWidget);
        final shape =
            tester
                    .widget<DecoratedBox>(
                      find
                          .descendant(
                            of: chosen,
                            matching: find.byType(DecoratedBox),
                          )
                          .first,
                    )
                    .decoration
                as ShapeDecoration;
        expect(shape.color, _ctx(tester).jiabu.colors.primarySoft);
        final other = find.byKey(const ValueKey('chat-option-cash'));
        expect(_icon(JiabuIcons.uiCheck, within: other), findsNothing);
        expect(
          tester
              .widget<Opacity>(
                find.descendant(of: other, matching: find.byType(Opacity)),
              )
              .opacity,
          .5,
        );
        expect(tester.widget<ChatOptionPill>(other).onPressed, isNull);
      },
    );

    testWidgets('question is highlighted and written on the page, not a card', (
      tester,
    ) async {
      await pumpC3(tester, child: const C5Preview(state: 'choice_open'));
      final question = find.text('用哪张卡付的？');
      expect(
        find.ancestor(
          of: question,
          matching: find.byKey(const Key('jiabu-text-highlight')),
        ),
        findsOneWidget,
      );
      expect(
        find.ancestor(of: question, matching: find.byType(PaperCard)),
        findsNothing,
      );
      expect(find.byType(HandUnderline), findsNothing);
      final options = find.byKey(const Key('chat-choice-options'));
      expect(
        tester.getSize(options).width,
        lessThanOrEqualTo(JiabuChatMetrics.width),
      );
      expect(find.byType(TextButton), findsNothing);
    });

    testWidgets('open pills have no check; other-input is a 0° dashed pill', (
      tester,
    ) async {
      await pumpC3(tester, child: const C5Preview(state: 'paused'));
      final pills = find.byType(ChatOptionPill);
      expect(_icon(JiabuIcons.uiCheck, within: pills.first), findsNothing);
      final other = find.byKey(const ValueKey('chat-option-other'));
      expect(other, findsOneWidget);
      expect(
        _degrees(
          tester,
          find.descendant(of: other, matching: find.byType(Tilt)).first,
        ),
        0,
      );
      expect(_icon(JiabuIcons.doodlePencil, within: other), findsOneWidget);
      expect(tester.getSize(other).height, greaterThanOrEqualTo(44));
    });
  });

  group('floating composer', () {
    testWidgets('no camera button; paperclip in a paper field; round send', (
      tester,
    ) async {
      await pumpC3(tester, child: const C5Preview(state: 'composer_idle'));
      expect(find.byKey(const ValueKey('chat-camera')), findsNothing);
      expect(find.byType(PaperRoundButton), findsNothing);
      final field = find.byKey(const Key('paper-composer-field'));
      expect(_icon(JiabuIcons.doodlePencil, within: field), findsOneWidget);
      final attach = find.descendant(
        of: field,
        matching: find.byKey(const ValueKey('chat-attach')),
      );
      expect(attach, findsOneWidget);
      final clip = _icon(JiabuIcons.uiAttach, within: attach);
      expect(clip, findsOneWidget);
      final pencil = tester.widget<JiabuIcon>(
        _icon(JiabuIcons.doodlePencil, within: field),
      );
      final glyph = tester.widget<JiabuIcon>(clip);
      // Same line family as camera / image / nav icons, pencil's ink and
      // roughly its optical size.
      expect(glyph.icon.strokeWidth, JiabuIcons.uiCamera.strokeWidth);
      expect(glyph.icon.category, JiabuIcons.uiCamera.category);
      expect(glyph.color, pencil.color);
      expect(glyph.size, inInclusiveRange(20, 22));
      expect(
        tester.getSize(attach).height,
        greaterThanOrEqualTo(JiabuChatMetrics.fieldButton),
      );
      expect(tester.widget<IconButton>(attach).tooltip, '附件');
      // The field now starts at the composer's left inset.
      expect(
        tester.getRect(field).left -
            tester.getRect(find.byKey(const Key('chat-composer'))).left,
        closeTo(JiabuSpacing.md, .5),
      );
      expect(
        tester.getSize(field).height,
        greaterThanOrEqualTo(JiabuChatMetrics.fieldHeight),
      );
      final input = tester.widget<TextField>(
        find.byKey(const ValueKey('chat-input')),
      );
      expect(input.decoration!.border, InputBorder.none);
      // No full-width white bar behind it any more.
      final bar =
          tester
                  .widget<DecoratedBox>(find.byKey(const Key('chat-composer')))
                  .decoration
              as BoxDecoration;
      expect(bar.color, isNull);
      expect(bar.border, isNull);
      final disc = find.byKey(const ValueKey('chat-send-disc'));
      final tilt = find.ancestor(of: disc, matching: find.byType(Tilt)).first;
      expect(_degrees(tester, tilt), 0);
      await tester.enterText(find.byKey(const ValueKey('chat-input')), '午饭 68');
      await tester.pump();
      expect(
        _degrees(
          tester,
          find
              .ancestor(
                of: find.byKey(const ValueKey('chat-send-disc')),
                matching: find.byType(Tilt),
              )
              .first,
        ),
        JiabuChatMetrics.sendTilt,
      );
    });
  });

  group('attachment sheet', () {
    testWidgets('gallery tab: camera tile first in a three-column grid', (
      tester,
    ) async {
      await pumpC3(tester, child: const C5Preview(state: 'attach_gallery'));
      final sheet = find.byKey(const Key('jiabu-sheet'));
      expect(sheet, findsOneWidget);
      final camera = tester.getRect(
        find.byKey(const ValueKey('chat-attach-camera')),
      );
      final gallery = tester.getRect(
        find.byKey(const ValueKey('chat-attach-gallery')),
      );
      final grid = tester.getRect(find.byKey(const Key('chat-attach-grid')));
      expect(camera.left, closeTo(grid.left, .5));
      expect(gallery.left, greaterThan(camera.right));
      expect(camera.top, closeTo(gallery.top, .5));
      expect(camera.width, closeTo((grid.width - JiabuSpacing.sm * 2) / 3, .5));
      expect(camera.height, greaterThanOrEqualTo(camera.width - .5));
      expect(find.text('拍照'), findsOneWidget);
      expect(find.text('从相册选择'), findsOneWidget);
      expect(find.byKey(const Key('chat-attach-files-note')), findsNothing);
      // Tabs sit at the bottom; 相册 is selected and tilted like the badge.
      final tabs = find.byKey(const Key('chat-attach-tabs'));
      expect(tester.getRect(tabs).top, greaterThan(camera.bottom));
      final tab = tester.widget<PaperSegmentedTabs>(tabs);
      expect(tab.selected, 0);
      expect(tab.labels, ['相册', '文件']);
      for (final key in ['paper-tab-0', 'paper-tab-1']) {
        expect(
          tester.getSize(find.byKey(ValueKey(key))).height,
          greaterThanOrEqualTo(44),
        );
      }
    });

    testWidgets('files tab: images or PDFs, with the limits note', (
      tester,
    ) async {
      await pumpC3(tester, child: const C5Preview(state: 'attach_gallery'));
      await tester.tap(find.byKey(const ValueKey('paper-tab-1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('chat-attach-files')), findsOneWidget);
      expect(find.byKey(const ValueKey('chat-attach-camera')), findsNothing);
      expect(find.text('选择图片或 PDF 文件'), findsOneWidget);
      expect(
        find.text('可选图片或 PDF：每条最多 8 张图片、4 个 PDF，每个 PDF 不超过 10 MB，合计不超过 20 MB'),
        findsOneWidget,
      );
    });

    for (final (tab, key, source) in [
      (0, 'chat-attach-camera', ChatAttachSource.camera),
      (0, 'chat-attach-gallery', ChatAttachSource.gallery),
      (1, 'chat-attach-files', ChatAttachSource.files),
    ]) {
      testWidgets('tile_${key}_resolves_the_sheet_to_$source', (tester) async {
        ChatAttachSource? picked;
        await pumpC3(
          tester,
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  picked = await showChatAttachmentSheet(context),
              child: const Text('open'),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        if (tab == 1) {
          await tester.tap(find.byKey(const ValueKey('paper-tab-1')));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.byKey(ValueKey(key)));
        await tester.pumpAndSettle();
        expect(picked, source);
        expect(find.byKey(const Key('chat-attachment-sheet')), findsNothing);
      });
    }

    test('the 文件 tab asks Android for images and PDFs', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      const channel = MethodChannel('jiabu/image_files');
      MethodCall? call;
      Object? reply = {
        'documents': [
          {
            'kind': 'pdf',
            'name': '虚构发票.pdf',
            'size': 3,
            'path': '/fictional/cache/document-1.part',
          },
          {
            'kind': 'image',
            'name': null,
            'size': 70,
            'path': '/fictional/cache/document-2.part',
          },
        ],
      };
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (request) async {
            call = request;
            return reply;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      Future<List<PickedDocument>> pick() =>
          PlatformDocumentPicker().pickDocuments(
            imageSlots: 8,
            fileSlots: 3,
            maxBytes: 10 * 1024 * 1024,
            maxImageBytes: 64 * 1024 * 1024,
          );
      final picked = await pick();
      expect(call?.method, 'pickDocuments');
      expect(call?.arguments, {
        'imageSlots': 8,
        'fileSlots': 3,
        'maxBytes': 10 * 1024 * 1024,
        'maxImageBytes': 64 * 1024 * 1024,
      });
      expect(picked.first.name, '虚构发票.pdf');
      expect(picked.first.isImage, isFalse);
      expect(picked.first.path, '/fictional/cache/document-1.part');
      expect(picked.last.isImage, isTrue);
      expect(picked.last.name, isNull);
      expect(picked.last.size, 70);
      // The platform rejects an over-limit selection before copying it.
      reply = {'rejected': 'chat_files_too_many'};
      await expectLater(
        pick(),
        throwsA(
          isA<DocumentSelectionRejected>().having(
            (rejected) => rejected.code,
            'code',
            'chat_files_too_many',
          ),
        ),
      );
    });

    test('without a native picker, PDFs are unsupported', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      await expectLater(
        PlatformDocumentPicker(
          channel: const MethodChannel('jiabu/fictional_missing'),
        ).pickDocuments(
          imageSlots: 1,
          fileSlots: 1,
          maxBytes: 1,
          maxImageBytes: 1,
        ),
        throwsA(isA<DocumentPickerUnavailable>()),
      );
    });

    test('image files from the document picker, at most nine', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      const channel = MethodChannel('jiabu/image_files');
      MethodCall? call;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (request) async {
            call = request;
            return [
              for (var i = 0; i < 12; i++) Uint8List.fromList([i]),
            ];
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final picked = await PlatformImagePicker().pick(
        camera: false,
        files: true,
      );
      expect(call?.method, 'pick');
      expect(call?.arguments, {'limit': 9});
      expect(picked, hasLength(9));
    });
  });

  group('torn bottom edge', () {
    test('scallops rise half their width above the bar', () {
      final bounds = PaperTornEdgePainter.edge(360).getBounds();
      expect(
        bounds.top,
        closeTo(-JiabuLedgerMetrics.navigationScallop / 2, .5),
      );
      expect(bounds.right, greaterThanOrEqualTo(360));
    });

    testWidgets('the bottom bar paints the torn edge', (tester) async {
      await pumpC3(tester, child: const C5Preview(state: 'conversation'));
      final edge = find.byKey(const Key('paper-navigation-edge'));
      expect(edge, findsOneWidget);
      expect(
        tester.widget<CustomPaint>(edge).painter,
        isA<PaperTornEdgePainter>(),
      );
    });
  });

  group('markdown next to Chinese punctuation', () {
    test('bold closes and opens beside full-width punctuation', () {
      for (final (source, fixed) in [
        ('**记账：**后面', '**记账：​**后面'),
        ('点**「编辑」**修改', '点**​「编辑」​**修改'),
        ('用**招行卡**付的', '用**招行卡**付的'),
        ('`a：**b` **x：**y', '`a：**b` **x：​**y'),
        ('* 列表项', '* 列表项'),
      ]) {
        expect(cjkEmphasis(source), fixed, reason: source);
      }
    });

    testWidgets('no raw asterisks reach the screen', (tester) async {
      await pumpC3(tester, child: const C5Preview(state: 'conversation'));
      expect(find.textContaining('**', findRichText: true), findsNothing);
      expect(find.textContaining('已记好', findRichText: true), findsOneWidget);
    });
  });

  testWidgets('conversation fits 360 and 430 at 100% and 200% text', (
    tester,
  ) async {
    for (final width in [360.0, 430.0]) {
      for (final scale in [1.0, 2.0]) {
        for (final locale in ['zh', 'en']) {
          await pumpC3(
            tester,
            width: width,
            scale: scale,
            locale: locale,
            child: C5Preview(
              key: ValueKey('$width-$scale-$locale'),
              state: 'conversation',
            ),
          );
          expect(tester.takeException(), isNull);
          for (final pill in find.byType(ChatOptionPill).evaluate()) {
            final rect = tester.getRect(find.byWidget(pill.widget));
            expect(rect.right, lessThanOrEqualTo(width + 1));
            expect(rect.left, greaterThanOrEqualTo(-1));
          }
        }
      }
    }
  });
}

BuildContext _ctx(WidgetTester tester) =>
    tester.element(find.byKey(c3Boundary));

/// A lone note at the right of a 360 column.
class _NoteHost extends StatelessWidget {
  const _NoteHost({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topRight,
    child: SizedBox(width: 360, child: child),
  );
}
