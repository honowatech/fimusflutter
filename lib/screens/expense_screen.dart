import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:monitrack/l10n/app_localizations.dart';
import '../providers/expense_provider.dart';
import '../providers/contact_provider.dart';
import '../widgets/add_transaction_sheet.dart';
import 'expense/accounts_tab.dart';
import 'expense/categories_tab.dart';
import 'expense/category_dialogs.dart';
import 'expense/dashboard_tab.dart';
import 'expense/expense_date_filters.dart';
import 'expense/history_tab.dart';

/// Écran « Dépenses » : coordonne les 4 onglets (tableau de bord, historique,
/// comptes, catégories) et conserve l'état des filtres.
///
/// L'implémentation de chaque onglet et les éléments réutilisables
/// (graphiques, barre de filtres, feuilles d'actions, dialogues) vivent dans
/// `lib/screens/expense/`.
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

  // Dashboard tab filters
  String _dashboardPeriodFilter = '7days';
  DateTimeRange? _dashboardCustomDateRange;
  String _dashboardTypeFilter = 'all';
  // null = toutes les catégories sélectionnées ; sinon sous-ensemble des
  // catégories disponibles pour le type choisi.
  Set<String>? _dashboardSelectedCategories;
  bool _isBarChart = true;

  // History tab filters
  String _periodFilter = '7days';
  DateTimeRange? _customDateRange;
  String _typeFilter = 'all';
  // null = toutes les catégories sélectionnées (même logique que le dashboard).
  Set<String>? _historySelectedCategories;
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
    AddTransactionSheet.show(context);
  }

  /// Conservé pour compatibilité : point d'entrée public de création de
  /// catégorie (voir `showAddCategoryDialog`).
  void addCategoryDialog(BuildContext context, ExpenseProvider provider, {bool isIncome = false}) {
    showAddCategoryDialog(context, provider, isIncome: isIncome);
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
          // L'AppBar est peinte en `primary` : les libellés d'onglets suivent
          // donc `onPrimary` (blanc en clair, sombre sur primaire clair en sombre).
          labelColor: Theme.of(context).colorScheme.onPrimary,
          unselectedLabelColor:
              Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7),
          indicatorColor: Theme.of(context).colorScheme.onPrimary,
          isScrollable: true,
          tabs: [
            Tab(text: l10n.dashboard),
            Tab(text: l10n.history),
            Tab(text: l10n.accounts),
            Tab(text: l10n.category),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          ExpenseDashboardTab(
            periodFilter: _dashboardPeriodFilter,
            customDateRange: _dashboardCustomDateRange,
            typeFilter: _dashboardTypeFilter,
            selectedCategories: _dashboardSelectedCategories,
            isBarChart: _isBarChart,
            onPeriodChanged: (val) => setState(() => _dashboardPeriodFilter = val),
            onCustomDateTap: () => _selectCustomDateRange(isDashboard: true),
            onTypeChanged: (val) => setState(() {
              _dashboardTypeFilter = val;
              // Les catégories disponibles dépendent du type : retour à
              // « toutes les catégories ».
              _dashboardSelectedCategories = null;
            }),
            onCategoriesChanged: (sel) => setState(() => _dashboardSelectedCategories = sel),
            onChartTypeChanged: (isBar) => setState(() => _isBarChart = isBar),
          ),
          ExpenseHistoryTab(
            periodFilter: _periodFilter,
            customDateRange: _customDateRange,
            typeFilter: _typeFilter,
            selectedCategories: _historySelectedCategories,
            onPeriodChanged: (val) => setState(() => _periodFilter = val),
            onCustomDateTap: () => _selectCustomDateRange(isDashboard: false),
            onTypeChanged: (val) => setState(() {
              _typeFilter = val;
              // Les catégories disponibles dépendent du type : retour à
              // « toutes les catégories ».
              _historySelectedCategories = null;
            }),
            onCategoriesChanged: (sel) => setState(() => _historySelectedCategories = sel),
          ),
          const ExpenseAccountsTab(),
          ExpenseCategoriesTab(
            categoryTypeFilter: _categoryTypeFilter,
            onCategoryTypeChanged: (val) => setState(() => _categoryTypeFilter = val),
          ),
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

  Future<void> _selectCustomDateRange({bool isDashboard = false}) async {
    final currentCustomRange = isDashboard ? _dashboardCustomDateRange : _customDateRange;
    final newRange = await pickExpenseCustomRange(context, currentCustomRange);

    if (newRange != null) {
      setState(() {
        if (isDashboard) {
          _dashboardCustomDateRange = newRange;
          _dashboardPeriodFilter = 'custom';
        } else {
          _customDateRange = newRange;
          _periodFilter = 'custom';
        }
      });
    } else {
      if (isDashboard) {
        if (_dashboardCustomDateRange == null && _dashboardPeriodFilter == 'custom') {
          setState(() {
            _dashboardPeriodFilter = '7days';
          });
        }
      } else {
        if (_customDateRange == null && _periodFilter == 'custom') {
          setState(() {
            _periodFilter = '7days';
          });
        }
      }
    }
  }
}
