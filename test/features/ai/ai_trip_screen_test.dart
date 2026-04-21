import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:northstar/agent/agent_client.dart';
import 'package:northstar/features/ai/ai_trip_screen.dart';
import 'package:northstar/models/agent_event.dart';
import 'package:northstar/models/trip_day.dart';
import 'package:northstar/models/trip_plan.dart';
import 'package:northstar/models/trip_stop.dart';

void main() {
  testWidgets('trip picker hides past trips until expanded', (tester) async {
    final plans = [
      _plan(
        id: 'future-trip',
        title: 'Future Trip',
        dateRange: 'January 1, 2100 - January 4, 2100',
      ),
      _plan(
        id: 'past-trip',
        title: 'Past Trip',
        dateRange: 'January 1, 2000 - January 4, 2000',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AiTripScreen(
            agent: AgentClient(),
            plans: plans,
            selectedPlan: null,
            onTripSelected: (_) {},
            onPlanReady: (plan) async => plan,
            onOpenTrips: () {},
            onOpenTrip: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Show past trips (1)'), findsOneWidget);

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();

    expect(find.text('Future Trip'), findsOneWidget);
    expect(find.text('Past Trip'), findsNothing);

    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Show past trips (1)'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();

    expect(find.text('Past Trip'), findsOneWidget);
  });
}

TripPlan _plan({
  required String id,
  required String title,
  required String dateRange,
}) {
  return TripPlan(
    id: id,
    title: title,
    destinations: const ['Test City'],
    dateRange: dateRange,
    summary: 'Test summary',
    pace: 'Balanced',
    days: const [
      TripDay(
        label: 'Day 1',
        title: 'Arrival',
        guidance: 'Keep it simple.',
        stops: [
          TripStop(
            time: '10:00',
            title: 'Check in',
            place: 'Hotel',
            note: 'Drop bags.',
            latitude: 0,
            longitude: 0,
            tag: 'Stay',
          ),
        ],
      ),
    ],
    openQuestions: const [],
    agentEvents: const <AgentEvent>[],
    updatedAt: DateTime(2026, 4, 20),
  );
}
