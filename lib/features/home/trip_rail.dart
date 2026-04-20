import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/trip_plan.dart';

class TripSwitcher extends StatefulWidget {
  const TripSwitcher({
    super.key,
    required this.plans,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<TripPlan> plans;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  State<TripSwitcher> createState() => _TripSwitcherState();
}

class _TripSwitcherState extends State<TripSwitcher>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final safeIndex = widget.selectedIndex.clamp(0, widget.plans.length - 1);
    final selected = widget.plans[safeIndex];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Ink(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cs.surface.withValues(alpha: .82),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: cs.surface.withValues(alpha: .9)),
                  boxShadow: [
                    BoxShadow(
                      color: kInk.withValues(alpha: .06),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.luggage_outlined, color: cs.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selected.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          Text(
                            '${widget.plans.length} trips - tap to ${_expanded ? 'collapse' : 'expand'}',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: cs.onSurface.withValues(alpha: .55),
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: _expanded ? .5 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: const Icon(Icons.keyboard_arrow_down_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: _expanded
                ? SizedBox(
                    height: 132,
                    child: ListView.separated(
                      padding: const EdgeInsets.only(top: 10),
                      scrollDirection: Axis.horizontal,
                      itemCount: widget.plans.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (_, i) => SizedBox(
                        width: 250,
                        child: TripCard(
                          plan: widget.plans[i],
                          selected: i == widget.selectedIndex,
                          onTap: () {
                            widget.onSelected(i);
                            setState(() => _expanded = false);
                          },
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class TripRail extends StatelessWidget {
  const TripRail({
    super.key,
    required this.plans,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<TripPlan> plans;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 18),
      itemCount: plans.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) => TripCard(
        plan: plans[i],
        selected: i == selectedIndex,
        onTap: () => onSelected(i),
      ),
    );
  }
}

class TripCard extends StatelessWidget {
  const TripCard({
    super.key,
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: selected ? kInk : cs.surface.withValues(alpha: .74),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: selected ? kInk : cs.surface.withValues(alpha: .82),
        ),
        boxShadow: [
          BoxShadow(
            color: kInk.withValues(alpha: selected ? .16 : .06),
            blurRadius: selected ? 22 : 12,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      plan.destinations.length > 1
                          ? Icons.route_outlined
                          : Icons.place_outlined,
                      color: selected ? kGold : kForest,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        plan.dateRange,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: selected
                                  ? Colors.white70
                                  : cs.onSurface.withValues(alpha: .55),
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  plan.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: selected ? Colors.white : cs.onSurface,
                    fontWeight: FontWeight.w900,
                    height: 1.08,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  '${plan.days.length} days · ${plan.stops.length} places',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: selected
                        ? Colors.white70
                        : cs.onSurface.withValues(alpha: .55),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
