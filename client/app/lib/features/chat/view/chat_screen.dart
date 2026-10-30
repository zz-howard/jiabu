import 'dart:async';

import 'package:chatweave_flutter/chatweave_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jiabu/app/chat_providers.dart';
import 'package:jiabu/app/ledger_providers.dart';
import 'package:jiabu/domain/chat.dart';
import 'package:jiabu/features/chat/view_model/chat_view_model.dart';
import 'package:jiabu/features/chat/widgets/chat_composer.dart';
import 'package:jiabu/features/chat/widgets/user_message_note.dart';
import 'package:jiabu/l10n/generated/app_localizations.dart';
import 'package:jiabu/shared/chatweave/chat_block_revealer.dart';
import 'package:jiabu/shared/chatweave/chat_day_tape.dart';
import 'package:jiabu/shared/chatweave/jiabu_chatweave_theme.dart';
import 'package:jiabu/shared/chatweave/jiabu_message_view.dart';
import 'package:jiabu/shared/ledger/ledger_forms.dart';
import 'package:jiabu/shared/ledger/ledger_view_model.dart';
import 'package:jiabu_design/jiabu_design.dart';

class ChatScreen extends ConsumerWidget {
  const ChatScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final space = ref.watch(currentLedgerSpaceProvider).asData?.value;
    return space == null
        ? Center(child: Text(AppLocalizations.of(context).ledgerNoSpace))
        : _ChatPage(key: ValueKey(space), spaceId: space);
  }
}

