import 'package:flutter/material.dart';
import 'package:monitrack/l10n/app_localizations.dart';

import '../../models/expense.dart';
import '../../utils/app_theme.dart';
import 'expense_bar_chart.dart';
import 'expense_chart_data.dart';
import 'expense_line_chart.dart';

/// Section « graphique » du tableau de bord : bascule barres/courbes,
/// graphique et légende.
class ExpenseChartSection extends StatelessWidget {
  const ExpenseChartSection({
    super.key,
    required this.range,
    required this.expenses,
    required this.currency,
    required this.showIncome,
    required this.showExpense,
    required this.isBarChart,
    required this.onChartTypeChanged,
  });

  final DateTimeRange range;
  final List<Expense> expenses;
  final String currency;
  final bool showIncome;
  final bool showExpense;
  final bool isBarChart;
  final ValueChanged<bool> onChartTypeChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final dailyData = aggregateDailyData(expenses, range);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _ChartToggleButton(
              icon: Icons.bar_chart_rounded,
              isActive: isBarChart,
              onTap: () => onChartTypeChanged(true),
            ),
            const SizedBox(width: 4),
            _ChartToggleButton(
              icon: Icons.show_chart_rounded,
              isActive: !isBarChart,
              onTap: () => onChartTypeChanged(false),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 220,
          child: dailyData.isEmpty
              ? Center(
                  child: Text(
                    l10n.noOperationPeriod,
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                )
              : isBarChart
                  ? buildExpenseBarChart(
                      dailyData, showIncome, showExpense, currency, colorScheme)
                  : buildExpenseLineChart(
                      dailyData, showIncome, showExpense, currency, colorScheme),
        ),
        if (dailyData.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (showIncome) ...[
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: colorScheme.income,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  l10n.incomes,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (showIncome && showExpense) const SizedBox(width: 16),
              if (showExpense) ...[
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: colorScheme.expense,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  l10n.expenses,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _ChartToggleButton extends StatelessWidget {
  const _ChartToggleButton({
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isActive
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
              // `Colors.transparent` : état inactif neutre, valide dans les
              // deux thèmes (la surface réelle transparaît).
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outlineVariant,
            width: 1.5,
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isActive
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
