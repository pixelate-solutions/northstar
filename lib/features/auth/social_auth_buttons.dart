import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../data/auth_repository.dart';

bool get isAppleDevice {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

class SocialAuthButtons extends StatefulWidget {
  const SocialAuthButtons({super.key, this.onError, this.onColor = false});

  final ValueChanged<String>? onError;
  final bool onColor;

  @override
  State<SocialAuthButtons> createState() => _SocialAuthButtonsState();
}

class _SocialAuthButtonsState extends State<SocialAuthButtons> {
  String? _loadingProvider;

  Future<void> _run(String provider, Future<void> Function() action) async {
    if (_loadingProvider != null) return;
    setState(() => _loadingProvider = provider);
    try {
      await action();
    } catch (e) {
      widget.onError?.call(e.toString());
    } finally {
      if (mounted) setState(() => _loadingProvider = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SocialButton(
          label: 'Continue with Google',
          icon: Icons.g_mobiledata_rounded,
          loading: _loadingProvider == 'google',
          onColor: widget.onColor,
          onPressed: () =>
              _run('google', () => AuthRepository().signInWithGoogle()),
        ),
        if (isAppleDevice) ...[
          const SizedBox(height: 10),
          _SocialButton(
            label: 'Continue with Apple',
            icon: Icons.apple_rounded,
            loading: _loadingProvider == 'apple',
            onColor: widget.onColor,
            onPressed: () =>
                _run('apple', () => AuthRepository().signInWithApple()),
          ),
        ],
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.icon,
    required this.loading,
    required this.onColor,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool loading;
  final bool onColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: loading ? null : onPressed,
      style: onColor
          ? OutlinedButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: .92),
              foregroundColor: const Color(0xFF13211E),
              side: BorderSide(color: Colors.white.withValues(alpha: .42)),
            )
          : null,
      icon: loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, size: 22),
      label: Text(label),
    );
  }
}
