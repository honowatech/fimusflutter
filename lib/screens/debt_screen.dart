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
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 0,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Dashboard'),
            Tab(text: 'Historique'),
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
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Nouvelle opération de dette',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.red.shade100,
                  child: Icon(Icons.arrow_downward, color: Colors.red.shade900),
                ),
                title: const Text('Emprunt'),
                subtitle: const Text('Enregistrer une dette que vous avez contractée'),
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
                  backgroundColor: Colors.green.shade100,
                  child: Icon(Icons.arrow_upward, color: Colors.green.shade900),
                ),
                title: const Text('Créance'),
                subtitle: const Text('L\'argent que vous percevrez'),
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
                  backgroundColor: Colors.blue.shade100,
                  child: Icon(Icons.payments_outlined, color: Colors.blue.shade900),
                ),
                title: const Text('Remboursement'),
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
    final provider = Provider.of<ExpenseProvider>(context, listen: false);
    final contacts = Provider.of<ContactProvider>(context, listen: false).contacts;
    final currency = Provider.of<ProfileProvider>(context, listen: false).profile.currency;
    final tags = provider.debtTags;

    if (tags.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Aucune dette ou créance enregistrée pour le moment.'),
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
            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Sélectionner une dette',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: controller,
                    itemCount: tags.length,
                    itemBuilder: (context, index) {
                      final tag = tags[index];
                      final balance = provider.getDebtBalance(tag);
                      final isDebt = balance > 0;
                      final isSettled = balance == 0;
                      final displayName = _getDisplayNameForTag(tag, contacts);

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isSettled
                              ? Colors.grey.shade200
                              : (isDebt ? Colors.red.shade50 : Colors.green.shade50),
                          child: Icon(
                            isSettled
                                ? Icons.check_circle_outline
                                : (isDebt ? Icons.arrow_downward : Icons.arrow_upward),
                            color: isSettled
                                ? Colors.grey
                                : (isDebt ? Colors.red.shade700 : Colors.green.shade700),
                          ),
                        ),
                        title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          isSettled
                              ? 'Soldé'
                              : (isDebt ? 'Dette à rembourser' : 'Créance à encaisser'),
                        ),
                        trailing: Text(
                          '${balance.abs().formatAmountDouble()} $currency',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isSettled
                                ? Colors.grey
                                : (isDebt ? Colors.red.shade700 : Colors.green.shade700),
                          ),
                        ),
                        onTap: () async {
                          Navigator.pop(ctx);
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AddDebtOperationScreen(initialTag: tag),
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
            );
          },
        );
      },
    );
  }


  Widget _buildDashboardTab(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
                  subtitle: 'À rembourser',
                  amount: totalDebts,
                  currency: currency,
                  color: Colors.red.shade100,
                  textColor: Colors.red.shade900,
                  icon: Icons.arrow_downward,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryCard(
                  title: l10n.totalReceivables,
                  subtitle: 'Total à percevoir',
                  amount: totalReceivables,
                  currency: currency,
                  color: Colors.green.shade100,
                  textColor: Colors.green.shade900,
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
                child: Text('Aucune opération récente', style: TextStyle(color: Colors.grey.shade600)),
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
          return balance > 0;
        case 'receivables':
          return balance < 0;
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
                'Filtre :',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700),
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
                          child: Text(l10n.noDebtTags, style: TextStyle(color: Colors.grey.shade600)),
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
                      final isDebt = balance > 0;
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
                              color: isSettled ? Colors.grey : (isDebt ? Colors.red : Colors.green),
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
    final isIncome = op.type == 'income';
    final amountColor = isIncome ? Colors.green : Colors.red;
    final sign = isIncome ? '+' : '-';
    final dateFormat = DateFormat('dd/MM/yyyy');
    final displayName = op.debtTag != null ? _getDisplayNameForTag(op.debtTag!, contacts) : '';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 1,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: amountColor.withOpacity(0.1),
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
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('Mémo', style: TextStyle(fontSize: 10, color: Colors.amber.shade900)),
              ),
            if (op.creatorName != null && op.creatorName!.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 4),
                child: Text(l10n.createdBy(op.creatorName!), style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.blueGrey)),
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
    final provider = Provider.of<ExpenseProvider>(context);
    
    final pendingExpenses = provider.expenses.where((e) => e.debtStatus == 'pending' && e.debtorUserId == provider.currentUserId).toList();
    if (pendingExpenses.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: pendingExpenses.map((expense) {
        final creatorName = expense.creatorName ?? 'Quelqu\'un';
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.orange.shade50,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Colors.orange.shade300, width: 1),
            borderRadius: BorderRadius.circular(8)
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$creatorName vous a associé à une dette : ${expense.title}',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade900),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.close, color: Colors.red),
                      label: const Text('Supprimer', style: TextStyle(color: Colors.red)),
                      onPressed: () => _confirmRejectDebt(context, expense),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.check, color: Colors.white),
                      label: const Text('Valider'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Refuser la dette'),
        content: const Text('Êtes-vous sûr de vouloir supprimer cette dette ? Cette action est irréversible et retirera votre nom de cette opération.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              final provider = Provider.of<ExpenseProvider>(context, listen: false);
              provider.deleteExpense(expense.id);
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
