import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/data/api/api_error.dart';
import 'package:jiabu/data/sync/sync_triggers.dart';

import '../support/sync_harness.dart';

class ManualTimer implements Timer {
  ManualTimer(this.action);
  final void Function() action;
  bool _active = true;
  void fire() {
    if (_active) {
      _active = false;
      action();
    }
  }

  @override
  bool get isActive => _active;
  @override
  int get tick => 0;
  @override
  void cancel() {
    _active = false;
  }
}

class ReachabilityApi extends FakeApi {
  bool reachable = false;
  @override
  Future<void> health() async {
    events.add('health');
    if (!reachable) {
      throw const ApiError('network');
    }
  }
}

void main() {
  test('network_recovery_requires_health_before_a_sync_round', () async {
    final api = ReachabilityApi();
    final h = await SyncHarness.create(api: api);
    addTearDown(h.close);
    final triggers = SyncTriggers(
      h.engine,
      api,
      h.store,
      observeLifecycle: false,
      connectivity: const Stream<List<ConnectivityResult>>.empty(),
      scheduleTask: () async {},
    );
    addTearDown(triggers.dispose);
    await triggers.networkChanged([ConnectivityResult.wifi]);
    expect(api.events, ['health']);
    await triggers.networkChanged([ConnectivityResult.none]);
    api.reachable = true;
    await triggers.networkChanged([ConnectivityResult.wifi]);
    expect(api.events, ['health', 'health', 'spaces']);
  });

  test('outbox_trigger_debounces_one_second_and_foreground_syncs', () async {
    final h = await SyncHarness.create();
    addTearDown(h.close);
    final timers = <ManualTimer>[];
    final durations = <Duration>[];
    var scheduled = 0;
    final triggers = SyncTriggers(
      h.engine,
      h.api,
      h.store,
      observeLifecycle: false,
      connectivity: const Stream<List<ConnectivityResult>>.empty(),
      scheduleTask: () async {
        scheduled++;
      },
      timer: (duration, action) {
        durations.add(duration);
        final timer = ManualTimer(action);
        timers.add(timer);
        return timer;
      },
    );
    addTearDown(triggers.dispose);
    await triggers.start();
    triggers
      ..enqueued()
      ..enqueued();
    expect(durations, everyElement(const Duration(seconds: 1)));
    expect(timers.first.isActive, isFalse);
    expect(h.api.events, isEmpty);
    timers.last.fire();
    await h.engine.runRound();
    expect(h.api.events, contains('spaces'));
    expect(scheduled, 3);
    final before = h.api.events.length;
    await triggers.foreground();
    expect(h.api.events.length, greaterThan(before));
  });
}
