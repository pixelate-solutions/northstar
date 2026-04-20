import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'plan_view.dart';

class PlanTabs extends StatelessWidget {
  const PlanTabs({super.key, required this.selected, required this.onSelected});

  final PlanView selected;
  final ValueChanged<PlanView> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _TabButton(
          key: const ValueKey('plan-tab'),
          label: 'Plan',
          icon: Icons.view_agenda_outlined,
          selected: selected == PlanView.overview,
          onTap: () => onSelected(PlanView.overview),
        ),
        const SizedBox(width: 8),
        _TabButton(
          key: const ValueKey('map-tab'),
          label: 'Map',
          icon: Icons.map_outlined,
          selected: selected == PlanView.map,
          onTap: () => onSelected(PlanView.map),
        ),
        const SizedBox(width: 8),
        _TabButton(
          key: const ValueKey('budget-tab'),
          label: 'Budget',
          icon: Icons.savings_outlined,
          selected: selected == PlanView.budget,
          onTap: () => onSelected(PlanView.budget),
        ),
      ],
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: selected ? kInk : cs.surface.withValues(alpha: .72),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? kInk : cs.surface),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 19,
                    color: selected
                        ? kGold
                        : cs.onSurface.withValues(alpha: .5),
                  ),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: selected ? Colors.white : cs.onSurface,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
