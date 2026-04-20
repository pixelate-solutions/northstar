import 'package:flutter_test/flutter_test.dart';
import 'package:northstar/models/trip_plan.dart';
import 'package:northstar/models/trip_day.dart';
import 'package:northstar/models/trip_stop.dart';

// Mirrors the validation rules in server/src/agent/evaluator.ts.
// Keeps Flutter tests green even if the server is not running.

bool _hasZeroCoords(TripPlan plan) => plan.days.any(
  (d) => d.stops.any((s) => s.latitude == 0 && s.longitude == 0),
);

bool _hasDuplicateCoords(TripPlan plan) {
  for (final day in plan.days) {
    final seen = <String>{};
    for (final s in day.stops) {
      final key = '${s.latitude},${s.longitude}';
      if (!seen.add(key)) return true;
    }
  }
  return false;
}

TripPlan _validPlan() => TripPlan(
  id: 'test-plan',
  title: 'Test Trip',
  summary: 'A test trip.',
  destinations: const ['Anywhere'],
  dateRange: 'Jan 1 - Jan 3',
  pace: 'Balanced',
  updatedAt: DateTime(2026),
  openQuestions: const [],
  agentEvents: const [],
  days: const [
    TripDay(
      label: 'Day 1',
      title: 'First day',
      guidance: 'Have fun.',
      stops: [
        TripStop(
          time: '10:00',
          title: 'A',
          place: 'A',
          note: '',
          latitude: 40.0,
          longitude: -74.0,
          tag: 'Walk',
        ),
        TripStop(
          time: '14:00',
          title: 'B',
          place: 'B',
          note: '',
          latitude: 40.1,
          longitude: -74.1,
          tag: 'Food',
        ),
      ],
    ),
  ],
);

void main() {
  group('plan completeness rules', () {
    test('valid plan passes all checks', () {
      final plan = _validPlan();
      expect(plan.title, isNotEmpty);
      expect(plan.summary, isNotEmpty);
      expect(plan.days, isNotEmpty);
      expect(plan.days.first.stops, isNotEmpty);
      expect(_hasZeroCoords(plan), isFalse);
      expect(_hasDuplicateCoords(plan), isFalse);
    });

    test('zero-coordinate stop is detected', () {
      final plan = _validPlan().copyWith(
        days: const [
          TripDay(
            label: 'Day 1',
            title: 'Bad day',
            guidance: '',
            stops: [
              TripStop(
                time: '10:00',
                title: 'Origin',
                place: 'Null Island',
                note: '',
                latitude: 0,
                longitude: 0,
                tag: 'Walk',
              ),
            ],
          ),
        ],
      );
      expect(_hasZeroCoords(plan), isTrue);
    });

    test('duplicate coordinates within a day are detected', () {
      final plan = _validPlan().copyWith(
        days: const [
          TripDay(
            label: 'Day 1',
            title: 'Dup coords',
            guidance: '',
            stops: [
              TripStop(
                time: '10:00',
                title: 'A',
                place: 'A',
                note: '',
                latitude: 40.0,
                longitude: -74.0,
                tag: 'Walk',
              ),
              TripStop(
                time: '12:00',
                title: 'B',
                place: 'B',
                note: '',
                latitude: 40.0,
                longitude: -74.0,
                tag: 'Food',
              ),
            ],
          ),
        ],
      );
      expect(_hasDuplicateCoords(plan), isTrue);
    });

    test('empty title is caught', () {
      final plan = _validPlan().copyWith(title: '');
      expect(plan.title.isEmpty, isTrue);
    });

    test('plan with no days is caught', () {
      final plan = _validPlan().copyWith(days: []);
      expect(plan.days.isEmpty, isTrue);
    });
  });
}
