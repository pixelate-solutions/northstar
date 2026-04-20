import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/trip_plan.dart';
import 'trip_rail.dart';

enum TripLibraryView { grid, list }

class TripLibrary extends StatefulWidget {
  const TripLibrary({
    super.key,
    required this.plans,
    required this.selectedIndex,
    required this.onSelected,
    required this.onNewTrip,
  });

  final List<TripPlan> plans;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onNewTrip;

  @override
  State<TripLibrary> createState() => _TripLibraryState();
}

class _TripLibraryState extends State<TripLibrary> {
  final _searchController = TextEditingController();
  TripLibraryView _view = TripLibraryView.grid;
  bool _showPastTrips = false;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entries = _filteredEntries;
    final hiddenPastCount = widget.plans.where(_isPastTrip).length;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: kInk,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.travel_explore_rounded,
                        color: kGold,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Trips',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  height: 1,
                                ),
                          ),
                          Text(
                            '${entries.length} ${entries.length == 1 ? 'trip' : 'trips'}',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: .55),
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: 'Plan a trip',
                      onPressed: widget.onNewTrip,
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SegmentedButton<TripLibraryView>(
                  segments: const [
                    ButtonSegment(
                      value: TripLibraryView.grid,
                      icon: Icon(Icons.grid_view_rounded),
                      label: Text('Grid'),
                    ),
                    ButtonSegment(
                      value: TripLibraryView.list,
                      icon: Icon(Icons.view_list_rounded),
                      label: Text('List'),
                    ),
                  ],
                  selected: {_view},
                  onSelectionChanged: (selection) {
                    setState(() => _view = selection.first);
                  },
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                    hintText: 'Search trips, destinations, dates',
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilterChip(
                      label: Text(
                        hiddenPastCount == 0
                            ? 'Show past trips'
                            : 'Show past trips ($hiddenPastCount)',
                      ),
                      selected: _showPastTrips,
                      showCheckmark: false,
                      onSelected: (value) =>
                          setState(() => _showPastTrips = value),
                      avatar: const Icon(Icons.history_rounded, size: 18),
                    ),
                    if (!_showPastTrips && hiddenPastCount > 0)
                      Text(
                        'Past trips are hidden.',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: .55),
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (widget.plans.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _LibraryEmptyState(onNewTrip: widget.onNewTrip),
          )
        else if (entries.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _NoMatchingTrips(
              showPastTrips: _showPastTrips,
              hiddenPastCount: hiddenPastCount,
              onShowPastTrips: hiddenPastCount == 0
                  ? null
                  : () => setState(() => _showPastTrips = true),
            ),
          )
        else if (_view == TripLibraryView.grid)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.crossAxisExtent;
                final crossAxisCount = width >= 980
                    ? 3
                    : width >= 620
                    ? 2
                    : 1;
                return SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    mainAxisExtent: 150,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final entry = entries[index];
                    return TripCard(
                      plan: entry.plan,
                      selected: false,
                      onTap: () => widget.onSelected(entry.originalIndex),
                    );
                  }, childCount: entries.length),
                );
              },
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
            sliver: SliverList.separated(
              itemCount: entries.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return _TripListTile(
                  plan: entry.plan,
                  selected: false,
                  onTap: () => widget.onSelected(entry.originalIndex),
                );
              },
            ),
          ),
      ],
    );
  }

  List<_TripEntry> get _filteredEntries {
    final normalizedQuery = _query.trim().toLowerCase();
    final entries = <_TripEntry>[];
    for (var i = 0; i < widget.plans.length; i++) {
      final plan = widget.plans[i];
      if (!_showPastTrips && _isPastTrip(plan)) continue;
      if (normalizedQuery.isNotEmpty && !_matchesQuery(plan, normalizedQuery)) {
        continue;
      }
      entries.add(_TripEntry(originalIndex: i, plan: plan));
    }
    return entries;
  }

  bool _matchesQuery(TripPlan plan, String query) {
    final haystack = [
      plan.title,
      plan.dateRange,
      plan.summary,
      plan.pace,
      ...plan.destinations,
    ].join(' ').toLowerCase();
    return haystack.contains(query);
  }
}

class _TripListTile extends StatelessWidget {
  const _TripListTile({
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  final TripPlan plan;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: selected ? kInk : cs.surface.withValues(alpha: .82),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: .1)
                      : kMint.withValues(alpha: .9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  plan.destinations.length > 1
                      ? Icons.route_outlined
                      : Icons.place_outlined,
                  color: selected ? kGold : kForest,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: selected ? Colors.white : cs.onSurface,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${plan.dateRange} · ${plan.days.length} days · ${plan.stops.length} stops',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: selected
                            ? Colors.white70
                            : cs.onSurface.withValues(alpha: .58),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.chevron_right_rounded,
                color: selected
                    ? Colors.white70
                    : cs.onSurface.withValues(alpha: .45),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LibraryEmptyState extends StatelessWidget {
  const _LibraryEmptyState({required this.onNewTrip});

  final VoidCallback onNewTrip;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.luggage_outlined, size: 48, color: cs.primary),
            const SizedBox(height: 14),
            Text(
              'No trips yet',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              'Start with a destination, dates, or the kind of trip you want.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.onSurface.withValues(alpha: .58),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onNewTrip,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Plan a trip'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoMatchingTrips extends StatelessWidget {
  const _NoMatchingTrips({
    required this.showPastTrips,
    required this.hiddenPastCount,
    required this.onShowPastTrips,
  });

  final bool showPastTrips;
  final int hiddenPastCount;
  final VoidCallback? onShowPastTrips;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final canShowPast = !showPastTrips && hiddenPastCount > 0;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.manage_search_rounded, size: 48, color: cs.primary),
            const SizedBox(height: 14),
            Text(
              'No matching trips',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              canShowPast
                  ? 'Past trips are hidden by default.'
                  : 'Try a different search.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.onSurface.withValues(alpha: .58),
                height: 1.35,
              ),
            ),
            if (canShowPast) ...[
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: onShowPastTrips,
                icon: const Icon(Icons.history_rounded),
                label: const Text('Show past trips'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TripEntry {
  const _TripEntry({required this.originalIndex, required this.plan});

  final int originalIndex;
  final TripPlan plan;
}

bool _isPastTrip(TripPlan plan) {
  final endDate = _parseTripEndDate(plan.dateRange);
  if (endDate == null) return false;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final lastDay = DateTime(endDate.year, endDate.month, endDate.day);
  return lastDay.isBefore(today);
}

DateTime? _parseTripEndDate(String dateRange) {
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
