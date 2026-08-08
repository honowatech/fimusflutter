import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:monitrack/l10n/app_localizations.dart';
import '../providers/expense_provider.dart';
import '../providers/account_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/contact_provider.dart';
import '../models/account.dart';
import 'package:intl/intl.dart';
import '../utils/formatters.dart';
import '../widgets/add_account_bottom_sheet.dart';
import 'add_expense_screen.dart';
import '../services/database_service.dart';

class AccountDetailScreen extends StatefulWidget {
  final String accountId;

  const AccountDetailScreen({super.key, required this.accountId});

  @override
  State<AccountDetailScreen> createState() => _AccountDetailScreenState();
}

class _AccountDetailScreenState extends State<AccountDetailScreen> {
  Color _parseAccountColor(String? colorStr, BuildContext context) {
    if (colorStr == null || colorStr.trim().isEmpty) {
      return Theme.of(context).colorScheme.primaryContainer;
    }
    try {
      String hex = colorStr.trim().replaceAll('#', '');
      if (hex.startsWith('0x') || hex.startsWith('0X')) {
        hex = hex.substring(2);
      }
      if (hex.length == 6) {
        hex = 'FF$hex';
      }
      if (hex.length == 8) {
        return Color(int.parse(hex, radix: 16));
      }
    } catch (_) {}
    return Theme.of(context).colorScheme.primaryContainer;
  }

