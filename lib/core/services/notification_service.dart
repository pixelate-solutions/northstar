import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../utils/time_format.dart';
import '../../models/trip_plan.dart';

final _plugin = FlutterLocalNotificationsPlugin();

Future<void> initNotifications() async {
  tz_data.initializeTimeZones();

  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const ios = DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
  );
  await _plugin.initialize(
    const InitializationSettings(android: android, iOS: ios, macOS: ios),
  );
}

Future<void> requestPermission() async {
  await _plugin
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >()
      ?.requestPermissions(alert: true, badge: true, sound: true);

  await _plugin
      .resolvePlatformSpecificImplementation<
        MacOSFlutterLocalNotificationsPlugin
      >()
      ?.requestPermissions(alert: true, badge: true, sound: true);
}

/// Schedule one notification per stop in [plan], 30 min before each stop time.
/// Notifications are keyed by a stable int derived from the plan+day+stop.
Future<void> scheduleRemindersForPlan(TripPlan plan) async {
  final startDate = _parseStartDate(plan.dateRange);
  if (startDate == null) return;

  for (var d = 0; d < plan.days.length; d++) {
    final day = plan.days[d];
    final dayDate = startDate.add(Duration(days: d));

    for (var s = 0; s < day.stops.length; s++) {
      final stop = day.stops[s];
      final stopTime = _parseTime(stop.time);
      if (stopTime == null) continue;

      final remindAt = DateTime(
        dayDate.year,
        dayDate.month,
        dayDate.day,
        stopTime.hour,
        stopTime.minute,
      ).subtract(const Duration(minutes: 30));

      if (remindAt.isBefore(DateTime.now())) continue;

      final notifId = _notifId(plan.id, d, s);
      final tzRemindAt = tz.TZDateTime.from(remindAt, tz.local);

      await _plugin.zonedSchedule(
        notifId,
        stop.title,
        '${day.label} · ${stop.place} · ${formatDisplayTime(stop.time)}',
        tzRemindAt,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'trip_stops',
            'Trip stops',
            channelDescription: 'Reminders 30 min before each planned stop',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
          macOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }
}

/// Cancel all notifications previously scheduled for this plan.
Future<void> cancelRemindersForPlan(TripPlan plan) async {
  final startDate = _parseStartDate(plan.dateRange);
  if (startDate == null) return;

  for (var d = 0; d < plan.days.length; d++) {
    for (var s = 0; s < plan.days[d].stops.length; s++) {
      await _plugin.cancel(_notifId(plan.id, d, s));
    }
  }
}

// ── helpers ──────────────────────────────────────────────────────────────────

int _notifId(String planId, int day, int stop) {
  // Stable int in [0, 2^31) built from plan hash + day + stop.
  final hash = planId.hashCode.abs();
  return ((hash & 0xFFFF) << 12) | ((day & 0x3F) << 6) | (stop & 0x3F);
}

// Parses "June 8 - June 15", "Sep 2 - Sep 11", "2026-06-08", "June 8–15", etc.
DateTime? _parseStartDate(String dateRange) {
  // Try ISO format first
  final iso = RegExp(r'(\d{4}-\d{2}-\d{2})');
  final isoMatch = iso.firstMatch(dateRange);
  if (isoMatch != null) return DateTime.tryParse(isoMatch.group(1)!);

  // Month name + day, e.g. "June 8" or "Sep 2"
  final months = {
    'jan': 1,
    'feb': 2,
    'mar': 3,
    'apr': 4,
    'may': 5,
    'jun': 6,
    'jul': 7,
    'aug': 8,
    'sep': 9,
    'oct': 10,
    'nov': 11,
    'dec': 12,
  };
  final monthDay = RegExp(r'([A-Za-z]+)\s+(\d{1,2})', caseSensitive: false);
  final match = monthDay.firstMatch(dateRange);
  if (match != null) {
    final monthKey = match.group(1)!.toLowerCase().substring(0, 3);
    final month = months[monthKey];
    final day = int.tryParse(match.group(2)!);
    if (month != null && day != null) {
      final year = DateTime.now().year;
      return DateTime(year, month, day);
    }
  }
  return null;
}

// Parses "14:00", "9:30 AM", "2pm"
({int hour, int minute})? _parseTime(String time) {
  // HH:MM
  final hhmm = RegExp(r'^(\d{1,2}):(\d{2})');
  final m = hhmm.firstMatch(time.trim());
  if (m != null) {
    final h = int.parse(m.group(1)!);
    final min = int.parse(m.group(2)!);
    // AM/PM suffix
    final lc = time.toLowerCase();
    final hour = lc.contains('pm') && h < 12
        ? h + 12
        : lc.contains('am') && h == 12
        ? 0
        : h;
    return (hour: hour, minute: min);
  }
  return null;
}
