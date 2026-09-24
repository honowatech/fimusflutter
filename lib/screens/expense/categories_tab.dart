import 'package:flutter/material.dart';
import 'package:monitrack/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../providers/expense_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/translation_helper.dart';
import 'category_dialogs.dart';

/// Onglet « Catégories » : liste des catégories de dépenses ou de revenus.
class ExpenseCategoriesTab extends StatelessWidget {
  const ExpenseCategoriesTab({
    super.key,
    required this.categoryTypeFilter,
    required this.onCategoryTypeChanged,
  });

  final String categoryTypeFilter;
  final ValueChanged<String> onCategoryTypeChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Abonnement limité à cet onglet.
    final expenseProvider = context.watch<ExpenseProvider>();
    final categories = categoryTypeFilter == 'income'
        ? expenseProvider.incomeCategories
        : expenseProvider.expenseCategories;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                categoryTypeFilter == 'income' ? l10n.incomeCategories : l10n.expenseCategories,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              DropdownButton<String>(
                value: categoryTypeFilter,
                underline: const SizedBox(),
                items: [
                  DropdownMenuItem(value: 'expense', child: Text(l10n.expenses)),
                  DropdownMenuItem(value: 'income', child: Text(l10n.incomes)),
                ],
                onChanged: (val) => onCategoryTypeChanged(val!),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              await context.read<ExpenseProvider>().loadData();
            },
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final cat = categories[index];
                return ListTile(
                  leading: const Icon(Icons.account_balance_wallet),
                  title: Text(l10n.translateCategory(cat)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(),
                        // Bleu d'action : voir accounts_tab.dart, `info` garde
                        // la teinte bleue et reste lisible en sombre.
                        icon: Icon(
                          Icons.edit,
                          color: Theme.of(context).colorScheme.info,
                        ),
                        onPressed: () {
                          if (cat == 'Autre') {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(l10n.cannotDeleteOther)),
                            );
                            return;
                          }
                          showEditCategoryDialog(
                            context,
                            expenseProvider,
                            cat,
                            isIncome: categoryTypeFilter == 'income',
                          );
                        },
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(),
                        icon: Icon(
                          Icons.delete,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        onPressed: () {
                          if (cat == 'Autre') {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(l10n.cannotDeleteOther)),
                            );
                            return;
                          }
                          expenseProvider.deleteCategory(cat, isIncome: categoryTypeFilter == 'income');
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
