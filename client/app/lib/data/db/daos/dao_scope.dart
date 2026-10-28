/// Runtime backstop for every hand-written business query. Keeping it separate
/// also lets the guard tests exercise deliberate unscoped queries safely.
abstract final class DaoScope {
  static void verify(String sql, {bool infrastructure = false}) {
    if (infrastructure) {
      return;
    }
    if (sql.startsWith('INSERT INTO ')) {
      if (!sql.split('VALUES').first.contains('space_id')) {
        throw StateError('space_scope_required');
      }
    } else if (!sql.contains('WHERE space_id = ?')) {
      throw StateError('space_scope_required');
    }
  }
}
