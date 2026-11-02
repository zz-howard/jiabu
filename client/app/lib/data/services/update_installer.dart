import 'package:flutter/services.dart';
import 'package:jiabu/domain/update.dart';

abstract interface class UpdateInstaller {
  Future<bool> verifySignature(String path);
  Future<bool> canInstall();
  Future<void> openInstallSettings();
  Future<InstallResult> install(String path);
}

final class PlatformUpdateInstaller implements UpdateInstaller {
  PlatformUpdateInstaller({MethodChannel? channel})
    : channel = channel ?? const MethodChannel('jiabu/update_installer');
  final MethodChannel channel;

  @override
  Future<bool> verifySignature(String path) async =>
      await channel.invokeMethod<bool>('verifySignature', {'path': path}) ??
      false;
  @override
  Future<bool> canInstall() async =>
      await channel.invokeMethod<bool>('canInstall') ?? false;
  @override
  Future<void> openInstallSettings() =>
      channel.invokeMethod<void>('openInstallSettings');
  @override
  Future<InstallResult> install(String path) async =>
      switch (await channel.invokeMethod<String>('install', {'path': path})) {
        'success' => InstallResult.success,
        'cancelled' => InstallResult.cancelled,
        _ => InstallResult.failed,
      };
}
