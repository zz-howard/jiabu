import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

final class DeviceContext {
  const DeviceContext({
    required this.appVersion,
    required this.build,
    required this.model,
    required this.osVersion,
    this.channel = 'beta',
  });
  final String appVersion;
  final int build;
  final String model;
  final String osVersion;
  final String channel;
  String get clientHeader =>
      '${Platform.isIOS ? 'ios' : 'android'}/'
      '$appVersion+$build; channel=$channel';

  static Future<DeviceContext> load({String channel = 'beta'}) async {
    final package = await PackageInfo.fromPlatform();
    var model = 'unknown';
    var os = Platform.operatingSystem;
    if (Platform.isAndroid) {
      final info = await DeviceInfoPlugin().androidInfo;
      model = info.model;
      os = info.version.release;
    } else if (Platform.isIOS) {
      final info = await DeviceInfoPlugin().iosInfo;
      model = info.utsname.machine;
      os = info.systemVersion;
    }
    return DeviceContext(
      appVersion: package.version,
      build: int.tryParse(package.buildNumber) ?? 1,
      model: model,
      osVersion: os,
      channel: channel,
    );
  }
}
