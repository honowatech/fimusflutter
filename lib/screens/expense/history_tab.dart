import 'package:flutter/material.dart';
import 'package:monitrack/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../models/expense.dart';
import '../../providers/account_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/profile_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/formatters.dart';
import '../../utils/translation_helper.dart';
import '../expense_detail_screen.dart';
import 'expense_action_sheets.dart';
import 'expense_category_filter.dart';
import 'expense_date_filters.dart';
import 'expense_filter_bar.dart';

/// Onglet « Historique » : liste filtrable des opérations et des dépenses
/// programmées.
class ExpenseHistoryTab extends StatelessWidget {
  const ExpenseHistoryTab({
    super.key,
    required this.periodFilter,
    required this.customDateRange,
    required this.typeFilter,
    required this.selectedCategories,
    required this.onPeriodChanged,
    required this.onCustomDateTap,
    required this.onTypeChanged,
    required this.onCategoriesChanged,
  });

  final String periodFilter;
  final DateTimeRange? customDateRange;
  final String typeFilter;

  /// `null` = toutes les catégories sélectionnées.
  final Set<String>? selectedCategories;
  final ValueChanged<String> onPeriodChanged;
  final VoidCallback onCustomDateTap;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<Set<String>?> onCategoriesChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Abonnement limité à cet onglet.
    final provider = context.watch<ExpenseProvider>();
    final currency = context.select<ProfileProvider, String>((p) => p.profile.currency);
    final range = expenseRangeFor(
      periodFilter: periodFilter,
      customDateRange: customDateRange,
    );

    final showScheduled = typeFilter == 'scheduled';

    List<Expense> filteredExpenses;
    if (showScheduled) {
      // Échéances futures : tri par échéance croissante (la plus proche en
      // premier), sans filtre de période.
      filteredExpenses = provider.scheduledExpenses;
    } else {
      String? filterType;
      if (typeFilter == 'expense') filterType = 'expense';
      if (typeFilter == 'income') filterType = 'income';
      filteredExpenses = provider.getFilteredExpenses(range.start, range.end, type: filterType);
    }

    final categoryFilter = selectedCategories;
    if (categoryFilter != null) {
      filteredExpenses = filteredExpenses
          .where((e) => categoryFilter.contains(e.category))
          .toList();
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: ExpenseFilterBar(
            periodFilter: periodFilter,
            customDateRange: customDateRange,
            typeFilter: typeFilter,
            onPeriodChanged: onPeriodChanged,
            onCustomDateTap: onCustomDateTap,
            onTypeChanged: onTypeChanged,
            showAllOption: true,
            showScheduledOption: true,
            showPeriodFilter: !showScheduled,
            categoryFilter: ExpenseCategoryFilterButton(
              categories: availableExpenseCategories(provider, typeFilter),
              selected: selectedCategories,
              onApply: onCategoriesChanged,
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => provider.syncAndReloadAll(
                accountProvider: context.read<AccountProvider>()),
            child: filteredExpenses.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.5,
                        child: Center(
                          child: Text(
                            showScheduled
                                ? l10n.scheduledExpensesEmpty
                                : l10n.noOperationPeriod,
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: filteredExpenses.length,
                    itemBuilder: (context, index) {
                      final transaction = filteredExpenses[index];
                      if (transaction.scheduleStatus == 'scheduled') {
                        return _ScheduledExpenseTile(
                          expense: transaction,
                          currency: currency,
                        );
                      }
                      final isIncome = transaction.type == 'income';

                      final authProvider = Provider.of<AuthProvider>(context, listen: false);
                      final currentUserId = authProvider.user?['id']?.toString() ?? authProvider.user?['uuid']?.toString();
                      String subtitleText = '${l10n.translateCategory(transaction.category)} • ${transaction.date.toLocal().day}/${transaction.date.toLocal().month}/${transaction.date.toLocal().year}';
                      if (transaction.creatorId != null && transaction.creatorId != currentUserId && transaction.creatorName != null && transaction.creatorName!.isNotEmpty) {
                        subtitleText = '${l10n.translateCategory(transaction.category)} • ${l10n.createdBy(transaction.creatorName!)} • ${transaction.date.toLocal().day}/${transaction.date.toLocal().month}/${transaction.date.toLocal().year}';
                      }

                      return ListTile(
                        leading: CircleAvatar(
                          // Même dérivation que dans expense_action_sheets :
                          // pas de jeton conteneur pour income/expense, on tire
                          // le fond de la teinte elle-même.
                          backgroundColor: (isIncome
                                  ? Theme.of(context).colorScheme.income
                                  : Theme.of(context).colorScheme.expense)
                              .withValues(alpha: 0.15),
                          foregroundColor: isIncome
                              ? Theme.of(context).colorScheme.income
                              : Theme.of(context).colorScheme.expense,
                          child: Icon(isIncome ? Icons.arrow_downward : Icons.arrow_upward),
                        ),
                        title: Text(transaction.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(subtitleText),
                        trailing: Text(
                          '${isIncome ? '+' : '-'}${transaction.amount.formatAmount()} $currency',
                          style: TextStyle(
                            color: isIncome
                                ? Theme.of(context).colorScheme.income
                                : Theme.of(context).colorScheme.expense,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ExpenseDetailScreen(expense: transaction),
                            ),
                          );
                        },
                        onLongPress: () => showExpenseActionBottomSheet(context, transaction),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

/// Ligne « dépense programmée » de l'onglet Historique.
class _ScheduledExpenseTile extends StatelessWidget {
  const _ScheduledExpenseTile({required this.expense, required this.currency});

  final Expense expense;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final reminderAt = (expense.reminderAt ?? expense.date).toLocal();
    final dateLabel = '${reminderAt.day.toString().padLeft(2, '0')}/${reminderAt.month.toString().padLeft(2, '0')}/${reminderAt.year}';
    final subtitle = '${l10n.translateCategory(expense.category)} • ${l10n.scheduledOn(dateLabel)}';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.warningContainer,
        foregroundColor: Theme.of(context).colorScheme.onWarningContainer,
        child: const Icon(Icons.schedule),
      ),
      title: Text(expense.title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle),
      trailing: Text(
        '-${expense.amount.formatAmount()} $currency',
        style: TextStyle(
          color: Theme.of(context).colorScheme.warning,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ExpenseDetailScreen(expense: expense),
          ),
        );
      },
      onLongPress: () => showScheduledExpenseActionBottomSheet(context, expense),
    );
  }
}
