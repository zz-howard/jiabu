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

/// The part of the chat history a conversation holds: a window of the
/// member's timeline that grows a page at a time in either direction.
final class ChatHistory {
  const ChatHistory({
    this.hasOlder = false,
    this.hasNewer = false,
    this.loadingOlder = false,
    this.loadingNewer = false,
    this.oldestId,
    this.precedingCreatedAt,
    this.paged = const {},
  });

  /// Older messages exist before the window.
  final bool hasOlder;

  /// The window stops short of the latest message (after a jump).
  final bool hasNewer;
  final bool loadingOlder;
  final bool loadingNewer;

  /// While [hasOlder]: the window's oldest message and the creation time of
  /// the message just before it, so a date tape opens a day only where the
  /// day really starts.
  final String? oldestId;
  final String? precedingCreatedAt;

  /// Messages that came in with a page rather than arriving live.
  final Set<String> paged;
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

  /// The window [blocks] holds; [loadOlder] and [loadNewer] extend it by a
  /// page. Both are no-ops when there is nothing more or a load is running.
  ChatHistory get history;
  Future<Result<void>> loadOlder();
  Future<Result<void>> loadNewer();
}
