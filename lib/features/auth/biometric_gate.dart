import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets/app_loading_screen.dart';
import '../../data/auth_repository.dart';
import '../../providers/auth_mode_provider.dart';
import '../../providers/biometric_provider.dart';

class BiometricGate extends ConsumerWidget {
  const BiometricGate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(biometricAuthProvider);
    return state.when(
      loading: () => const AppLoadingScreen(),
      error: (_, _) => child,
      data: (value) {
        if (!value.needsUnlock) return child;
        return const _UnlockScreen();
      },
    );
  }
}

class _UnlockScreen extends ConsumerStatefulWidget {
  const _UnlockScreen();

  @override
  ConsumerState<_UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends ConsumerState<_UnlockScreen> {
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock(auto: true));
  }

  Future<void> _sendToSignIn() async {
    try {
      if (ref.read(useClerkAuthProvider)) {
        await ClerkAuth.of(context).signOut();
      } else {
        await AuthRepository().signOut();
      }
    } catch (_) {
      // The auth screen is still the safest fallback if session cleanup fails.
    }
    if (mounted) context.go('/welcome');
  }

  Future<void> _unlock({bool auto = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final ok = await ref.read(biometricAuthProvider.notifier).unlock();
    if (!mounted) return;
    if (!ok && auto) {
      await _sendToSignIn();
      return;
    }
    setState(() {
      _loading = false;
      _error = ok ? null : 'Biometric authentication did not unlock Northstar.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Stack(
        children: [
          const AppLoadingScreen(),
          if (_error != null)
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 34),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: cs.error),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _loading ? null : _unlock,
                          icon: const Icon(Icons.fingerprint_rounded),
                          label: const Text('Try again'),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _loading ? null : _sendToSignIn,
                          child: const Text('Sign in another way'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
