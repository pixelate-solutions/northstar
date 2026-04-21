import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:northstar/features/plan/plan_hero.dart';
import 'package:northstar/models/trip_day.dart';
import 'package:northstar/models/trip_plan.dart';
import 'package:northstar/models/trip_stop.dart';

void main() {
  testWidgets('days until respects explicit year in date range', (
    tester,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final nearFuture = today.add(const Duration(days: 42));
    final targetYear = nearFuture.year + 1;
    final targetStart = DateTime(targetYear, nearFuture.month, nearFuture.day);
    final targetEnd = targetStart.add(const Duration(days: 3));
    final expectedDaysUntil = targetStart.difference(today).inDays;

    final plan = TripPlan(
      id: 'plan-1',
      title: 'Future Test Trip',
      destinations: const ['Seattle'],
      dateRange:
          '${_monthName(nearFuture.month)} ${nearFuture.day} - ${_monthName(targetEnd.month)} ${targetEnd.day}, $targetYear',
      summary: 'Test trip',
      pace: 'Balanced',
      days: [
        const TripDay(
          label: 'Day 1',
          title: 'Start',
          guidance: 'Test guidance',
          stops: [
            TripStop(
              time: '10:00',
              title: 'Stop 1',
              place: 'Place 1',
              note: 'Note',
              latitude: 0,
              longitude: 0,
              tag: 'Tag',
            ),
          ],
        ),
        const TripDay(
          label: 'Day 2',
          title: 'Continue',
          guidance: 'Test guidance',
          stops: [
            TripStop(
              time: '11:00',
              title: 'Stop 2',
              place: 'Place 2',
              note: 'Note',
              latitude: 1,
              longitude: 1,
              tag: 'Tag',
            ),
          ],
        ),
      ],
      openQuestions: const [],
      agentEvents: const [],
      updatedAt: now,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PlanHero(plan: plan)),
      ),
    );

    expect(find.text('Days until'), findsOneWidget);
    expect(find.text('$expectedDaysUntil'), findsOneWidget);
    expect(find.text('42'), findsNothing);
  });
}

String _monthName(int month) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return months[month - 1];
}
