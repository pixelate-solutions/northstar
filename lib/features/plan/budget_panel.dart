import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/glass_card.dart';
import '../../models/trip_plan.dart';

const _budgetLabels = {
  'lodging': 'Lodging',
  'food': 'Food',
  'transport': 'Transport',
  'activities': 'Activities',
  'other': 'Other',
};

class BudgetPanel extends StatefulWidget {
  const BudgetPanel({super.key, required this.plan, required this.onChanged});

  final TripPlan plan;
  final ValueChanged<TripPlan>? onChanged;

  @override
  State<BudgetPanel> createState() => _BudgetPanelState();
}

class _BudgetPanelState extends State<BudgetPanel> {
  late final TextEditingController _total;
  late final Map<String, TextEditingController> _categories;

  @override
  void initState() {
    super.initState();
    _total = TextEditingController(
      text: _formatAmount(widget.plan.budgetTotal),
    );
    _categories = {
      for (final key in _budgetLabels.keys)
        key: TextEditingController(
          text: _formatAmount(widget.plan.budgetCategories[key]),
        ),
    };
  }

  @override
  void didUpdateWidget(covariant BudgetPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.plan.id == widget.plan.id &&
        oldWidget.plan.updatedAt == widget.plan.updatedAt) {
      return;
    }
    _total.text = _formatAmount(widget.plan.budgetTotal);
    for (final entry in _categories.entries) {
      entry.value.text = _formatAmount(widget.plan.budgetCategories[entry.key]);
    }
  }

  @override
  void dispose() {
    _total.dispose();
    for (final controller in _categories.values) {
      controller.dispose();
    }
    super.dispose();
  }

  double get _plannedTotal => _categories.values
      .map((controller) => _parseAmount(controller.text))
      .fold(0, (sum, value) => sum + value);

  double get _tripTotal => _parseAmount(_total.text);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final remaining = _tripTotal - _plannedTotal;

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
                  'Budget',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                _tripTotal > 0
                    ? '${_currencySymbol(widget.plan.budgetCurrency)}${remaining.toStringAsFixed(0)} left'
                    : 'Set total',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: remaining < 0 ? cs.error : cs.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _total,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Trip budget',
              prefixIcon: Icon(Icons.attach_money_rounded),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final twoColumns = constraints.maxWidth >= 560;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final entry in _budgetLabels.entries)
                    SizedBox(
                      width: twoColumns
                          ? (constraints.maxWidth - 10) / 2
                          : constraints.maxWidth,
                      child: TextField(
                        controller: _categories[entry.key],
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: entry.value),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Planned ${_currencySymbol(widget.plan.budgetCurrency)}${_plannedTotal.toStringAsFixed(0)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: .58),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              FilledButton(
                onPressed: widget.onChanged == null ? null : _save,
                child: const Text('Save budget'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _save() {
    widget.onChanged?.call(
      widget.plan.copyWith(
        budgetTotal: _tripTotal,
        budgetCategories: {
          for (final entry in _categories.entries)
            entry.key: _parseAmount(entry.value.text),
        },
      ),
    );
  }

  double _parseAmount(String value) {
    return double.tryParse(value.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
  }

  String _formatAmount(double? value) {
    if (value == null || value == 0) return '';
    return value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2);
  }

  String _currencySymbol(String currency) {
    return switch (currency.toUpperCase()) {
      'USD' => r'$',
      'EUR' => '€',
      'GBP' => '£',
      _ => '$currency ',
    };
  }
}
