import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricAuthRepository {
  BiometricAuthRepository({LocalAuthentication? auth})
    : _auth = auth ?? LocalAuthentication();

  static const _enabledKey = 'northstar_biometric_enabled';

  final LocalAuthentication _auth;

  Future<bool> isDeviceSupported() async {
    try {
      return await _auth.isDeviceSupported() &&
          await _auth.canCheckBiometrics &&
          (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<String> authenticationName() async {
    try {
      final biometrics = await _auth.getAvailableBiometrics();
      if (biometrics.contains(BiometricType.face)) return 'Face ID';
      if (biometrics.contains(BiometricType.fingerprint)) {
        return 'fingerprint';
      }
      if (biometrics.contains(BiometricType.iris)) return 'iris scan';
      if (biometrics.isNotEmpty) return 'biometric authentication';
    } catch (_) {
      // Fall through to generic device-safe copy.
    }
    return 'biometric authentication';
  }

  Future<bool> isEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_enabledKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
  }

  Future<bool> authenticate({
    String reason = 'Unlock Northstar to continue.',
  }) async {
    if (!await isDeviceSupported()) return false;
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
