import 'dart:typed_data';

import 'package:chatweave_flutter/chatweave_flutter.dart';
import 'package:flutter/material.dart';
import 'package:jiabu/domain/chat.dart';
import 'package:jiabu/domain/result.dart';
import 'package:jiabu/l10n/generated/app_localizations.dart';
import 'package:jiabu/shared/chatweave/chat_day_tape.dart';
import 'package:jiabu_design/jiabu_design.dart';

class UserMessageNote extends StatelessWidget {
  const UserMessageNote({
    required this.message,
    required this.delivery,
    this.onRetry,
    this.onManual,
    this.image,
    super.key,
  });
  final Message message;
  final ChatDelivery delivery;
  final VoidCallback? onRetry;
  final VoidCallback? onManual;
  final Future<Result<List<int>>> Function(String)? image;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final input = object(
      object(message['metadata'] ?? <String, Object?>{})['input'] ??
          <String, Object?>{},
    );
    final images = (input['images'] as List<Object?>? ?? []).cast<String>();
    final colors = context.jiabu.colors;
    final status = delivery == ChatDelivery.complete
        ? null
        : switch (delivery) {
            ChatDelivery.pending => l.chatPending,
            ChatDelivery.failed => l.chatFailed,
            ChatDelivery.waitingAi => l.chatWaitingAi,
            ChatDelivery.manual => l.chatManualState,
            ChatDelivery.complete => '',
          };
    final manual = const {
      ChatDelivery.pending,
      ChatDelivery.failed,
      ChatDelivery.waitingAi,
      ChatDelivery.manual,
    }.contains(delivery);
    final time = chatMessageTime(message, l);
    // Design-spec 4.9: a small sticky note with only what I wrote (and my
    // photos); its state and the small 「改为手动填写」 link sit under it,
    // then the handwritten time. 56 of free paper stays on the left.
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
              NoteBubble(
                id: message.id,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${input['text'] ?? message['fallbackText'] ?? ''}',
                      style: context.jiabu.type.body,
                    ),
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
              if (status != null || manual)
                Wrap(
                  key: const Key('chat-note-status'),
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: JiabuSpacing.sm,
                  children: [
                    if (status != null)
                      Text(
                        status,
                        style: context.jiabu.type.badge.copyWith(
                          color: delivery == ChatDelivery.failed
                              ? colors.warn
                              : colors.ink2,
                        ),
                      ),
                    if (delivery == ChatDelivery.failed)
                      _NoteLink(label: l.chatRetry, onPressed: onRetry),
                    if (manual)
                      _NoteLink(label: l.chatManual, onPressed: onManual),
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
