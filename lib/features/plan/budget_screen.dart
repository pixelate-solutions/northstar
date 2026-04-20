import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/tag_colors.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/tiny_pill.dart';
import '../../models/trip_plan.dart';
import '../../models/trip_stop.dart';

const _categoryLabels = {
  'lodging': 'Lodging',
  'food': 'Food',
  'transport': 'Transport',
  'activities': 'Activities',
  'other': 'Other',
};

const _categoryIcons = {
  'lodging': Icons.hotel_outlined,
  'food': Icons.restaurant_outlined,
  'transport': Icons.directions_transit_outlined,
  'activities': Icons.local_activity_outlined,
  'other': Icons.more_horiz_rounded,
};

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({
    super.key,
    required this.plan,
    required this.onChanged,
  });

  final TripPlan plan;
  final ValueChanged<TripPlan>? onChanged;

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  late final TextEditingController _totalController;

  @override
  void initState() {
    super.initState();
    _totalController = TextEditingController(
      text: _fmt(widget.plan.budgetTotal),
    );
  }

  @override
  void didUpdateWidget(covariant BudgetScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.plan.id != widget.plan.id ||
        oldWidget.plan.updatedAt != widget.plan.updatedAt) {
      _totalController.text = _fmt(widget.plan.budgetTotal);
    }
  }

  @override
  void dispose() {
    _totalController.dispose();
    super.dispose();
  }

  String get _currency => widget.plan.budgetCurrency;
  String get _symbol => _currencySymbol(_currency);

  // AI-estimated totals per category (summed from stop estimated_cost)
  Map<String, double> get _aiEstimates {
    final totals = <String, double>{};
    for (final day in widget.plan.days) {
      for (final stop in day.stops) {
        if (stop.estimatedCost != null && stop.costCategory != null) {
          totals[stop.costCategory!] =
              (totals[stop.costCategory!] ?? 0) + stop.estimatedCost!;
        }
      }
    }
    // Merge with any server-provided budget_categories
    for (final entry in widget.plan.budgetCategories.entries) {
      if (!totals.containsKey(entry.key)) {
        totals[entry.key] = entry.value;
      }
    }
    return totals;
  }

  double get _aiTotal => _aiEstimates.values.fold(0, (a, b) => a + b);

  double get _userTotal =>
      double.tryParse(
        _totalController.text.replaceAll(RegExp(r'[^0-9.]'), ''),
      ) ??
      0;

  List<TripStop> get _costableStops => [
        for (final day in widget.plan.days)
          for (final stop in day.stops)
            if (stop.estimatedCost != null && stop.estimatedCost! > 0) stop,
      ];

  void _saveBudget() {
    widget.onChanged?.call(
      widget.plan.copyWith(
        budgetTotal: _userTotal > 0 ? _userTotal : null,
        updatedAt: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasAiEstimates = _aiTotal > 0;
    final hasUserBudget = _userTotal > 0;
    final remaining = hasUserBudget ? _userTotal - _aiTotal : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _OverviewCard(
          symbol: _symbol,
          aiTotal: _aiTotal,
          userTotal: _userTotal,
          remaining: remaining,
          hasAiEstimates: hasAiEstimates,
          totalController: _totalController,
          onSave: widget.onChanged == null ? null : _saveBudget,
          onChanged: () => setState(() {}),
        ),
        if (hasAiEstimates) ...[
          const SizedBox(height: 10),
          _CategoryBreakdown(
            symbol: _symbol,
            estimates: _aiEstimates,
            userBudget: _userTotal,
          ),
        ],
        if (_costableStops.isNotEmpty) ...[
          const SizedBox(height: 10),
          _ItemizedList(
            symbol: _symbol,
            plan: widget.plan,
            stops: _costableStops,
          ),
        ],
        if (!hasAiEstimates) ...[
          const SizedBox(height: 10),
          _NoEstimatesCard(),
        ],
      ],
    );
  }
}

// ─── Overview card ────────────────────────────────────────────────────────────

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.symbol,
    required this.aiTotal,
    required this.userTotal,
    required this.remaining,
    required this.hasAiEstimates,
    required this.totalController,
    required this.onSave,
    required this.onChanged,
  });

  final String symbol;
  final double aiTotal;
  final double userTotal;
  final double? remaining;
  final bool hasAiEstimates;
  final TextEditingController totalController;
  final VoidCallback? onSave;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final rem = remaining;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.savings_outlined, color: kForest),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Budget overview',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              if (rem != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: rem >= 0
                        ? kForest.withValues(alpha: .12)
                        : cs.error.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    rem >= 0
                        ? '$symbol${rem.toStringAsFixed(0)} under'
                        : '$symbol${(-rem).toStringAsFixed(0)} over',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: rem >= 0 ? kForest : cs.error,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
          if (hasAiEstimates) ...[
            const SizedBox(height: 14),
            _StatRow(
              label: 'AI estimated total',
              value: '$symbol${aiTotal.toStringAsFixed(0)}',
              valueColor: cs.primary,
            ),
          ],
          if (userTotal > 0) ...[
            const SizedBox(height: 6),
            _StatRow(
              label: 'Your budget',
              value: '$symbol${userTotal.toStringAsFixed(0)}',
              valueColor: cs.onSurface,
            ),
          ],
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: totalController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Set your budget',
                    prefixText: symbol,
                  ),
                  onChanged: (_) => onChanged(),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: onSave,
                child: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: cs.onSurface.withValues(alpha: .6),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w900,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

