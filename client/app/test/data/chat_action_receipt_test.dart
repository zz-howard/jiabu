import 'package:chatweave_core/chatweave_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/data/chat/chat_action_transport.dart';
import 'package:jiabu/features/catalog/c5_cases.dart';

import '../support/chat_harness.dart';

void main() {
  for (final mode in ['timeout', 'restart', 'background']) {
    test(
      'action_receipt_${mode}_reuses_intent_without_second_request',
      () async {
        final h = await ChatHarness.create(offline: false);
        final store = BlockStore()..apply(SyncMessage(c5Message('paused')));
        final transport = JiabuActionTransport(
          h.h.store,
          (await h.h.store.fence('s'))!,
        );
        var controller = InteractionController(
          store: store,
          persistence: h.persistence,
          nextId: () => 'stable-action',
          transport: transport,
        );
        await controller.submit('reply', 'card', {
          'selected': ['credit'],
        });
        expect(
          controller.stateFor('reply', 'card').phase,
          InteractionPhase.queued,
        );
        if (mode != 'timeout') {
          await controller.dispose();
        }
        await h.processor.drain(await h.owner());
        expect(h.api.writes, hasLength(1));
        var resumes = 0;
        if (mode != 'timeout') {
          controller = InteractionController(
            store: store,
            persistence: h.persistence,
            nextId: () => 'must-not-use-this',
            transport: transport,
            onResume: (_) async {
              resumes++;
            },
          );
          await controller.restore('reply');
        }
        await controller.retryPending('reply');
        expect(h.api.writes, hasLength(1));
        expect(await h.h.store.outbox('s'), isEmpty);
        expect(controller.stateFor('reply', 'card').resumeAccepted, isTrue);
        if (mode != 'timeout') expect(resumes, greaterThan(0));
        await controller.dispose();
        await store.dispose();
        await h.close();
      },
    );
  }
}
