import 'package:flutter/material.dart';

import '../../core/utils/trip_date_utils.dart';
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
  TripLibraryView _view = TripLibraryView.list;
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
    final hiddenPastCount = widget.plans.where(isPastTrip).length;

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
                      isPast: entry.isPast,
                      badgeLabel: entry.isPast ? 'Past' : null,
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
                  isPast: entry.isPast,
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
      final isPast = isPastTrip(plan);
      if (!_showPastTrips && isPast) continue;
      if (normalizedQuery.isNotEmpty && !_matchesQuery(plan, normalizedQuery)) {
        continue;
      }
      entries.add(_TripEntry(originalIndex: i, plan: plan, isPast: isPast));
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
    required this.isPast,
    required this.onTap,
  });

  final TripPlan plan;
  final bool selected;
  final bool isPast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final backgroundColor = selected
        ? kInk
        : isPast
        ? cs.surfaceContainerHighest.withValues(alpha: .68)
        : cs.surface.withValues(alpha: .82);
    final titleColor = selected
        ? Colors.white
        : isPast
        ? cs.onSurface.withValues(alpha: .82)
        : cs.onSurface;
    final detailColor = selected
        ? Colors.white70
        : cs.onSurface.withValues(alpha: isPast ? .48 : .58);
    return Material(
      color: backgroundColor,
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
                      : isPast
                      ? cs.surface.withValues(alpha: .95)
                      : kMint.withValues(alpha: .9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  plan.destinations.length > 1
                      ? Icons.route_outlined
                      : Icons.place_outlined,
                  color: selected
                      ? kGold
                      : isPast
                      ? cs.onSurface.withValues(alpha: .62)
                      : kForest,
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
                        color: titleColor,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${plan.dateRange} · ${plan.days.length} days · ${plan.stops.length} stops',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: detailColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (isPast) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Past',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
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
  const _TripEntry({
    required this.originalIndex,
    required this.plan,
    required this.isPast,
  });

  final int originalIndex;
  final TripPlan plan;
  final bool isPast;
}
