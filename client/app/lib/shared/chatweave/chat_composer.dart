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
    required this.onPhoto,
    required this.onGallery,
    this.busy = false,
    this.photoCount = 0,
    super.key,
  });
  final InterruptComposerController composer;
  final String draft;
  final ValueChanged<String> onDraft;
  final Future<bool> Function(String) onSend;
  final VoidCallback onPhoto;
  final VoidCallback onGallery;
  final bool busy;
  final int photoCount;
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
      return DecoratedBox(
        decoration: BoxDecoration(
          color: context.jiabu.colors.paper,
          border: Border(
            top: BorderSide(color: context.jiabu.colors.lineStrong),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(JiabuChatMetrics.gap),
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
              TextField(
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
                  filled: true,
                  fillColor: locked
                      ? context.jiabu.colors.surface2
                      : context.jiabu.colors.paper,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      JiabuChatMetrics.fieldRadius,
                    ),
                  ),
                ),
              ),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  IconButton(
                    tooltip: l.chatPhoto,
                    onPressed: !locked && !answering && !widget.busy
                        ? widget.onPhoto
                        : null,
                    icon: const JiabuIcon(JiabuIcons.uiCamera),
                  ),
                  IconButton(
                    tooltip: l.chatGallery,
                    onPressed: !locked && !answering && !widget.busy
                        ? widget.onGallery
                        : null,
                    icon: const JiabuIcon(JiabuIcons.uiImage),
                  ),
                  if (widget.photoCount > 0)
                    Text(
                      l.chatPhotoCount(widget.photoCount),
                      style: context.jiabu.type.caption,
                    ),
                  TextButton.icon(
                    onPressed: locked || widget.busy
                        ? null
                        : () => unawaited(_send(answering)),
                    icon: const JiabuIcon(JiabuIcons.uiSend),
                    label: Text(l.chatSend),
                  ),
                ],
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
