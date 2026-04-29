import 'dart:ui';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'biometric_preference_tile.dart';
import 'northstar_clerk_authentication.dart';

class ClerkAuthScreen extends StatelessWidget {
  const ClerkAuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [kDarkBg, Color(0xFF162822), Color(0xFF203A32)]
                : const [Color(0xFFD4EDE6), kMint, Color(0xFFF0F9F5)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 720;
              final content = _AuthContent(isWide: isWide);
              if (!isWide) return content;

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: content,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AuthContent extends StatelessWidget {
  const _AuthContent({required this.isWide});

  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final header = Padding(
      padding: EdgeInsets.fromLTRB(
        isWide ? 4 : 28,
        isWide ? 0 : 42,
        isWide ? 4 : 28,
        26,
      ),
      child: const _AuthHeader(),
    );

    final panel = _FrostedAuthPanel(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(isWide ? 32 : 30),
        bottom: Radius.circular(isWide ? 32 : 0),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 34),
        child: const _AuthPanelContents(),
      ),
    );

    if (isWide) {
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 38),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            panel,
            const SizedBox(height: 18),
            Text(
              'Secure travel planning for every trip.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: cs.onSurface.withValues(alpha: .54),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        Expanded(child: panel),
      ],
    );
  }
}

class _AuthPanelContents extends StatelessWidget {
  const _AuthPanelContents();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ConnectivityResult>>(
      future: Connectivity().checkConnectivity(),
      builder: (context, snapshot) {
        return StreamBuilder<List<ConnectivityResult>>(
          stream: Connectivity().onConnectivityChanged,
          initialData: snapshot.data,
          builder: (context, streamSnapshot) {
            final results = streamSnapshot.data;
            final isOffline =
                results != null &&
                results.every((result) => result == ConnectivityResult.none);

            if (isOffline) {
              return const _OfflineSignInUnavailable();
            }

            return const Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                NorthstarClerkAuthentication(),
                SizedBox(height: 14),
                BiometricPreferenceTile(),
              ],
            );
          },
        );
      },
    );
  }
}

class _OfflineSignInUnavailable extends StatelessWidget {
  const _OfflineSignInUnavailable();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: BoxDecoration(
        color: cs.onSurface.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.onSurface.withValues(alpha: .12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: .14),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.wifi_off_rounded, color: cs.primary, size: 26),
          ),
          const SizedBox(height: 14),
          Text(
            'Sign in needs internet',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              height: 1.08,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Offline mode keeps saved trips available after you have signed in on this device. Reconnect to sign in or refresh your account.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: cs.onSurface.withValues(alpha: .68),
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthHeader extends StatelessWidget {
  const _AuthHeader();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: kInk,
                borderRadius: BorderRadius.circular(13),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .14),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: const Icon(
                Icons.explore_rounded,
                color: Colors.white,
                size: 27,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Northstar',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'AI travel planning',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: cs.onSurface.withValues(alpha: .58),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Text(
          'Your trips, decisions,\nand maps all here.',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
            height: 1.08,
          ),
        ),
      ],
    );
  }
}

class _FrostedAuthPanel extends StatelessWidget {
  const _FrostedAuthPanel({required this.child, required this.borderRadius});

  final Widget child;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          decoration: BoxDecoration(
            color: (isDark ? kDarkSurface : Colors.white).withValues(
              alpha: isDark ? .78 : .74,
            ),
            border: Border.all(
              color: (isDark ? Colors.white : kLine).withValues(alpha: .55),
            ),
            borderRadius: borderRadius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? .28 : .08),
                blurRadius: 34,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
