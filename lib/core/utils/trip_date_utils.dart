import '../../models/trip_plan.dart';

bool isPastTrip(TripPlan plan) {
  final endDate = parseTripEndDate(plan.dateRange);
  if (endDate == null) return false;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final lastDay = DateTime(endDate.year, endDate.month, endDate.day);
  return lastDay.isBefore(today);
}

DateTime? parseTripEndDate(String dateRange) {
  final normalized = dateRange
      .replaceAll(RegExp(r'[–—]'), '-')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (normalized.isEmpty) return null;

  final isoMatches = RegExp(r'(\d{4}-\d{2}-\d{2})').allMatches(normalized);
  if (isoMatches.isNotEmpty) {
    return DateTime.tryParse(isoMatches.last.group(1)!);
  }

  final compactRange = RegExp(
    r'([A-Za-z]{3,9})\s+(\d{1,2})(?:,\s*\d{4})?\s*-\s*(?:([A-Za-z]{3,9})\s+)?(\d{1,2})(?:,?\s*(\d{4}))?',
    caseSensitive: false,
  ).firstMatch(normalized);
  if (compactRange != null) {
    final endMonthName = compactRange.group(3) ?? compactRange.group(1)!;
    final month = _monthNumber(endMonthName);
    final day = int.tryParse(compactRange.group(4)!);
    final year =
        int.tryParse(compactRange.group(5) ?? '') ?? _lastYear(normalized);
    if (month != null && day != null) return DateTime(year, month, day);
  }

  final monthDayYear = RegExp(
    r'([A-Za-z]{3,9})\s+(\d{1,2})(?:,?\s*(\d{4}))?',
    caseSensitive: false,
  );
  final matches = monthDayYear.allMatches(normalized).toList();
  if (matches.isEmpty) return null;

  final last = matches.last;
  final month = _monthNumber(last.group(1)!);
  final day = int.tryParse(last.group(2)!);
  final year = int.tryParse(last.group(3) ?? '') ?? _lastYear(normalized);
  if (month == null || day == null) return null;
  return DateTime(year, month, day);
}

int _lastYear(String value) {
  final years = RegExp(r'\b(19\d{2}|20\d{2}|21\d{2})\b').allMatches(value);
  if (years.isNotEmpty) return int.parse(years.last.group(1)!);
  return DateTime.now().year;
}

int? _monthNumber(String value) {
  final key = value.toLowerCase();
  if (key.length < 3) return null;
  return const {
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
  }[key.substring(0, 3)];
}
