import 'package:flutter/material.dart';
import '../../models/trip_plan.dart';
import '../../models/trip_day.dart';
import '../../models/trip_stop.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/tag_colors.dart';
import '../../core/utils/time_format.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/tiny_pill.dart';

class OverviewPanel extends StatelessWidget {
  const OverviewPanel({
    super.key,
    required this.plan,
    required this.days,
    required this.onFollowUpSelected,
  });

  final TripPlan plan;
  final List<TripDay> days;
  final ValueChanged<String> onFollowUpSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final day in days) ...[
          DayCard(day: day),
          const SizedBox(height: 10),
        ],
        if (plan.openQuestions.isNotEmpty)
          _OpenQuestionsCard(
            questions: plan.openQuestions,
            onSelected: onFollowUpSelected,
          ),
      ],
    );
  }
}

class DayCard extends StatelessWidget {
  const DayCard({super.key, required this.day});
  final TripDay day;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TinyPill(label: day.label, color: kForest),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  day.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _briefPublicText(day.guidance, maxChars: 130),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: cs.onSurface.withValues(alpha: .55),
              height: 1.32,
            ),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < day.stops.length; i++)
            StopRow(stop: day.stops[i], isLast: i == day.stops.length - 1),
        ],
      ),
    );
  }
}

class StopRow extends StatelessWidget {
  const StopRow({super.key, required this.stop, required this.isLast});
  final TripStop stop;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = tagColor(stop.tag);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 54,
            child: Text(
              formatDisplayTime(stop.time, compactPeriod: true),
              maxLines: 1,
              overflow: TextOverflow.visible,
              softWrap: false,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: cs.onSurface.withValues(alpha: .5),
                fontWeight: FontWeight.w900,
                fontSize: 11,
              ),
            ),
          ),
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(stop.icon, color: color, size: 18),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 7),
                    color: cs.brightness == Brightness.light
                        ? kLine
                        : kDarkLine,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          stop.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      TinyPill(label: stop.tag, color: color),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _briefPublicText(stop.place, maxChars: 46),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurface.withValues(alpha: .55),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _briefPublicText(stop.note, maxChars: 110),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(height: 1.3),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OpenQuestionsCard extends StatelessWidget {
  const _OpenQuestionsCard({required this.questions, required this.onSelected});
  final List<String> questions;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.help_outline_rounded, color: kCoral),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Suggested edits',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final q in questions)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onSelected(_followUpCommand(q)),
                  borderRadius: BorderRadius.circular(16),
                  child: Ink(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: kCoral.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: kCoral.withValues(alpha: .18)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.auto_fix_high_outlined,
                          size: 18,
                          color: kCoral,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            _followUpCommand(q),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  height: 1.3,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
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

String _followUpCommand(String value) {
  final clean = _briefPublicText(
    value,
    maxChars: 100,
  ).replaceAll(RegExp(r'\?+$'), '.').trim();
  if (clean.isEmpty) return clean;
  final lower = clean.toLowerCase();
  if (RegExp(
    r'^(do|does|did|are|is|was|were|will|would|should|can|could|have|has)\b',
  ).hasMatch(lower)) {
    return 'Confirm: ${clean.replaceAll(RegExp(r'\.$'), '')}.';
  }
  if (RegExp(r'^(what|where|when|who|which|how)\b').hasMatch(lower)) {
    return 'Provide: ${clean.replaceAll(RegExp(r'\.$'), '')}.';
  }
  return RegExp(r'[.!]$').hasMatch(clean) ? clean : '$clean.';
}
