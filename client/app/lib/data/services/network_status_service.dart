import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

final class NetworkStatusService {
  NetworkStatusService({required this.probe, required this.onChanged});
  final Future<void> Function() probe;
  final void Function() onChanged;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool online = false;
  bool? _hasInterface;
  int _generation = 0;

  Future<void> start() async {
    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      unawaited(update(results));
    });
    await update(await Connectivity().checkConnectivity());
  }

  Future<void> update(List<ConnectivityResult> results) async {
    final generation = ++_generation;
    _hasInterface = results.any((value) => value != ConnectivityResult.none);
    online = false;
    onChanged();
    if (_hasInterface == false) {
      return;
    }
    try {
      await probe();
      if (generation == _generation) {
        online = true;
        onChanged();
      }
    } on Object {
      // A network interface alone is not proof that the server is reachable.
    }
  }

  void reached() {
    if (_hasInterface == false) {
      return;
    }
    ++_generation;
    online = true;
    onChanged();
  }

  void failed() {
    ++_generation;
    online = false;
    onChanged();
  }

  Future<void> dispose() async {
    ++_generation;
    await _subscription?.cancel();
  }
}
