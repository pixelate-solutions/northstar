import 'package:flutter/material.dart';
import '../../agent/agent_client.dart';
import '../../models/trip_plan.dart';
import '../../models/trip_day.dart';
import '../../models/agent_event.dart';
import 'overview_panel.dart';
import 'map_panel.dart';
import 'budget_screen.dart';
import 'plan_hero.dart';
import 'plan_tabs.dart';
import 'plan_view.dart';

class PlanDetailScreen extends StatefulWidget {
  const PlanDetailScreen({
    super.key,
    required this.plan,
    required this.view,
    required this.onViewChanged,
    required this.onEdit,
    this.onShare,
    this.onDelete,
    this.onFollowUpSelected,
    this.onBudgetChanged,
    this.canManage = true,
  });

  final TripPlan plan;
  final PlanView view;
  final ValueChanged<PlanView> onViewChanged;
  final Future<void> Function(
    String instruction,
    AgentEventSink onEvent, {
    AgentRunController? controller,
  })
  onEdit;
  final VoidCallback? onShare;
  final VoidCallback? onDelete;
  final ValueChanged<String>? onFollowUpSelected;
  final ValueChanged<TripPlan>? onBudgetChanged;
  final bool canManage;

  @override
  State<PlanDetailScreen> createState() => _PlanDetailScreenState();
}

class _PlanDetailScreenState extends State<PlanDetailScreen> {
  int? _selectedDayIndex;

  List<TripDay> get _visibleDays {
    final index = _selectedDayIndex;
    if (index == null || index < 0 || index >= widget.plan.days.length) {
      return widget.plan.days;
    }
    return [widget.plan.days[index]];
  }

  @override
  void didUpdateWidget(covariant PlanDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.plan.id != widget.plan.id) {
      _selectedDayIndex = null;
      return;
    }
    final index = _selectedDayIndex;
    if (index != null && index >= widget.plan.days.length) {
      _selectedDayIndex = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeOutCubic,
      child: ListView(
        key: ValueKey('${widget.plan.id}-${widget.view}'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          PlanHero(
            plan: widget.plan,
            onShare: widget.onShare,
            onDelete: widget.onDelete,
            canManage: widget.canManage,
          ),
          const SizedBox(height: 14),
          PlanTabs(selected: widget.view, onSelected: widget.onViewChanged),
          if (widget.plan.days.length > 1 &&
              widget.view != PlanView.budget) ...[
            const SizedBox(height: 10),
            _DayFilterDropdown(
              days: widget.plan.days,
              selectedIndex: _selectedDayIndex,
              onChanged: (index) => setState(() => _selectedDayIndex = index),
            ),
          ],
          const SizedBox(height: 14),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            child: switch (widget.view) {
              PlanView.overview => OverviewPanel(
                key: const ValueKey('overview'),
                plan: widget.plan,
                days: _visibleDays,
                onFollowUpSelected: widget.onFollowUpSelected ?? (_) {},
              ),
              PlanView.map => MapPanel(
                key: const ValueKey('map'),
                plan: widget.plan,
                days: _visibleDays,
              ),
              PlanView.budget => BudgetScreen(
                key: const ValueKey('budget'),
                plan: widget.plan,
                onChanged: widget.onBudgetChanged,
              ),
            },
          ),
        ],
      ),
    );
  }
}

class _DayFilterDropdown extends StatelessWidget {
  const _DayFilterDropdown({
    required this.days,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<TripDay> days;
  final int? selectedIndex;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: .82),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.onSurface.withValues(alpha: .08)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: selectedIndex,
          isExpanded: true,
          menuMaxHeight: 300,
          borderRadius: BorderRadius.circular(20),
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          onChanged: onChanged,
          items: [
            const DropdownMenuItem<int?>(
              value: null,
              child: Text(
                'All days',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
              ),
            ),
            for (var i = 0; i < days.length; i++)
              DropdownMenuItem<int?>(
                value: i,
                child: Text(
                  '${days[i].label} - ${days[i].title}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
