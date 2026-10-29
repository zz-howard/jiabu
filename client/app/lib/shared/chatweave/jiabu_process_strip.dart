import 'package:chatweave_flutter/chatweave_flutter.dart';
import 'package:flutter/material.dart';
import 'package:jiabu/l10n/generated/app_localizations.dart';
import 'package:jiabu_design/jiabu_design.dart';

class JiabuProcessStrip extends StatefulWidget {
  const JiabuProcessStrip({
    required this.message,
    required this.state,
    this.onReveal,
    this.onBeforeResize,
    this.onManualResize,
    super.key,
  });
  final Message message;
  final ProcessState state;
  final ValueChanged<String>? onReveal;
  final VoidCallback? onBeforeResize;
  final ValueChanged<BlockAnchorKey>? onManualResize;
  @override
  State<JiabuProcessStrip> createState() => _JiabuProcessStripState();
}

class _JiabuProcessStripState extends State<JiabuProcessStrip> {
  final _anchor = GlobalKey<State<StatefulWidget>>();
  @override
  void didUpdateWidget(JiabuProcessStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message.steps.length != widget.message.steps.length ||
        oldWidget.state.expanded(oldWidget.message) !=
            widget.state.expanded(widget.message)) {
      widget.onBeforeResize?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    if (message.steps.isEmpty) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final expanded = widget.state.expanded(message);
    final steps = message.steps
        .where((step) => step['parentStepId'] == null)
        .toList();
    final failures = steps.where((step) => step['state'] == 'failed').length;
    final interrupted = steps.any((step) => step['blockId'] != null);
    final answers = steps
        .where(
          (step) => step['blockId'] != null && step['state'] == 'succeeded',
        )
        .length;
    final milliseconds = steps.fold<int>(
      0,
      (sum, step) => sum + (step['durationMs'] as int? ?? 0),
    );
    final summary = [
      l.chatProcessSummary(steps.length),
      if (failures > 0) l.chatProcessFailed(failures),
      if (interrupted && answers > 0) l.chatConfirmedCount(answers),
      if (!interrupted && message.status == 'complete')
        l.chatDuration((milliseconds / 1000).toStringAsFixed(1)),
      if (message.status == 'interrupted') l.chatStopped,
    ].join(' · ');
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: JiabuChatMetrics.width),
      child: Column(
        key: _anchor,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            button: true,
            expanded: expanded,
            label: '${l.chatProcess}: $summary',
            child: TextButton(
              onPressed: () {
                widget.onManualResize?.call(_anchor);
                setState(() => widget.state.setExpanded(message.id, !expanded));
              },
              child: Row(
                children: [
                  const ExcludeSemantics(
                    child: JiabuIcon(
                      JiabuIcons.uiEdit,
                      size: JiabuChatMetrics.icon,
                    ),
                  ),
                  const SizedBox(width: JiabuChatMetrics.gap),
                  Expanded(
                    child: Text(
                      summary,
                      style: context.jiabu.type.secondary.copyWith(
                        color: failures > 0
                            ? context.jiabu.colors.warn
                            : context.jiabu.colors.ink3,
                      ),
                    ),
                  ),
                  ExcludeSemantics(
                    child: JiabuIcon(
                      expanded ? JiabuIcons.uiDash : JiabuIcons.uiDown,
                      size: JiabuChatMetrics.icon,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            for (final step in message.steps) _step(context, step.json),
          const SizedBox(height: JiabuChatMetrics.gap),
        ],
      ),
    );
  }

  Widget _step(BuildContext context, Json step) {
    final l = AppLocalizations.of(context);
    final waiting = step['state'] == 'awaiting_user';
    final block = widget.message.blocks
        .where((block) => block.id == step['blockId'])
        .firstOrNull;
    final label = switch (step['state']) {
      'succeeded' => l.chatSucceeded,
      'failed' => l.chatIncomplete,
      'cancelled' => l.chatStopped,
      'awaiting_user' =>
        block?.type == 'confirmation' ? l.chatAwaitConfirm : l.chatAwaitAnswer,
      _ => l.chatRunning,
    };
    final icon = switch (step['state']) {
      'succeeded' => JiabuIcons.uiCheck,
      'failed' => JiabuIcons.uiInfo,
      'cancelled' => JiabuIcons.uiDash,
      'awaiting_user' => JiabuIcons.uiRight,
      _ => JiabuIcons.uiClock,
    };
    final color = step['state'] == 'failed'
        ? context.jiabu.colors.warn
        : step['state'] == 'succeeded'
        ? context.jiabu.colors.pos
        : context.jiabu.colors.ink2;
    final duration = step['durationMs'] as int?;
    return Padding(
      padding: EdgeInsets.only(
        left: step['parentStepId'] == null ? 0 : JiabuChatMetrics.stepIndent,
      ),
      child: InkWell(
        onTap: waiting && block != null
            ? () => widget.onReveal?.call(block.id)
            : null,
        child: ChatStepRail(
          child: Container(
            constraints: const BoxConstraints(
              minHeight: JiabuChatMetrics.stepHeight,
            ),
            padding: const EdgeInsets.only(
              left: JiabuChatMetrics.stepIndent,
              bottom: JiabuChatMetrics.rowGap,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: JiabuIcon(
                    icon,
                    size: JiabuChatMetrics.icon,
                    color: color,
                  ),
                ),
                const SizedBox(width: JiabuChatMetrics.gap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${step['label'] ?? ''}',
                        style: context.jiabu.type.secondary.copyWith(
                          color: context.jiabu.colors.ink2,
                        ),
                      ),
                      Wrap(
                        spacing: JiabuChatMetrics.gap,
                        children: [
                          Text(
                            label,
                            style: context.jiabu.type.caption.copyWith(
                              color: color,
                            ),
                          ),
                          if (duration != null)
                            Text(
                              l.chatSeconds(
                                (duration / 1000).toStringAsFixed(1),
                              ),
                              style: context.jiabu.type.date,
                            ),
                        ],
                      ),
                      if (step['summary'] != null)
                        Text(
                          '${step['summary']}',
                          style: context.jiabu.type.caption,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
