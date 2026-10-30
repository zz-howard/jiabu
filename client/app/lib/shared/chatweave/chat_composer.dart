import 'dart:async';

import 'package:chatweave_flutter/chatweave_flutter.dart';
import 'package:flutter/material.dart';
import 'package:jiabu/l10n/generated/app_localizations.dart';
import 'package:jiabu_design/jiabu_design.dart';

class JiabuChatComposer extends StatefulWidget {
  const JiabuChatComposer({
    required this.composer,
    required this.draft,
    required this.onDraft,
    required this.onSend,
    required this.onAttach,
    this.busy = false,
    this.photoCount = 0,
    this.stopActive = false,
    this.stopRequested = false,
    this.onStop,
    super.key,
  });
  final InterruptComposerController composer;
  final String draft;
  final ValueChanged<String> onDraft;
  final Future<bool> Function(String) onSend;

  /// The paperclip in the field: opens the attachment sheet (camera,
  /// gallery, image files).
  final VoidCallback onAttach;
  final bool busy;
  final int photoCount;

  /// The AI is processing a reply: with nothing typed the round button is the
  /// stop button (Telegram style); typing flips it back to send.
  final bool stopActive;
  final bool stopRequested;
  final VoidCallback? onStop;
  @override
  State<JiabuChatComposer> createState() => _JiabuChatComposerState();
}

