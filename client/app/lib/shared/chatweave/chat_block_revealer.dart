import 'package:chatweave_flutter/chatweave_flutter.dart';
import 'package:flutter/material.dart';

/// CW2 exposes block keys through its message frame, but no list reveal API.
/// Use public Scrollable APIs when a paused message has been recycled. The
/// common mounted case is a single ensureVisible; the bounded fallback walks
/// older viewports until the list builds the target key. No physics override.
class ChatBlockRevealer {
  final _anchors = <String, BlockAnchorKey>{};
  ScrollableState? _scrollable;
  int _generation = 0;
  bool _closed = false;

  void register(BuildContext context, MessageView source) {
    _scrollable = Scrollable.maybeOf(context) ?? _scrollable;
    for (final entry
        in (source.blockKeys ?? <String, BlockAnchorKey>{}).entries) {
      _anchors['${source.message.id}/${entry.key}'] = entry.value;
    }
  }

  Future<void> reveal(String messageId, String blockId) async {
    final generation = ++_generation;
    final key = '$messageId/$blockId';
    Future<bool> show() async {
      final context = _anchors[key]?.currentContext;
      if (context == null || !context.mounted) return false;
      await Scrollable.ensureVisible(context);
      return true;
    }

    if (await show()) return;
    final scrollable = _scrollable;
    if (_closed || scrollable == null || !scrollable.mounted) return;
    final position = scrollable.position;
    // Reverse chat: zero is newest. A question can be above offline user notes.
    position.jumpTo(0);
    for (
      var page = 0;
      page < 200 && !_closed && generation == _generation;
      page++
    ) {
      await WidgetsBinding.instance.endOfFrame;
      if (!scrollable.mounted || !position.hasPixels) return;
      if (await show()) return;
      final next = (position.pixels + position.viewportDimension).clamp(
        0.0,
        position.maxScrollExtent,
      );
      if (next == position.pixels) return;
      position.jumpTo(next);
    }
  }

  void dispose() {
    _closed = true;
    _generation++;
    _anchors.clear();
    _scrollable = null;
  }
}
