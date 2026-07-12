import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:monitrack/l10n/app_localizations.dart';
import '../providers/expense_provider.dart';
import '../providers/account_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/contact_provider.dart';
import '../models/account.dart';
import '../utils/formatters.dart';
import '../services/sync_service.dart';
import '../services/database_service.dart';
import 'add_expense_screen.dart';
import 'package:uuid/uuid.dart';

class ExpenseScreen extends StatefulWidget {
  static final GlobalKey<ExpenseScreenState> globalKey = GlobalKey<ExpenseScreenState>();

  ExpenseScreen({Key? key}) : super(key: key ?? globalKey);

  @override
  State<ExpenseScreen> createState() => ExpenseScreenState();
}

class ExpenseScreenState extends State<ExpenseScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  void switchToTab(int index) {
    if (_tabController.length > index) {
      _tabController.animateTo(index);
    }
  }
  
  // History tab filters
  String _periodFilter = 'month';
  String _typeFilter = 'all';
  String _categoryTypeFilter = 'expense';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_handleTabSelection);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ContactProvider>().fetchContacts();
      }
    });
  }

  void _handleTabSelection() {
    setState(() {});
  }
  
  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    super.dispose();
  }

  void showAddTransactionDialog() {
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
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AddExpenseScreen(isIncome: false)));
                },
              ),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.arrow_downward, color: Colors.white)),
                title: Text(l10n.income),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AddExpenseScreen(isIncome: true)));
                },
              ),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.blue, child: Icon(Icons.account_balance_wallet, color: Colors.white)),
                title: Text(l10n.addAccount),
                onTap: () {
                  Navigator.pop(context);
                  final accountProvider = Provider.of<AccountProvider>(context, listen: false);
                  _showAddAccountDialog(context, accountProvider);
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
    
    // We need to sync our initial filters if they haven't been localized yet, but let's keep them logic-based for simplicity, or we map them dynamically.
    // For simplicity, we just display the keys.
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.expenses),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          isScrollable: true,
          tabs: [
            Tab(text: l10n.dashboard),
            Tab(text: l10n.history),
            Tab(text: l10n.accounts),
            Tab(text: l10n.category),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDashboardTab(),
          _buildHistoryTab(),
          _buildAccountsTab(),
          _buildCategoriesTab(),
        ],
      ),
    );
  }

  void handleFabPress() {
    if (_tabController.index == 3) {
      final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
      addCategoryDialog(context, expenseProvider, isIncome: _categoryTypeFilter == 'income');
    } else {
      showAddTransactionDialog();
    }
  }

  // --- DASHBOARD TAB ---
  Widget _buildDashboardTab() {
    final l10n = AppLocalizations.of(context)!;
    final expenseProvider = Provider.of<ExpenseProvider>(context);
    final accountProvider = Provider.of<AccountProvider>(context);
    final currency = Provider.of<ProfileProvider>(context).profile.currency;
    
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month, now.day, 23, 59, 59);
    
    final totalExpense = expenseProvider.getTotalExpenses(startOfMonth, endOfMonth);
    final totalIncome = expenseProvider.getTotalIncomes(startOfMonth, endOfMonth);
    final totalBalance = accountProvider.getTotalBalance();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.monthOverview, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.arrow_downward, color: Colors.white, size: 16),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l10n.incomes,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${totalIncome.formatAmount()} $currency',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.redAccent.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.arrow_upward, color: Colors.white, size: 16),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l10n.expenses,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${totalExpense.formatAmount()} $currency',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(l10n.yourAccounts, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l10n.totalBalance, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${totalBalance.formatAmount()} $currency',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
          Text(l10n.recentOperations, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (expenseProvider.expenses.isEmpty)
            Center(child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Text(l10n.noOperationPeriod, style: const TextStyle(color: Colors.grey)),
            ))
          else
            ...expenseProvider.expenses.take(5).map((transaction) {
              final isIncome = transaction.type == 'income';
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: isIncome ? Colors.green.shade100 : Colors.red.shade100,
                  foregroundColor: isIncome ? Colors.green : Colors.red,
                  child: Icon(isIncome ? Icons.arrow_downward : Icons.arrow_upward),
                ),
                title: Text(transaction.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${transaction.category} • ${transaction.date.toLocal().day}/${transaction.date.toLocal().month}/${transaction.date.toLocal().year}'),
                trailing: Text(
                  '${isIncome ? '+' : '-'}${transaction.amount.formatAmount()} $currency',
                  style: TextStyle(
                    color: isIncome ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  // --- HISTORY TAB ---
  DateTimeRange _getRange() {
    final now = DateTime.now();
    switch (_periodFilter) {
      case 'today':
        return DateTimeRange(
          start: DateTime(now.year, now.month, now.day),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59, 999),
        );
      case 'week':
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        return DateTimeRange(
          start: DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day),
          end: DateTime(endOfWeek.year, endOfWeek.month, endOfWeek.day, 23, 59, 59, 999),
        );
      case 'month':
        final lastDay = DateTime(now.year, now.month + 1, 0);
        return DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month, lastDay.day, 23, 59, 59, 999),
        );
      case 'all':
      default:
        return DateTimeRange(
          start: DateTime(2000),
          end: DateTime(2100),
        );
    }
  }

  Widget _buildHistoryTab() {
    final l10n = AppLocalizations.of(context)!;
    final provider = Provider.of<ExpenseProvider>(context);
    final accountProvider = Provider.of<AccountProvider>(context, listen: false);
    final currency = Provider.of<ProfileProvider>(context).profile.currency;
    final range = _getRange();
    
    String? filterType;
    if (_typeFilter == 'expense') filterType = 'expense';
    if (_typeFilter == 'income') filterType = 'income';

    final filteredExpenses = provider.getFilteredExpenses(range.start, range.end, type: filterType);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              DropdownButton<String>(
                value: _periodFilter,
                underline: const SizedBox(),
                items: [
                  DropdownMenuItem(value: 'all', child: Text(l10n.all)),
                  DropdownMenuItem(value: 'today', child: Text(l10n.today)),
                  DropdownMenuItem(value: 'week', child: Text(l10n.thisWeek)),
                  DropdownMenuItem(value: 'month', child: Text(l10n.thisMonth)),
                ],
                onChanged: (val) {
                  setState(() => _periodFilter = val!);
                },
              ),
              DropdownButton<String>(
                value: _typeFilter,
                underline: const SizedBox(),
                items: [
                  DropdownMenuItem(value: 'all', child: Text(l10n.all)),
                  DropdownMenuItem(value: 'expense', child: Text(l10n.expenses)),
                  DropdownMenuItem(value: 'income', child: Text(l10n.incomes)),
                ],
                onChanged: (val) => setState(() => _typeFilter = val!),
              ),
            ],
          ),
        ),
        Expanded(
          child: filteredExpenses.isEmpty
              ? Center(child: Text(l10n.noOperationPeriod))
              : ListView.builder(
                  itemCount: filteredExpenses.length,
                  itemBuilder: (context, index) {
                    final transaction = filteredExpenses[index];
                    final isIncome = transaction.type == 'income';
                    
                    return Dismissible(
                      key: Key(transaction.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (_) {
                        DatabaseService.instance.runTransaction((txn) async {
                          if (transaction.accountId != null) {
                            await accountProvider.updateBalance(
                              transaction.accountId!,
                              isIncome ? -transaction.amount : transaction.amount,
                              executor: txn,
                            );
                          }
                          await provider.deleteExpense(transaction.id, executor: txn);
                        });
                      },
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isIncome ? Colors.green.shade100 : Colors.red.shade100,
                          foregroundColor: isIncome ? Colors.green : Colors.red,
                          child: Icon(isIncome ? Icons.arrow_downward : Icons.arrow_upward),
                        ),
                        title: Text(transaction.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${transaction.category} • ${transaction.date.toLocal().day}/${transaction.date.toLocal().month}/${transaction.date.toLocal().year}'),
                        trailing: Text(
                          '${isIncome ? '+' : '-'}${transaction.amount.formatAmount()} $currency',
                          style: TextStyle(
                            color: isIncome ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // --- ACCOUNTS TAB ---
  void _showAddAccountDialog(BuildContext context, AccountProvider provider, {Account? existingAccount}) {
    final l10n = AppLocalizations.of(context)!;
    final currency = Provider.of<ProfileProvider>(context, listen: false).profile.currency;
    final contacts = Provider.of<ContactProvider>(context, listen: false).contacts;
    String name = existingAccount?.name ?? '';
    double balance = existingAccount?.balance ?? 0.0;
    int? selectedContactId;
    bool isSharing = false;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(existingAccount == null ? l10n.addAccount : l10n.editAccount),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: name,
                  decoration: InputDecoration(labelText: l10n.accountName),
                  onChanged: (val) => name = val,
                  enabled: !isSharing,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: existingAccount != null ? (balance == 0.0 ? '' : balance.formatAmount()) : '',
                  decoration: InputDecoration(
                    labelText: l10n.initialBalance,
                    prefixText: '$currency ',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [AmountInputFormatter()],
                  onChanged: (val) => balance = double.tryParse(val.replaceAll(RegExp(r'\s+'), '').replaceAll(',', '.')) ?? 0.0,
                  enabled: !isSharing,
                ),
                if (existingAccount == null && contacts.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    value: selectedContactId,
                    decoration: const InputDecoration(labelText: 'Partager avec (Optionnel)'),
                    items: [
                      const DropdownMenuItem<int>(
                        value: null,
                        child: Text('Ne pas partager'),
                      ),
                      ...contacts.map((c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(c.displayName),
                      )),
                    ],
                    onChanged: isSharing ? null : (val) => setState(() => selectedContactId = val),
                  ),
                ],
                if (isSharing) ...[
                  const SizedBox(height: 16),
                  const Center(child: CircularProgressIndicator()),
                  const SizedBox(height: 8),
                  const Center(child: Text('Création et partage en cours...')),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSharing ? null : () => Navigator.pop(ctx),
                child: Text(l10n.cancel),
              ),
              TextButton(
                onPressed: isSharing ? null : () async {
                  if (name.trim().isNotEmpty) {
                    if (existingAccount == null) {
                      final newAccount = Account(
                        id: const Uuid().v4(),
                        name: name.trim(),
                        balance: balance,
                      );
                      
                      if (selectedContactId != null) {
                        setState(() => isSharing = true);
                        try {
                          await provider.addAccount(newAccount);
                          // Wait for push to complete so backend has the account
                          await SyncService().push();
                          await provider.shareAccount(newAccount.id, selectedContactId!);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('Compte créé et partagé avec succès !')),
                            );
                            Navigator.pop(ctx);
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
                            );
                            setState(() => isSharing = false);
                          }
                        }
                      } else {
                        provider.addAccount(newAccount);
                        Navigator.pop(ctx);
                      }
                    } else {
                      provider.updateAccount(existingAccount.copyWith(name: name.trim(), balance: balance));
                      Navigator.pop(ctx);
                    }
                  }
                },
                child: Text(l10n.save),
              ),
            ],
          );
        }
      ),
    );
  }

  void _showShareAccountDialog(Account account, bool isOwner) {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(isOwner ? 'Partager "${account.name}"' : 'Membres de "${account.name}"'),
              content: SizedBox(
                width: double.maxFinite,
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: Provider.of<AccountProvider>(context, listen: false).getAccountMembers(account.id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final members = snapshot.data ?? [];
                    final contacts = Provider.of<ContactProvider>(context, listen: false).contacts;
                    
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
                            itemBuilder: (context, index) {
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
                              itemBuilder: (context, index) {
                                final contact = contacts[index];
                                final isAlreadyMember = members.any((m) => m['id'] == contact.id);
                                if (isAlreadyMember) return const SizedBox();
                                
                                return ListTile(
                                  leading: const CircleAvatar(child: Icon(Icons.person)),
                                  title: Text(contact.displayName),
                                  subtitle: Text(contact.email),
                                  trailing: ElevatedButton(
                                    onPressed: () async {
                                      try {
                                        await Provider.of<AccountProvider>(context, listen: false)
                                            .shareAccount(account.id, contact.id);
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Compte partagé avec ${contact.displayName} !')),
                                          );
                                          setState(() {}); // Refresh members list
                                        }
                                      } catch (e) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
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

  Widget _buildAccountsTab() {
    final l10n = AppLocalizations.of(context)!;
    final accountProvider = Provider.of<AccountProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final currency = Provider.of<ProfileProvider>(context).profile.currency;
    final accounts = accountProvider.accounts;
    final currentUserId = authProvider.user?['id'];

    if (accounts.isEmpty) {
      return Center(child: Text(l10n.noAccountSaved));
    }

    return ListView.builder(
      itemCount: accounts.length,
      itemBuilder: (context, index) {
        final account = accounts[index];
        final isOwner = account.ownerId == null || account.ownerId == currentUserId;

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: (account.color != null && account.color!.isNotEmpty) 
                ? Color(int.parse(account.color!.startsWith('#') ? account.color!.replaceFirst('#', '0xff') : '0xff${account.color}'))
                : Theme.of(context).colorScheme.primaryContainer,
            child: Text(account.name[0]),
          ),
          title: Row(
            children: [
              Text(account.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              if (account.isShared) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isOwner ? 'En commun' : 'Partagé par ${account.ownerName ?? 'Contact'}',
                    style: TextStyle(fontSize: 10, color: Colors.green.shade900, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
          subtitle: Text('${account.balance.formatAmount()} $currency'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isOwner) ...[
                IconButton(
                  icon: const Icon(Icons.share, color: Colors.green),
                  onPressed: () => _showShareAccountDialog(account, true),
                  tooltip: 'Partager le compte',
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _showAddAccountDialog(context, accountProvider, existingAccount: account),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
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
                            },
                            child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ] else ...[
                IconButton(
                  icon: const Icon(Icons.group, color: Colors.green),
                  onPressed: () => _showShareAccountDialog(account, false),
                  tooltip: 'Voir les membres',
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void addCategoryDialog(BuildContext context, ExpenseProvider provider, {bool isIncome = false}) {
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

  void _editCategoryDialog(BuildContext context, ExpenseProvider provider, String oldCategory, {bool isIncome = false}) {
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

  Widget _buildCategoriesTab() {
    final l10n = AppLocalizations.of(context)!;
    final expenseProvider = Provider.of<ExpenseProvider>(context);
    final categories = _categoryTypeFilter == 'income'
        ? expenseProvider.incomeCategories
        : expenseProvider.expenseCategories;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _categoryTypeFilter == 'income' ? l10n.incomeCategories : l10n.expenseCategories,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              DropdownButton<String>(
                value: _categoryTypeFilter,
                underline: const SizedBox(),
                items: [
                  DropdownMenuItem(value: 'expense', child: Text(l10n.expenses)),
                  DropdownMenuItem(value: 'income', child: Text(l10n.incomes)),
                ],
                onChanged: (val) => setState(() => _categoryTypeFilter = val!),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              return ListTile(
                leading: const Icon(Icons.account_balance_wallet),
                title: Text(cat),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () {
                        if (cat == 'Autre') {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.cannotDeleteOther)),
                          );
                          return;
                        }
                        _editCategoryDialog(context, expenseProvider, cat, isIncome: _categoryTypeFilter == 'income');
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        if (cat == 'Autre') {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.cannotDeleteOther)),
                          );
                          return;
                        }
                        expenseProvider.deleteCategory(cat, isIncome: _categoryTypeFilter == 'income');
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