class _ChatPage extends ConsumerStatefulWidget {
  const _ChatPage({required this.spaceId, super.key});
  final String spaceId;
  @override
  ConsumerState<_ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<_ChatPage> {
  final _revealer = ChatBlockRevealer();
  ChatDayBreaks? _days;
  String get spaceId => widget.spaceId;
  ChatDayBreaks _dayBreaks(String conversationId) {
    final current = _days;
    if (current != null && current.conversationId == conversationId) {
      return current;
    }
    return _days = ChatDayBreaks(conversationId);
  }

  @override
  void dispose() {
    _revealer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final provider = chatViewModelProvider(spaceId, locale);
    final state = ref.watch(provider);
    final vm = ref.read(provider.notifier);
    final session = state.conversation;
    final ledger = ref.watch(ledgerViewModelProvider(spaceId)).snapshot;
    final registry = ref.watch(chatRegistryProvider(spaceId));
    if (session == null) {
      return Center(
        child: Text(state.error == null ? l.ledgerLoading : l.chatError),
      );
    }
    session.revealInterrupt = (message, block) =>
        unawaited(_revealer.reveal(message, block));
    // The reply being processed (streaming or waiting for an answer): the
    // composer's round button becomes its stop button.
    final activeId = session.blocks.snapshot.messages.values
        .where(
          (m) =>
              m['role'] != 'user' &&
              const {'streaming', 'paused'}.contains(m.status),
        )
        .lastOrNull
        ?.id;
    // The assistant's reply in Jiabu's message view; my own notes pass
    // through. Every message that opens a new day gets the date tape.
    Widget frame(BuildContext context, Message message, Widget child) {
      if (message['role'] == 'user' || child is! MessageView) return child;
      _revealer.register(context, child);
      return JiabuMessageView(
        source: MessageView(
          message: child.message,
          registry: child.registry,
          processState: child.processState,
          interactions: child.interactions,
          composer: child.composer,
          blockKeys: child.blockKeys,
          activity: child.activity,
          onProcessResize: child.onProcessResize,
          onManualProcessResize: child.onManualProcessResize,
          stopRequested:
              session.stopRequested.contains(message.id) ||
              state.stopping.contains(message.id),
        ),
        onRetry:
            message.status == 'error' ||
                (message.status == 'interrupted' &&
                    !session.stopRequested.contains(message.id))
            ? () => unawaited(vm.command(() => session.retry(message.id)))
            : null,
      );
    }

    final days = _dayBreaks(session.conversationId);
    final now = ref.watch(ledgerClockProvider)();
    Future<void> manual(String id) async {
      final initial = await vm.takeOver(id);
      if (context.mounted && initial != null) {
        await openManualEntry(context, spaceId, initial: initial);
      }
    }

    return JiabuChatWeaveTheme(
      child: Column(
        children: [
          if (session.aiUnavailable)
            Padding(
              padding: const EdgeInsets.all(JiabuChatMetrics.gap),
              child: NoteBubble(
                id: 'ai-unavailable',
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(l.chatUnavailable),
                    TextButton(
                      onPressed: ledger?.writable == true
                          ? () => openManualEntry(context, spaceId)
                          : null,
                      child: Text(l.chatManualEntry),
                    ),
                  ],
                ),
              ),
            ),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.all(JiabuChatMetrics.gap),
              child: Text(chatErrorLabel(l, state.error)),
            ),
          Expanded(
            child: session.blocks.snapshot.messages.isEmpty
                ? Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(JiabuChatMetrics.gap),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(l.chatEmpty, style: context.jiabu.type.chat),
                          if (ledger != null &&
                              ledger.writable &&
                              ledger.accounts.isEmpty)
                            TextButton(
                              onPressed: () =>
                                  unawaited(vm.send(l.chatSetupRequest)),
                              child: Text(l.chatSetup),
                            ),
                        ],
                      ),
                    ),
                  )
                : ChatWeaveList(
                    key: ObjectKey(session.blocks),
                    store: session.blocks,
                    registry: registry,
                    conversationId: session.conversationId,
                    interactions: session.interactions,
                    composer: session.composer,
                    stopRequested: session.stopRequested,
                    userMessageBuilder: (context, message) => UserMessageNote(
                      message: message,
                      delivery:
                          session.delivery[message.id] ??
                          ChatDelivery.waitingAi,
                      image: session.image,
                      onRetry: () => unawaited(
                        vm.command(() => session.retryUpload(message.id)),
                      ),
                      onManual: ledger?.writable == true
                          ? () => unawaited(manual(message.id))
                          : null,
                    ),
                    messageFrameBuilder: (context, message, child) =>
                        ChatDayFrame(
                          day: days.dayStartedBy(
                            session.blocks.snapshot.messages,
                            message.id,
                          ),
                          now: now,
                          child: frame(context, message, child),
                        ),
                  ),
          ),
          if (state.images.isNotEmpty)
            SizedBox(
              height: JiabuChatMetrics.action,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final hash in state.images)
                    InputChip(
                      label: const JiabuIcon(JiabuIcons.uiImage),
                      deleteIcon: const JiabuIcon(JiabuIcons.uiClose),
                      deleteButtonTooltipMessage: l.chatRemovePhoto,
                      onDeleted: () => vm.removePhoto(hash),
                    ),
                ],
              ),
            ),
          JiabuChatComposer(
            composer: session.composer,
            draft: state.draft,
            onDraft: vm.draft,
            onSend: vm.send,
            onPhoto: () => unawaited(vm.photos(camera: true)),
            onGallery: () => unawaited(vm.photos(camera: false)),
            busy: state.busy,
            photoCount: state.images.length,
            stopActive: activeId != null && session.online,
            stopRequested:
                activeId != null &&
                (session.stopRequested.contains(activeId) ||
                    state.stopping.contains(activeId)),
            onStop: activeId == null
                ? null
                : () => unawaited(vm.stop(activeId)),
          ),
        ],
      ),
    );
  }
}

String chatErrorLabel(AppLocalizations l, String? code) => switch (code) {
  'chat_online_required' => l.chatOnlineRequired,
  'chat_wait_upload' => l.chatWaitUpload,
  'chat_wait_stop' => l.chatWaitStop,
  'chat_already_recorded' => l.chatAlreadyRecorded,
  'chat_too_large' => l.chatLimit,
  _ => l.chatError,
};