// ─── Category breakdown ───────────────────────────────────────────────────────

class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown({
    required this.symbol,
    required this.estimates,
    required this.userBudget,
  });

  final String symbol;
  final Map<String, double> estimates;
  final double userBudget;

  @override
  Widget build(BuildContext context) {
    final total = estimates.values.fold(0.0, (a, b) => a + b);
    final categories = _categoryLabels.keys
        .where((k) => (estimates[k] ?? 0) > 0)
        .toList();

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pie_chart_outline_rounded, color: kSky),
              const SizedBox(width: 8),
              Text(
                'By category',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final key in categories) ...[
            _CategoryRow(
              icon: _categoryIcons[key] ?? Icons.circle_outlined,
              label: _categoryLabels[key] ?? key,
              amount: estimates[key] ?? 0,
              total: total,
              symbol: symbol,
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.icon,
    required this.label,
    required this.amount,
    required this.total,
    required this.symbol,
  });

  final IconData icon;
  final String label;
  final double amount;
  final double total;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fraction = total > 0 ? (amount / total).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: cs.primary),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              '$symbol${amount.toStringAsFixed(0)}',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 38,
              child: Text(
                '${(fraction * 100).toStringAsFixed(0)}%',
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: .5),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 5,
            backgroundColor: cs.onSurface.withValues(alpha: .08),
            color: cs.primary,
          ),
        ),
      ],
    );
  }
}

// ─── Itemized list ────────────────────────────────────────────────────────────

class _ItemizedList extends StatelessWidget {
  const _ItemizedList({
    required this.symbol,
    required this.plan,
    required this.stops,
  });

  final String symbol;
  final TripPlan plan;
  final List<TripStop> stops;

  String _dayLabel(TripStop stop) {
    for (final day in plan.days) {
      if (day.stops.contains(stop)) return day.label;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_outlined, color: kCoral),
              const SizedBox(width: 8),
              Text(
                'Itemized costs',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < stops.length; i++) ...[
            _ItemRow(
              symbol: symbol,
              stop: stops[i],
              dayLabel: _dayLabel(stops[i]),
            ),
            if (i < stops.length - 1)
              Divider(
                height: 16,
                color: cs.onSurface.withValues(alpha: .08),
              ),
          ],
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.symbol,
    required this.stop,
    required this.dayLabel,
  });

  final String symbol;
  final TripStop stop;
  final String dayLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = tagColor(stop.tag);
    final catLabel =
        _categoryLabels[stop.costCategory] ?? stop.costCategory ?? '';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .14),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(stop.icon, color: color, size: 17),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stop.title,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              Row(
                children: [
                  Text(
                    dayLabel,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: .5),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (catLabel.isNotEmpty) ...[
                    Text(
                      ' · ',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: .4),
                      ),
                    ),
                    TinyPill(label: catLabel, color: cs.primary),
                  ],
                ],
              ),
            ],
          ),
        ),
        Text(
          '$symbol${stop.estimatedCost!.toStringAsFixed(0)}',
          style: Theme.of(context).textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

// ─── No estimates placeholder ─────────────────────────────────────────────────

class _NoEstimatesCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GlassCard(
      child: Column(
        children: [
          Icon(
            Icons.auto_awesome_outlined,
            size: 32,
            color: cs.onSurface.withValues(alpha: .3),
          ),
          const SizedBox(height: 10),
          Text(
            'No AI estimates yet',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: cs.onSurface.withValues(alpha: .5),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Cost estimates will appear here after the AI builds your trip.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cs.onSurface.withValues(alpha: .45),
            ),
          ),
        ],
      ),
    );
  }
}

String _fmt(double? v) {
  if (v == null || v == 0) return '';
  return v.truncateToDouble() == v
      ? v.toStringAsFixed(0)
      : v.toStringAsFixed(2);
}

String _currencySymbol(String currency) => switch (currency.toUpperCase()) {
      'USD' => r'$',
      'EUR' => '€',
      'GBP' => '£',
      _ => '$currency ',
    };
