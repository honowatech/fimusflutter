import 'package:flutter/material.dart';
import 'package:monitrack/l10n/app_localizations.dart';

import 'expense_date_filters.dart';

/// Barre de filtres (période + type + catégories) partagée par les onglets
/// Tableau de bord et Historique.
class ExpenseFilterBar extends StatelessWidget {
  const ExpenseFilterBar({
    super.key,
    required this.periodFilter,
    required this.customDateRange,
    required this.typeFilter,
    required this.onPeriodChanged,
    required this.onCustomDateTap,
    required this.onTypeChanged,
    this.showAllOption = true,
    this.showScheduledOption = false,
    this.showPeriodFilter = true,
    this.categoryFilter,
  });

  final String periodFilter;
  final DateTimeRange? customDateRange;
  final String typeFilter;
  final ValueChanged<String> onPeriodChanged;
  final VoidCallback onCustomDateTap;
  final ValueChanged<String> onTypeChanged;
  final bool showAllOption;
  final bool showScheduledOption;
  final bool showPeriodFilter;
  final Widget? categoryFilter;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (showPeriodFilter)
                  Row(
                    children: [
                      DropdownButton<String>(
                        value: periodFilter,
                        underline: const SizedBox(),
                        items: [
                          DropdownMenuItem(value: '7days', child: Text(l10n.last7Days)),
                          DropdownMenuItem(value: '30days', child: Text(l10n.period30Days)),
                          DropdownMenuItem(value: 'last_month', child: Text(lastMonthLabel(context))),
                          DropdownMenuItem(value: 'custom', child: Text(l10n.periodCustom)),
                        ],
                        onChanged: (val) async {
                          if (val == null) return;
                          if (val == 'custom') {
                            onCustomDateTap();
                          } else {
                            onPeriodChanged(val);
                          }
                        },
                      ),
                      if (periodFilter == 'custom' && customDateRange != null) ...[
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: onCustomDateTap,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit_calendar, size: 14, color: Theme.of(context).colorScheme.primary),
                                const SizedBox(width: 4),
                                Text(
                                  '${customDateRange!.start.day.toString().padLeft(2, '0')}/${customDateRange!.start.month.toString().padLeft(2, '0')} - ${customDateRange!.end.day.toString().padLeft(2, '0')}/${customDateRange!.end.month.toString().padLeft(2, '0')}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButton<String>(
                      value: typeFilter,
                      underline: const SizedBox(),
                      items: [
                        if (showAllOption) DropdownMenuItem(value: 'all', child: Text(l10n.typeLabel)),
                        DropdownMenuItem(value: 'expense', child: Text(l10n.expenses)),
                        DropdownMenuItem(value: 'income', child: Text(l10n.incomes)),
                        if (showScheduledOption) DropdownMenuItem(value: 'scheduled', child: Text(l10n.scheduledLabel)),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          onTypeChanged(val);
                        }
                      },
                    ),
                    if (categoryFilter != null) ...[
                      const SizedBox(width: 12),
                      categoryFilter!,
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
