// ignore_for_file: implementation_imports

import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:clerk_flutter/src/widgets/authentication/clerk_sign_in_panel.dart';
import 'package:clerk_flutter/src/widgets/authentication/clerk_sign_up_panel.dart';
import 'package:clerk_flutter/src/widgets/ui/clerk_cached_image.dart';
import 'package:clerk_flutter/src/widgets/ui/clerk_panel_header.dart';
import 'package:clerk_flutter/src/widgets/ui/clerk_vertical_card.dart';
import 'package:clerk_flutter/src/widgets/ui/closeable.dart';
import 'package:clerk_flutter/src/widgets/ui/common.dart';
import 'package:clerk_flutter/src/widgets/ui/or_divider.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

enum _AuthState {
  signingIn,
  signingUp;

  bool get isSigningIn => this == signingIn;

  _AuthState get nextState => values[(index + 1) % values.length];
}

class NorthstarClerkAuthentication extends StatefulWidget {
  const NorthstarClerkAuthentication({super.key});

  @override
  State<NorthstarClerkAuthentication> createState() =>
      _NorthstarClerkAuthenticationState();
}

class _NorthstarClerkAuthenticationState
    extends State<NorthstarClerkAuthentication> {
  _AuthState _state = _AuthState.signingIn;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 250), () {
        if (!mounted) return;
        FocusManager.instance.primaryFocus?.unfocus();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ClerkAuth.of(context);
    if (authState.isNotAvailable) return emptyWidget;

    final display = ClerkAuth.displayConfigOf(context);
    final localizations = ClerkAuth.localizationsOf(context);

    if (authState.isSigningIn && authState.isSigningUp == false) {
      _state = _AuthState.signingIn;
    } else if (authState.isSigningUp) {
      _state = _AuthState.signingUp;
    }

    return ClerkVerticalCard(
      topPortion: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClerkPanelHeader(
            title: _state.isSigningIn
                ? localizations.signInTo(display.applicationName)
                : localizations.signUpTo(display.applicationName),
            subtitle: _state.isSigningIn
                ? localizations.welcomeBackPleaseSignInToContinue
                : localizations.welcomePleaseFillInTheDetailsToGetStarted,
          ),
          Padding(
            padding: horizontalPadding32,
            child: Column(
              children: [
                if (authState.env.hasOauthStrategies) ...[
                  Closeable(
                    closed:
                        authState.isSigningUp ||
                        (authState.isSigningIn &&
                            authState.signIn!.verification?.strategy.isOauth !=
                                true),
                    child: const _NorthstarOAuthPanel(),
                  ),
                  Closeable(
                    closed: authState.isSigningUp || authState.isSigningIn,
                    child: const OrDivider(),
                  ),
                ],
                Openable(
                  open: _state.isSigningIn,
                  keepAlive: true,
                  child: const ClerkSignInPanel(),
                ),
                Openable(
                  open: _state == _AuthState.signingUp,
                  keepAlive: true,
                  child: const ClerkSignUpPanel(),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomPortion: _BottomPortion(
        state: _state,
        onChange: () => setState(() => _state = _state.nextState),
      ),
    );
  }
}

class _NorthstarOAuthPanel extends StatefulWidget {
  const _NorthstarOAuthPanel();

  @override
  State<_NorthstarOAuthPanel> createState() => _NorthstarOAuthPanelState();
}

class _NorthstarOAuthPanelState extends State<_NorthstarOAuthPanel> {
  Object? _connection;

  Future<void> _choose(ClerkAuthState authState, dynamic connection) async {
    setState(() => _connection = connection);
    await authState.ssoSignIn(context, connection.strategy);
    if (mounted) setState(() => _connection = null);
  }

  @override
  Widget build(BuildContext context) {
    return ClerkAuthBuilder(
      builder: (context, authState) {
        if (authState.isNotAvailable) return emptyWidget;

        final connections = authState.env.socialConnections;
        if (connections.isEmpty) return emptyWidget;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            for (final connection in connections)
              _SocialButton(
                connection: connection,
                enabled: _connection == null || _connection == connection,
                onPressed: () => _choose(authState, connection),
              ),
          ],
        );
      },
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.connection,
    required this.enabled,
    required this.onPressed,
  });

  final dynamic connection;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final clerkTheme = ClerkAuth.themeExtensionOf(context);
    final isDark = Theme.of(context).colorScheme.brightness == Brightness.dark;
    final provider = connection.strategy.provider?.toString() ?? '';

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: enabled ? 1 : .55,
      child: SizedBox(
        width: 62,
        height: 44,
        child: OutlinedButton(
          onPressed: enabled ? onPressed : null,
          style: OutlinedButton.styleFrom(
            backgroundColor: clerkTheme.colors.background,
            foregroundColor: clerkTheme.colors.text,
            disabledForegroundColor: clerkTheme.colors.text.withValues(
              alpha: .46,
            ),
            side: BorderSide(color: clerkTheme.colors.borderSide),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            padding: EdgeInsets.zero,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: enabled ? 1 : .24,
                child: _ProviderLogo(
                  connection: connection,
                  provider: provider,
                ),
              ),
              if (!enabled)
                SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: isDark ? Colors.white : clerkTheme.colors.accent,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProviderLogo extends StatelessWidget {
  const _ProviderLogo({required this.connection, required this.provider});

  final dynamic connection;
  final String provider;

  @override
  Widget build(BuildContext context) {
    final logoUrl = connection.logoUrl.toString();
    final invert =
        _invertLogoForDarkMode(provider) &&
        ClerkAuth.themeExtensionOf(context).brightness == Brightness.dark;
    if (logoUrl.isNotEmpty) {
      return ClerkCachedImage(
        logoUrl,
        invertColors: invert,
        width: 22,
        height: 22,
      );
    }

    return Text(
      connection.name.toString().isEmpty
          ? '?'
          : connection.name.toString().characters.first.toUpperCase(),
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
    );
  }

  bool _invertLogoForDarkMode(String provider) {
    return const {
      'apple',
      'github',
      'x',
      'tiktok',
      'notion',
      'vercel',
    }.contains(provider);
  }
}

class _BottomPortion extends StatelessWidget {
  const _BottomPortion({required this.onChange, required this.state});

  final VoidCallback onChange;
  final _AuthState state;

  @override
  Widget build(BuildContext context) {
    final localizations = ClerkAuth.localizationsOf(context);
    final themeExtension = ClerkAuth.themeExtensionOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        verticalMargin12,
        Padding(
          padding: horizontalPadding32,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: state.isSigningIn
                      ? localizations.dontHaveAnAccount
                      : localizations.alreadyHaveAnAccount,
                  style: themeExtension.styles.subheading,
                ),
                const WidgetSpan(child: SizedBox(width: 6)),
                TextSpan(
                  text: state.isSigningIn
                      ? localizations.signUp
                      : localizations.signIn,
                  style: themeExtension.styles.subheading.copyWith(
                    color: themeExtension.colors.accent,
                    fontWeight: FontWeight.w800,
                  ),
                  recognizer: TapGestureRecognizer()..onTap = onChange,
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ),
        verticalMargin12,
      ],
    );
  }
}
