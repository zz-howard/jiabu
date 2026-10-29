import 'package:local_auth/local_auth.dart';

abstract interface class BiometricAuthService {
  Future<bool> available();
  Future<bool> authenticate(String reason);
}

final class PlatformBiometricAuth implements BiometricAuthService {
  PlatformBiometricAuth({LocalAuthentication? authentication})
    : authentication = authentication ?? LocalAuthentication();
  final LocalAuthentication authentication;

  @override
  Future<bool> available() async {
    try {
      return await authentication.canCheckBiometrics &&
          (await authentication.getAvailableBiometrics()).isNotEmpty;
    } on Object {
      return false;
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      if (!await available()) {
        return false;
      }
      // TODO(luna): verify local_auth 3.x named arguments after pub get.
      return await authentication.authenticate(
        localizedReason: reason,
        biometricOnly: true,
      );
    } on Object {
      // Unsupported hardware, no enrollment, failure and cancellation all leave
      // the gate locked. PIN is always available.
      return false;
    }
  }
}
