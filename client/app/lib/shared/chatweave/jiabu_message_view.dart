import 'package:chatweave_flutter/chatweave_flutter.dart';
import 'package:flutter/material.dart';
import 'package:jiabu/l10n/generated/app_localizations.dart';
import 'package:jiabu/shared/chatweave/jiabu_process_strip.dart';
import 'package:jiabu_design/jiabu_design.dart';

/// CW2 has no processStripBuilder. Reuse the MessageView handed to the public
/// frame hook, including its list-owned anchor keys and resize callbacks.
class JiabuMessageView extends StatelessWidget {
  const JiabuMessageView({
    required this.source,
    this.onRetry,
    this.stopEnabled = true,
    super.key,
  });
  final MessageView source;
  final VoidCallback? onRetry;
  final bool stopEnabled;
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
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: JiabuChatMetrics.width),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l.chatAssistant,
              style: context.jiabu.type.caption.copyWith(
                color: context.jiabu.colors.ink3,
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
            if (message.status == 'streaming' && message.steps.isEmpty)
              Text(
                source.activity?['phase'] == 'degraded'
                    ? l.chatWaitingAi
                    : l.chatRunning,
                style: context.jiabu.type.caption,
              ),
            if (active && source.onStop != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: source.stopRequested || !stopEnabled
                      ? null
                      : source.onStop,
                  child: Text(
                    source.stopRequested ? l.chatStopping : l.chatStop,
                  ),
                ),
              ),
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
