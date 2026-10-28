import 'dart:async';

import 'package:jiabu/app/providers.dart';
import 'package:jiabu/domain/ledger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'ledger_providers.g.dart';

@riverpod
LedgerRepository ledgerRepository(Ref ref) {
  final runtime = ref.watch(appRuntimeProvider);
  final repository = runtime.ledger;
  if (repository == null) {
    throw StateError('No active ledger partition');
  }
  return repository;
}

@riverpod
Stream<String?> currentLedgerSpace(Ref ref) async* {
  final runtime = ref.watch(appRuntimeProvider);
  yield runtime.ledger == null ? null : runtime.currentSpace;
  await for (final _ in runtime.events) {
    yield runtime.ledger == null ? null : runtime.currentSpace;
  }
}

@Riverpod(keepAlive: true)
class MainNavigation extends _$MainNavigation {
  @override
  int build() => 0;
  int get selectedIndex => state;
  set selectedIndex(int index) => state = index;
}

/// Runtime status can change while the current space ID stays equal. A distinct
/// event counter keeps the shell's offline/auth notices reactive as well.
@riverpod
Stream<int> ledgerRuntimeEvents(Ref ref) async* {
  final runtime = ref.watch(appRuntimeProvider);
  var revision = 0;
  yield revision;
  await for (final _ in runtime.events) {
    yield ++revision;
  }
}
