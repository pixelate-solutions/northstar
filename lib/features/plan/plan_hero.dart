import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/tiny_pill.dart';
import '../../models/trip_plan.dart';

class PlanHero extends StatelessWidget {
  const PlanHero({
    super.key,
    required this.plan,
    this.onShare,
    this.onDelete,
    this.canManage = true,
  });

  final TripPlan plan;
  final VoidCallback? onShare;
  final VoidCallback? onDelete;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final daysUntilStart = _daysUntilTripStart(plan.dateRange);
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: .74),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: cs.surface.withValues(alpha: .82)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _briefPublicText(plan.title, maxChars: 52),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w900,
                                height: 1.02,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${plan.destinations.take(4).join(' · ')} · ${plan.dateRange}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: cs.onSurface.withValues(alpha: .55),
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  TinyPill(label: plan.pace, color: kForest),
                  if (onShare != null || onDelete != null) ...[
                    const SizedBox(width: 4),
                    PopupMenuButton<_TripAction>(
                      tooltip: 'Trip actions',
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                      clipBehavior: Clip.antiAlias,
                      onSelected: (action) {
                        switch (action) {
                          case _TripAction.share:
                            onShare?.call();
                          case _TripAction.delete:
                            onDelete?.call();
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: _TripAction.share,
                          enabled: canManage && onShare != null,
                          child: const ListTile(
                            leading: Icon(Icons.ios_share_outlined),
                            title: Text('Share trip'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        PopupMenuItem(
                          value: _TripAction.delete,
                          enabled: canManage && onDelete != null,
                          child: ListTile(
                            leading: Icon(
                              Icons.delete_outline_rounded,
                              color: cs.error,
                            ),
                            title: Text(
                              'Delete trip',
                              style: TextStyle(color: cs.error),
                            ),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                      icon: const Icon(Icons.more_horiz_rounded),
                    ),
                  ],
                ],
              ),
              if (plan.sharedWithEmails.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final email in plan.sharedWithEmails)
                      TinyPill(label: email, color: kSky),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              Text(
                _briefPublicText(plan.summary, maxChars: 190),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(height: 1.34),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _HeroStat(
                      icon: Icons.calendar_today_outlined,
                      label: 'Trip days',
                      value: '${plan.days.length}',
                      color: kForest,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _HeroStat(
                      icon: Icons.pin_drop_outlined,
                      label: 'Stops',
                      value: '${plan.stops.length}',
                      color: kCoral,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _HeroStat(
                      icon: Icons.event_available_outlined,
                      label: 'Days until',
                      value: daysUntilStart?.toString() ?? '--',
                      color: kSky,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _briefPublicText(String value, {required int maxChars}) {
  final internalPattern = RegExp(
    r'\b(adjusted|validated?|validates?|validation|coordinate|coordinates|geocod(?:e|ed|ing)|tool|internal|model|agent)\b',
    caseSensitive: false,
  );
  final cleaned = value
      .replaceAll(RegExp(r'\s+'), ' ')
      .split(RegExp(r'(?<=[.!?])\s+'))
      .where((sentence) => !internalPattern.hasMatch(sentence))
      .join(' ')
      .trim();
  final text = cleaned.isEmpty
      ? value.replaceAll(RegExp(r'\s+'), ' ').trim()
      : cleaned;
  if (text.length <= maxChars) return text;
  final cut = text.substring(0, maxChars + 1);
  final boundary = cut.lastIndexOf(RegExp(r'\s'));
  return '${cut.substring(0, boundary > 24 ? boundary : maxChars).trim()}...';
}

int? _daysUntilTripStart(String dateRange) {
  final startDate = _parseTripStartDate(dateRange);
  if (startDate == null) return null;
  final today = DateTime.now();
  final todayDate = DateTime(today.year, today.month, today.day);
  final tripDate = DateTime(startDate.year, startDate.month, startDate.day);
  final days = tripDate.difference(todayDate).inDays;
  return days < 0 ? 0 : days;
}

DateTime? _parseTripStartDate(String dateRange) {
  final iso = RegExp(r'(\d{4}-\d{2}-\d{2})');
  final isoMatch = iso.firstMatch(dateRange);
  if (isoMatch != null) return DateTime.tryParse(isoMatch.group(1)!);

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
  if (match == null) return null;

  final rawMonth = match.group(1)!.toLowerCase();
  if (rawMonth.length < 3) return null;
  final month = months[rawMonth.substring(0, 3)];
  final day = int.tryParse(match.group(2)!);
  if (month == null || day == null) return null;

  final now = DateTime.now();
  final parsed = DateTime(now.year, month, day);
  final today = DateTime(now.year, now.month, now.day);
  if (parsed.isBefore(today)) return DateTime(now.year + 1, month, day);
  return parsed;
}

enum _TripAction { share, delete }

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: cs.onSurface.withValues(alpha: .55),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
