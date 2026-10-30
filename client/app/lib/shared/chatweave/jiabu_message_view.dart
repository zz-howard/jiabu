import 'package:chatweave_flutter/chatweave_flutter.dart';
import 'package:flutter/material.dart';
import 'package:jiabu/l10n/generated/app_localizations.dart';
import 'package:jiabu/shared/chatweave/jiabu_process_strip.dart';
import 'package:jiabu/shared/chatweave/jiabu_thinking_indicator.dart';
import 'package:jiabu_design/jiabu_design.dart';

/// CW2 has no processStripBuilder. Reuse the MessageView handed to the public
/// frame hook, including its list-owned anchor keys and resize callbacks.
class JiabuMessageView extends StatelessWidget {
  const JiabuMessageView({required this.source, this.onRetry, super.key});
  final MessageView source;
  final VoidCallback? onRetry;
  void _reveal(BuildContext context, String id) {
    final target = source.blockKeys?[id]?.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : context.jiabu.motion.cardIn,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final message = source.message;
    final l = AppLocalizations.of(context);
    final active = const {'streaming', 'paused'}.contains(message.status);
    final thinking = jiabuShowsThinking(message) && !source.stopRequested;
    final name = context.jiabu.type.badge.copyWith(
      color: context.jiabu.colors.ink2,
    );
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: JiabuChatMetrics.width),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Round seal + name (design-spec 4.9), 8 above the reply.
            Padding(
              padding: const EdgeInsets.only(bottom: JiabuSpacing.sm),
              child: Row(
                key: const Key('chat-assistant-name'),
                children: [
                  const ChatAvatarSeal(),
                  const SizedBox(width: JiabuSpacing.sm),
                  Flexible(child: Text(l.chatAssistant, style: name)),
                ],
              ),
            ),
            MessageAnnouncements(message: message),
            if (message.steps.isNotEmpty)
              JiabuProcessStrip(
                message: message,
                state: source.processState,
                onBeforeResize: source.onProcessResize,
                onManualResize: source.onManualProcessResize,
                onReveal: (id) => _reveal(context, id),
              ),
            for (final block in message.blocks)
              KeyedSubtree(
                key: source.blockKeys?[block.id] ?? ValueKey(block.id),
                child: Semantics(
                  liveRegion: false,
                  child: source.registry.render(
                    block,
                    interactions: source.interactions,
                    messageId: message.id,
                    composer: source.composer,
                    readOnly: source.readOnly,
                  ),
                ),
              ),
            if (thinking)
              JiabuThinkingRow(
                label: source.activity?['phase'] == 'degraded'
                    ? l.chatWaitingAi
                    : l.chatThinking,
              ),
            if (active && source.stopRequested)
              Text(l.chatStopping, style: context.jiabu.type.caption),
            if (const {'error', 'interrupted'}.contains(message.status))
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: JiabuChatMetrics.gap,
                children: [
                  Text(
                    message.status == 'error'
                        ? l.chatIncomplete
                        : l.chatStopped,
                    style: context.jiabu.type.secondary,
                  ),
                  if (onRetry != null)
                    TextButton(onPressed: onRetry, child: Text(l.chatRetry)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
