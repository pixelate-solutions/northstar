import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/biometric_auth_repository.dart';

final biometricAuthRepositoryProvider = Provider<BiometricAuthRepository>((
  ref,
) {
  return BiometricAuthRepository();
});

final biometricAuthProvider =
    AsyncNotifierProvider<BiometricAuthNotifier, BiometricAuthState>(
      BiometricAuthNotifier.new,
    );

class BiometricAuthState {
  const BiometricAuthState({
    required this.supported,
    required this.enabled,
    required this.unlocked,
    this.message,
  });

  final bool supported;
  final bool enabled;
  final bool unlocked;
  final String? message;

  bool get needsUnlock => enabled && !unlocked;

  BiometricAuthState copyWith({
    bool? supported,
    bool? enabled,
    bool? unlocked,
    String? message,
  }) {
    return BiometricAuthState(
      supported: supported ?? this.supported,
      enabled: enabled ?? this.enabled,
      unlocked: unlocked ?? this.unlocked,
      message: message,
    );
  }
}

class BiometricAuthNotifier extends AsyncNotifier<BiometricAuthState> {
  bool _unlockedThisSession = false;

  @override
  Future<BiometricAuthState> build() async {
    final repo = ref.read(biometricAuthRepositoryProvider);
    final supported = await repo.isDeviceSupported();
    final enabled = supported && await repo.isEnabled();
    return BiometricAuthState(
      supported: supported,
      enabled: enabled,
      unlocked: !enabled || _unlockedThisSession,
    );
  }

  Future<bool> setEnabled(bool enabled) async {
    final repo = ref.read(biometricAuthRepositoryProvider);
    final current = state.valueOrNull;
    state = AsyncValue.data(
      current ??
          const BiometricAuthState(
            supported: false,
            enabled: false,
            unlocked: true,
          ),
    );

    if (enabled) {
      final supported = await repo.isDeviceSupported();
      if (!supported) {
        state = const AsyncValue.data(
          BiometricAuthState(
            supported: false,
            enabled: false,
            unlocked: true,
            message:
                'Biometric authentication is not available on this device.',
          ),
        );
        return false;
      }

      final authName = await repo.authenticationName();
      final ok = await repo.authenticate(
        reason: 'Enable $authName for Northstar on this device.',
      );
      if (!ok) {
        state = AsyncValue.data(
          BiometricAuthState(
            supported: supported,
            enabled: false,
            unlocked: true,
            message: 'Biometric unlock was not enabled.',
          ),
        );
        return false;
      }
    }

    await repo.setEnabled(enabled);
    _unlockedThisSession = enabled;
    state = AsyncValue.data(
      BiometricAuthState(
        supported: await repo.isDeviceSupported(),
        enabled: enabled,
        unlocked: true,
      ),
    );
    return true;
  }

  Future<bool> unlock() async {
    final repo = ref.read(biometricAuthRepositoryProvider);
    final ok = await repo.authenticate();
    if (!ok) return false;

    _unlockedThisSession = true;
    final current = state.valueOrNull;
    state = AsyncValue.data(
      (current ??
              const BiometricAuthState(
                supported: true,
                enabled: true,
                unlocked: false,
              ))
          .copyWith(unlocked: true),
    );
    return true;
  }
}
