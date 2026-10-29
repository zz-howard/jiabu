import 'package:chatweave_core/chatweave_core.dart';
import 'package:jiabu/data/api/api_error.dart';
import 'package:jiabu/data/db/daos/local_store.dart';
import 'package:jiabu/domain/outbox_operation.dart';

final class JiabuActionTransport implements ActionTransport {
  JiabuActionTransport(this.dao, this.fence, {this.onEnqueued});
  final LocalStore dao;
  final RequestFence fence;
  final void Function()? onEnqueued;

  @override
  Future<ActionSubmission> submit(
    ActionRequest request,
  ) => dao.transaction(() async {
    await dao.lockRuntime();
    if (!await dao.accepts(fence)) {
      throw const ApiError('stale_response');
    }
    if ((await dao.runtime())['write_allowed'] != 1) {
      throw const ApiError('client_too_old');
    }
    final context = request['context']! as Map<String, Object?>;
    final message = context['messageId']! as String;
    final state = await dao.chatClientState(fence.spaceId, message);
    final receipt = (state['receipts'] as Map<String, Object?>?)?[request.id];
    if (receipt is Map<String, Object?>) {
      return ActionSubmission.result(ActionResult.fromJson(receipt));
    }
    final queue = await dao.outbox(fence.spaceId);
    if (!queue.any((op) => op.id == request.id)) {
      // A new explicit answer may replace a permanently rejected intent. Keep
      // its receipt for diagnosis; never discard an uncertain/in-flight action.
      for (final old in queue.where(
        (op) => op.kind == 'chat_action' && op.state == 'failed',
      )) {
        final target = old.payload['context']! as Map<String, Object?>;
        if (target['messageId'] == message &&
            target['blockId'] == context['blockId']) {
          await dao.removeOp(fence.spaceId, old.id);
        }
      }
      await dao.enqueue(
        OutboxOperation(
          id: request.id,
          spaceId: fence.spaceId,
          joinEpoch: fence.joinEpoch,
          kind: 'chat_action',
          payload: request.json,
          entityIds: {'chat_entry:$message'},
          dependsOn: const {},
          requestId: request.id,
          createdAt: DateTime.now().microsecondsSinceEpoch,
        ),
      );
      dao.afterCommit(onEnqueued);
    }
    // Never patch selected/resolved here. Only the server owns that state.
    return const ActionSubmission.queued();
  });
}
