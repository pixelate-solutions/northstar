import 'package:flutter_test/flutter_test.dart';
import 'package:northstar/models/agent_event.dart';
import 'package:northstar/models/reminder.dart';
import 'package:northstar/models/trip_brief.dart';
import 'package:northstar/models/trip_day.dart';
import 'package:northstar/models/trip_plan.dart';
import 'package:northstar/models/trip_stop.dart';

void main() {
  group('TripStop', () {
    test('round-trips through JSON', () {
      const stop = TripStop(
        time: '10:00',
        title: 'Sagrada Familia',
        place: 'Sagrada Familia, Barcelona',
        note: 'Timed entry required.',
        latitude: 41.4036,
        longitude: 2.1744,
        tag: 'Ticket',
      );
      final json = stop.toJson();
      final decoded = TripStop.fromJson(json);
      expect(decoded.time, stop.time);
      expect(decoded.title, stop.title);
      expect(decoded.place, stop.place);
      expect(decoded.latitude, stop.latitude);
      expect(decoded.longitude, stop.longitude);
      expect(decoded.tag, stop.tag);
    });

    test('icon is derived from tag, not stored in JSON', () {
      const stop = TripStop(
        time: '09:00',
        title: 'Walk',
        place: 'Park',
        note: '',
        latitude: 0,
        longitude: 0,
        tag: 'Walk',
      );
      final json = stop.toJson();
      expect(json.containsKey('icon'), isFalse);
    });
  });

  group('TripDay', () {
    test('round-trips through JSON with stops', () {
      const day = TripDay(
        label: 'Day 1',
        title: 'Arrival',
        guidance: 'Keep it light.',
        stops: [
          TripStop(
            time: '14:00',
            title: 'Hotel',
            place: 'Eixample',
            note: '',
            latitude: 41.39,
            longitude: 2.16,
            tag: 'Arrival',
          ),
        ],
      );
      final decoded = TripDay.fromJson(day.toJson());
      expect(decoded.label, 'Day 1');
      expect(decoded.stops, hasLength(1));
      expect(decoded.stops.first.tag, 'Arrival');
    });
  });

  group('TripPlan', () {
    test('round-trips through JSON preserving all fields', () {
      final plan = TripPlan.seedPlans().first;
      final decoded = TripPlan.fromJson(plan.toJson());
      expect(decoded.id, plan.id);
      expect(decoded.title, plan.title);
      expect(decoded.destinations, plan.destinations);
      expect(decoded.pace, plan.pace);
      expect(decoded.days, hasLength(plan.days.length));
      expect(decoded.openQuestions, hasLength(plan.openQuestions.length));
      expect(
        decoded.updatedAt.toIso8601String(),
        plan.updatedAt.toIso8601String(),
      );
    });

    test('all seed plans are valid', () {
      for (final plan in TripPlan.seedPlans()) {
        expect(plan.id, isNotEmpty);
        expect(plan.title, isNotEmpty);
        expect(plan.days, isNotEmpty);
        for (final day in plan.days) {
          expect(day.stops, isNotEmpty);
          for (final stop in day.stops) {
            expect(
              stop.latitude,
              isNot(0.0),
              reason: '${stop.place} has zero latitude',
            );
            expect(
              stop.longitude,
              isNot(0.0),
              reason: '${stop.place} has zero longitude',
            );
          }
        }
      }
    });
  });

  group('TripBrief', () {
    test('round-trips through JSON', () {
      const brief = TripBrief(
        destinations: 'Tokyo',
        dates: 'Sep 2 - Sep 11',
        travelers: '2 adults',
        interests: 'food, culture',
        pace: 'Balanced',
      );
      final decoded = TripBrief.fromJson(brief.toJson());
      expect(decoded.destinations, brief.destinations);
      expect(decoded.dates, brief.dates);
      expect(decoded.pace, brief.pace);
    });
  });

  group('AgentEvent', () {
    test('round-trips all kinds', () {
      for (final kind in AgentEventKind.values) {
        final event = AgentEvent(kind: kind, title: 'T', detail: 'D');
        final decoded = AgentEvent.fromJson(event.toJson());
        expect(decoded.kind, kind);
        expect(decoded.title, 'T');
      }
    });
  });

  group('Reminder', () {
    test('round-trips through JSON', () {
      final reminder = Reminder(
        id: 'r1',
        userId: 'user1',
        tripId: 'trip1',
        title: 'Sagrada Familia',
        body: 'Day 2 · 10:30',
        remindAt: DateTime(2026, 6, 9, 10, 0),
      );
      final decoded = Reminder.fromJson(reminder.toJson());
      expect(decoded.id, reminder.id);
      expect(decoded.userId, reminder.userId);
      expect(decoded.tripId, reminder.tripId);
      expect(decoded.remindAt, reminder.remindAt);
      expect(decoded.sent, isFalse);
    });
  });
}
