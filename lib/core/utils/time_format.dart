String formatDisplayTime(String value, {bool compactPeriod = false}) {
  final trimmed = value.trim();
  final normalized = _normalizeTimeValue(trimmed);
  final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(normalized);
  if (match == null) return '--';

  final hour = int.tryParse(match.group(1)!);
  final minute = int.tryParse(match.group(2)!);
  if (hour == null || minute == null || hour > 23 || minute > 59) {
    return trimmed;
  }

  final suffix = hour >= 12
      ? compactPeriod
            ? 'p'
            : 'pm'
      : compactPeriod
      ? 'a'
      : 'am';
  final displayHour = hour % 12 == 0 ? 12 : hour % 12;
  return '$displayHour:${minute.toString().padLeft(2, '0')}$suffix';
}

String _normalizeTimeValue(String value) {
  final trimmed = value.trim();
  if (RegExp(r'^\d{1,2}:\d{2}$').hasMatch(trimmed)) return trimmed;

  final lower = trimmed.toLowerCase();
  final periodMatch = RegExp(
    r'^(\d{1,2})(?::([0-5]\d))?\s*([ap])\.?m?\.?$',
  ).firstMatch(lower);
  if (periodMatch != null) {
    var hour = int.tryParse(periodMatch.group(1)!);
    final minute = periodMatch.group(2) ?? '00';
    final period = periodMatch.group(3);
    if (hour == null) return trimmed;
    if (period == 'p' && hour < 12) hour += 12;
    if (period == 'a' && hour == 12) hour = 0;
    if (hour >= 0 && hour <= 23) {
      return '${hour.toString().padLeft(2, '0')}:$minute';
    }
  }

  if (lower.contains('early') && lower.contains('morning')) return '08:00';
  if (lower.contains('morning')) return '09:00';
  if (lower.contains('lunch')) return '12:30';
  if (lower.contains('late') && lower.contains('afternoon')) return '16:00';
  if (lower.contains('afternoon')) return '13:30';
  if (lower.contains('dinner')) return '19:00';
  if (lower.contains('evening')) return '18:30';
  if (lower.contains('night')) return '20:00';
  return trimmed;
}
