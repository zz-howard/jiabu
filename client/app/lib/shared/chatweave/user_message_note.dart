import 'dart:async';

import 'package:chatweave_flutter/chatweave_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:jiabu/domain/chat.dart';
import 'package:jiabu/domain/result.dart';
import 'package:jiabu/l10n/generated/app_localizations.dart';
import 'package:jiabu/shared/chatweave/chat_day_tape.dart';
import 'package:jiabu_design/jiabu_design.dart';

/// What the long-press menu on my sticky note can do.
enum NoteMenuAction { copy, retry, manual }

class UserMessageNote extends StatelessWidget {
  const UserMessageNote({
    required this.message,
    required this.delivery,
    this.online = true,
    this.onRetry,
    this.onManual,
    this.image,
    super.key,
  });
  final Message message;
  final ChatDelivery delivery;

  /// Whether the chat stream is connected; a queued send while offline is
  /// the only queued state that says anything under the note.
  final bool online;
  final VoidCallback? onRetry;
  final VoidCallback? onManual;
  final Future<Result<List<int>>> Function(String)? image;

  /// States whose note used to carry the 「改为手动填写」 link; it now lives
  /// in the long-press menu for exactly these.
  static const Set<ChatDelivery> manualStates = {
    ChatDelivery.pending,
    ChatDelivery.failed,
    ChatDelivery.waitingAi,
    ChatDelivery.manual,
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final input = object(
      object(message['metadata'] ?? <String, Object?>{})['input'] ??
          <String, Object?>{},
    );
    final text = '${input['text'] ?? message['fallbackText'] ?? ''}';
    final images = (input['images'] as List<Object?>? ?? []).cast<String>();
    final colors = context.jiabu.colors;
    // Normal flow (sending, queued online, waiting for / being answered by
    // AI, answered, switched to manual) says nothing here: the assistant's
    // 「思考中」 already shows progress. Only abnormal states get one line.
    final notice = switch (delivery) {
      ChatDelivery.failed => l.chatNotSent,
      ChatDelivery.pending when !online => l.chatWaitOnline,
      _ => null,
    };
    final retryable = delivery == ChatDelivery.failed && onRetry != null;
    final manual = manualStates.contains(delivery);
    final actions = [
      NoteMenuAction.copy,
      if (retryable) NoteMenuAction.retry,
      if (manual) NoteMenuAction.manual,
    ];
    void run(NoteMenuAction action) {
      switch (action) {
        case NoteMenuAction.copy:
          _copy(context, text);
        case NoteMenuAction.retry:
          onRetry?.call();
        case NoteMenuAction.manual:
          onManual?.call();
      }
    }

    Future<void> menu() async {
      final action = await showNoteMenu(
        context,
        actions: actions,
        manualEnabled: onManual != null,
      );
      if (action != null) {
        run(action);
      }
    }

    final time = chatMessageTime(message, l);
    // Design-spec 4.9: a small sticky note with only what I wrote (and my
    // photos); an abnormal state's single small line sits under it, then
    // the handwritten time. Copy / retry / manual entry are on long press.
    // 56 of free paper stays on the left.
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(left: JiabuChatMetrics.noteLead),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: JiabuChatMetrics.width),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Semantics(
                key: const Key('chat-note-actions'),
                container: true,
                onLongPressHint: l.chatNoteActions,
                // Long press is invisible to screen readers: every menu
                // item is also a custom action on the note.
                customSemanticsActions: {
                  for (final action in actions)
                    if (action != NoteMenuAction.manual || onManual != null)
                      CustomSemanticsAction(label: _label(l, action)): () =>
                          run(action),
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onLongPress: () => unawaited(menu()),
                  child: NoteBubble(
                    id: message.id,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(text, style: context.jiabu.type.body),
                        for (final hash in images)
                          Padding(
                            padding: const EdgeInsets.only(
                              top: JiabuChatMetrics.gap,
                            ),
                            child: Polaroid(
                              caption: l.handOriginalSaved,
                              image: image == null
                                  ? const JiabuIcon(JiabuIcons.uiImage)
                                  : ChatPhoto(load: () => image!(hash)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (notice != null)
                Wrap(
                  key: const Key('chat-note-status'),
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      notice,
                      style: context.jiabu.type.badge.copyWith(
                        color: delivery == ChatDelivery.failed
                            ? colors.warn
                            : colors.ink2,
                      ),
                    ),
                    if (delivery == ChatDelivery.failed) ...[
                      ExcludeSemantics(
                        child: Text(
                          ' · ',
                          style: context.jiabu.type.badge.copyWith(
                            color: colors.ink3,
                          ),
                        ),
                      ),
                      _NoteLink(label: l.chatRetry, onPressed: onRetry),
                    ],
                  ],
                ),
              if (time.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(
                    top: JiabuSpacing.xs,
                    right: JiabuSpacing.xs,
                  ),
                  child: Text(
                    time,
                    key: const Key('chat-note-time'),
                    style: context.jiabu.type.date.copyWith(color: colors.ink3),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static void _copy(BuildContext context, String text) {
    final l = AppLocalizations.of(context);
    unawaited(Clipboard.setData(ClipboardData(text: text)));
    if (ScaffoldMessenger.maybeOf(context) != null) {
      PaperSnackBar.show(
        context: context,
        message: l.chatNoteCopied,
        position: PaperSnackPosition.chat,
      );
    }
  }
}

String _label(AppLocalizations l, NoteMenuAction action) => switch (action) {
  NoteMenuAction.copy => l.chatNoteCopy,
  NoteMenuAction.retry => l.chatRetry,
  NoteMenuAction.manual => l.chatManual,
};

/// The long-press menu on my sticky note: a paper sheet (tape handle) with
/// one 48-high row per action. Resolves to the chosen action, or null.
Future<NoteMenuAction?> showNoteMenu(
  BuildContext context, {
  required List<NoteMenuAction> actions,
  bool manualEnabled = true,
}) => JiabuSheet.show<NoteMenuAction>(
  context: context,
  builder: (sheetContext) => NoteMenu(
    actions: actions,
    manualEnabled: manualEnabled,
    onPick: (action) => Navigator.of(sheetContext).pop(action),
  ),
);

class NoteMenu extends StatelessWidget {
  const NoteMenu({
    required this.actions,
    required this.onPick,
    this.manualEnabled = true,
    super.key,
  });
  final List<NoteMenuAction> actions;
  final ValueChanged<NoteMenuAction> onPick;

  /// Manual entry needs a writable ledger; the row stays, greyed, otherwise.
  final bool manualEnabled;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.jiabu.colors;
    return Column(
      key: const Key('chat-note-menu'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, action) in actions.indexed) ...[
          if (i > 0) Divider(height: 1, thickness: 1, color: colors.line),
          Builder(
            builder: (context) {
              final enabled = action != NoteMenuAction.manual || manualEnabled;
              final ink = enabled ? colors.ink : colors.ink3;
              return Semantics(
                button: true,
                enabled: enabled,
                excludeSemantics: true,
                label: _label(l, action),
                child: InkWell(
                  key: ValueKey('chat-note-menu-${action.name}'),
                  onTap: enabled ? () => onPick(action) : null,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: JiabuChatMetrics.action,
                    ),
                    child: Row(
                      children: [
                        JiabuIcon(
                          switch (action) {
                            NoteMenuAction.copy => JiabuIcons.uiDoc,
                            NoteMenuAction.retry => JiabuIcons.uiRetry,
                            NoteMenuAction.manual => JiabuIcons.uiEdit,
                          },
                          size: JiabuChatMetrics.icon,
                          color: action == NoteMenuAction.retry && enabled
                              ? colors.primaryText
                              : ink,
                        ),
                        const SizedBox(width: JiabuSpacing.md),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: JiabuSpacing.sm,
                            ),
                            child: Text(
                              _label(l, action),
                              style: context.jiabu.type.body.copyWith(
                                color: ink,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

/// A small underlined text link (Sans 13, primary-text) whose tap area is
/// still 44 high, so the note itself stays small (design-spec 4.9).
class _NoteLink extends StatelessWidget {
  const _NoteLink({required this.label, this.onPressed});
  final String label;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onPressed != null,
    excludeSemantics: true,
    label: label,
    child: InkWell(
      onTap: onPressed,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: JiabuLedgerMetrics.recordActionHeight,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: JiabuSpacing.xs),
          child: Center(
            widthFactor: 1,
            child: Text(
              label,
              style: context.jiabu.type.secondary.copyWith(
                color: onPressed == null
                    ? context.jiabu.colors.ink3
                    : context.jiabu.colors.primaryText,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
                decorationColor: context.jiabu.colors.primaryText,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class ChatPhoto extends StatefulWidget {
  const ChatPhoto({required this.load, super.key});
  final Future<Result<List<int>>> Function() load;
  @override
  State<ChatPhoto> createState() => _ChatPhotoState();
}

class _ChatPhotoState extends State<ChatPhoto> {
  late final Future<Result<List<int>>> _image = widget.load();
  @override
  Widget build(BuildContext context) => FutureBuilder<Result<List<int>>>(
    future: _image,
    builder: (context, snapshot) {
      final result = snapshot.data;
      return result is Ok<List<int>>
          ? Image.memory(
              Uint8List.fromList(result.value),
              fit: BoxFit.contain,
              gaplessPlayback: true,
            )
          : const JiabuIcon(JiabuIcons.uiImage);
    },
  );
}
