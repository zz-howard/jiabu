import 'package:jiabu/data/repositories/auth_repository.dart';
import 'package:jiabu/data/sync/sync_engine.dart';
import 'package:jiabu/domain/result.dart';

/// Independent-isolate coordination. The app composition root creates plugins
/// and dependencies; this data layer never imports app/ or a feature.
Future<bool> runBackgroundOutbox({
  required LocalAuthRepository auth,
  required Future<void> Function() prepare,
  required SyncEngine? Function() engine,
}) async {
  try {
    final result = await auth.resume();
    if (result is Failure<AuthSession?>) {
      return result.status == 401;
    }
    await prepare();
    await engine()?.runRound();
    final store = auth.handle?.store;
    if (store != null) {
      for (final id in await store.spaceIds()) {
        final pending = await store.outbox(id);
        if (pending.any(
          (op) =>
              (op.kind == 'tool' || op.kind == 'blob') &&
              (op.state == 'pending' || op.state == 'sending'),
        )) {
          return false;
        }
      }
    }
    return engine() == null || engine()?.status.name == 'idle';
  } on Object {
    return false;
  }
}
