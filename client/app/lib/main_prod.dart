import 'package:jiabu/app/bootstrap.dart';

const configuredChannel = String.fromEnvironment(
  'JIABU_CHANNEL',
  defaultValue: 'stable',
);

Future<void> main() => bootstrap(
  channel: const {'stable', 'beta'}.contains(configuredChannel)
      ? configuredChannel
      : 'stable',
  updatesEnabled: true,
);
