import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/data/db/daos/dao_scope.dart';

void main() {
  for (final sql in [
    'SELECT * FROM records',
    'SELECT COUNT(*) FROM records WHERE id = ?',
    'UPDATE records SET note = ? WHERE id = ?',
    'DELETE FROM records WHERE id = ?',
    'INSERT INTO records (id, data_json) VALUES (?, ?)',
  ]) {
    test(
      'scope_guard_rejects_$sql',
      () => expect(() => DaoScope.verify(sql), throwsStateError),
    );
  }
  test('scope_guard_accepts_scoped_queries_and_explicit_'
      'runtime_exception', () {
    DaoScope.verify('SELECT * FROM records WHERE space_id = ? AND id = ?');
    DaoScope.verify('DELETE FROM records WHERE space_id = ?');
    DaoScope.verify('INSERT INTO records (space_id, id) VALUES (?, ?)');
    DaoScope.verify(
      'SELECT * FROM sync_runtime WHERE id = 1',
      infrastructure: true,
    );
  });
}
