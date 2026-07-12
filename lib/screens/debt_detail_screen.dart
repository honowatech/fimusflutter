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
            child: Text(l10n.confirm, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = Provider.of<ExpenseProvider>(context);
    final currency = Provider.of<ProfileProvider>(context).profile.currency;
    
    final contacts = Provider.of<ContactProvider>(context).contacts;
    final displayName = _getDisplayNameForTag(debtTag, contacts);

    final balance = provider.getDebtBalance(debtTag);
    final transactions = provider.getTransactionsForDebt(debtTag);
    // Sort transactions chronologically (oldest first or newest first, let's do newest first)
    transactions.sort((a, b) => b.date.compareTo(a.date));

    final isDebt = balance > 0;
    final isSettled = balance == 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(displayName),
        actions: [
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
            color: isSettled ? Colors.grey.shade200 : (isDebt ? Colors.red.shade50 : Colors.green.shade50),
            child: Column(
              children: [
                Text(
                  l10n.debtBalance,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${balance.abs().formatAmountDouble()} $currency',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: isSettled ? Colors.grey.shade800 : (isDebt ? Colors.red.shade700 : Colors.green.shade700),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isSettled ? 'Soldé' : (isDebt ? 'Dette' : 'Créance'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isSettled ? Colors.grey.shade600 : (isDebt ? Colors.red.shade600 : Colors.green.shade600),
                  ),
                ),
              ],
            ),
          ),
          
          // Transactions List
          Expanded(
            child: transactions.isEmpty 
              ? Center(child: Text('Aucune transaction', style: TextStyle(color: Colors.grey.shade600)))
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
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddDebtOperationScreen(initialTag: debtTag),
            ),
          );
        },
        child: Icon(Icons.add, color: Theme.of(context).colorScheme.primary, weight: 900, size: 28),
      ),
    );
  }

  Widget _buildTransactionTile(BuildContext context, Expense op, String currency) {
    final isIncome = op.type == 'income';
    final isPlanned = op.isPlanned;
    
    final amountColor = isPlanned ? Colors.grey : (isIncome ? Colors.green : Colors.red);
    final sign = isPlanned ? '' : (isIncome ? '+' : '-');
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: amountColor.withOpacity(0.1),
          child: Icon(
            isPlanned 
                ? Icons.schedule 
                : (isIncome ? Icons.arrow_downward : Icons.arrow_upward),
            color: amountColor,
          ),
        ),
        title: Text(op.title, style: TextStyle(fontWeight: FontWeight.bold, color: isPlanned ? Colors.grey.shade700 : null)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(dateFormat.format(op.date), style: TextStyle(color: isPlanned ? Colors.grey.shade600 : null)),
            if (isPlanned)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('Échéance prévue', style: TextStyle(fontSize: 10, color: Colors.blue.shade700)),
              )
            else if (!op.isLinkedToCashFlow)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('Mémo', style: TextStyle(fontSize: 10, color: Colors.amber.shade900)),
              ),
            if (op.originalType != null && op.creatorName != null)
              Container(
                margin: const EdgeInsets.only(top: 4),
                child: Text('Créé par ${op.creatorName}', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.blueGrey)),
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
