enum SyncState { synced, pending, conflict }

enum OutboxState { pending, sending, failed, blocked }

/// C5 supplies the three chat uploaders. C2 must never consume their entries.
enum OutboxKind { tool, blob, chatSend, chatAction, chatRetry }

enum SyncStatus {
  idle,
  syncing,
  offline,
  loginRequired,
  passwordChangeRequired,
  clientTooOld,
  serverTooOld,
  retryLater,
}
