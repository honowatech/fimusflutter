import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../models/expense.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';
import '../services/auth_service.dart';

class ExpenseProvider with ChangeNotifier {
  List<Expense> _expenses = [];
  List<String> _categories = [];
  List<String> _incomeCategories = [];
  List<String> _debtTags = [];
  String? _currentUserId;
  Future<void>? _loadFuture;

  List<Expense> get expenses => _expenses;
  List<String> get categories => _categories;
  List<String> get expenseCategories => _categories;
  List<String> get incomeCategories => _incomeCategories;
  List<String> get debtTags => _debtTags;
  String? get currentUserId => _currentUserId;

  ExpenseProvider() {
    loadData();
  }

  Future<void> loadData() {
    _loadFuture ??= _performLoadData();
    return _loadFuture!;
  }

  Future<void> _performLoadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

    // Get current user id
    final authUser = await AuthService().getCachedUser();
    _currentUserId = authUser?['id']?.toString() ?? authUser?['uuid']?.toString();

    // Load Expenses from SQLite
    final db = await DatabaseService.instance.database;
    final List<Map<String, dynamic>> maps = await db.query('expenses');
    _expenses = maps.map((e) {
      final exp = Expense.fromDbMap(e);
      if (_currentUserId != null &&
          exp.creatorId != null &&
          exp.creatorId.toString() != _currentUserId.toString() &&
          exp.debtorUserId != null &&
          exp.debtorUserId.toString() == _currentUserId.toString()) {
        final creatorTagName = (exp.creatorName != null && exp.creatorName!.trim().isNotEmpty)
            ? exp.creatorName!.trim()
            : exp.debtTag;
        return exp.copyWith(
          type: exp.type == 'income' ? 'expense' : 'income',
          debtTag: creatorTagName,
          debtorUserId: exp.creatorId,
          originalType: exp.type,
          originalDebtTag: exp.debtTag,
          originalDebtorUserId: exp.debtorUserId,
        );
      }
      return exp;
    }).toList();
    _expenses.sort((a, b) => b.date.compareTo(a.date));

    // Load Categories
    final List<String>? cats = prefs.getStringList('expense_categories');
    if (cats != null) {
      _categories = cats;
    } else {
      _categories = _getDefaultCategories();
      await _saveCategories();
    }

    // Load Income Categories
    final List<String>? incomeCats = prefs.getStringList('income_categories');
    if (incomeCats != null) {
      _incomeCategories = incomeCats;
    } else {
      _incomeCategories = _getDefaultIncomeCategories();
      await _saveIncomeCategories();
    }

    // Load Debt Tags
    final List<String>? dTags = prefs.getStringList('debt_tags');
    final Set<String> allTags = dTags != null ? dTags.toSet() : {};
    for (var e in _expenses) {
      if (e.debtTag != null && e.debtTag!.isNotEmpty) {
        allTags.add(e.debtTag!);
      }
    }
    _debtTags = allTags.toList();
    await _saveDebtTags();

