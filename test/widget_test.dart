import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:northstar/models/trip_plan.dart';
import 'package:northstar/northstar_app.dart';
import 'package:northstar/providers/auth_mode_provider.dart';
import 'package:northstar/providers/auth_provider.dart';
import 'package:northstar/providers/biometric_provider.dart';
import 'package:northstar/providers/trip_providers.dart';

void main() {
  testWidgets('missing Clerk key does not show legacy auth screens', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: NorthstarApp()));
    await tester.pumpAndSettle();

    expect(find.text('Clerk is not configured'), findsOneWidget);
    expect(find.text('Welcome back'), findsNothing);
  });

  testWidgets('home screen renders seed trips without network', (tester) async {
    // Override tripListProvider to return seed plans immediately — no Supabase/Hive.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          useClerkAuthProvider.overrideWithValue(false),
          isSignedInProvider.overrideWithValue(true),
          biometricAuthProvider.overrideWith(_UnlockedBiometricNotifier.new),
          tripListProvider.overrideWith(() => _SeedTripListNotifier()),
        ],
        child: const NorthstarApp(),
      ),
    );

    // Let go_router and Riverpod settle.
    await tester.pumpAndSettle();

    // The AI screen is the default tab; navigate to Trips to inspect saved plans.
    expect(find.text('Where to next?'), findsOneWidget);
    await tester.tap(find.text('Trips').last);
    await tester.pumpAndSettle();

    // The trips screen should show the first seed plan title.
    expect(
      find.textContaining('Barcelona'),
      findsWidgets,
      reason: 'First seed plan should be visible on home screen',
    );
  });

  testWidgets('app renders without crashing when trips are empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          useClerkAuthProvider.overrideWithValue(false),
          isSignedInProvider.overrideWithValue(true),
          biometricAuthProvider.overrideWith(_UnlockedBiometricNotifier.new),
          tripListProvider.overrideWith(() => _EmptyTripListNotifier()),
        ],
        child: const NorthstarApp(),
      ),
    );
    await tester.pumpAndSettle();
    // Should not throw; empty state widget should be visible.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}

class _UnlockedBiometricNotifier extends BiometricAuthNotifier {
  @override
  Future<BiometricAuthState> build() async {
    return const BiometricAuthState(
      supported: false,
      enabled: false,
      unlocked: true,
    );
  }
}

class _SeedTripListNotifier extends TripListNotifier {
  @override
  Future<List<TripPlan>> build() async => TripPlan.seedPlans();
}

class _EmptyTripListNotifier extends TripListNotifier {
  @override
  Future<List<TripPlan>> build() async => [];
}
