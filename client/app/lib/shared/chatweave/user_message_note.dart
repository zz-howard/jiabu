import 'dart:typed_data';

import 'package:chatweave_flutter/chatweave_flutter.dart';
import 'package:flutter/material.dart';
import 'package:jiabu/domain/chat.dart';
import 'package:jiabu/domain/result.dart';
import 'package:jiabu/l10n/generated/app_localizations.dart';
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
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: JiabuChatMetrics.width),
        child: NoteBubble(
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
                  padding: const EdgeInsets.only(top: JiabuChatMetrics.gap),
                  child: Polaroid(
                    degrees: 0,
                    caption: l.handOriginalSaved,
                    image: image == null
                        ? const JiabuIcon(JiabuIcons.uiImage)
                        : ChatPhoto(load: () => image!(hash)),
                  ),
                ),
              if (delivery != ChatDelivery.complete)
                Text(switch (delivery) {
                  ChatDelivery.pending => l.chatPending,
                  ChatDelivery.failed => l.chatFailed,
                  ChatDelivery.waitingAi => l.chatWaitingAi,
                  ChatDelivery.manual => l.chatManualState,
                  ChatDelivery.complete => '',
                }, style: context.jiabu.type.caption),
              Wrap(
                children: [
                  if (delivery == ChatDelivery.failed)
                    TextButton(onPressed: onRetry, child: Text(l.chatRetry)),
                  if (const {
                    ChatDelivery.pending,
                    ChatDelivery.failed,
                    ChatDelivery.waitingAi,
                    ChatDelivery.manual,
                  }.contains(delivery))
                    TextButton(onPressed: onManual, child: Text(l.chatManual)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
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
