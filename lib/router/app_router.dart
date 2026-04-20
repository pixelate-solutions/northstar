import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/account/account_screen.dart';
import '../features/auth/auth_landing_screen.dart';
import '../features/auth/biometric_gate.dart';
import '../features/auth/clerk_auth_screen.dart';
import '../features/auth/forgot_password_screen.dart';
import '../providers/auth_mode_provider.dart';
import '../providers/auth_provider.dart';
import '../features/auth/sign_in_screen.dart';
import '../features/auth/sign_up_screen.dart';
import '../features/home/home_screen.dart';
import '../features/reminders/reminders_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = _AuthListenable(ref);
  final shouldUseClerkAuth = ref.watch(useClerkAuthProvider);

  return GoRouter(
    refreshListenable: authNotifier,
    redirect: (context, state) {
      if (shouldUseClerkAuth) {
        if (_isAuthRoute(state.matchedLocation)) return '/';
        return null;
      }

      final isSignedIn = ref.read(isSignedInProvider);
      final isAuthRoute = _isAuthRoute(state.matchedLocation);

      if (!isSignedIn && !isAuthRoute) return '/welcome';
      if (isSignedIn && isAuthRoute) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const BiometricGate(child: HomeScreen()),
      ),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => shouldUseClerkAuth
            ? const ClerkAuthScreen()
            : const AuthLandingScreen(),
      ),
      GoRoute(
        path: '/sign-in',
        builder: (context, state) =>
            shouldUseClerkAuth ? const ClerkAuthScreen() : const SignInScreen(),
      ),
      GoRoute(
        path: '/sign-up',
        builder: (context, state) =>
            shouldUseClerkAuth ? const ClerkAuthScreen() : const SignUpScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => shouldUseClerkAuth
            ? const ClerkAuthScreen()
            : const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/account',
        builder: (context, state) =>
            const BiometricGate(child: AccountScreen()),
      ),
      GoRoute(
        path: '/reminders/:tripId',
        builder: (context, state) {
          final tripId = state.pathParameters['tripId']!;
          return BiometricGate(child: RemindersScreen(tripId: tripId));
        },
      ),
    ],
  );
});

bool _isAuthRoute(String location) {
  return location == '/welcome' ||
      location == '/sign-in' ||
      location == '/sign-up' ||
      location == '/forgot-password';
}

class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Ref ref) {
    ref.listen(authStateProvider, (_, _) => notifyListeners());
  }
}
