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
import '../services/exchange_rate_service.dart';

class DebtDetailScreen extends StatefulWidget {
  final String debtTag;

  const DebtDetailScreen({super.key, required this.debtTag});

  @override
  State<DebtDetailScreen> createState() => _DebtDetailScreenState();
}

class _DebtDetailScreenState extends State<DebtDetailScreen> {
  /// Taux de change actifs, chargés une seule fois pour l'écran : ni la liste
  /// des opérations ni l'en-tête ne relisent le cache ligne par ligne.
  Map<String, double> _rates = const {};

  @override
  void initState() {
    super.initState();
    _chargerTaux();
  }

  Future<void> _chargerTaux() async {
    final rates = await ExchangeRateService().getRates();
    if (!mounted) return;
    setState(() => _rates = rates);
  }

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
              // Suppression du tag **et** remboursement des comptes imputés :
              // le provider convertit chaque opération dans la devise de son
              // compte et refuse tout en bloc si un taux manque.
              final accountProvider = Provider.of<AccountProvider>(context, listen: false);
              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);
              Navigator.pop(ctx);

              final result = await provider.deleteDebtTagAndAdjustBalances(
                widget.debtTag,
                accountProvider: accountProvider,
              );

              if (!mounted) return;
              if (!result.isSuccess) {
                // Rien n'a été écrit : la dette est toujours là, on reste sur
                // l'écran et on le dit au lieu d'un faux succès silencieux.
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      result.isRateUnavailable
                          ? l10n.balanceRateUnavailable(
                              result.missingFrom ?? '?',
                              result.missingTo ?? '?',
                            )
                          : l10n.operationNotFound,
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
              navigator.pop();
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
    final displayName = _getDisplayNameForTag(widget.debtTag, contacts);

    final balance = provider.getDebtBalance(widget.debtTag);
    final transactions = provider.getTransactionsForDebt(widget.debtTag);
    // Sort transactions chronologically (oldest first or newest first, let's do newest first)
    transactions.sort((a, b) => b.date.compareTo(a.date));

    final isDebt = balance < 0;
    final isSettled = balance == 0;

    // Solde d'en-tête : gardé dans la devise des opérations quand elles
    // s'accordent (une dette contractée en XOF se lit en XOF), ramené à la
    // devise du profil dès qu'elles en mêlent plusieurs.
    final solde = SoldeDette.calculer(
      transactions,
      profileCurrency: currency,
      activeRates: _rates,
    );
    final equivalentSolde = MoneyFormatter.isForeign(solde.devise, currency)
        // `montantProfil` est déjà dans la devise du profil : la conversion
        // est une identité, il ne reste qu'à le libeller.
        ? '≈ ${MoneyFormatter.formatConverted(
            solde.montantProfil.abs(),
            rowCurrency: currency,
            profileCurrency: currency,
            activeRates: _rates,
          )}'
        : null;

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
                  MoneyFormatter.format(
                    solde.montant.abs(),
                    rowCurrency: solde.devise,
                    profileCurrency: currency,
                  ),
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: isSettled ? scheme.onSurface : (isDebt ? scheme.expense : scheme.income),
                  ),
                ),
                if (equivalentSolde != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    equivalentSolde,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
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
                initialTag: widget.debtTag,
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
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Opération isolée : dans sa devise de saisie, pas dans celle du
            // profil.
            Text(
              '$sign${MoneyFormatter.format(
                op.amount,
                rowCurrency: op.currency,
                profileCurrency: currency,
              )}',
              style: TextStyle(
                color: amountColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            if (MoneyFormatter.isForeign(op.currency, currency))
              Text(
                '≈ ${MoneyFormatter.formatConverted(
                  op.amount,
                  rowCurrency: op.currency,
                  profileCurrency: currency,
                  activeRates: _rates,
                )}',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
          ],
        ),
      ),
    );
  }
}
