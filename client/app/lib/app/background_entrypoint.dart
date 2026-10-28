import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:jiabu/app/runtime.dart';
import 'package:jiabu/data/sync/background_sync.dart';
import 'package:workmanager/workmanager.dart';

@pragma('vm:entry-point')
void backgroundDispatcher() {
  Workmanager().executeTask((task, input) async {
    if (task != 'outbox') {
      return true;
    }
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    AppRuntime? runtime;
    try {
      final worker = await AppRuntime.create(background: true);
      runtime = worker;
      return await runBackgroundOutbox(
        auth: worker.auth,
        prepare: () => worker.sessionWork,
        engine: () => worker.engine,
      );
    } on Object {
      return false;
    } finally {
      await runtime?.close();
    }
  });
}
