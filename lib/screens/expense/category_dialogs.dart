import 'package:flutter/material.dart';
import 'package:monitrack/l10n/app_localizations.dart';

import '../../providers/expense_provider.dart';

/// Dialogue de création d'une catégorie (dépense ou revenu).
void showAddCategoryDialog(
  BuildContext context,
  ExpenseProvider provider, {
  bool isIncome = false,
}) {
  final l10n = AppLocalizations.of(context)!;
  String name = '';
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(isIncome ? l10n.addIncomeCategory : l10n.addExpenseCategory),
      content: TextFormField(
        autofocus: true,
        onChanged: (val) => name = val,
        decoration: InputDecoration(labelText: l10n.categoryName),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
        TextButton(
          onPressed: () {
            if (name.trim().isNotEmpty) {
              provider.addCategory(name.trim(), isIncome: isIncome);
              Navigator.pop(ctx);
            }
          },
          child: Text(l10n.add),
        ),
      ],
    ),
  );
}

/// Dialogue de renommage d'une catégorie existante.
void showEditCategoryDialog(
  BuildContext context,
  ExpenseProvider provider,
  String oldCategory, {
  bool isIncome = false,
}) {
  final l10n = AppLocalizations.of(context)!;
  String name = oldCategory;
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.categoryName),
      content: TextFormField(
        initialValue: oldCategory,
        autofocus: true,
        onChanged: (val) => name = val,
        decoration: InputDecoration(labelText: l10n.categoryName),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
        TextButton(
          onPressed: () {
            if (name.trim().isNotEmpty && name.trim() != oldCategory) {
              provider.updateCategory(oldCategory, name.trim(), isIncome: isIncome);
              Navigator.pop(ctx);
            } else if (name.trim() == oldCategory) {
              Navigator.pop(ctx);
            }
          },
          child: Text(l10n.save),
        ),
      ],
    ),
  );
}
