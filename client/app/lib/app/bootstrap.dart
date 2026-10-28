import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jiabu/app/background_entrypoint.dart';
import 'package:jiabu/app/partition_host.dart';
import 'package:jiabu/app/providers.dart';
import 'package:jiabu/app/runtime.dart';
import 'package:jiabu_design/jiabu_design.dart';
import 'package:workmanager/workmanager.dart';

Future<void> bootstrap({String channel = 'beta'}) async {
  WidgetsFlutterBinding.ensureInitialized();
  registerJiabuLicenses();
  final runtime = await AppRuntime.create(channel: channel);
  runtime.installStartupLogging();
  await Workmanager().initialize(backgroundDispatcher);
  runApp(
    ProviderScope(
      overrides: [appRuntimeProvider.overrideWith((ref) => runtime)],
      child: const PartitionHost(),
    ),
  );
}
