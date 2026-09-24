import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:monitrack/l10n/app_localizations.dart';
import '../providers/expense_provider.dart';
import '../providers/account_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/contact_provider.dart';
import '../models/expense.dart';
import '../models/contact.dart';
import 'package:intl/intl.dart';
import 'add_debt_operation_screen.dart';
import 'debt_screen.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import '../services/database_service.dart';

class DebtDetailScreen extends StatelessWidget {
  final String debtTag;

  const DebtDetailScreen({super.key, required this.debtTag});

  String _getDisplayNameForTag(String tag, List<Contact> contacts) {
    final match = contacts.firstWhere(
      (c) => c.name.toLowerCase() == tag.toLowerCase(),
      orElse: () => Contact(id: -1, name: '', email: '', userCode: ''),
    );
    return match.id != -1 ? match.displayName : tag;
  }

  void _confirmDelete(BuildContext context, ExpenseProvider provider) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteDebtConfirm),
        content: Text(l10n.deleteDebtConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () async {
              // Handle account refunds for linked cashflow operations
              final accountProvider = Provider.of<AccountProvider>(context, listen: false);
              final transactions = provider.getTransactionsForDebt(debtTag);
              
              await DatabaseService.instance.runTransaction((txn) async {
                for (var tx in transactions) {
                  if (tx.isLinkedToCashFlow && tx.accountId != null) {
                    await accountProvider.updateBalance(
                      tx.accountId!,
                      tx.type == 'income' ? -tx.amount : tx.amount,
                      executor: txn,
                    );
                  }
                }
                
                await provider.deleteDebtTag(debtTag, executor: txn);
              });

              if (context.mounted) {
                Navigator.pop(ctx);
                Navigator.pop(context);
              }
            },
            child: Text(l10n.confirm, style: TextStyle(color: scheme.error)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final provider = Provider.of<ExpenseProvider>(context);
    final currency = Provider.of<ProfileProvider>(context).profile.currency;

    final contacts = Provider.of<ContactProvider>(context).contacts;
    final displayName = _getDisplayNameForTag(debtTag, contacts);

    final balance = provider.getDebtBalance(debtTag);
    final transactions = provider.getTransactionsForDebt(debtTag);
    // Sort transactions chronologically (oldest first or newest first, let's do newest first)
    transactions.sort((a, b) => b.date.compareTo(a.date));

    final isDebt = balance < 0;
    final isSettled = balance == 0;

    bool isCreator = true;
    if (transactions.isNotEmpty) {
       final originalTx = transactions.last; // Oldest transaction is likely the original debt
       if (originalTx.creatorId != null && originalTx.creatorId != provider.currentUserId) {
           isCreator = false;
       }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(displayName),
        actions: [
          if (isCreator)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _confirmDelete(context, provider),
            ),
        ],
      ),
      body: Column(
        children: [
          // Balance Header
          Container(
            padding: const EdgeInsets.all(24),
            width: double.infinity,
            color: isSettled
                ? scheme.surfaceContainerHighest
                : (isDebt
                    ? scheme.expense.withValues(alpha: 0.12)
                    : scheme.income.withValues(alpha: 0.12)),
            child: Column(
              children: [
                Text(
                  l10n.debtBalance,
                  style: TextStyle(
                    fontSize: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${balance.abs().formatAmountDouble()} $currency',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: isSettled ? scheme.onSurface : (isDebt ? scheme.expense : scheme.income),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isSettled
                      ? l10n.debtBadgeSettled
                      : (isDebt ? l10n.debtKind : l10n.receivableKind),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isSettled ? scheme.onSurfaceVariant : (isDebt ? scheme.expense : scheme.income),
                  ),
                ),
                if (!isSettled && transactions.any((t) => t.dueDate != null && !t.isPlanned)) ...[
                  const SizedBox(height: 10),
                  Builder(builder: (_) {
                    final txWithDueDate = transactions.firstWhere((t) => t.dueDate != null && !t.isPlanned);
                    final dueDate = txWithDueDate.dueDate!;
                    final isOverdue = dueDate.isBefore(DateTime.now());
                    final formattedDate = DateFormat('dd/MM/yyyy').format(dueDate);
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isOverdue ? scheme.errorContainer : scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isOverdue ? scheme.error : scheme.primary,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isOverdue ? Icons.warning_amber_rounded : Icons.event,
                            size: 16,
                            color: isOverdue ? scheme.onErrorContainer : scheme.onPrimaryContainer,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isOverdue
                                ? l10n.debtDueDateOverdue(formattedDate)
                                : l10n.debtDueDatePlanned(formattedDate),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isOverdue ? scheme.onErrorContainer : scheme.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
          
          // Transactions List
          Expanded(
            child: transactions.isEmpty 
              ? Center(child: Text(l10n.noTransaction, style: TextStyle(color: scheme.onSurfaceVariant)))
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final tx = transactions[index];
                    return _buildTransactionTile(context, tx, currency);
                  },
                ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddDebtOperationScreen(
                initialTag: debtTag,
                initialAmount: balance != 0 ? balance.abs() : null,
                initialIsIncome: balance != 0 ? balance > 0 : null,
              ),
            ),
          );
          if (result == true) {
            if (context.mounted) {
              Navigator.pop(context); // Return to DebtScreen
              DebtScreen.globalKey.currentState?.switchToHistoryTab();
            }
          }
        },
        child: Icon(Icons.add, color: Theme.of(context).colorScheme.primary, weight: 900, size: 28),
      ),
    );
  }

  Widget _buildTransactionTile(BuildContext context, Expense op, String currency) {
    final l10n = AppLocalizations.of(context)!;
    final isIncome = op.type == 'income';
    final isPlanned = op.isPlanned;
    
    final scheme = Theme.of(context).colorScheme;
    final amountColor = isPlanned
        ? scheme.onSurfaceVariant
        : (isIncome ? scheme.income : scheme.expense);
    // Badge « Mémo » : l'ambre clair d'origine n'a pas d'équivalent exact,
    // on le fige en clair et on bascule sur le conteneur d'avertissement en sombre.
    final memoBackground = scheme.tone(
      light: const Color(0xFFFFECB3), // Colors.amber.shade100
      dark: scheme.warningContainer,
    );
    final sign = isPlanned ? '' : (isIncome ? '+' : '-');
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: amountColor.withValues(alpha: 0.1),
          child: Icon(
            isPlanned 
                ? Icons.schedule 
                : (isIncome ? Icons.arrow_downward : Icons.arrow_upward),
            color: amountColor,
          ),
        ),
        title: Text(op.title, style: TextStyle(fontWeight: FontWeight.bold, color: isPlanned ? scheme.onSurfaceVariant : null)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(dateFormat.format(op.date), style: TextStyle(color: isPlanned ? scheme.onSurfaceVariant : null)),
            if (op.isPlanned)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.infoContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(l10n.expectedDueDate, style: TextStyle(fontSize: 10, color: scheme.onInfoContainer)),
              )
            else ...[
              if (op.dueDate != null)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: op.dueDate!.isBefore(DateTime.now())
                        ? scheme.errorContainer
                        : scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: op.dueDate!.isBefore(DateTime.now())
                          ? scheme.error
                          : scheme.primary,
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        op.dueDate!.isBefore(DateTime.now())
                            ? Icons.error_outline
                            : Icons.event,
                        size: 11,
                        color: op.dueDate!.isBefore(DateTime.now())
                            ? scheme.onErrorContainer
                            : scheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        l10n.debtDueDateValue(
                            DateFormat('dd/MM/yyyy').format(op.dueDate!)),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: op.dueDate!.isBefore(DateTime.now())
                              ? scheme.onErrorContainer
                              : scheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              if (!op.isLinkedToCashFlow)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: memoBackground,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(l10n.memo, style: TextStyle(fontSize: 10, color: scheme.onWarningContainer)),
                ),
            ],
            if (op.creatorName != null && op.creatorName!.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 4),
                child: Text(l10n.createdBy(op.creatorName!), style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: scheme.onSurfaceVariant)),
              ),
          ],
        ),
        trailing: Text(
          '$sign${op.amount.formatAmountDouble()} $currency',
          style: TextStyle(
            color: amountColor,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
