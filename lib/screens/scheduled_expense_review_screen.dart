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

/// Écran ouvert au tap sur la notification d'échéance d'une dépense programmée.
/// Permet de Confirmer (→ dépense réelle), Modifier (→ formulaire pré-rempli)
/// ou Annuler (→ suppression de la programmation).
class ScheduledExpenseReviewScreen extends StatefulWidget {
  final String expenseId;

  const ScheduledExpenseReviewScreen({super.key, required this.expenseId});

  @override
  State<ScheduledExpenseReviewScreen> createState() => _ScheduledExpenseReviewScreenState();
}

class _ScheduledExpenseReviewScreenState extends State<ScheduledExpenseReviewScreen> {
  bool _processing = false;

  Future<void> _confirm() async {
    if (_processing) return;
    setState(() => _processing = true);
    final l10n = AppLocalizations.of(context)!;
    final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
    final accountProvider = Provider.of<AccountProvider>(context, listen: false);

    final ok = await expenseProvider.confirmScheduledExpense(widget.expenseId);
    // Le solde a été modifié en base dans la transaction : on rafraîchit les comptes
    await accountProvider.loadData();

    if (!mounted) return;
    setState(() => _processing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? l10n.scheduledExpenseConfirmed : l10n.scheduledExpensesEmpty)),
    );
    if (ok) Navigator.pop(context);
  }

  Future<void> _cancel() async {
    if (_processing) return;
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

    setState(() => _processing = true);
    final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
    final ok = await expenseProvider.cancelScheduledExpense(widget.expenseId);
    if (!mounted) return;
    setState(() => _processing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? l10n.scheduledExpenseCancelled : l10n.scheduledExpensesEmpty)),
    );
    if (ok) Navigator.pop(context);
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
    if (reminder.isBefore(now)) return l10n.scheduledOn('${_formatDate(reminder)} ${_formatTime(reminder)}');
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

    Expense? expense;
    for (final e in expenseProvider.expenses) {
      if (e.id == widget.expenseId) {
        expense = e;
        break;
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.scheduledExpense)),
      body: expense == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.event_busy,
                    size: 56,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  Text(l10n.scheduledExpensesEmpty),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.cancel),
                  ),
                ],
              ),
            )
          : _buildContent(context, l10n, expense, currency),
    );
  }

  Widget _buildContent(BuildContext context, AppLocalizations l10n, Expense expense, String currency) {
    final accountProvider = Provider.of<AccountProvider>(context);
    final account = expense.accountId != null
        ? accountProvider.accounts.where((a) => a.id == expense.accountId).firstOrNull
        : null;
    final reminderAt = expense.reminderAt ?? expense.date;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          CircleAvatar(
            radius: 36,
            backgroundColor: Theme.of(context).colorScheme.warningContainer,
            child: Icon(
              Icons.schedule,
              size: 40,
              color: Theme.of(context).colorScheme.onWarningContainer,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            expense.title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '${expense.amount.formatAmount()} $currency',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          _buildDetailTile(
            icon: Icons.label_outline,
            label: l10n.category,
            value: l10n.translateCategory(expense.category),
          ),
          if (account != null)
            _buildDetailTile(
              icon: Icons.account_balance_wallet_outlined,
              label: l10n.linkedAccountOptional,
              value: account.name.isNotEmpty ? account.name : l10n.untitled,
            ),
          _buildDetailTile(
            icon: Icons.event,
            label: l10n.dateAndTime,
            value: '${_formatDate(reminderAt)} à ${_formatTime(reminderAt)}',
          ),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.warningContainer,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.warningOutline,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.timer_outlined,
                  color: Theme.of(context).colorScheme.onWarningContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _countdownLabel(reminderAt, l10n),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _processing ? null : _confirm,
            style: ElevatedButton.styleFrom(
              // Bouton de confirmation : `success` vire au vert clair en sombre
              // et ne supporterait pas un libellé blanc ; on garde donc un vert
              // profond via `tone` (valeur clair inchangée).
              backgroundColor: Theme.of(context).colorScheme.tone(
                    light: Colors.green.shade600,
                    dark: const Color(0xFF2E7D32),
                  ),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.check_circle_outline),
            label: Text(l10n.confirmExpense, style: const TextStyle(fontSize: 17)),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _processing ? null : () => _edit(expense),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.edit_outlined),
            label: Text(l10n.modify, style: const TextStyle(fontSize: 17)),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _processing ? null : _cancel,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            icon: const Icon(Icons.close),
            label: Text(l10n.cancelScheduledExpense, style: const TextStyle(fontSize: 17)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
