import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:monitrack/l10n/app_localizations.dart';

import '../providers/expense_provider.dart';
import '../providers/account_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/auth_provider.dart';
import '../models/account.dart';
import '../models/expense.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/translation_helper.dart';
import '../widgets/add_account_bottom_sheet.dart';
import '../widgets/share_account_dialog.dart';
import 'add_expense_screen.dart';
import 'expense_detail_screen.dart';
import '../services/database_service.dart';

class AccountDetailScreen extends StatefulWidget {
  final String accountId;

  const AccountDetailScreen({super.key, required this.accountId});

  @override
  State<AccountDetailScreen> createState() => _AccountDetailScreenState();
}

class _AccountDetailScreenState extends State<AccountDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  String _periodFilter = 'month'; // 'month', 'last_month', '30days', 'year', 'custom'
  DateTimeRange? _customDateRange;
  String? _categoryFilter;
  String? _contributorFilter;

  /// Palette d'identité des pôles de dépense.
  ///
  /// Les teintes claires sont exactement celles d'origine ; en sombre on passe
  /// sur les variantes 300 correspondantes, seules lisibles sur une carte
  /// foncée.
  List<Color> _categoryPalette(ColorScheme scheme) => [
        scheme.tone(light: const Color(0xFF009688), dark: const Color(0xFF4DB6AC)), // teal
        scheme.tone(light: const Color(0xFF3F51B5), dark: const Color(0xFF7986CB)), // indigo
        scheme.tone(light: const Color(0xFFEF6C00), dark: const Color(0xFFFFB74D)), // orange.shade800
        scheme.tone(light: const Color(0xFFC2185B), dark: const Color(0xFFF06292)), // pink.shade700
        scheme.tone(light: const Color(0xFF1976D2), dark: const Color(0xFF64B5F6)), // blue.shade700
        scheme.tone(light: const Color(0xFF673AB7), dark: const Color(0xFF9575CD)), // deepPurple
        scheme.tone(light: const Color(0xFF388E3C), dark: const Color(0xFF81C784)), // green.shade700
        scheme.tone(light: const Color(0xFFFF6F00), dark: const Color(0xFFFFD54F)), // amber.shade900
        scheme.tone(light: const Color(0xFF00838F), dark: const Color(0xFF4DD0E1)), // cyan.shade800
        scheme.tone(light: const Color(0xFFFF5722), dark: const Color(0xFFFF8A65)), // deepOrange
        scheme.tone(light: const Color(0xFF607D8B), dark: const Color(0xFF90A4AE)), // blueGrey
      ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

  DateTimeRange _getRange() {
    final now = DateTime.now();
    switch (_periodFilter) {
      case 'month':
        final start = DateTime(now.year, now.month, 1, 0, 0, 0);
        final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
        return DateTimeRange(start: start, end: end);
      case 'last_month':
        final lastMonthYear = now.month == 1 ? now.year - 1 : now.year;
        final lastMonth = now.month == 1 ? 12 : now.month - 1;
        final lastDay = DateTime(lastMonthYear, lastMonth + 1, 0).day;
        return DateTimeRange(
          start: DateTime(lastMonthYear, lastMonth, 1, 0, 0, 0),
          end: DateTime(lastMonthYear, lastMonth, lastDay, 23, 59, 59, 999),
        );
      case '30days':
        final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29));
        final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        return DateTimeRange(start: start, end: end);
      case 'year':
        final start = DateTime(now.year, 1, 1, 0, 0, 0);
        final end = DateTime(now.year, 12, 31, 23, 59, 59, 999);
        return DateTimeRange(start: start, end: end);
      case 'custom':
        if (_customDateRange != null) return _customDateRange!;
        final start = DateTime(now.year, now.month, 1, 0, 0, 0);
        final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
        return DateTimeRange(start: start, end: end);
      default:
        final start = DateTime(now.year, now.month, 1, 0, 0, 0);
        final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
        return DateTimeRange(start: start, end: end);
    }
  }

  Future<void> _selectCustomDateRange() async {
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 2, 1, 1);
    final lastDate = DateTime(now.year + 1, 12, 31);

    final defaultStart = DateTime(now.year, now.month, 1);
    final defaultEnd = DateTime(now.year, now.month, now.day);

    final initialStart = _customDateRange?.start ?? defaultStart;
    final initialEnd = _customDateRange?.end ?? defaultEnd;

    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: initialStart, end: initialEnd),
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: l10n.selectPeriod,
      cancelText: l10n.cancel,
      confirmText: l10n.validate,
    );

    if (picked != null) {
      setState(() {
        _customDateRange = DateTimeRange(
          start: DateTime(picked.start.year, picked.start.month, picked.start.day, 0, 0, 0, 0),
          end: DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59, 999),
        );
        _periodFilter = 'custom';
      });
    }
  }

  void _showAddTransactionDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    // Pastilles d'identité dépense / entrée : teintes d'origine en clair,
    // variantes plus denses en sombre pour garder l'icône blanche lisible.
    final expenseAccent = scheme.tone(
      light: const Color(0xFFFF5252), // Colors.redAccent
      dark: const Color(0xFFC62828),
    );
    final incomeAccent = scheme.tone(
      light: const Color(0xFF4CAF50), // Colors.green
      dark: const Color(0xFF2E7D32),
    );
    // Posé sur une pastille toujours saturée : blanc dans les deux thèmes.
    const onAccent = Colors.white;
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
                leading: CircleAvatar(backgroundColor: expenseAccent, child: const Icon(Icons.arrow_upward, color: onAccent)),
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
                leading: CircleAvatar(backgroundColor: incomeAccent, child: const Icon(Icons.arrow_downward, color: onAccent)),
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
    final scheme = Theme.of(context).colorScheme;
    final accountProvider = Provider.of<AccountProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final expenseProvider = Provider.of<ExpenseProvider>(context);
    final currency = Provider.of<ProfileProvider>(context).profile.currency;

    final currentUserId = authProvider.user?['id'];
    final account = accountProvider.accounts.firstWhere(
      (a) => a.id == widget.accountId,
      orElse: () => Account(id: '', name: l10n.unknownAccount, balance: 0.0),
    );

    if (account.id.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.accounts)),
        body: Center(child: Text(l10n.accountNotFound)),
      );
    }

    final isOwner = account.ownerId == null ||
        currentUserId == null ||
        account.ownerId.toString() == currentUserId.toString();

    final accountColor = _parseAccountColor(account.color, context);
    // `accountColor` est la teinte choisie par l'utilisateur : identique en
    // clair et en sombre, aucun jeton `on*` du ColorScheme ne s'y applique. Le
    // blanc reste donc le bon contenu dans les deux thèmes.
    const onAccountColor = Colors.white;
    // Le solde reprend la couleur du compte tant qu'elle contraste avec le
    // fond ; sinon on retombe sur un contenu neutre : le noir d'origine en
    // clair (teinte trop claire) et `onSurface` en sombre (teinte trop
    // foncée, cas de la valeur par défaut `primaryContainer`).
    final accountLuminance = accountColor.computeLuminance();
    final balanceColor = scheme.tone(
      light: accountLuminance > 0.5 ? Colors.black87 : accountColor,
      dark: accountLuminance < 0.25 ? scheme.onSurface : accountColor,
    );

    // All account transactions
    final allAccountTransactions = expenseProvider.expenses.where((e) => e.accountId == widget.accountId).toList();
    allAccountTransactions.sort((a, b) => b.date.compareTo(a.date));

    // Filtered by date range
    final range = _getRange();
    final periodTransactions = allAccountTransactions.where((e) {
      return e.date.isAfter(range.start.subtract(const Duration(milliseconds: 1))) &&
             e.date.isBefore(range.end.add(const Duration(milliseconds: 1)));
    }).toList();

    // Calculate totals for the period
    double periodExpenses = 0.0;
    double periodIncomes = 0.0;
    final Map<String, double> categoryAmounts = {};
    final Map<String, int> categoryCounts = {};
    final Map<String, double> contributorAmounts = {};
    final Map<String, int> contributorCounts = {};

    for (final t in periodTransactions) {
      if (t.type == 'income') {
        periodIncomes += t.amount;
      } else {
        periodExpenses += t.amount;
        // By Category
        final cat = t.category.isNotEmpty ? t.category : 'Autre';
        categoryAmounts[cat] = (categoryAmounts[cat] ?? 0.0) + t.amount;
        categoryCounts[cat] = (categoryCounts[cat] ?? 0) + 1;

        // By Contributor
        final contributor = (t.creatorName != null && t.creatorName!.trim().isNotEmpty)
            ? t.creatorName!.trim()
            : (t.creatorId != null && t.creatorId == currentUserId?.toString()
                ? l10n.createdByMe
                : l10n.createdByMember);
        contributorAmounts[contributor] = (contributorAmounts[contributor] ?? 0.0) + t.amount;
        contributorCounts[contributor] = (contributorCounts[contributor] ?? 0) + 1;
      }
    }

    // Filtered transactions for the "Opérations" tab
    var displayTransactions = periodTransactions;
    if (_categoryFilter != null) {
      displayTransactions = displayTransactions.where((e) => e.category == _categoryFilter).toList();
    }
    if (_contributorFilter != null) {
      displayTransactions = displayTransactions.where((e) {
        final contributor = (e.creatorName != null && e.creatorName!.trim().isNotEmpty)
            ? e.creatorName!.trim()
            : (e.creatorId != null && e.creatorId == currentUserId?.toString()
                ? l10n.createdByMe
                : l10n.createdByMember);
        return contributor == _contributorFilter;
      }).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(account.name.isNotEmpty ? account.name : l10n.untitled),
        backgroundColor: accountColor,
        foregroundColor: onAccountColor,
        actions: [
          IconButton(
            icon: Icon(isOwner ? Icons.share : Icons.group),
            onPressed: () => showShareAccountDialog(context, account, isOwner),
            tooltip: isOwner ? l10n.tooltipShareAccount : l10n.tooltipViewMembers,
          ),
          if (isOwner) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => AddAccountBottomSheet.show(context, existingAccount: account),
              tooltip: l10n.tooltipEditAccount,
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
                        child: Text(l10n.delete, style: TextStyle(color: scheme.error)),
                      ),
                    ],
                  ),
                );
              },
              tooltip: l10n.tooltipDeleteAccount,
            ),
          ],
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: onAccountColor,
          unselectedLabelColor: onAccountColor.withValues(alpha: 0.7),
          indicatorColor: onAccountColor,
          indicatorWeight: 3,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.list_alt, size: 18),
                  const SizedBox(width: 8),
                  Text(l10n.tabOperations),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.pie_chart_outline, size: 18),
                  const SizedBox(width: 8),
                  Text(l10n.tabBreakdown),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Solde du compte Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            width: double.maxFinite,
            color: accountColor.withValues(alpha: 0.12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.accountBalance,
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${account.balance.formatAmountDouble()} $currency',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: balanceColor,
                      ),
                    ),
                  ],
                ),
                if (account.isShared)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      border: Border.all(color: scheme.primary),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.people, size: 14, color: scheme.onPrimaryContainer),
                        const SizedBox(width: 4),
                        Text(
                          isOwner ? l10n.sharedAccountBadge : l10n.sharedByBadge(account.ownerName ?? l10n.unknown),
                          style: TextStyle(fontSize: 11, color: scheme.onPrimaryContainer, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Période selector Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            color: scheme.surfaceContainerLow,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                DropdownButton<String>(
                  value: _periodFilter,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.calendar_today, size: 16),
                  style: TextStyle(color: scheme.onSurface, fontSize: 13, fontWeight: FontWeight.w600),
                  items: [
                    DropdownMenuItem(value: 'month', child: Text(l10n.periodMonth)),
                    DropdownMenuItem(value: 'last_month', child: Text(l10n.periodLastMonth)),
                    DropdownMenuItem(value: '30days', child: Text(l10n.period30Days)),
                    DropdownMenuItem(value: 'year', child: Text(l10n.periodYear)),
                    DropdownMenuItem(value: 'custom', child: Text(l10n.periodCustom)),
                  ],
                  onChanged: (val) async {
                    if (val == null) return;
                    if (val == 'custom') {
                      await _selectCustomDateRange();
                    } else {
                      setState(() {
                        _periodFilter = val;
                      });
                    }
                  },
                ),
                if (_periodFilter == 'custom' && _customDateRange != null)
                  InkWell(
                    onTap: _selectCustomDateRange,
                    child: Text(
                      '${DateFormat('dd/MM').format(_customDateRange!.start)} - ${DateFormat('dd/MM').format(_customDateRange!.end)}',
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                    ),
                  )
                else
                  Text(
                    '${DateFormat('dd/MM').format(range.start)} - ${DateFormat('dd/MM').format(range.end)}',
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),

          // Contenu selon l'onglet sélectionné
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // TAB 1: LISTE DES OPÉRATIONS
                _buildOperationsTab(displayTransactions, currentUserId, currency, l10n, accountProvider, expenseProvider),

                // TAB 2: SYNTHÈSE & PÔLES (ANALYTIQUE FAMILLE)
                _buildAnalyticsTab(periodExpenses, periodIncomes, categoryAmounts, categoryCounts, contributorAmounts, contributorCounts, currency, l10n),
              ],
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

  // --- WIDGET : ONGLET OPÉRATIONS ---
  Widget _buildOperationsTab(
    List<Expense> transactions,
    dynamic currentUserId,
    String currency,
    AppLocalizations l10n,
    AccountProvider accountProvider,
    ExpenseProvider expenseProvider,
  ) {
    final scheme = Theme.of(context).colorScheme;
    // Icône décorative d'état vide : gris clair d'origine en clair, gris
    // lisible sur fond foncé en sombre.
    final emptyStateIcon = scheme.tone(
      light: const Color(0xFFBDBDBD), // Colors.grey.shade400
      dark: scheme.onSurfaceVariant,
    );
    return Column(
      children: [
        // Active Filter Chips (if any)
        if (_categoryFilter != null || _contributorFilter != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: scheme.primaryContainer,
            child: Row(
              children: [
                Icon(Icons.filter_list, size: 16, color: scheme.onPrimaryContainer),
                const SizedBox(width: 6),
                Text('${l10n.filterLabel} ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: scheme.onPrimaryContainer)),
                if (_categoryFilter != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: Chip(
                      label: Text(l10n.translateCategory(_categoryFilter!), style: const TextStyle(fontSize: 11)),
                      deleteIcon: const Icon(Icons.close, size: 14),
                      onDeleted: () => setState(() => _categoryFilter = null),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                if (_contributorFilter != null)
                  Chip(
                    label: Text(_contributorFilter!, style: const TextStyle(fontSize: 11)),
                    deleteIcon: const Icon(Icons.close, size: 14),
                    onDeleted: () => setState(() => _contributorFilter = null),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),

        Expanded(
          child: transactions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 48, color: emptyStateIcon),
                      const SizedBox(height: 12),
                      Text(
                        l10n.noOperationOnAccount,
                        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 15),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final transaction = transactions[index];
                    final isIncome = transaction.type == 'income';
                    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

                    String subtitleText = '${l10n.translateCategory(transaction.category)} • ${dateFormat.format(transaction.date.toLocal())}';
                    if (transaction.creatorId != null &&
                        transaction.creatorId != currentUserId?.toString() &&
                        transaction.creatorName != null &&
                        transaction.creatorName!.isNotEmpty) {
                      subtitleText = '${l10n.translateCategory(transaction.category)} • ${l10n.createdBy(transaction.creatorName!)} • ${dateFormat.format(transaction.date.toLocal())}';
                    }

                    return Card(
                      elevation: 1,
                      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: (isIncome ? scheme.income : scheme.expense).withValues(alpha: 0.15),
                          foregroundColor: isIncome ? scheme.income : scheme.expense,
                          child: Icon(isIncome ? Icons.arrow_downward : Icons.arrow_upward),
                        ),
                        title: Text(transaction.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(subtitleText, style: const TextStyle(fontSize: 12)),
                        trailing: Text(
                          '${isIncome ? '+' : '-'}${transaction.amount.formatAmountDouble()} $currency',
                          style: TextStyle(
                            color: isIncome ? scheme.income : scheme.expense,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ExpenseDetailScreen(expense: transaction),
                            ),
                          );
                        },
                        onLongPress: () => _showExpenseActionBottomSheet(context, transaction),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _confirmDeleteExpense(BuildContext context, Expense transaction) {
    final l10n = AppLocalizations.of(context)!;
    final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
    final accountProvider = Provider.of<AccountProvider>(context, listen: false);
    final isIncome = transaction.type == 'income';

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
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  void _showExpenseActionBottomSheet(BuildContext context, Expense transaction) {
    final l10n = AppLocalizations.of(context)!;
    final isIncome = transaction.type == 'income';
    final currency = Provider.of<ProfileProvider>(context, listen: false).profile.currency;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

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
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Transaction header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: (isIncome ? scheme.income : scheme.expense).withValues(alpha: 0.15),
                        foregroundColor: isIncome ? scheme.income : scheme.expense,
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
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${isIncome ? '+' : '-'}${transaction.amount.formatAmountDouble()} $currency',
                        style: TextStyle(
                          color: isIncome ? scheme.income : scheme.expense,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
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
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
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
                      color: scheme.errorContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.delete_outline,
                      color: scheme.onErrorContainer,
                    ),
                  ),
                  title: Text(
                    l10n.delete,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: scheme.error,
                    ),
                  ),
                  subtitle: Text(
                    l10n.deleteEntryConfirm,
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmDeleteExpense(context, transaction);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- WIDGET : ONGLET SYNTHÈSE & PÔLES ---
  Widget _buildAnalyticsTab(
    double periodExpenses,
    double periodIncomes,
    Map<String, double> categoryAmounts,
    Map<String, int> categoryCounts,
    Map<String, double> contributorAmounts,
    Map<String, int> contributorCounts,
    String currency,
    AppLocalizations l10n,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final palette = _categoryPalette(scheme);
    // Icône décorative d'état vide (cf. onglet Opérations).
    final emptyStateIcon = scheme.tone(
      light: const Color(0xFFBDBDBD), // Colors.grey.shade400
      dark: scheme.onSurfaceVariant,
    );
    // Cartouches de synthèse : les jetons `expense` / `income` sont trop
    // clairs pour porter un texte de 12 px sur fond pâle, on garde donc les
    // teintes d'origine en clair et on ne bascule sur les jetons qu'en sombre.
    final expenseCardBackground = scheme.tone(
      light: const Color(0xFFFF8A80).withValues(alpha: 0.3), // Colors.redAccent.shade100
      dark: scheme.expense.withValues(alpha: 0.14),
    );
    final expenseCardBorder = scheme.tone(
      light: const Color(0xFFFF8A80), // Colors.redAccent.shade100
      dark: scheme.expense.withValues(alpha: 0.45),
    );
    final expenseCardLabel = scheme.tone(
      light: const Color(0xFFB71C1C), // Colors.red.shade900
      dark: scheme.expense,
    );
    final expenseCardAmount = scheme.tone(
      light: const Color(0xFFC62828), // Colors.red.shade800
      dark: scheme.expense,
    );
    final incomeCardBackground = scheme.tone(
      light: const Color(0xFFC8E6C9).withValues(alpha: 0.4), // Colors.green.shade100
      dark: scheme.income.withValues(alpha: 0.14),
    );
    final incomeCardBorder = scheme.tone(
      light: const Color(0xFFA5D6A7), // Colors.green.shade200
      dark: scheme.income.withValues(alpha: 0.45),
    );
    final incomeCardLabel = scheme.tone(
      light: const Color(0xFF1B5E20), // Colors.green.shade900
      dark: scheme.income,
    );
    final incomeCardAmount = scheme.tone(
      light: const Color(0xFF2E7D32), // Colors.green.shade800
      dark: scheme.income,
    );
    if (periodExpenses == 0 && periodIncomes == 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics_outlined, size: 54, color: emptyStateIcon),
            const SizedBox(height: 12),
            Text(
              l10n.noExpenseInPeriod,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 15),
            ),
          ],
        ),
      );
    }

    // Sort categories by amount descending
    final sortedCategories = categoryAmounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Sort contributors by amount descending
    final sortedContributors = contributorAmounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Synthèse Chiffrée (Cards)
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: expenseCardBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: expenseCardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.totalExpenses, style: TextStyle(fontSize: 12, color: expenseCardLabel, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${periodExpenses.formatAmountDouble()} $currency',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: expenseCardAmount),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: incomeCardBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: incomeCardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.totalIncomes, style: TextStyle(fontSize: 12, color: incomeCardLabel, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${periodIncomes.formatAmountDouble()} $currency',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: incomeCardAmount),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // 2. Répartition par Pôle de dépenses (Catégories)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.spendingByPole,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              if (_categoryFilter != null)
                TextButton(
                  onPressed: () => setState(() => _categoryFilter = null),
                  child: Text(l10n.filterAll, style: const TextStyle(fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 10),

          Card(
            elevation: 1.5,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                children: [
                  ...sortedCategories.asMap().entries.map((entry) {
                    final index = entry.key;
                    final catName = entry.value.key;
                    final amount = entry.value.value;
                    final percentage = periodExpenses > 0 ? (amount / periodExpenses) * 100 : 0.0;
                    final count = categoryCounts[catName] ?? 0;
                    final color = palette[index % palette.length];
                    final isSelected = _categoryFilter == catName;

                    return InkWell(
                      onTap: () {
                        setState(() {
                          _categoryFilter = isSelected ? null : catName;
                          _tabController.animateTo(0); // Switch to transactions tab
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? scheme.primaryContainer : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      l10n.translateCategory(catName),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '($count)',
                                      style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11),
                                    ),
                                  ],
                                ),
                                Text(
                                  '${amount.formatAmountDouble()} $currency (${percentage.toStringAsFixed(1)}%)',
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: percentage / 100,
                                minHeight: 6,
                                backgroundColor: scheme.surfaceContainerHighest,
                                valueColor: AlwaysStoppedAnimation<Color>(color),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // 3. Répartition par Contributeur / Membre de la famille
          if (sortedContributors.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.spendingByMember,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                if (_contributorFilter != null)
                  TextButton(
                    onPressed: () => setState(() => _contributorFilter = null),
                    child: Text(l10n.filterAll, style: const TextStyle(fontSize: 12)),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            Card(
              elevation: 1.5,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  children: [
                    ...sortedContributors.asMap().entries.map((entry) {
                      final contributorName = entry.value.key;
                      final amount = entry.value.value;
                      final percentage = periodExpenses > 0 ? (amount / periodExpenses) * 100 : 0.0;
                      final count = contributorCounts[contributorName] ?? 0;
                      final isSelected = _contributorFilter == contributorName;

                      return InkWell(
                        onTap: () {
                          setState(() {
                            _contributorFilter = isSelected ? null : contributorName;
                            _tabController.animateTo(0); // Switch to transactions tab
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? scheme.primaryContainer : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: scheme.primaryContainer,
                                    child: Text(
                                      contributorName.isNotEmpty ? contributorName[0].toUpperCase() : '?',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: scheme.onPrimaryContainer),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      contributorName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ),
                                  Text(
                                    '${amount.formatAmountDouble()} $currency (${percentage.toStringAsFixed(1)}%)',
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: percentage / 100,
                                  minHeight: 6,
                                  backgroundColor: scheme.surfaceContainerHighest,
                                  valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  l10n.operationsCount(count),
                                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 10),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