    notifyListeners();
    } finally {
      _loadFuture = null;
    }
  }


  Future<void> _saveCategories() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('expense_categories', _categories);
  }

  Future<void> _saveIncomeCategories() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('income_categories', _incomeCategories);
  }

  Future<void> _saveDebtTags() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('debt_tags', _debtTags);
  }


  // --- Expense Methods ---

  Future<void> addExpense(Expense expense, {DatabaseExecutor? executor}) async {
    final db = executor ?? await DatabaseService.instance.database;
    final updatedExpense = expense.copyWith(updatedAt: DateTime.now());
    await db.insert('expenses', updatedExpense.toDbMap());
    
    _expenses.add(updatedExpense);
    // Sort by date descending
    _expenses.sort((a, b) => b.date.compareTo(a.date));

    // Automatically add debt tag to _debtTags if it exists and is new
    if (expense.debtTag != null && expense.debtTag!.isNotEmpty) {
      if (!_debtTags.contains(expense.debtTag)) {
        _debtTags.add(expense.debtTag!);
        await _saveDebtTags();
      }
    }

    notifyListeners();
    SyncService().push();
  }

  Future<void> deleteExpense(String id, {DatabaseExecutor? executor}) async {
    final db = executor ?? await DatabaseService.instance.database;
    await db.update(
      'expenses',
      {
        'sync_action': 'delete',
        'is_synced': 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    
    _expenses.removeWhere((e) => e.id == id);
    notifyListeners();
    SyncService().push();
  }

  Future<void> updateExpense(Expense expense, {DatabaseExecutor? executor}) async {
    final db = executor ?? await DatabaseService.instance.database;
    final updatedExpense = expense.copyWith(updatedAt: DateTime.now());
    await db.update(
      'expenses',
      {
        ...updatedExpense.toDbMap(),
        'is_synced': 0,
        'sync_action': 'updated',
        'updated_at': updatedExpense.updatedAt!.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [updatedExpense.id],
    );
    
    final index = _expenses.indexWhere((e) => e.id == updatedExpense.id);
    if (index != -1) {
      _expenses[index] = updatedExpense;
      _expenses.sort((a, b) => b.date.compareTo(a.date));
      notifyListeners();
    }
    SyncService().push();
  }

  List<Expense> getFilteredExpenses(DateTime start, DateTime end, {String? type}) {
    return _expenses.where((e) => 
      e.isLinkedToCashFlow &&
      !e.isPlanned &&
      (e.date.toLocal().isAfter(start) || e.date.toLocal().isAtSameMomentAs(start)) && 
      (e.date.toLocal().isBefore(end) || e.date.toLocal().isAtSameMomentAs(end)) &&
      (type == null || e.type == type)
    ).toList();
  }

  double getTotalExpenses(DateTime start, DateTime end) {
    return getFilteredExpenses(start, end, type: 'expense').fold(0.0, (sum, item) => sum + item.amount);
  }

  double getTotalIncomes(DateTime start, DateTime end) {
    return getFilteredExpenses(start, end, type: 'income').fold(0.0, (sum, item) => sum + item.amount);
  }

  // --- Category Methods ---

  Future<void> addCategory(String category, {bool isIncome = false}) async {
    if (isIncome) {
      if (!_incomeCategories.contains(category)) {
        _incomeCategories.add(category);
        await _saveIncomeCategories();
        notifyListeners();
      }
    } else {
      if (!_categories.contains(category)) {
        _categories.add(category);
        await _saveCategories();
        notifyListeners();
      }
    }
  }

  Future<void> deleteCategory(String category, {bool isIncome = false}) async {
    if (category != 'Autre') {
      if (isIncome) {
        _incomeCategories.remove(category);
        await _saveIncomeCategories();
        notifyListeners();
      } else {
        _categories.remove(category);
        await _saveCategories();
        notifyListeners();
      }
    }
  }

  Future<void> updateCategory(String oldCategory, String newCategory, {bool isIncome = false}) async {
    if (newCategory.trim().isEmpty || oldCategory == 'Autre') return;
    
    if (isIncome) {
      final index = _incomeCategories.indexOf(oldCategory);
      if (index != -1 && !_incomeCategories.contains(newCategory)) {
        _incomeCategories[index] = newCategory;
        for (int i = 0; i < _expenses.length; i++) {
          if (_expenses[i].type == 'income' && _expenses[i].category == oldCategory) {
            final updatedExpense = _expenses[i].copyWith(category: newCategory, updatedAt: DateTime.now());
            _expenses[i] = updatedExpense;
            final db = await DatabaseService.instance.database;
            await db.update(
              'expenses',
              {
                ...updatedExpense.toDbMap(),
                'is_synced': 0,
                'sync_action': 'updated',
                'updated_at': updatedExpense.updatedAt!.toIso8601String(),
              },
              where: 'id = ?',
              whereArgs: [updatedExpense.id],
            );
          }
        }
        await _saveIncomeCategories();
        notifyListeners();
        SyncService().push();
      }
    } else {
      final index = _categories.indexOf(oldCategory);
      if (index != -1 && !_categories.contains(newCategory)) {
        _categories[index] = newCategory;
        for (int i = 0; i < _expenses.length; i++) {
          if (_expenses[i].type == 'expense' && _expenses[i].category == oldCategory) {
            final updatedExpense = _expenses[i].copyWith(category: newCategory, updatedAt: DateTime.now());
            _expenses[i] = updatedExpense;
            final db = await DatabaseService.instance.database;
            await db.update(
              'expenses',
              {
                ...updatedExpense.toDbMap(),
                'is_synced': 0,
                'sync_action': 'updated',
                'updated_at': updatedExpense.updatedAt!.toIso8601String(),
              },
              where: 'id = ?',
              whereArgs: [updatedExpense.id],
            );
          }
        }
        await _saveCategories();
        notifyListeners();
        SyncService().push();
      }
    }
  }

  // --- Debt Methods ---

  Future<void> addDebtTag(String tag) async {
    if (!_debtTags.contains(tag)) {
      _debtTags.add(tag);
      await _saveDebtTags();
      notifyListeners();
    }
  }

  Future<void> deleteDebtTag(String tag, {DatabaseExecutor? executor}) async {
    final db = executor ?? await DatabaseService.instance.database;
    await db.delete('expenses', where: 'debtTag = ?', whereArgs: [tag]);
    
    _debtTags.remove(tag);
    _expenses.removeWhere((e) => e.debtTag == tag);
    await _saveDebtTags();
    notifyListeners();
  }

  double getDebtBalance(String tag) {
    return _expenses.where((e) => e.debtTag == tag && !e.isPlanned).fold(0.0, (sum, e) => sum + (e.type == 'income' ? e.amount : -e.amount));
  }

  double getTotalDebts() {
    double total = 0;
    for (var tag in _debtTags) {
      final bal = getDebtBalance(tag);
      if (bal > 0) total += bal; // We owe them
    }
    return total;
  }

  double getTotalReceivables() {
    double total = 0;
    for (var tag in _debtTags) {
      final bal = getDebtBalance(tag);
      if (bal < 0) total += bal.abs(); // They owe us
    }
    return total;
  }

  List<Expense> getTransactionsForDebt(String tag) {
    return _expenses.where((e) => e.debtTag == tag).toList();
  }

  List<Expense> getRecentDebtTransactions({int limit = 5}) {
    return _expenses.where((e) => e.debtTag != null && !e.isPlanned).take(limit).toList();
  }

  List<String> _getDefaultCategories() {
    return ['Alimentation', 'Transport', 'Loisirs', 'Santé', 'Factures', 'Autre'];
  }

  List<String> _getDefaultIncomeCategories() {
    return [
      'Salaires',
      'Pension retraite',
      'Honoraires',
      'Bénéfices',
      'Dividendes',
      'Vente de bien',
      'Dons',
      'Héritages',
      'Autre'
    ];
  }
}
