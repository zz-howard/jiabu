import 'dart:math' as math;

import 'package:chatweave_flutter/chatweave_flutter.dart';
import 'package:flutter/material.dart';
import 'package:jiabu_design/jiabu_design.dart';

/// Whether the assistant is between visible output: the reply is still being
/// produced and no block is being filled right now (streaming text or a
/// component placeholder speaks for itself). That is before the first token,
/// between tool calls and while a tool runs. The row never appears while text
/// is arriving, after a stop, or once the reply has finished.
bool jiabuShowsThinking(Message message) {
  if (message.status != 'streaming') return false;
  final last = message.blocks.lastOrNull;
  return last == null || last['status'] != 'pending';
}

/// The tail row under the reply (design-spec 4.17a): indented, three pulsing
/// dots and a small muted label, so it reads as a status note and not as part
/// of the reply text. It is the last thing in the message, so it stays in view
/// while the list follows the bottom.
class JiabuThinkingRow extends StatelessWidget {
  const JiabuThinkingRow({required this.label, super.key});
  final String label;

  @override
  Widget build(BuildContext context) {
    final style = context.jiabu.type.caption.copyWith(
      color: context.jiabu.colors.ink3,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.4,
    );
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: JiabuChatMetrics.thinkingIndent,
        top: JiabuChatMetrics.thinkingGapTop,
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: JiabuChatMetrics.gap,
        children: [
          const JiabuThinkingDots(),
          Text(label, style: style),
        ],
      ),
    );
  }
}

/// Three small ink-3 dots that pulse in turn, inside the row below the reply.
/// Static (all dots equally soft) when the system asks for reduced motion,
/// so goldens and screen readers see one stable shape.
class JiabuThinkingDots extends StatefulWidget {
  const JiabuThinkingDots({super.key});
  @override
  State<JiabuThinkingDots> createState() => _JiabuThinkingDotsState();
}

class _JiabuThinkingDotsState extends State<JiabuThinkingDots>
    with SingleTickerProviderStateMixin {
  static const _dots = 3;
  late final AnimationController _controller = AnimationController(vsync: this);
  bool _animating = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final period = context.jiabu.motion.typing;
    final animate =
        !MediaQuery.disableAnimationsOf(context) && period > Duration.zero;
    if (animate == _animating) return;
    _animating = animate;
    if (animate) {
      _controller
        ..duration = context.jiabu.motion.typing
        ..repeat();
    } else {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _opacity(double t, int index) {
    if (!_animating) return 0.6;
    final phase = (t - index / _dots) % 1;
    return 0.3 + 0.7 * (0.5 + 0.5 * math.cos(2 * math.pi * phase));
  }

  @override
  Widget build(BuildContext context) {
    final color = context.jiabu.colors.ink3;
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < _dots; i++) ...[
              if (i > 0) const SizedBox(width: JiabuChatMetrics.rowGap),
              Opacity(
                opacity: _opacity(_controller.value, i),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: const SizedBox.square(
                    dimension: JiabuChatMetrics.thinkingDot,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
