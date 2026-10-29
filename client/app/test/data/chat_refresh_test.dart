import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/data/api/api_error.dart';
import 'package:jiabu/data/api/dto/sync_dto.dart';

import '../support/chat_harness.dart';
import '../support/sync_harness.dart';

void main() {
  test(
    'authoritative_chat_refresh_contacts_server_and_fences_late_page',
    () async {
      final h = await SyncHarness.create();
      addTearDown(h.close);
      await h.store.putEntity(
        's',
        'chat_entry',
        chatRow(chatMessage(rev: 1, text: 'cached')),
      );
      h.api.onPull = (request) async => PullResponseDto(
        spaces: [
          PullPageDto(
            spaceId: 's',
            cursor: 1,
            hasMore: false,
            changes: [
              ChangeDto(
                entity: 'chat_entry',
                data: chatRow(chatMessage(rev: 1, text: 'server')),
              ),
            ],
          ),
        ],
        unavailable: [],
      );
      await h.engine.refreshChat('s');
      expect(h.api.pulls, hasLength(1));
      expect(
        (await h.store.entity(
          's',
          'chat_entry',
          'reply',
        ))!.data['fallback_text'],
        'server',
      );
      h.api.onPull = (request) async {
        await h.store.activate(authenticated: true);
        return PullResponseDto(
          spaces: [
            PullPageDto(
              spaceId: 's',
              cursor: 2,
              hasMore: false,
              changes: [
                ChangeDto(
                  entity: 'chat_entry',
                  data: chatRow(chatMessage(rev: 1, text: 'late')),
                ),
              ],
            ),
          ],
          unavailable: [],
        );
      };
      await expectLater(h.engine.refreshChat('s'), throwsA(isA<ApiError>()));
      expect(await h.store.cursor('s'), 1);
      expect(
        (await h.store.entity(
          's',
          'chat_entry',
          'reply',
        ))!.data['fallback_text'],
        'server',
      );
    },
  );
}
