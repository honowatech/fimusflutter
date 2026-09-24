import 'package:flutter/material.dart';
import 'package:monitrack/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../models/expense.dart';
import '../../providers/profile_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/formatters.dart';
import '../../utils/translation_helper.dart';
import '../add_expense_screen.dart';
import '../add_scheduled_expense_screen.dart';
import 'expense_delete_dialogs.dart';

/// Feuille d'actions (appui long) d'une dépense programmée : modifier /
/// annuler.
void showScheduledExpenseActionBottomSheet(BuildContext context, Expense expense) {
  final l10n = AppLocalizations.of(context)!;
  final theme = Theme.of(context);
  final currency = Provider.of<ProfileProvider>(context, listen: false).profile.currency;
  final reminderAt = (expense.reminderAt ?? expense.date).toLocal();

  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: theme.colorScheme.warningContainer,
                      foregroundColor: theme.colorScheme.onWarningContainer,
                      child: const Icon(Icons.schedule),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            expense.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${l10n.translateCategory(expense.category)} • ${l10n.scheduledOn('${reminderAt.day}/${reminderAt.month}/${reminderAt.year}')}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '-${expense.amount.formatAmount()} $currency',
                      style: TextStyle(
                        color: theme.colorScheme.warning,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Divider(),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.edit_outlined,
                    color: theme.colorScheme.primary,
                  ),
                ),
                title: Text(
                  l10n.modify,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  l10n.editScheduledExpense,
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddScheduledExpenseScreen(initialExpense: expense),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.delete_outline,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
                title: Text(
                  l10n.delete,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.error,
                  ),
                ),
                subtitle: Text(
                  l10n.cancelScheduledExpense,
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  confirmDeleteScheduledExpense(context, expense);
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Feuille d'actions (appui long) d'une opération : modifier / supprimer.
void showExpenseActionBottomSheet(BuildContext context, Expense transaction) {
  final l10n = AppLocalizations.of(context)!;
  final isIncome = transaction.type == 'income';
  final currency = Provider.of<ProfileProvider>(context, listen: false).profile.currency;
  final theme = Theme.of(context);

  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Transaction header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  children: [
                    CircleAvatar(
                      // Pas de jeton « conteneur » pour income/expense : on
                      // dérive le fond de la teinte elle-même, ce qui reste
                      // discret en clair comme en sombre.
                      backgroundColor: (isIncome
                              ? theme.colorScheme.income
                              : theme.colorScheme.expense)
                          .withValues(alpha: 0.15),
                      foregroundColor: isIncome
                          ? theme.colorScheme.income
                          : theme.colorScheme.expense,
                      child: Icon(isIncome ? Icons.arrow_downward : Icons.arrow_upward),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            transaction.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${l10n.translateCategory(transaction.category)} • ${transaction.date.toLocal().day}/${transaction.date.toLocal().month}/${transaction.date.toLocal().year}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${isIncome ? '+' : '-'}${transaction.amount.formatAmount()} $currency',
                      style: TextStyle(
                        color: isIncome
                            ? theme.colorScheme.income
                            : theme.colorScheme.expense,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Divider(),
              // Option Modifier
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.edit_outlined,
                    color: theme.colorScheme.primary,
                  ),
                ),
                title: Text(
                  l10n.modify,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  isIncome ? l10n.editIncome : l10n.editExpense,
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddExpenseScreen(
                        expenseToEdit: transaction,
                        isIncome: isIncome,
                      ),
                    ),
                  );
                },
              ),
              // Option Supprimer
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.delete_outline,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
                title: Text(
                  l10n.delete,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.error,
                  ),
                ),
                subtitle: Text(
                  l10n.deleteEntryConfirm,
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  confirmDeleteExpense(context, transaction);
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}
