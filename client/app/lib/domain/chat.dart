import 'package:chatweave_core/chatweave_core.dart';
import 'package:jiabu/domain/chat_files.dart';
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
  void Function(String messageId, String blockId)? get revealInterrupt;
  set revealInterrupt(
    void Function(String messageId, String blockId)? callback,
  );
  String get draft;
  List<String> get draftImages;
  List<ChatFile> get draftFiles;
  Future<void> saveDraft(
    String text,
    List<String> images,
    List<ChatFile> files,
  );
  Future<Result<void>> send(
    String text,
    List<String> images, {
    List<ChatFile> files = const [],
  });
  Future<Result<List<int>>> image(String hash);
  Future<Result<List<String>>> photos({
    required bool camera,
    bool files = false,
    int limit = 8,
  });

  /// Images and PDFs from the 文件 tab, validated against the limits
  /// together with the [images] and [files] in the draft already.
  Future<Result<ChatAttachments>> documents({
    List<String> images = const [],
    List<ChatFile> files = const [],
  });
  Future<Result<void>> retry(String messageId);
  Future<Result<void>> retryUpload(String userMessageId);
  Future<Result<void>> stop(String messageId);
  Future<Result<Map<String, Object?>>> takeOver(String userMessageId);
  Future<void> recover();
  Future<void> disconnect();
}
