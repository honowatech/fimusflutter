import 'package:flutter/material.dart';
import 'package:monitrack/l10n/app_localizations.dart';

import '../../providers/expense_provider.dart';
import '../../utils/translation_helper.dart';

/// Catégories disponibles pour un filtre de type donné : dépenses →
/// catégories de dépenses, revenus → catégories de revenus, tous →
/// union des deux. Les dépenses programmées sont des dépenses.
List<String> availableExpenseCategories(
  ExpenseProvider expenseProvider,
  String typeFilter,
) {
  if (typeFilter == 'expense' || typeFilter == 'scheduled') {
    return expenseProvider.expenseCategories;
  }
  if (typeFilter == 'income') return expenseProvider.incomeCategories;
  return <String>{
    ...expenseProvider.expenseCategories,
    ...expenseProvider.incomeCategories,
  }.toList();
}

/// Bouton « catégories » affiché dans la barre de filtres.
class ExpenseCategoryFilterButton extends StatelessWidget {
  const ExpenseCategoryFilterButton({
    super.key,
    required this.categories,
    required this.selected,
    required this.onApply,
  });

  /// Catégories proposées dans la feuille de sélection.
  final List<String> categories;

  /// `null` = toutes les catégories sélectionnées.
  final Set<String>? selected;
  final ValueChanged<Set<String>?> onApply;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final label = selected == null || selected!.isEmpty
        ? l10n.allCategoriesSelected
        : selected!.length == 1
            ? l10n.translateCategory(selected!.first)
            : l10n.categoriesSelectedCount(selected!.length);

    return InkWell(
      onTap: () => showExpenseCategoryPicker(
        context: context,
        categories: categories,
        current: selected,
        onApply: onApply,
      ),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }
}

/// Feuille de sélection multiple des catégories.
void showExpenseCategoryPicker({
  required BuildContext context,
  required List<String> categories,
  required Set<String>? current,
  required ValueChanged<Set<String>?> onApply,
}) {
  final l10n = AppLocalizations.of(context)!;
  Set<String> selection = current ?? categories.toSet();

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (sheetContext, setModalState) {
          final allSelected = categories.every(selection.contains);
          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetContext).size.height * 0.7,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      l10n.filterByCategory,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        CheckboxListTile(
                          title: Text(
                            l10n.allCategoriesSelected,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          value: allSelected,
                          onChanged: (checked) {
                            setModalState(() {
                              selection = checked == true ? categories.toSet() : <String>{};
                            });
                          },
                        ),
                        ...categories.map((category) {
                          return CheckboxListTile(
                            title: Text(l10n.translateCategory(category)),
                            value: selection.contains(category),
                            onChanged: (checked) {
                              setModalState(() {
                                if (checked == true) {
                                  selection.add(category);
                                } else {
                                  selection.remove(category);
                                }
                              });
                            },
                          );
                        }),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          child: Text(l10n.cancel),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            if (!context.mounted) return;
                            // Sélection complète ou vide = toutes les catégories.
                            onApply(
                              selection.isEmpty || categories.every(selection.contains)
                                  ? null
                                  : Set<String>.from(selection),
                            );
                          },
                          child: Text(l10n.confirm),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

