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
import '../utils/translation_helper.dart';
import '../services/sync_service.dart';
import '../services/database_service.dart';
import '../widgets/add_account_bottom_sheet.dart';
import 'add_expense_screen.dart';
import 'account_detail_screen.dart';
import 'main_screen.dart';

class ExpenseScreen extends StatefulWidget {
  static final GlobalKey<ExpenseScreenState> globalKey = GlobalKey<ExpenseScreenState>();
  static int initialTabIndex = 0;

  static void navigateToTab(int index) {
    final state = globalKey.currentState;
    if (state != null && state.mounted) {
      state.switchToTab(index);
    } else {
      initialTabIndex = index;
    }
  }

  ExpenseScreen({Key? key}) : super(key: key ?? globalKey);

  @override
  State<ExpenseScreen> createState() => ExpenseScreenState();
}

class ExpenseScreenState extends State<ExpenseScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  void switchToTab(int index) {
    if (mounted && _tabController.length > index) {
      _tabController.animateTo(index);
    }
  }

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

  
  // History tab filters
  String _periodFilter = '7days';
  DateTimeRange? _customDateRange;
  String _typeFilter = 'all';
  String _categoryTypeFilter = 'expense';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4, 
      vsync: this,
      initialIndex: ExpenseScreen.initialTabIndex,
    );
    ExpenseScreen.initialTabIndex = 0;
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
      builder: (dialogContext) {
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
                  Navigator.pop(dialogContext);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AddExpenseScreen(isIncome: false)));
                },
              ),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.arrow_downward, color: Colors.white)),
                title: Text(l10n.income),
                onTap: () {
                  Navigator.pop(dialogContext);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AddExpenseScreen(isIncome: true)));
                },
              ),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.blue, child: Icon(Icons.account_balance_wallet, color: Colors.white)),
                title: const Text('Compte'),
                onTap: () {
                  Navigator.pop(dialogContext); // Close FAB menu
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    AddAccountBottomSheet.show(context, onSuccess: () {
                      MainScreen.of(context)?.setSelectedIndex(1);
                      ExpenseScreen.navigateToTab(2);
                    });
                  });
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
        toolbarHeight: 0,
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

    return RefreshIndicator(
      onRefresh: () async {
        await SyncService().fullSync();
        if (context.mounted) {
          await context.read<ExpenseProvider>().loadData();
          await context.read<AccountProvider>().loadData();
        }
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
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
                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                final currentUserId = authProvider.user?['id']?.toString() ?? authProvider.user?['uuid']?.toString();
                String subtitleText = '${l10n.translateCategory(transaction.category)} • ${transaction.date.toLocal().day}/${transaction.date.toLocal().month}/${transaction.date.toLocal().year}';
                if (transaction.creatorId != null && transaction.creatorId != currentUserId && transaction.creatorName != null && transaction.creatorName!.isNotEmpty) {
                  subtitleText = '${l10n.translateCategory(transaction.category)} • Par ${transaction.creatorName} • ${transaction.date.toLocal().day}/${transaction.date.toLocal().month}/${transaction.date.toLocal().year}';
                }
                
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isIncome ? Colors.green.shade100 : Colors.red.shade100,
                    foregroundColor: isIncome ? Colors.green : Colors.red,
                    child: Icon(isIncome ? Icons.arrow_downward : Icons.arrow_upward),
                  ),
                  title: Text(transaction.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(subtitleText),
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
      ),
    );
  }

  String _getLastMonthLabel() {
    final now = DateTime.now();
    final lastMonthYear = now.month == 1 ? now.year - 1 : now.year;
    final lastMonth = now.month == 1 ? 12 : now.month - 1;
    const monthNames = [
      'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
    ];
    final monthName = monthNames[lastMonth - 1];
    return '$monthName $lastMonthYear';
  }

  Future<void> _selectCustomDateRange() async {
    final now = DateTime.now();
    final sixMonthsAgo = DateTime(now.year, now.month - 6, now.day);
    final firstDate = DateTime(sixMonthsAgo.year, sixMonthsAgo.month, sixMonthsAgo.day);
    final lastDate = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    final defaultStart = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
    final defaultEnd = DateTime(now.year, now.month, now.day);

    final initialStart = _customDateRange?.start ?? defaultStart;
    final initialEnd = _customDateRange?.end ?? defaultEnd;

    final validStart = initialStart.isBefore(firstDate) ? firstDate : initialStart;
    final validEnd = initialEnd.isAfter(lastDate) ? lastDate : initialEnd;

    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: validStart, end: validEnd),
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'Sélectionner une période (max 6 mois)',
      cancelText: 'Annuler',
      confirmText: 'Valider',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).colorScheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _customDateRange = DateTimeRange(
          start: DateTime(picked.start.year, picked.start.month, picked.start.day, 0, 0, 0, 0),
          end: DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59, 999),
        );
        _periodFilter = 'custom';
      });
    } else {
      if (_customDateRange == null && _periodFilter == 'custom') {
        setState(() {
          _periodFilter = '7days';
        });
      }
    }
  }

  // --- HISTORY TAB ---
  DateTimeRange _getRange() {
    final now = DateTime.now();
    switch (_periodFilter) {
      case '7days':
        final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
        final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        return DateTimeRange(start: start, end: end);
      case '30days':
        final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29));
        final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        return DateTimeRange(start: start, end: end);
      case 'last_month':
        final lastMonthYear = now.month == 1 ? now.year - 1 : now.year;
        final lastMonth = now.month == 1 ? 12 : now.month - 1;
        final lastDayOfLastMonth = DateTime(lastMonthYear, lastMonth + 1, 0).day;
        return DateTimeRange(
          start: DateTime(lastMonthYear, lastMonth, 1, 0, 0, 0, 0),
          end: DateTime(lastMonthYear, lastMonth, lastDayOfLastMonth, 23, 59, 59, 999),
        );
      case 'custom':
        if (_customDateRange != null) {
          return _customDateRange!;
        }
        final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
        final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        return DateTimeRange(start: start, end: end);
      default:
        final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
        final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        return DateTimeRange(start: start, end: end);
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
              Row(
                children: [
                  DropdownButton<String>(
                    value: _periodFilter,
                    underline: const SizedBox(),
                    items: [
                      const DropdownMenuItem(value: '7days', child: Text('7 derniers jours')),
                      const DropdownMenuItem(value: '30days', child: Text('30 derniers jours')),
                      DropdownMenuItem(value: 'last_month', child: Text(_getLastMonthLabel())),
                      const DropdownMenuItem(value: 'custom', child: Text('(Personnaliser)')),
                    ],
                    onChanged: (val) async {
                      if (val == null) return;
                      if (val == 'custom') {
                        await _selectCustomDateRange();
                      } else {
                        setState(() => _periodFilter = val);
                      }
                    },
                  ),
                  if (_periodFilter == 'custom' && _customDateRange != null) ...[
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: _selectCustomDateRange,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit_calendar, size: 14, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 4),
                            Text(
                              '${_customDateRange!.start.day.toString().padLeft(2, '0')}/${_customDateRange!.start.month.toString().padLeft(2, '0')} - ${_customDateRange!.end.day.toString().padLeft(2, '0')}/${_customDateRange!.end.month.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
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
          child: RefreshIndicator(
            onRefresh: () async {
              await SyncService().fullSync();
              if (context.mounted) {
                await context.read<ExpenseProvider>().loadData();
                await context.read<AccountProvider>().loadData();
              }
            },
            child: filteredExpenses.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.5,
                        child: Center(child: Text(l10n.noOperationPeriod)),
                      ),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: filteredExpenses.length,
                  itemBuilder: (context, index) {
                    final transaction = filteredExpenses[index];
                    final isIncome = transaction.type == 'income';
                    
                    final authProvider = Provider.of<AuthProvider>(context, listen: false);
                    final currentUserId = authProvider.user?['id']?.toString() ?? authProvider.user?['uuid']?.toString();
                    String subtitleText = '${l10n.translateCategory(transaction.category)} • ${transaction.date.toLocal().day}/${transaction.date.toLocal().month}/${transaction.date.toLocal().year}';
                    if (transaction.creatorId != null && transaction.creatorId != currentUserId && transaction.creatorName != null && transaction.creatorName!.isNotEmpty) {
                      subtitleText = '${l10n.translateCategory(transaction.category)} • Par ${transaction.creatorName} • ${transaction.date.toLocal().day}/${transaction.date.toLocal().month}/${transaction.date.toLocal().year}';
                    }

                    return Dismissible(
                      key: Key(transaction.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (direction) async {
                        return await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text(l10n.deleteEntryConfirm),
                            content: Text(l10n.deleteEntryWarning),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: Text(l10n.cancel),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: TextButton.styleFrom(foregroundColor: Colors.red),
                                child: Text(l10n.delete),
                              ),
                            ],
                          ),
                        ) ?? false;
                      },
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
                        subtitle: Text(subtitleText),
                        trailing: Text(
                          '${isIncome ? '+' : '-'}${transaction.amount.formatAmount()} $currency',
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
                                      await provider.deleteExpense(transaction.id, executor: txn);
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
        ),
      ],
    );
  }

  // --- ACCOUNTS TAB ---
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
                                      // Afficher le loader
                                      showDialog(
                                        context: context,
                                        barrierDismissible: false,
                                        builder: (ctx) => Dialog(
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
                                        await Provider.of<AccountProvider>(context, listen: false)
                                            .shareAccount(account.id, contact.id);
                                        if (mounted) {
                                          Navigator.pop(context); // Cacher le loader
                                          ScaffoldMessenger.of(context).showSnackBar(
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
                                        if (mounted) {
                                          Navigator.pop(context); // Cacher le loader
                                          
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

                                          ScaffoldMessenger.of(context).showSnackBar(
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

  Widget _buildAccountsTab() {
    final l10n = AppLocalizations.of(context)!;
    final accountProvider = Provider.of<AccountProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final currency = Provider.of<ProfileProvider>(context).profile.currency;
    final accounts = accountProvider.accounts;
    final currentUserId = authProvider.user?['id'];

    return RefreshIndicator(
      onRefresh: () async {
        await SyncService().fullSync();
        if (context.mounted) {
          await context.read<ExpenseProvider>().loadData();
          await context.read<AccountProvider>().loadData();
        }
      },
      child: accounts.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.8,
                  child: Center(child: Text(l10n.noAccountSaved)),
                ),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: accounts.length,
      itemBuilder: (context, index) {
        final account = accounts[index];
        final isOwner = account.ownerId == null ||
            currentUserId == null ||
            account.ownerId.toString() == currentUserId.toString();
        final String initial = account.name.trim().isNotEmpty
            ? account.name.trim()[0].toUpperCase()
            : '?';

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: _parseAccountColor(account.color, context),
            child: Text(initial),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  account.name.isNotEmpty ? account.name : 'Sans nom',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
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
                  onPressed: () => AddAccountBottomSheet.show(context, existingAccount: account),
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
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AccountDetailScreen(accountId: account.id),
              ),
            );
          },
        );
      },
    ),
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
          child: RefreshIndicator(
            onRefresh: () async {
              await context.read<ExpenseProvider>().loadData();
            },
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              return ListTile(
                leading: const Icon(Icons.account_balance_wallet),
                title: Text(l10n.translateCategory(cat)),
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
        ),
      ],
    );
  }
}
