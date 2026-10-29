import 'package:chatweave_core/chatweave_core.dart';
import 'package:jiabu/domain/result.dart';

enum ChatDelivery { pending, failed, waitingAi, complete, manual }

abstract interface class ChatRepository {
  Future<Result<ChatConversation>> open(
    String spaceId,
    ClientCapabilities caps,
  );
  Future<void> foreground();
  Future<void> disconnect();
  Future<void> dispose();
}

/// Core controllers contain no Flutter or persistence implementation details.
abstract interface class ChatConversation {
  String get spaceId;
  String get conversationId;
  BlockStore get blocks;
  InteractionController get interactions;
  InterruptComposerController get composer;
  Stream<void> get changes;
  Map<String, ChatDelivery> get delivery;
  Set<String> get stopRequested;
  bool get online;
  bool get aiUnavailable;
  String? get error;
  set revealInterrupt(
    void Function(String messageId, String blockId)? callback,
  );
  String get draft;
  List<String> get draftImages;
  Future<void> saveDraft(String text, List<String> images);
  Future<Result<void>> send(String text, List<String> images);
  Future<Result<List<int>>> image(String hash);
  Future<Result<List<String>>> photos({required bool camera, int limit = 8});
  Future<Result<void>> retry(String messageId);
  Future<Result<void>> retryUpload(String userMessageId);
  Future<Result<void>> stop(String messageId);
  Future<Result<Map<String, Object?>>> takeOver(String userMessageId);
  Future<void> recover();
  Future<void> disconnect();
}
