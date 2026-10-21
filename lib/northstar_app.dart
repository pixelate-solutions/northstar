import 'dart:async';
import 'dart:ui';

import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/app_loading_screen.dart';
import 'data/clerk_config.dart';
import 'data/offline_auth_repository.dart';
import 'data/supabase_client.dart';
import 'features/auth/clerk_auth_screen.dart';
import 'features/auth/clerk_configuration_screen.dart';
import 'providers/auth_mode_provider.dart';
import 'providers/status_bar_provider.dart';
import 'router/app_router.dart';

class NorthstarApp extends ConsumerWidget {
  const NorthstarApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shouldUseClerkAuth = ref.watch(useClerkAuthProvider);
    final router = ref.watch(routerProvider);
    final app = MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Northstar',
      theme: lightTheme(),
      darkTheme: darkTheme(),
      themeMode: ThemeMode.system,
      routerConfig: router,
      builder: _dismissKeyboardBuilder,
    );

    if (!shouldUseClerkAuth) return app;

    if (!isClerkConfigured) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Northstar',
        theme: lightTheme(),
        darkTheme: darkTheme(),
        themeMode: ThemeMode.system,
        builder: _dismissKeyboardBuilder,
        home: const ClerkConfigurationScreen(),
      );
    }

    return ClerkAuth(
      config: ClerkAuthConfig(
        publishableKey: clerkPublishableKey,
        loading: MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Northstar',
          theme: lightTheme(),
          darkTheme: darkTheme(),
          themeMode: ThemeMode.system,
          builder: _dismissKeyboardBuilder,
          home: const AppLoadingScreen(),
        ),
      ),
      child: ClerkErrorListener(
        handler: (context, error) => debugPrint('Clerk error: $error'),
        child: ClerkAuthBuilder(
          signedInBuilder: (context, authState) {
            unawaited(OfflineAuthRepository.markClerkSessionAvailable());
            setSupabaseAccessTokenProvider(() async {
              return (await authState.sessionToken()).jwt;
            });
            return app;
          },
          signedOutBuilder: (context, authState) {
            setSupabaseAccessTokenProvider(null);
            return _OfflineClerkSessionFallback(
              app: app,
              signedOutApp: MaterialApp(
                debugShowCheckedModeBanner: false,
                title: 'Northstar',
                theme: lightTheme(),
                darkTheme: darkTheme(),
                themeMode: ThemeMode.system,
                builder: _dismissKeyboardBuilder,
                home: const ClerkAuthScreen(),
              ),
            );
          },
        ),
      ),
    );
  }
}

Widget _dismissKeyboardBuilder(BuildContext context, Widget? child) {
  return Stack(
    children: [
      GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          final focus = FocusManager.instance.primaryFocus;
          if (focus != null && !focus.hasPrimaryFocus) {
            focus.unfocus();
          }
        },
        child: child ?? const SizedBox.shrink(),
      ),
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: Consumer(
          builder: (context, ref, _) {
            final hideFade = ref.watch(hideStatusBarFadeProvider);
            if (hideFade) return const SizedBox.shrink();
            return const _StatusBarScrollFade();
          },
        ),
      ),
    ],
  );
}

class _StatusBarScrollFade extends StatelessWidget {
  const _StatusBarScrollFade();

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    if (topInset <= 0) return const SizedBox.shrink();

    final bg = Theme.of(context).scaffoldBackgroundColor;
    return IgnorePointer(
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: topInset + 4,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  bg,
                  bg.withValues(alpha: .78),
                  bg.withValues(alpha: .34),
                  bg.withValues(alpha: 0),
                ],
                stops: const [0, .48, .78, 1],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OfflineClerkSessionFallback extends StatelessWidget {
  const _OfflineClerkSessionFallback({
    required this.app,
    required this.signedOutApp,
  });

  final Widget app;
  final Widget signedOutApp;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: OfflineAuthRepository.hadClerkSession(),
      builder: (context, sessionSnapshot) {
        return FutureBuilder<List<ConnectivityResult>>(
          future: Connectivity().checkConnectivity(),
          builder: (context, connectivitySnapshot) {
            return StreamBuilder<List<ConnectivityResult>>(
              stream: Connectivity().onConnectivityChanged,
              initialData: connectivitySnapshot.data,
              builder: (context, streamSnapshot) {
                final hadSession = sessionSnapshot.data ?? false;
                final results = streamSnapshot.data;
                final isOffline =
                    results != null &&
                    results.every(
                      (result) => result == ConnectivityResult.none,
                    );

                if (hadSession && isOffline) return app;
                return signedOutApp;
              },
            );
          },
        );
      },
    );
  }
}
