import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/biometric_provider.dart';

class BiometricPreferenceTile extends ConsumerWidget {
  const BiometricPreferenceTile({super.key, this.cardStyle = false});

  final bool cardStyle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(biometricAuthProvider);
    final cs = Theme.of(context).colorScheme;

    return asyncState.when(
      loading: () => _TileShell(
        cardStyle: cardStyle,
        title: 'Biometric unlock',
        subtitle: 'Checking this device...',
        trailing: const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (_, _) => _TileShell(
        cardStyle: cardStyle,
        title: 'Biometric unlock',
        subtitle: 'Biometric authentication is not available on this device.',
        trailing: const Switch(value: false, onChanged: null),
      ),
      data: (state) {
        final authName = state.message ?? 'Face ID';
        final title = state.supported ? authName : 'Biometric unlock';
        return _TileShell(
          cardStyle: cardStyle,
          title: title,
          subtitle: state.supported
              ? 'Quick, secure sign-in'
              : 'Biometric authentication is not available on this device.',
          trailing: Switch(
            value: state.enabled,
            onChanged: state.supported
                ? (value) =>
                      ref.read(biometricAuthProvider.notifier).setEnabled(value)
                : null,
          ),
          iconColor: state.enabled ? cs.primary : cs.onSurface,
        );
      },
    );
  }
}

class _TileShell extends StatelessWidget {
  const _TileShell({
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.iconColor,
    this.cardStyle = false,
  });

  final String title;
  final String subtitle;
  final Widget trailing;
  final Color? iconColor;
  final bool cardStyle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: cs.onSurface.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.face_retouching_natural_rounded,
              color: (iconColor ?? cs.onSurface).withValues(alpha: .75),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: .55),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );

    if (cardStyle) return content;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: .82),
        border: Border.all(color: cs.onSurface.withValues(alpha: .10)),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: content,
    );
  }
}
