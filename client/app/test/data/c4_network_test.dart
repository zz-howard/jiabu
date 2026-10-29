import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiabu/data/services/network_status_service.dart';

void main() {
  test(
    'network_interface_requires_probe_and_stale_probe_cannot_enable_management',
    () async {
      final probe = Completer<void>();
      var changes = 0;
      final network = NetworkStatusService(
        probe: () => probe.future,
        onChanged: () => changes++,
      );
      expect(network.online, isFalse);
      final checking = network.update([ConnectivityResult.wifi]);
      expect(network.online, isFalse);
      await network.update([ConnectivityResult.none]);
      probe.complete();
      await checking;
      expect(network.online, isFalse);
      network.reached();
      expect(network.online, isFalse);
      expect(changes, greaterThan(0));
      await network.dispose();
    },
  );
}