class _JiabuChatComposerState extends State<JiabuChatComposer> {
  late final TextEditingController _text;
  final _focus = FocusNode();
  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.draft);
    _attach();
  }

  void _attach() =>
      widget.composer.attachDraft(TextControllerDraft(_text, _focus));
  @override
  void didUpdateWidget(JiabuChatComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.composer != widget.composer) _attach();
    if (widget.draft != _text.text) {
      _text.value = TextEditingValue(
        text: widget.draft,
        selection: TextSelection.collapsed(offset: widget.draft.length),
      );
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<InterruptComposerState>(
    stream: widget.composer.changes,
    initialData: widget.composer.state,
    builder: (context, snapshot) {
      final state = snapshot.data ?? widget.composer.state;
      final l = AppLocalizations.of(context);
      final locked = const {
        ComposerMode.locked,
        ComposerMode.submitting,
      }.contains(state.mode);
      final answering = state.mode == ComposerMode.answering;
      final question =
          state.block?.data['prompt'] ?? state.block?.data['title'] ?? '';
      // Design-spec 4.17b (V5b, Telegram-like): no full-width bar. The field
      // is a small floating paper card (pencil inside, paperclip at its end
      // opening the attachment sheet) next to the round send / stop button.
      return DecoratedBox(
        key: const Key('chat-composer'),
        decoration: const BoxDecoration(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            JiabuSpacing.md,
            JiabuChatMetrics.gap,
            JiabuSpacing.md,
            JiabuSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (answering)
                Container(
                  padding: const EdgeInsets.only(left: JiabuChatMetrics.gap),
                  color: context.jiabu.colors.note,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          l.chatReply('$question'),
                          style: context.jiabu.type.secondary,
                        ),
                      ),
                      IconButton(
                        tooltip: l.chatCancelAnswer,
                        onPressed: widget.composer.cancelOtherInput,
                        icon: const JiabuIcon(JiabuIcons.uiClose),
                      ),
                    ],
                  ),
                ),
              if (locked)
                InkWell(
                  onTap: widget.composer.revealInterrupt,
                  child: Padding(
                    padding: const EdgeInsets.all(JiabuChatMetrics.gap),
                    child: Row(
                      children: [
                        const JiabuIcon(
                          JiabuIcons.uiLock,
                          size: JiabuChatMetrics.icon,
                        ),
                        const SizedBox(width: JiabuChatMetrics.gap),
                        Expanded(child: Text(l.chatLocked)),
                      ],
                    ),
                  ),
                ),
              if (state.closedReason != null)
                Text(switch (state.closedReason) {
                  'answered_elsewhere' => l.chatAnsweredElsewhere,
                  'expired' => l.chatExpired,
                  'stopped' => l.chatStopped,
                  _ => l.chatWithdrawn,
                }, style: context.jiabu.type.caption),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: JiabuSpacing.sm),
                      child: PaperComposerField(
                        locked: locked,
                        trailing: Builder(
                          builder: (context) {
                            final enabled =
                                !locked && !answering && !widget.busy;
                            return IconButton(
                              key: const ValueKey('chat-attach'),
                              tooltip: l.chatAttach,
                              constraints: const BoxConstraints.tightFor(
                                width: JiabuChatMetrics.fieldButton,
                                height: JiabuChatMetrics.fieldButton,
                              ),
                              padding: EdgeInsets.zero,
                              onPressed: enabled ? widget.onAttach : null,
                              // Lucide paperclip, same line family as the
                              // camera / image / nav icons; pencil's ink
                              // and optical size.
                              icon: JiabuIcon(
                                JiabuIcons.uiAttach,
                                size: JiabuChatMetrics.attachIcon,
                                color: enabled
                                    ? context.jiabu.colors.ink3
                                    : context.jiabu.colors.lineStrong,
                              ),
                            );
                          },
                        ),
                        child: TextField(
                          key: const ValueKey('chat-input'),
                          controller: _text,
                          focusNode: _focus,
                          onChanged: widget.onDraft,
                          enabled: !locked && !widget.busy,
                          minLines: 1,
                          maxLines: 4,
                          style: context.jiabu.type.body,
                          decoration: InputDecoration(
                            hintText: locked ? l.chatLocked : l.chatInput,
                            hintStyle: context.jiabu.type.body.copyWith(
                              color: context.jiabu.colors.ink3,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            isDense: true,
                          ),
                        ),
                      ),
                    ),
                  ),
                  ListenableBuilder(
                    listenable: _text,
                    builder: (context, _) {
                      final hasInput =
                          _text.text.trim().isNotEmpty ||
                          (!answering && widget.photoCount > 0);
                      final stop =
                          widget.stopActive &&
                          widget.onStop != null &&
                          !hasInput;
                      final enabled = stop
                          ? !widget.stopRequested
                          : hasInput && !locked && !widget.busy;
                      final colors = context.jiabu.colors;
                      return Padding(
                        padding: const EdgeInsets.only(
                          bottom: JiabuChatMetrics.roundLift,
                        ),
                        child: Semantics(
                          button: true,
                          enabled: enabled,
                          label: stop
                              ? (widget.stopRequested
                                    ? l.chatStopping
                                    : l.chatStop)
                              : l.chatSend,
                          excludeSemantics: true,
                          child: GestureDetector(
                            key: ValueKey(stop ? 'chat-stop' : 'chat-send'),
                            behavior: HitTestBehavior.opaque,
                            onTap: enabled
                                ? (stop
                                      ? widget.onStop
                                      : () => unawaited(_send(answering)))
                                : null,
                            child: SizedBox.square(
                              dimension: JiabuChatMetrics.action,
                              child: Center(
                                child: Tilt(
                                  // Turns −8° once there is something to send
                                  // (original `.has-text .cmp-send`).
                                  degrees: enabled && !stop
                                      ? JiabuChatMetrics.sendTilt
                                      : 0,
                                  child: DecoratedBox(
                                    key: const ValueKey('chat-send-disc'),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: enabled
                                          ? colors.primary
                                          : colors.surface3,
                                      border: Border.all(
                                        color: colors.white,
                                        width: JiabuChatMetrics.roundRing,
                                      ),
                                      boxShadow:
                                          context.jiabu.decor.stickerShadow,
                                    ),
                                    child: SizedBox.square(
                                      dimension: JiabuChatMetrics.sendDisc,
                                      child: Center(
                                        child: JiabuIcon(
                                          stop
                                              ? JiabuIcons.uiStop
                                              : JiabuIcons.uiSend,
                                          color: enabled
                                              ? colors.onPrimary
                                              : colors.ink3,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              if (widget.photoCount > 0)
                Text(
                  l.chatPhotoCount(widget.photoCount),
                  style: context.jiabu.type.caption,
                ),
            ],
          ),
        ),
      );
    },
  );
  Future<void> _send(bool answering) async {
    if (answering) {
      await widget.composer.submitOtherInput(_text.text);
      if (mounted) widget.onDraft(_text.text);
    } else if (await widget.onSend(_text.text) && mounted) {
      _text.clear();
    }
  }

  @override
  void dispose() {
    widget.composer.attachDraft(_DetachedDraft(_text.text));
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }
}

class _DetachedDraft implements DraftPort {
  _DetachedDraft(this.text);
  @override
  String text;
  @override
  void focus() {}
}
