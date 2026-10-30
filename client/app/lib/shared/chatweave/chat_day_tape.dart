import 'package:chatweave_flutter/chatweave_flutter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jiabu/l10n/generated/app_localizations.dart';
import 'package:jiabu_design/jiabu_design.dart';

/// Local calendar day of a message; ChatWeave timestamps are UTC ISO 8601.
DateTime? chatMessageDay(Message message) {
  final at = DateTime.tryParse(message['createdAt'] as String? ?? '')
      ?.toLocal();
  return at == null ? null : DateTime(at.year, at.month, at.day);
}

/// The handwritten time under my sticky note (design-spec 4.9), e.g. 15:14.
String chatMessageTime(Message message, AppLocalizations l) {
  final at = DateTime.tryParse(message['createdAt'] as String? ?? '')
      ?.toLocal();
  return at == null ? '' : DateFormat.Hm(l.localeName).format(at);
}

/// 「今天 · 10月29日 周四」 / 「昨天 · …」 / 「10月24日 周六」.
String chatDayLabel(DateTime day, DateTime now, AppLocalizations l) {
  final date = DateFormat.MMMd(l.localeName).add_E().format(day);
  // Calendar days in UTC, so a daylight-saving switch never shifts them.
  final days = DateTime.utc(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime.utc(day.year, day.month, day.day)).inDays;
  return switch (days) {
    0 => '${l.handToday} · $date',
    1 => '${l.handYesterday} · $date',
    _ => date,
  };
}

/// Which messages open a new day in the list (design-spec 4.9): the oldest
/// message of every local calendar day gets a date tape above it. ChatWeave's
/// list hands its builders one message at a time, so the breaks are computed
/// once per store snapshot (snapshots are immutable maps) and looked up per
/// message.
class ChatDayBreaks {
  ChatDayBreaks(this.conversationId);
  final String conversationId;
  Map<String, Message>? _source;
  var _starts = const <String, DateTime>{};

  DateTime? dayStartedBy(Map<String, Message> messages, String id) {
    if (!identical(messages, _source)) {
      _source = messages;
      _starts = dayStarts(messages.values, conversationId);
    }
    return _starts[id];
  }

  static Map<String, DateTime> dayStarts(
    Iterable<Message> messages,
    String conversationId,
  ) {
    final ordered =
        messages.where((m) => m['conversationId'] == conversationId).toList()
          ..sort(
            (a, b) => (a['createdAt'] as String? ?? '').compareTo(
              b['createdAt'] as String? ?? '',
            ),
          );
    final starts = <String, DateTime>{};
    DateTime? last;
    for (final message in ordered) {
      final day = chatMessageDay(message);
      if (day != null && day != last) {
        starts[message.id] = day;
        last = day;
      }
    }
    return starts;
  }
}

/// A message with the day's date tape above it when it opens a new day.
class ChatDayFrame extends StatelessWidget {
  const ChatDayFrame({
    required this.day,
    required this.now,
    required this.child,
    super.key,
  });
  final DateTime? day;
  final DateTime now;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final day = this.day;
    if (day == null) return child;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: JiabuSpacing.md),
          child: Center(
            child: Semantics(
              header: true,
              child: DateTapeLabel(
                key: const Key('chat-day-tape'),
                text: chatDayLabel(day, now, AppLocalizations.of(context)),
                pattern: TapePattern.stripe,
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
