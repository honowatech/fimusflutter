import 'package:flutter/material.dart';
import 'package:monitrack/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../providers/account_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/profile_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/formatters.dart';
import '../scheduled_expenses_screen.dart';
import 'expense_chart_section.dart';
import 'expense_category_filter.dart';
import 'expense_date_filters.dart';
import 'expense_filter_bar.dart';

/// Onglet « Tableau de bord » : totaux de la période, rappel des dépenses
/// programmées et graphique.
class ExpenseDashboardTab extends StatelessWidget {
  const ExpenseDashboardTab({
    super.key,
    required this.periodFilter,
    required this.customDateRange,
    required this.typeFilter,
    required this.selectedCategories,
    required this.isBarChart,
    required this.onPeriodChanged,
    required this.onCustomDateTap,
    required this.onTypeChanged,
    required this.onCategoriesChanged,
    required this.onChartTypeChanged,
  });

  final String periodFilter;
  final DateTimeRange? customDateRange;
  final String typeFilter;

  /// `null` = toutes les catégories sélectionnées.
  final Set<String>? selectedCategories;
  final bool isBarChart;
  final ValueChanged<String> onPeriodChanged;
  final VoidCallback onCustomDateTap;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<Set<String>?> onCategoriesChanged;
  final ValueChanged<bool> onChartTypeChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    // Cartes « revenus » / « dépenses » : fonds pleins conservés à l'identique
    // en clair. En sombre on descend sur des teintes profondes : les jetons
    // `income`/`expense` y sont des teintes claires, sous lesquelles le contenu
    // blanc de ces cartes deviendrait illisible.
    final incomeCardColor =
        colorScheme.tone(light: Colors.green, dark: const Color(0xFF1B5E20));
    final expenseCardColor =
        colorScheme.tone(light: Colors.redAccent, dark: const Color(0xFFB71C1C));
    // Abonnement limité à cet onglet : une notification d'ExpenseProvider ne
    // reconstruit plus les 4 onglets.
    final expenseProvider = context.watch<ExpenseProvider>();
    final currency = context.select<ProfileProvider, String>((p) => p.profile.currency);

    final range = expenseRangeFor(
      periodFilter: periodFilter,
      customDateRange: customDateRange,
    );

    final allDashboardExpenses = expenseProvider.getFilteredExpenses(range.start, range.end);
    final categoryFilter = selectedCategories;
    final dashboardExpenses = categoryFilter == null
        ? allDashboardExpenses
        : allDashboardExpenses.where((e) => categoryFilter.contains(e.category)).toList();

    final totalExpense = dashboardExpenses
        .where((e) => e.type == 'expense')
        .fold(0.0, (sum, item) => sum + item.amount);
    final totalIncome = dashboardExpenses
        .where((e) => e.type == 'income')
        .fold(0.0, (sum, item) => sum + item.amount);

    final showIncome = typeFilter == 'all' || typeFilter == 'income';
    final showExpense = typeFilter == 'all' || typeFilter == 'expense';

    // Contenu des deux cartes : `Colors.white` est conservé volontairement,
    // les fonds ci-dessus restant saturés/profonds dans les deux thèmes.
    final incomeCard = Container(
      decoration: BoxDecoration(
        color: incomeCardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: incomeCardColor.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.arrow_downward, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.incomes,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '${totalIncome.formatAmount()} $currency',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ],
      ),
    );

    final expenseCard = Container(
      decoration: BoxDecoration(
        color: expenseCardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: expenseCardColor.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.arrow_upward, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.expenses,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '${totalExpense.formatAmount()} $currency',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ],
      ),
    );

    return RefreshIndicator(
      onRefresh: () => expenseProvider.syncAndReloadAll(
          accountProvider: context.read<AccountProvider>()),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ExpenseFilterBar(
              periodFilter: periodFilter,
              customDateRange: customDateRange,
              typeFilter: typeFilter,
              onPeriodChanged: onPeriodChanged,
              onCustomDateTap: onCustomDateTap,
              onTypeChanged: onTypeChanged,
              categoryFilter: ExpenseCategoryFilterButton(
                categories: availableExpenseCategories(expenseProvider, typeFilter),
                selected: selectedCategories,
                onApply: onCategoriesChanged,
              ),
            ),
            const SizedBox(height: 12),
            if (expenseProvider.upcomingScheduledExpensesCount > 0) ...[
              Material(
                color: colorScheme.warningContainer,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ScheduledExpensesScreen()),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          color: colorScheme.onWarningContainer,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            l10n.upcomingScheduledExpenses(expenseProvider.upcomingScheduledExpensesCount),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                if (showIncome) Expanded(child: incomeCard),
                if (showIncome && showExpense) const SizedBox(width: 12),
                if (showExpense) Expanded(child: expenseCard),
              ],
            ),
            const SizedBox(height: 24),
            // Chart section with toggle
            ExpenseChartSection(
              range: range,
              expenses: dashboardExpenses,
              currency: currency,
              showIncome: showIncome,
              showExpense: showExpense,
              isBarChart: isBarChart,
              onChartTypeChanged: onChartTypeChanged,
            ),
          ],
        ),
      ),
    );
  }
}
