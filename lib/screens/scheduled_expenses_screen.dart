import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:monitrack/l10n/app_localizations.dart';
import '../providers/expense_provider.dart';
import '../providers/account_provider.dart';
import '../providers/profile_provider.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/translation_helper.dart';
import '../models/expense.dart';
import 'add_scheduled_expense_screen.dart';

/// Liste des dépenses programmées en attente, avec actions
/// Confirmer / Modifier / Annuler.
class ScheduledExpensesScreen extends StatefulWidget {
  const ScheduledExpensesScreen({super.key});

  @override
  State<ScheduledExpensesScreen> createState() => _ScheduledExpensesScreenState();
}

class _ScheduledExpensesScreenState extends State<ScheduledExpensesScreen> {
  String? _processingId;

  Future<void> _confirm(Expense expense) async {
    if (_processingId != null) return;
    setState(() => _processingId = expense.id);
    final l10n = AppLocalizations.of(context)!;
    final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
    final accountProvider = Provider.of<AccountProvider>(context, listen: false);

    final ok = await expenseProvider.confirmScheduledExpense(expense.id);
    await accountProvider.loadData();

    if (!mounted) return;
    setState(() => _processingId = null);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? l10n.scheduledExpenseConfirmed : l10n.scheduledExpensesEmpty)),
    );
  }

  Future<void> _cancel(Expense expense) async {
    if (_processingId != null) return;
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.cancelScheduledExpenseTitle),
        content: Text(l10n.cancelScheduledExpenseBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete, style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _processingId = expense.id);
    final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
    final ok = await expenseProvider.cancelScheduledExpense(expense.id);
    if (!mounted) return;
    setState(() => _processingId = null);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? l10n.scheduledExpenseCancelled : l10n.scheduledExpensesEmpty)),
    );
  }

  void _edit(Expense expense) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddScheduledExpenseScreen(initialExpense: expense)),
    );
  }

  String _formatDate(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  String _countdownLabel(DateTime reminder, AppLocalizations l10n) {
    final now = DateTime.now();
    if (reminder.isBefore(now)) return '${l10n.scheduledOn('${_formatDate(reminder)} ${_formatTime(reminder)}')} · ${l10n.scheduledTodayAt(_formatTime(reminder))}';
    if (reminder.day == now.day && reminder.month == now.month && reminder.year == now.year) {
      return l10n.scheduledTodayAt(_formatTime(reminder));
    }
    final days = DateTime(reminder.year, reminder.month, reminder.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
    return l10n.scheduledInDays(days);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final expenseProvider = Provider.of<ExpenseProvider>(context);
    final currency = Provider.of<ProfileProvider>(context).profile.currency;
    final accountProvider = Provider.of<AccountProvider>(context);
    final scheduled = expenseProvider.scheduledExpenses;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.scheduledExpenses)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddScheduledExpenseScreen()),
        ),
        icon: const Icon(Icons.add),
        label: Text(l10n.addScheduledExpense),
      ),
      body: scheduled.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.event_available,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(l10n.scheduledExpensesEmpty, style: const TextStyle(fontSize: 16)),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: scheduled.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final expense = scheduled[index];
                final reminderAt = expense.reminderAt ?? expense.date;
                final account = expense.accountId != null
                    ? accountProvider.accounts.where((a) => a.id == expense.accountId).firstOrNull
                    : null;
                final isProcessing = _processingId == expense.id;

                return Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor:
                              Theme.of(context).colorScheme.warningContainer,
                          child: Icon(
                            Icons.schedule,
                            color: Theme.of(context).colorScheme.onWarningContainer,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                expense.title,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${expense.amount.formatAmount()} $currency',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                l10n.translateCategory(expense.category),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              Text(
                                '${_formatDate(reminderAt)} à ${_formatTime(reminderAt)} · ${_countdownLabel(reminderAt, l10n)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              if (account != null)
                                Text(
                                  account.name.isNotEmpty ? account.name : l10n.untitled,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (isProcessing)
                          const Padding(
                            padding: EdgeInsets.all(8),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        else ...[
                          IconButton(
                            tooltip: l10n.confirmNow,
                            icon: Icon(
                              Icons.check_circle_outline,
                              color: Theme.of(context).colorScheme.success,
                            ),
                            onPressed: () => _confirm(expense),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') {
                                _edit(expense);
                              } else if (value == 'cancel') {
                                _cancel(expense);
                              }
                            },
                            itemBuilder: (ctx) => [
                              PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    const Icon(Icons.edit_outlined, size: 20),
                                    const SizedBox(width: 8),
                                    Text(l10n.modify),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'cancel',
                                child: Row(
                                  children: [
                                    Icon(Icons.close, size: 20, color: Theme.of(ctx).colorScheme.error),
                                    const SizedBox(width: 8),
                                    Text(l10n.cancelScheduledExpense),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