  void _showShareAccountDialog(Account account, bool isOwner) {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            return AlertDialog(
              title: Text(isOwner ? 'Partager "${account.name}"' : 'Membres de "${account.name}"'),
              content: SizedBox(
                width: double.maxFinite,
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: Provider.of<AccountProvider>(dialogContext, listen: false).getAccountMembers(account.id),
                  builder: (futureContext, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final members = snapshot.data ?? [];
                    final contacts = Provider.of<ContactProvider>(futureContext, listen: false).contacts;
                    
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (members.isNotEmpty) ...[
                          const Text('Membres actuels:', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: members.length,
                            itemBuilder: (listContext, index) {
                              final member = members[index];
                              return ListTile(
                                leading: const CircleAvatar(child: Icon(Icons.person)),
                                title: Text(member['name'] ?? 'Inconnu'),
                                subtitle: Text(member['email'] ?? ''),
                              );
                            },
                          ),
                          const Divider(),
                        ],
                        if (isOwner) ...[
                          const SizedBox(height: 8),
                          const Text('Partager avec un contact:', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          if (contacts.isEmpty)
                            const Text('Vous n\'avez aucun contact. Ajoutez des contacts dans votre profil pour partager un compte.')
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: contacts.length,
                              itemBuilder: (contactListContext, index) {
                                final contact = contacts[index];
                                final isAlreadyMember = members.any((m) => m['id'] == contact.id);
                                if (isAlreadyMember) return const SizedBox();
                                
                                return ListTile(
                                  leading: const CircleAvatar(child: Icon(Icons.person)),
                                  title: Text(contact.displayName),
                                  subtitle: Text(contact.email),
                                  trailing: ElevatedButton(
                                    onPressed: () async {
                                      // Show loader
                                      showDialog(
                                        context: dialogContext,
                                        barrierDismissible: false,
                                        builder: (loaderCtx) => Dialog(
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                          child: const Padding(
                                            padding: EdgeInsets.all(20.0),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                CircularProgressIndicator(color: Colors.teal),
                                                SizedBox(width: 20),
                                                Expanded(
                                                  child: Text(
                                                    "Partage en cours...",
                                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );

                                      try {
                                        await Provider.of<AccountProvider>(dialogContext, listen: false)
                                            .shareAccount(account.id, contact.id);
                                        if (dialogContext.mounted) {
                                          Navigator.pop(dialogContext); // Hide loader
                                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                                            SnackBar(
                                              content: Text('Compte partagé avec ${contact.displayName} !'),
                                              backgroundColor: Colors.green.shade600,
                                              behavior: SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                              margin: const EdgeInsets.all(16),
                                            ),
                                          );
                                          setState(() {}); // Refresh members list
                                        }
                                      } catch (e) {
                                        if (dialogContext.mounted) {
                                          Navigator.pop(dialogContext); // Hide loader
                                          
                                          String errorMessage = "Une erreur s'est produite. Veuillez réessayer.";
                                          String errorString = e.toString().toLowerCase();
                                          bool isNetworkError = errorString.contains('dioexception') || 
                                                                errorString.contains('socketexception') || 
                                                                errorString.contains('network') || 
                                                                errorString.contains('connexion');
                                          
                                          if (isNetworkError) {
                                            errorMessage = "Partage impossible. Vérifiez votre connexion internet.";
                                          } else {
                                            errorMessage = e.toString().replaceAll('Exception: ', '').replaceAll('Erreur : ', '');
                                          }

                                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                                            SnackBar(
                                              content: Row(
                                                children: [
                                                  Icon(
                                                    isNetworkError ? Icons.cloud_off : Icons.warning_amber_rounded,
                                                    color: Colors.white,
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(child: Text(errorMessage)),
                                                ],
                                              ),
                                              backgroundColor: isNetworkError ? Colors.blueGrey.shade700 : Colors.orange.shade800,
                                              behavior: SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                              margin: const EdgeInsets.all(16),
                                              duration: const Duration(seconds: 4),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    child: const Text('Partager'),
                                  ),
                                );
                              },
                            ),
                        ]
                      ],
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Fermer'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  void _showAddTransactionDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(l10n.newOperation, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.redAccent, child: Icon(Icons.arrow_upward, color: Colors.white)),
                title: Text(l10n.expense),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddExpenseScreen(
                        isIncome: false,
                        initialAccountId: widget.accountId,
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.arrow_downward, color: Colors.white)),
                title: Text(l10n.income),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddExpenseScreen(
                        isIncome: true,
                        initialAccountId: widget.accountId,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final accountProvider = Provider.of<AccountProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final expenseProvider = Provider.of<ExpenseProvider>(context);
    final currency = Provider.of<ProfileProvider>(context).profile.currency;

    final currentUserId = authProvider.user?['id'];
    final account = accountProvider.accounts.firstWhere(
      (a) => a.id == widget.accountId,
      orElse: () => Account(id: '', name: 'Compte inconnu', balance: 0.0),
    );

    if (account.id.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.accounts)),
        body: const Center(child: Text('Compte introuvable')),
      );
    }

    final isOwner = account.ownerId == null ||
        currentUserId == null ||
        account.ownerId.toString() == currentUserId.toString();

    final accountColor = _parseAccountColor(account.color, context);

    final transactions = expenseProvider.expenses.where((e) => e.accountId == widget.accountId).toList();
    transactions.sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      appBar: AppBar(
        title: Text(account.name.isNotEmpty ? account.name : 'Sans nom'),
        backgroundColor: accountColor,
        foregroundColor: Colors.white,
        actions: [
          if (isOwner) ...[
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: () => _showShareAccountDialog(account, true),
              tooltip: 'Partager le compte',
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => AddAccountBottomSheet.show(context, existingAccount: account),
              tooltip: 'Modifier le compte',
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(l10n.deleteAccountConfirm),
                    content: Text(l10n.irreversibleAction),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
                      TextButton(
                        onPressed: () {
                          accountProvider.deleteAccount(account.id);
                          Navigator.pop(ctx);
                          Navigator.pop(context);
                        },
                        child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
              tooltip: 'Supprimer le compte',
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.group),
              onPressed: () => _showShareAccountDialog(account, false),
              tooltip: 'Voir les membres',
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // Solde du compte Header
          Container(
            padding: const EdgeInsets.all(24),
            width: double.infinity,
            color: accountColor.withOpacity(0.15),
            child: Column(
              children: [
                Text(
                  'Solde du compte',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${account.balance.formatAmountDouble()} $currency',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: accountColor.computeLuminance() > 0.5 ? Colors.black87 : accountColor,
                  ),
                ),
                if (account.isShared) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isOwner ? 'En commun' : 'Partagé par ${account.ownerName ?? 'Contact'}',
                      style: TextStyle(fontSize: 12, color: Colors.green.shade900, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // Transactions List
          Expanded(
            child: transactions.isEmpty
                ? Center(
                    child: Text(
                      'Aucune opération sur ce compte',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    itemCount: transactions.length,
                    itemBuilder: (context, index) {
                      final transaction = transactions[index];
                      final isIncome = transaction.type == 'income';
                      final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
                      
                      String subtitleText = '${transaction.category} • ${dateFormat.format(transaction.date.toLocal())}';
                      if (transaction.creatorId != null && 
                          transaction.creatorId != currentUserId && 
                          transaction.creatorName != null && 
                          transaction.creatorName!.isNotEmpty) {
                        subtitleText = '${transaction.category} • Par ${transaction.creatorName} • ${dateFormat.format(transaction.date.toLocal())}';
                      }

                      return Card(
                        elevation: 1,
                        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isIncome ? Colors.green.shade100 : Colors.red.shade100,
                            foregroundColor: isIncome ? Colors.green : Colors.red,
                            child: Icon(isIncome ? Icons.arrow_downward : Icons.arrow_upward),
                          ),
                          title: Text(transaction.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(subtitleText),
                          trailing: Text(
                            '${isIncome ? '+' : '-'}${transaction.amount.formatAmountDouble()} $currency',
                            style: TextStyle(
                              color: isIncome ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          onLongPress: () {
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
                                      await DatabaseService.instance.runTransaction((txn) async {
                                        if (transaction.accountId != null) {
                                          await accountProvider.updateBalance(
                                            transaction.accountId!,
                                            isIncome ? -transaction.amount : transaction.amount,
                                            executor: txn,
                                          );
                                        }
                                        await expenseProvider.deleteExpense(transaction.id, executor: txn);
                                      });
                                    },
                                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                                    child: Text(l10n.delete),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTransactionDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}
