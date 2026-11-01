import 'dart:async';

import 'package:chatweave_core/chatweave_core.dart';

/// The chat list's view of a conversation's [BlockStore].
///
/// ChatWeave's list counts every snapshot that adds a message as new content
/// ("N new") while the reader is scrolled up. A page of older (or, after a
/// jump, newer) history is not new, so its messages are left out of the
/// snapshots the list is notified with. The list still draws them: it reads
/// [snapshot] on every build. Everything else goes to [source], which the
/// conversation owns and disposes.
final class ChatHistoryStore implements BlockStore {
  ChatHistoryStore(this.source, this.paged);
  final BlockStore source;

  /// Ids of the messages that came in with a page (a live view).
  final Set<String> Function() paged;

  @override
  int get ringCapacity => source.ringCapacity;

  @override
  StoreSnapshot get snapshot => source.snapshot;

  @override
  Stream<StoreSnapshot> get changes => source.changes.map(_live);

  StoreSnapshot _live(StoreSnapshot snapshot) {
    final hidden = paged();
    if (hidden.isEmpty) {
      return snapshot;
    }
    return StoreSnapshot({
      for (final entry in snapshot.messages.entries)
        if (!hidden.contains(entry.key)) entry.key: entry.value,
    }, snapshot.cursors);
  }

  @override
  Json? activityFor(String id) => source.activityFor(id);

  @override
  StoreSnapshot apply(StoreEvent event) => source.apply(event);

  @override
  void recordDiagnostic(String kind, String id, Json metadata) =>
      source.recordDiagnostic(kind, id, metadata);

  @override
  Json inspect({bool includeContent = false}) =>
      source.inspect(includeContent: includeContent);

  @override
  Future<void> dispose() async {}
}
