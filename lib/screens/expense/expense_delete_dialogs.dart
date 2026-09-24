import 'package:flutter/material.dart';
import 'package:monitrack/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../models/expense.dart';
import '../../providers/account_provider.dart';
import '../../providers/expense_provider.dart';

/// Confirmation d'annulation d'une dépense programmée.
void confirmDeleteScheduledExpense(BuildContext context, Expense expense) {
  final l10n = AppLocalizations.of(context)!;
  final provider = Provider.of<ExpenseProvider>(context, listen: false);

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.cancelScheduledExpenseTitle),
      content: Text(l10n.cancelScheduledExpenseBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(ctx);
            await provider.deleteExpense(expense.id);
          },
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          child: Text(l10n.delete),
        ),
      ],
    ),
  );
}

/// Confirmation de suppression d'une opération : la suppression et le
/// réajustement du solde sont délégués à [ExpenseProvider], qui les exécute
/// dans une seule transaction.
void confirmDeleteExpense(BuildContext context, Expense transaction) {
  final l10n = AppLocalizations.of(context)!;
  final provider = Provider.of<ExpenseProvider>(context, listen: false);
  final accountProvider = Provider.of<AccountProvider>(context, listen: false);

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.deleteEntryConfirm),
      content: Text(l10n.deleteEntryWarning),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(ctx);
            await provider.deleteExpenseAndAdjustBalance(
              transaction,
              accountProvider: accountProvider,
            );
          },
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          child: Text(l10n.delete),
        ),
      ],
    ),
  );
}
