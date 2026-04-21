import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:northstar/data/billing_repository.dart';
import 'package:northstar/models/subscription_status.dart';
import 'package:northstar/models/trip_plan.dart';
import 'package:northstar/northstar_app.dart';
import 'package:northstar/providers/auth_mode_provider.dart';
import 'package:northstar/providers/auth_provider.dart';
import 'package:northstar/providers/biometric_provider.dart';
import 'package:northstar/providers/billing_provider.dart';
import 'package:northstar/providers/trip_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

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
          billingRepositoryProvider.overrideWithValue(
            _EntitledBillingRepository(),
          ),
          tripListProvider.overrideWith(() => _SeedTripListNotifier()),
        ],
        child: const NorthstarApp(),
      ),
    );

    // Let go_router and Riverpod settle.
    await tester.pumpAndSettle();

    // Trips is the default home tab and opens on the all-trips library.
    expect(find.text('Trips'), findsWidgets);
    expect(
      find.textContaining('Barcelona'),
      findsWidgets,
      reason: 'First seed plan should be visible in the trips library',
    );

    await tester.tap(find.textContaining('Barcelona').first);
    await tester.pumpAndSettle();
    expect(find.text('All trips'), findsOneWidget);

    await tester.tap(find.text('All trips'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.search_rounded), findsOneWidget);
  });

  testWidgets('trips library hides past trips until filter is enabled', (
    tester,
  ) async {
    final seedPlans = TripPlan.seedPlans();
    final plans = [
      seedPlans.first.copyWith(
        title: 'Future Trip',
        dateRange: 'January 1, 2100 - January 4, 2100',
      ),
      seedPlans.last.copyWith(
        title: 'Past Trip',
        dateRange: 'January 1, 2000 - January 4, 2000',
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          useClerkAuthProvider.overrideWithValue(false),
          isSignedInProvider.overrideWithValue(true),
          biometricAuthProvider.overrideWith(_UnlockedBiometricNotifier.new),
          billingRepositoryProvider.overrideWithValue(
            _EntitledBillingRepository(),
          ),
          tripListProvider.overrideWith(() => _SeedTripListNotifier(plans)),
        ],
        child: const NorthstarApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Future Trip'), findsOneWidget);
    expect(find.text('Past Trip'), findsNothing);

    await tester.tap(find.textContaining('Show past trips').first);
    await tester.pumpAndSettle();

    expect(find.text('Past Trip'), findsOneWidget);
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
          billingRepositoryProvider.overrideWithValue(
            _EntitledBillingRepository(),
          ),
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
  _SeedTripListNotifier([this._plans]);

  final List<TripPlan>? _plans;

  @override
  Future<List<TripPlan>> build() async => _plans ?? TripPlan.seedPlans();
}

class _EmptyTripListNotifier extends TripListNotifier {
  @override
  Future<List<TripPlan>> build() async => [];
}

class _EntitledBillingRepository extends BillingRepository {
  @override
  Future<SubscriptionStatus> fetchSubscription() async {
    return SubscriptionStatus.fromJson(const {
      'status': 'active',
      'billingPeriod': 'monthly',
      'isEntitled': true,
      'isLifetime': false,
      'hasRedeemedPromo': false,
    });
  }
}
