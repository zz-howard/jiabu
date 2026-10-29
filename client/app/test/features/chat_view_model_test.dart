import 'package:chatweave_core/chatweave_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/app/chat_providers.dart';
import 'package:jiabu/domain/chat.dart';
import 'package:jiabu/domain/result.dart';
import 'package:jiabu/features/chat/view_model/chat_view_model.dart';

import '../support/chat_harness.dart';

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

void main() {
  test(
    'chat_view_model_retains_failed_draft_and_clears_only_after_enqueue',
    () async {
      final h = await ChatHarness.create();
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
      final vm = container.read(provider.notifier)..draft('午饭 68');
      expect(await vm.send(''), false);
      expect(container.read(provider).draft, '午饭 68');
      expect(container.read(provider).error, 'chat_empty');
      expect(await vm.send('午饭 68'), true);
      expect(container.read(provider).draft, '');
      expect((await h.h.store.outbox('s')).single.kind, 'chat_send');
      subscription.close();
      container.dispose();
      await h.close();
    },
  );
}
