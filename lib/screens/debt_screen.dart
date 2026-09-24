import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:monitrack/l10n/app_localizations.dart';
import '../providers/expense_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/contact_provider.dart';
import '../models/expense.dart';
import '../models/contact.dart';
import 'add_debt_operation_screen.dart';
import 'debt_detail_screen.dart';
import 'package:intl/intl.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';
import '../services/sync_service.dart';

class DebtScreen extends StatefulWidget {
  static final GlobalKey<DebtScreenState> globalKey = GlobalKey<DebtScreenState>();

  DebtScreen({Key? key}) : super(key: key ?? globalKey);

  @override
  State<DebtScreen> createState() => DebtScreenState();
}

class DebtScreenState extends State<DebtScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _listFilter = 'all'; // all, active, debts, receivables, settled

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ContactProvider>().fetchContacts();
    });
  }

  String _getDisplayNameForTag(String tag, List<Contact> contacts) {
    final match = contacts.firstWhere(
      (c) => c.name.toLowerCase() == tag.toLowerCase(),
      orElse: () => Contact(id: -1, name: '', email: '', userCode: ''),
    );
    return match.id != -1 ? match.displayName : tag;
  }

  void switchToHistoryTab() {
    if (_tabController.index != 1) {
      _tabController.animateTo(1);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 0,
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        bottom: TabBar(
          controller: _tabController,
          labelColor: scheme.onPrimary,
          unselectedLabelColor: scheme.onPrimary.withValues(alpha: 0.7),
          indicatorColor: scheme.onPrimary,
          tabs: [
            Tab(text: l10n.dashboard),
            Tab(text: l10n.history),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDashboardTab(context),
          _buildListTab(context),
        ],
      ),
    );
  }

  void handleFabPress() {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  l10n.debtNewOperationTitle,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: scheme.expense.withValues(alpha: 0.15),
                  child: Icon(Icons.arrow_downward, color: scheme.expense),
                ),
                title: Text(l10n.borrowAction),
                subtitle: Text(l10n.borrowSubtitle),
                onTap: () async {
                  Navigator.pop(ctx);
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AddDebtOperationScreen(initialIsIncome: true),
                    ),
                  );
                  if (result == true) {
                    switchToHistoryTab();
                  }
                },
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: scheme.income.withValues(alpha: 0.15),
                  child: Icon(Icons.arrow_upward, color: scheme.income),
                ),
                title: Text(l10n.lendAction),
                subtitle: Text(l10n.lendSubtitle),
                onTap: () async {
                  Navigator.pop(ctx);
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AddDebtOperationScreen(initialIsIncome: false),
                    ),
                  );
                  if (result == true) {
                    switchToHistoryTab();
                  }
                },
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: scheme.infoContainer,
                  child: Icon(Icons.payments_outlined, color: scheme.onInfoContainer),
                ),
                title: Text(l10n.repaymentAction),
                onTap: () {
                  Navigator.pop(ctx);
                  _showDebtSelectionSheet(context);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showDebtSelectionSheet(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final provider = Provider.of<ExpenseProvider>(context, listen: false);
    final contacts = Provider.of<ContactProvider>(context, listen: false).contacts;
    final currency = Provider.of<ProfileProvider>(context, listen: false).profile.currency;
    final tags = provider.debtTags;

    if (tags.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.noDebtOrReceivableRecorded),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          builder: (_, controller) {
            return SafeArea(
              top: false,
              child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    l10n.debtSelectTitle,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: controller,
                    itemCount: tags.length,
                    itemBuilder: (context, index) {
                      final tag = tags[index];
                      final balance = provider.getDebtBalance(tag);
                      final isDebt = balance < 0;
                      final isSettled = balance == 0;
                      final displayName = _getDisplayNameForTag(tag, contacts);

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isSettled
                              ? scheme.surfaceContainerHighest
                              : (isDebt
                                  ? scheme.expense.withValues(alpha: 0.12)
                                  : scheme.income.withValues(alpha: 0.12)),
                          child: Icon(
                            isSettled
                                ? Icons.check_circle_outline
                                : (isDebt ? Icons.arrow_downward : Icons.arrow_upward),
                            color: isSettled
                                ? scheme.onSurfaceVariant
                                : (isDebt ? scheme.expense : scheme.income),
                          ),
                        ),
                        title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          isSettled
                              ? l10n.debtBadgeSettled
                              : (isDebt
                                  ? l10n.debtBadgeToRepay
                                  : l10n.debtBadgeToCollect),
                        ),
                        trailing: Text(
                          '${balance.abs().formatAmountDouble()} $currency',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isSettled
                                ? scheme.onSurfaceVariant
                                : (isDebt ? scheme.expense : scheme.income),
                          ),
                        ),
                        onTap: () async {
                          Navigator.pop(ctx);
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AddDebtOperationScreen(
                                initialTag: tag,
                                initialAmount: balance != 0 ? balance.abs() : null,
                              ),
                            ),
                          );
                          if (result == true) {
                            switchToHistoryTab();
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
            );
          },
        );
      },
    );
  }


  Widget _buildDashboardTab(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    // Cartouches de synthèse : teintes d'origine en clair (un fond plein
    // rouge/vert très pâle), voile coloré sur la surface sombre en sombre.
    final debtCardBackground = scheme.tone(
      light: const Color(0xFFFFCDD2), // Colors.red.shade100
      dark: scheme.expense.withValues(alpha: 0.18),
    );
    final debtCardText = scheme.tone(
      light: const Color(0xFFB71C1C), // Colors.red.shade900
      dark: scheme.expense,
    );
    final receivableCardBackground = scheme.tone(
      light: const Color(0xFFC8E6C9), // Colors.green.shade100
      dark: scheme.income.withValues(alpha: 0.18),
    );
    final receivableCardText = scheme.tone(
      light: const Color(0xFF1B5E20), // Colors.green.shade900
      dark: scheme.income,
    );
    final provider = Provider.of<ExpenseProvider>(context);
    final currency = Provider.of<ProfileProvider>(context).profile.currency;
    
    final totalDebts = provider.getTotalDebts();
    final totalReceivables = provider.getTotalReceivables();
    final recentOperations = provider.getRecentDebtTransactions(limit: 10);

    return RefreshIndicator(
      onRefresh: () async {
        try {
          await SyncService().fullSync();
        } catch (_) {}
        if (!context.mounted) return;
        await context.read<ExpenseProvider>().loadData();
        if (!context.mounted) return;
        await context.read<ContactProvider>().fetchContacts();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  title: l10n.totalDebts,
                  subtitle: l10n.toRepay,
                  amount: totalDebts,
                  currency: currency,
                  color: debtCardBackground,
                  textColor: debtCardText,
                  icon: Icons.arrow_downward,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryCard(
                  title: l10n.totalReceivables,
                  subtitle: l10n.totalToCollect,
                  amount: totalReceivables,
                  currency: currency,
                  color: receivableCardBackground,
                  textColor: receivableCardText,
                  icon: Icons.arrow_upward,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            l10n.recentDebtOperations,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (recentOperations.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Text(l10n.noRecentOperation, style: TextStyle(color: scheme.onSurfaceVariant)),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recentOperations.length,
              itemBuilder: (context, index) {
                final op = recentOperations[index];
                return _buildTransactionTile(context, op, currency);
              },
            ),
        ],
      ),
      ),
    );
  }

  Widget _buildListTab(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final provider = Provider.of<ExpenseProvider>(context);
    final currency = Provider.of<ProfileProvider>(context).profile.currency;
    final contacts = Provider.of<ContactProvider>(context).contacts;
    final allTags = provider.debtTags;

    // Filter logic
    final tags = allTags.where((tag) {
      final balance = provider.getDebtBalance(tag);
      switch (_listFilter) {
        case 'all':
          return true;
        case 'active':
          return balance != 0;
        case 'debts':
          return balance < 0;
        case 'receivables':
          return balance > 0;
        case 'settled':
          return balance == 0;
        default:
          return true;
      }
    }).toList();

    return Column(
      children: [
        _buildPendingInvitations(context),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.filterLabel,
                style: TextStyle(fontWeight: FontWeight.bold, color: scheme.onSurfaceVariant),
              ),
              DropdownButton<String>(
                value: _listFilter,
                underline: const SizedBox(),
                items: [
                  DropdownMenuItem(value: 'all', child: Text(l10n.allLabel)),
                  DropdownMenuItem(value: 'active', child: Text(l10n.filterActiveDebts)),
                  DropdownMenuItem(value: 'debts', child: Text(l10n.filterOnlyDebts)),
                  DropdownMenuItem(value: 'receivables', child: Text(l10n.filterOnlyReceivables)),
                  DropdownMenuItem(value: 'settled', child: Text(l10n.filterSettled)),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _listFilter = val);
                  }
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              try {
                await SyncService().fullSync();
              } catch (_) {}
              if (!context.mounted) return;
              await context.read<ExpenseProvider>().loadData();
              if (!context.mounted) return;
              await context.read<ContactProvider>().fetchContacts();
            },
            child: tags.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.5,
                        child: Center(
                          child: Text(l10n.noDebtTags, style: TextStyle(color: scheme.onSurfaceVariant)),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    itemCount: tags.length,
                    itemBuilder: (context, index) {
                      final tag = tags[index];
                      final balance = provider.getDebtBalance(tag);
                      final isDebt = balance < 0;
                      final isSettled = balance == 0;

                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        child: ListTile(
                          title: Text(_getDisplayNameForTag(tag, contacts), style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(isSettled ? l10n.filterSettled : (isDebt ? l10n.debts : l10n.receivables)),
                          trailing: Text(
                            '${balance.abs().formatAmountDouble()} $currency',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isSettled ? scheme.onSurfaceVariant : (isDebt ? scheme.expense : scheme.income),
                            ),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => DebtDetailScreen(debtTag: tag)),
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

  Widget _buildSummaryCard({
    required String title,
    String? subtitle,
    required double amount,
    required String currency,
    required Color color,
    required Color textColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: textColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '${amount.formatAmountDouble()} $currency',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: textColor.withAlpha(200),
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildTransactionTile(BuildContext context, Expense op, String currency) {
    final l10n = AppLocalizations.of(context)!;
    final contacts = Provider.of<ContactProvider>(context).contacts;
    final scheme = Theme.of(context).colorScheme;
    final isIncome = op.type == 'income';
    final amountColor = isIncome ? scheme.income : scheme.expense;
    // Badge « Mémo » : l'ambre clair d'origine n'a pas d'équivalent exact,
    // on le fige en clair et on bascule sur le conteneur d'avertissement en sombre.
    final memoBackground = scheme.tone(
      light: const Color(0xFFFFECB3), // Colors.amber.shade100
      dark: scheme.warningContainer,
    );
    final sign = isIncome ? '+' : '-';
    final dateFormat = DateFormat('dd/MM/yyyy');
    final displayName = op.debtTag != null ? _getDisplayNameForTag(op.debtTag!, contacts) : '';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 1,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: amountColor.withValues(alpha: 0.1),
          child: Icon(
            isIncome ? Icons.arrow_downward : Icons.arrow_upward,
            color: amountColor,
          ),
        ),
        title: Text(op.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${dateFormat.format(op.date)} • $displayName'),
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
            if (op.creatorName != null && op.creatorName!.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 4),
                child: Text(l10n.createdBy(op.creatorName!), style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: scheme.onSurfaceVariant)),
              ),
          ],
        ),
        trailing: Text(
          '$sign${op.amount.toStringAsFixed(2)} $currency',
          style: TextStyle(
            color: amountColor,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildPendingInvitations(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    // Bouton « Valider » : vert d'origine en clair, vert plus dense en sombre ;
    // le libellé et l'icône restent blancs (le fond est toujours saturé), sinon
    // le `onPrimary` sombre du thème les rendrait illisibles.
    final validateBackground = scheme.tone(
      light: const Color(0xFF4CAF50), // Colors.green
      dark: const Color(0xFF2E7D32),
    );
    const onValidate = Colors.white;
    final provider = Provider.of<ExpenseProvider>(context);
    
    final pendingExpenses = provider.expenses.where((e) => e.debtStatus == 'pending' && e.debtorUserId == provider.currentUserId).toList();
    if (pendingExpenses.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: pendingExpenses.map((expense) {
        final creatorName = expense.creatorName ?? l10n.someone;
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: scheme.warningContainer,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: scheme.warningOutline, width: 1),
            borderRadius: BorderRadius.circular(8)
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: scheme.onWarningContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.debtPendingInvitation(creatorName, expense.title),
                        style: TextStyle(fontWeight: FontWeight.bold, color: scheme.onWarningContainer),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: Icon(Icons.close, color: scheme.error),
                      label: Text(l10n.delete, style: TextStyle(color: scheme.error)),
                      onPressed: () => _confirmRejectDebt(context, expense),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.check, color: onValidate),
                      label: Text(l10n.validate),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: validateBackground,
                        foregroundColor: onValidate,
                      ),
                      onPressed: () => _acceptDebt(context, expense),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  void _acceptDebt(BuildContext context, Expense expense) {
    final provider = Provider.of<ExpenseProvider>(context, listen: false);
    final updatedExpense = expense.copyWith(debtStatus: 'accepted');
    provider.updateExpense(updatedExpense);
  }

  void _confirmRejectDebt(BuildContext context, Expense expense) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.rejectDebt),
        content: Text(l10n.rejectDebtConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              final provider = Provider.of<ExpenseProvider>(context, listen: false);
              provider.deleteExpense(expense.id);
            },
            child: Text(l10n.delete, style: TextStyle(color: scheme.error)),
          ),
        ],
      ),
    );
  }
}
