import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart' as rp;
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

/// Presentation ownership, independent of an individual request's fence.
typedef LedgerPresentationSession = ({String partition, String? spaceId});

final ledgerPresentationSessionProvider =
    rp.Provider<LedgerPresentationSession?>((ref) {
      ref.watch(ledgerRuntimeEventsProvider);
      final runtime = ref.watch(appRuntimeProvider);
      final session = runtime.auth.current;
      if (session == null || runtime.ledger == null) {
        return null;
      }
      return (
        partition:
            '${session.partition.prefix}:${session.generation}'
            ':${runtime.revision}',
        spaceId: runtime.currentSpace,
      );
    });

final ledgerClockProvider = rp.Provider<DateTime Function()>(
  (ref) => DateTime.now,
);
