import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/expense.dart';
import '../models/user_profile.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';
import '../utils/currency_converter.dart';
import '../services/alerts/local_alerts_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/notifications/reminder_plan.dart';
import '../services/notifications/reminder_scheduler.dart';
import '../utils/category_normalizer.dart';
import 'account_provider.dart';

class ExpenseProvider with ChangeNotifier {
  List<Expense> _expenses = [];
  List<String> _categories = [];
  List<String> _incomeCategories = [];
  List<String> _debtTags = [];
  String? _currentUserId;
  Future<void>? _loadFuture;
  Future<void>? _syncAndReloadFuture;

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
    return _loadFuture ??= _performLoadData();
  }

  Future<void> _performLoadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

    // Get current user id
    final authUser = await AuthService().getCachedUser();
    _currentUserId = authUser?['id']?.toString() ?? authUser?['uuid']?.toString();

    // Load Expenses from SQLite
    final db = await DatabaseService.instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'expenses',
      where: "sync_action != 'delete' AND sync_action != 'deleted' OR sync_action IS NULL",
    );
    _expenses = maps.map((e) {
      final exp = Expense.fromDbMap(e);
      if (_currentUserId != null &&
          exp.creatorId != null &&
          exp.creatorId.toString().trim() != _currentUserId.toString().trim() &&
          exp.debtorUserId != null &&
          exp.debtorUserId.toString().trim() == _currentUserId.toString().trim()) {
        final creatorTagName = (exp.creatorName != null && exp.creatorName!.trim().isNotEmpty)
            ? exp.creatorName!.trim()
            : exp.debtTag;
        // Inverser le titre pour refléter la perspective de l'autre utilisateur
        String invertedTitle = exp.title;
        if (exp.title == 'Emprunt') invertedTitle = 'Prêt';
        else if (exp.title == 'Prêt') invertedTitle = 'Emprunt';
        else if (exp.title == 'Remboursement perçu') invertedTitle = 'Dette remboursée';
        else if (exp.title == 'Dette remboursée') invertedTitle = 'Remboursement perçu';
        return exp.copyWith(
          title: invertedTitle,
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

    // Load Categories (pool partagé, depuis SQLite)
    await _loadCategories(db, prefs);

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

    // Aligner les rappels locaux sur l'état de la base (dépenses programmées
    // ET échéances de dettes). Non forcée : la réconciliation est anti-rebond,
    // les appels rapprochés de loadData() ne déclenchent qu'un passage. Les
    // points de synchronisation explicites (démarrage, fullSync) appellent
    // reconcileScheduledNotifications(force: true).
    reconcileScheduledNotifications();
    } finally {
      _loadFuture = null;
    }
  }



  /// Évalue les alertes locales (budget par catégorie, solde bas) après une
  /// écriture. Sans `BuildContext` ici : le service lit les données déjà en
  /// mémoire et ne fait rien si aucun budget n'est défini.
  void _evaluateLocalAlerts() {
    unawaited(LocalAlertsService.instance
        .evaluate(expenses: _expenses, accounts: const []));
  }

  /// Devise du compte imputé, lue en base plutôt que via `AccountProvider`
  /// (auquel ce provider n'a pas accès). `null` si le compte est introuvable
  /// ou sans devise : la devise du profil sert alors de repli.
  Future<String?> _accountCurrency(String? accountId,
      {DatabaseExecutor? executor}) async {
    if (accountId == null) return null;
    try {
      final db = executor ?? await DatabaseService.instance.database;
      final rows = await db.query(
        'accounts',
        columns: ['currency'],
        where: 'id = ?',
        whereArgs: [accountId],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return CurrencyConverter.normalizeCode(rows.first['currency']);
    } catch (e) {
      debugPrint('Erreur de lecture de la devise du compte: $e');
      return null;
    }
  }

  Future<void> _saveDebtTags() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('debt_tags', _debtTags);
  }


  // --- Expense Methods ---

  Future<void> addExpense(Expense expense, {DatabaseExecutor? executor}) async {
    final db = executor ?? await DatabaseService.instance.database;
    // Devise de saisie figée ici, une fois pour toutes : elle vaut celle du
    // compte imputé, sinon celle du profil. Le faire au centre couvre tous
    // les écrans de création. `updateExpense` ne la réécrit jamais — c'est ce
    // qui garde l'historique juste après un changement de pays.
    final withCurrency = expense.currency == null
        ? expense.copyWith(
            currency: CurrencyConverter.resolveForNewOperation(
              accountCurrency: await _accountCurrency(expense.accountId,
                executor: executor),
              profileCurrency: await _currentCurrency(),
            ),
          )
        : expense;
    final updatedExpense = withCurrency.createdAt != null
        ? withCurrency.copyWith(updatedAt: DateTime.now())
        : withCurrency.copyWith(
            createdAt: DateTime.now(), updatedAt: DateTime.now());
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

    // Schedule local due date reminder if dueDate is set
    final currency = await _currentCurrency();
    if (updatedExpense.dueDate != null && !updatedExpense.isPlanned) {
      NotificationService().scheduleDebtDueDateReminder(
        expenseId: updatedExpense.id,
        title: updatedExpense.title,
        amount: updatedExpense.amount,
        currency: currency,
        dueDate: updatedExpense.dueDate!,
        isDebt: updatedExpense.type == 'income',
        contactName: updatedExpense.debtTag,
      );
    }

    // Schedule the reminder for a scheduled expense (dépense programmée)
    if (updatedExpense.scheduleStatus == 'scheduled' && updatedExpense.reminderAt != null) {
      NotificationService().scheduleScheduledExpenseReminder(
        expenseId: updatedExpense.id,
        title: updatedExpense.title,
        amount: updatedExpense.amount,
        currency: currency,
        reminderAt: updatedExpense.reminderAt!,
      );
    }

    notifyListeners();
    _evaluateLocalAlerts();
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
    
    // Cancel any scheduled local reminder
    NotificationService().cancelDebtDueDateReminder(id);
    NotificationService().cancelScheduledExpenseReminder(id);

    _expenses.removeWhere((e) => e.id == id);
    notifyListeners();
    _evaluateLocalAlerts();
    SyncService().push();
  }

  /// Supprime une opération et réajuste le solde du compte associé dans la
  /// **même** transaction SQLite : soit les deux écritures passent, soit
  /// aucune. L'ouverture de la transaction est un détail interne du provider,
  /// l'UI n'a plus qu'à appeler cette méthode.
  ///
  /// Le réajustement est l'inverse du mouvement d'origine : une entrée
  /// supprimée retire son montant du solde, une dépense le restitue.
  /// Les alertes locales restent évaluées par [deleteExpense] (budgets) et par
  /// [AccountProvider.updateBalance] (solde bas).
  Future<void> deleteExpenseAndAdjustBalance(
    Expense transaction, {
    required AccountProvider accountProvider,
  }) async {
    final isIncome = transaction.type == 'income';
    await DatabaseService.instance.runTransaction((txn) async {
      if (transaction.accountId != null) {
        await accountProvider.updateBalance(
          transaction.accountId!,
          isIncome ? -transaction.amount : transaction.amount,
          executor: txn,
        );
      }
      await deleteExpense(transaction.id, executor: txn);
    });
  }

  /// Synchronisation complète puis rechargement des dépenses **et** des
  /// comptes. Utilisée par les `RefreshIndicator` des onglets Tableau de bord,
  /// Historique et Comptes : sans `BuildContext`, [SyncService] n'est plus
  /// appelé depuis un widget.
  ///
  /// Concurrence : les trois onglets partagent la même opération. Si un
  /// rafraîchissement est déjà en vol, l'appelant s'y raccroche au lieu de
  /// déclencher un second `fullSync()`. Le verrou de [SyncService] ne couvre
  /// que le push : le `pull()` et les deux rechargements qui suivent seraient
  /// sinon rejoués. Le verrou est libéré dès que l'opération se termine, y
  /// compris en erreur, pour qu'un second tirage puisse réessayer.
  Future<void> syncAndReloadAll({required AccountProvider accountProvider}) {
    return _syncAndReloadFuture ??= _performSyncAndReloadAll(accountProvider);
  }

  Future<void> _performSyncAndReloadAll(AccountProvider accountProvider) async {
    try {
      await SyncService().fullSync();
      await loadData();
      await accountProvider.loadData();
    } finally {
      _syncAndReloadFuture = null;
    }
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
    
    // Update local due date reminder
    final currency = await _currentCurrency();
    if (updatedExpense.dueDate != null && !updatedExpense.isPlanned) {
      NotificationService().scheduleDebtDueDateReminder(
        expenseId: updatedExpense.id,
        title: updatedExpense.title,
        amount: updatedExpense.amount,
        currency: currency,
        dueDate: updatedExpense.dueDate!,
        isDebt: updatedExpense.type == 'income',
        contactName: updatedExpense.debtTag,
      );
    } else {
      NotificationService().cancelDebtDueDateReminder(updatedExpense.id);
    }

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

  // --- Scheduled Expenses (dépenses programmées) ---

  /// Dépenses programmées en attente, triées par échéance croissante
  /// (la plus proche en premier).
  List<Expense> get scheduledExpenses {
    final list = _expenses.where((e) => e.scheduleStatus == 'scheduled').toList();
    list.sort((a, b) {
      final aDate = a.reminderAt ?? a.date;
      final bDate = b.reminderAt ?? b.date;
      return aDate.compareTo(bDate);
    });
    return list;
  }

  /// Nombre de dépenses programmées dont l'échéance n'est pas encore passée.
  int get upcomingScheduledExpensesCount {
    final now = DateTime.now();
    return _expenses.where((e) =>
      e.scheduleStatus == 'scheduled' && (e.reminderAt ?? e.date).isAfter(now)
    ).length;
  }

  /// Confirme une dépense programmée : la bascule en dépense réelle
  /// (isPlanned = false, isLinkedToCashFlow = true), datée du jour de la
  /// confirmation, et débite le compte lié, le tout dans une transaction.
  /// Retourne false si l'opération n'existe pas.
  Future<bool> confirmScheduledExpense(String id) async {
    await loadData();
    final expense = _expenses
        .where((e) => e.id == id && e.scheduleStatus == 'scheduled')
        .firstOrNull;
    if (expense == null) return false;

    // La date devient la date de confirmation : l'échéance programmée est
    // future, sans cela la dépense confirmée resterait invisible dans
    // l'historique et les statistiques (filtrées jusqu'à aujourd'hui).
    final confirmedExpense = expense.confirmAsRealExpense(newDate: DateTime.now());

    await DatabaseService.instance.runTransaction((txn) async {
      await updateExpense(confirmedExpense, executor: txn);
      if (confirmedExpense.accountId != null) {
        final delta = confirmedExpense.type == 'income'
            ? confirmedExpense.amount
            : -confirmedExpense.amount;
        await txn.rawUpdate(
          'UPDATE accounts SET balance = balance + ?, is_synced = 0, sync_action = \'updated\', updated_at = ? WHERE id = ?',
          [delta, DateTime.now().toIso8601String(), confirmedExpense.accountId],
        );
      }
    });

    NotificationService().cancelScheduledExpenseReminder(id);
    return true;
  }

  /// Annule une dépense programmée (suppression douce + annulation du rappel).
  Future<bool> cancelScheduledExpense(String id) async {
    await loadData();
    final exists = _expenses
        .any((e) => e.id == id && e.scheduleStatus == 'scheduled');
    if (!exists) return false;

    await deleteExpense(id);
    NotificationService().cancelScheduledExpenseReminder(id);
    return true;
  }

  /// Met à jour une dépense programmée et replanifie sa notification
  /// (uniquement si la nouvelle échéance est encore dans le futur).
  Future<void> updateScheduledExpense(Expense expense) async {
    await updateExpense(expense);

    final updated = _expenses.firstWhere(
      (e) => e.id == expense.id,
      orElse: () => expense,
    );
    NotificationService().cancelScheduledExpenseReminder(updated.id);
    if (updated.scheduleStatus == 'scheduled' && updated.reminderAt != null) {
      final currency = await _currentCurrency();
      NotificationService().scheduleScheduledExpenseReminder(
        expenseId: updated.id,
        title: updated.title,
        amount: updated.amount,
        currency: currency,
        reminderAt: updated.reminderAt!,
      );
    }
  }

  /// Réconcilie les rappels locaux avec l'état de la base (N18).
  ///
  /// Ne fait plus table rase : on décrit l'ensemble des rappels **attendus**
  /// (dépenses programmées à venir + échéances de dettes futures non soldées)
  /// et [ReminderScheduler.reconcile] applique le seul delta par rapport aux
  /// notifications déjà programmées. À appeler après un démarrage, une
  /// synchronisation ou un switch de compte ; [force] court-circuite
  /// l'anti-rebond pour ces points explicites.
  ///
  /// No-op tant que le service de notifications n'est pas initialisé : le
  /// constructeur du provider s'exécute avant NotificationService.init()
  /// (plugin + fuseau horaire), et planifier avant entraînerait des rappels
  /// perdus ou décalés. La reprise est faite par init().
  Future<void> reconcileScheduledNotifications({bool force = false}) async {
    if (!NotificationService().isInitialized) {
      return;
    }
    try {
      final currency = await _currentCurrency();
      await NotificationService().reconcileReminders(
        buildExpectedReminders(currency: currency, now: DateTime.now()),
        force: force,
      );
    } catch (e) {
      debugPrint('Error reconciling scheduled notifications: $e');
    }
  }

  /// Ensemble des rappels attendus, dérivé de l'état en mémoire.
  ///
  /// - dépenses programmées (`scheduleStatus == 'scheduled'`) dont le rappel
  ///   est encore à venir ;
  /// - échéances de dettes réelles (`dueDate` future, `!isPlanned`) dont le
  ///   solde n'est pas apuré.
  ///
  /// Le filtrage final (heures calmes, interrupteurs, échéance passée) est
  /// fait par le planificateur ; ici on ne retire que ce qui relève du métier.
  @visibleForTesting
  List<ReminderRequest> buildExpectedReminders({
    required String currency,
    required DateTime now,
  }) {
    final requests = <ReminderRequest>[];

    for (final exp in _expenses) {
      if (exp.scheduleStatus != 'scheduled') continue;
      final reminderAt = exp.reminderAt;
      if (reminderAt == null || !reminderAt.isAfter(now)) continue;
      requests.add(ReminderRequest(
        kind: ReminderKind.scheduledExpense,
        expenseId: exp.id,
        title: exp.title,
        amount: exp.amount,
        currency: currency,
        at: reminderAt,
      ));
    }

    for (final exp in _expenses) {
      final dueDate = exp.dueDate;
      if (dueDate == null || exp.isPlanned) continue;
      // Une échéance passée n'a plus de rappel à poser (le serveur prend le
      // relais via les pushs `debt_due_date_reminder`).
      if (!dueDate.isAfter(_startOfDay(now))) continue;
      if (isDebtSettled(exp.debtTag)) continue;
      requests.add(ReminderRequest(
        kind: ReminderKind.debt,
        expenseId: exp.id,
        title: exp.title,
        amount: exp.amount,
        currency: currency,
        at: dueDate,
        isDebt: exp.type == 'income',
        contactName: exp.debtTag,
      ));
    }

    return requests;
  }

  static DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Critère « dette soldée », aligné sur [getDebtBalance] (et sur le critère
  /// retenu côté serveur) : somme des opérations non planifiées partageant le
  /// même `debt_tag`, solde nul à 0,01 près.
  ///
  /// Une opération sans `debt_tag` n'est rattachée à aucun solde : on ne peut
  /// pas conclure qu'elle est soldée, son rappel est donc conservé.
  bool isDebtSettled(String? tag) {
    if (tag == null || tag.isEmpty) return false;
    return getDebtBalance(tag).abs() < 0.01;
  }

  /// Devise utilisateur lue depuis le profil local (SharedPreferences),
  /// utilisée pour formater les notifications.
  Future<String> _currentCurrency() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profileJson = prefs.getString('user_profile');
      if (profileJson != null) {
        return UserProfile.fromJson(json.decode(profileJson)).currency;
      }
    } catch (_) {}
    return 'XAF';
  }

  double getTotalExpenses(DateTime start, DateTime end) {
    return getFilteredExpenses(start, end, type: 'expense').fold(0.0, (sum, item) => sum + item.amount);
  }

  double getTotalIncomes(DateTime start, DateTime end) {
    return getFilteredExpenses(start, end, type: 'income').fold(0.0, (sum, item) => sum + item.amount);
  }

  // --- Category Methods ---

  /// Catégories partagées : pool commun à tous les utilisateurs. Une catégorie
  /// créée est insérée en SQLite (is_synced = 0) puis poussée immédiatement si
  /// l'appareil est connecté ; sinon elle reste en file et part au prochain
  /// push. Le nom est normalisé (Title case) avant tout traitement.
  Future<void> addCategory(String category, {bool isIncome = false}) async {
    final normalized = normalizeCategory(category);
    if (normalized.isEmpty) return;

    final type = isIncome ? 'income' : 'expense';
    final list = isIncome ? _incomeCategories : _categories;
    if (list.any((c) => normalizeCategory(c) == normalized)) return;

    final db = await DatabaseService.instance.database;
    await db.insert('categories', _categoryRow(Uuid().v4(), normalized, type));

    if (isIncome) {
      _incomeCategories.add(normalized);
    } else {
      _categories.add(normalized);
    }
    _sortCategoryLists();

    // La catégorie est recréée : retirer son éventuel tombstones.
    await _removeTombstone('$type|$normalized');

    notifyListeners();
    _evaluateLocalAlerts();
    SyncService().push();
  }

  /// Suppression locale uniquement : la catégorie disparaît des listes de cet
  /// utilisateur mais reste dans le pool partagé (elle ne doit pas être
  /// supprimée pour les autres). Le tombstones empêche le pull de la
  /// réinsérer localement.
  Future<void> deleteCategory(String category, {bool isIncome = false}) async {
    if (category == 'Autre') return;
    final type = isIncome ? 'income' : 'expense';

    final db = await DatabaseService.instance.database;
    await db.delete('categories',
        where: 'name = ? AND type = ?', whereArgs: [category, type]);
    await _addTombstone('$type|$category');

    if (isIncome) {
      _incomeCategories.remove(category);
    } else {
      _categories.remove(category);
    }
    notifyListeners();
  }

  Future<void> updateCategory(String oldCategory, String newCategory,
      {bool isIncome = false}) async {
    final newName = normalizeCategory(newCategory);
    if (newName.isEmpty || oldCategory == 'Autre' || newName == oldCategory) {
      return;
    }

    if (isIncome) {
      final index = _incomeCategories.indexOf(oldCategory);
      if (index == -1) return;
      if (_incomeCategories
          .any((c) => c != oldCategory && normalizeCategory(c) == newName)) {
        return;
      }
      _incomeCategories[index] = newName;
    } else {
      final index = _categories.indexOf(oldCategory);
      if (index == -1) return;
      if (_categories
          .any((c) => c != oldCategory && normalizeCategory(c) == newName)) {
        return;
      }
      _categories[index] = newName;
    }

    // Renommer les dépenses concernées (localement, puis synchro)
    final db = await DatabaseService.instance.database;
    for (int i = 0; i < _expenses.length; i++) {
      final matches = isIncome
          ? _expenses[i].type == 'income'
          : _expenses[i].type == 'expense';
      if (matches && _expenses[i].category == oldCategory) {
        final updatedExpense =
            _expenses[i].copyWith(category: newName, updatedAt: DateTime.now());
        _expenses[i] = updatedExpense;
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

    // L'ancien nom est retiré localement (tombstones) ; le nouveau est créé
    // dans le pool partagé.
    final type = isIncome ? 'income' : 'expense';
    await db.delete('categories',
        where: 'name = ? AND type = ?', whereArgs: [oldCategory, type]);
    await _addTombstone('$type|$oldCategory');
    await db.insert('categories', _categoryRow(Uuid().v4(), newName, type));

    _sortCategoryLists();
    notifyListeners();
    _evaluateLocalAlerts();
    SyncService().push();
  }

  // --- Category internals (SQLite) ---

  static const String _kTombstoneKey = 'deleted_category_keys';

  /// Charge les catégories depuis SQLite. À la première ouverture, migre les
  /// anciennes listes personnalisées (SharedPreferences) vers la base — en
  /// non synchronisées, pour qu'elles rejoignent le pool partagé — sinon
  /// insère les catégories par défaut (déjà présentes côté serveur).
  Future<void> _loadCategories(Database db, SharedPreferences prefs) async {
    final tombstones =
        (prefs.getStringList(_kTombstoneKey) ?? const []).toSet();
    final legacyExpense = prefs.getStringList('expense_categories');
    final legacyIncome = prefs.getStringList('income_categories');

    var rows = await db.query('categories');
    if (rows.isEmpty) {
      final batch = db.batch();
      if (legacyExpense != null || legacyIncome != null) {
        for (final name in legacyExpense ?? const <String>[]) {
          batch.insert(
              'categories', _categoryRow(Uuid().v4(), name, 'expense'));
        }
        for (final name in legacyIncome ?? const <String>[]) {
          batch.insert(
              'categories', _categoryRow(Uuid().v4(), name, 'income'));
        }
      } else {
        for (final name in _getDefaultCategories()) {
          batch.insert('categories',
              _categoryRow(Uuid().v4(), name, 'expense', synced: true));
        }
        for (final name in _getDefaultIncomeCategories()) {
          batch.insert('categories',
              _categoryRow(Uuid().v4(), name, 'income', synced: true));
        }
      }
      await batch.commit(noResult: true);
      await prefs.remove('expense_categories');
      await prefs.remove('income_categories');
      rows = await db.query('categories');
    }

    _categories = _loadCategoryNames(rows, 'expense', tombstones);
    _incomeCategories = _loadCategoryNames(rows, 'income', tombstones);
    _sortCategoryLists();
  }

  List<String> _loadCategoryNames(
      List<Map<String, dynamic>> rows, String type, Set<String> tombstones) {
    return rows
        .where((r) => r['type'] == type && r['name'] is String)
        .map((r) => r['name'] as String)
        .where((name) => !tombstones.contains('$type|$name'))
        .toList();
  }

  Map<String, dynamic> _categoryRow(String id, String name, String type,
      {bool synced = false}) {
    return {
      'id': id,
      'name': normalizeCategory(name),
      'type': type,
      'is_synced': synced ? 1 : 0,
      'sync_action': synced ? 'updated' : 'created',
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  void _sortCategoryLists() {
    _categories
        .sort((a, b) => categorySortKey(a).compareTo(categorySortKey(b)));
    _incomeCategories
        .sort((a, b) => categorySortKey(a).compareTo(categorySortKey(b)));
  }

  Future<void> _addTombstone(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final tombstones = prefs.getStringList(_kTombstoneKey) ?? [];
    if (!tombstones.contains(key)) {
      tombstones.add(key);
      await prefs.setStringList(_kTombstoneKey, tombstones);
    }
  }

  Future<void> _removeTombstone(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final tombstones = prefs.getStringList(_kTombstoneKey) ?? [];
    if (tombstones.remove(key)) {
      await prefs.setStringList(_kTombstoneKey, tombstones);
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
    await db.update(
      'expenses',
      {
        'sync_action': 'delete',
        'is_synced': 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'debtTag = ?',
      whereArgs: [tag],
    );
    
    _debtTags.remove(tag);
    _expenses.removeWhere((e) => e.debtTag == tag);
    await _saveDebtTags();
    notifyListeners();
    _evaluateLocalAlerts();
    SyncService().push();
  }

  double getDebtBalance(String tag) {
    return _expenses.where((e) => e.debtTag == tag && !e.isPlanned).fold(0.0, (sum, e) => sum + (e.type == 'expense' ? e.amount : -e.amount));
  }

  double getTotalDebts() {
    double total = 0;
    for (var tag in _debtTags) {
      final bal = getDebtBalance(tag);
      if (bal < 0) total += bal.abs(); // We owe them (negative balance = Debt)
    }
    return total;
  }

  double getTotalReceivables() {
    double total = 0;
    for (var tag in _debtTags) {
      final bal = getDebtBalance(tag);
      if (bal > 0) total += bal; // They owe us (positive balance = Créance)
    }
    return total;
  }

  List<Expense> getTransactionsForDebt(String tag) {
    return _expenses.where((e) => e.debtTag == tag).toList();
  }

  List<Expense> getRecentDebtTransactions({int limit = 5}) {
    return _expenses.where((e) => e.debtTag != null && !e.isPlanned).take(limit).toList();
  }

  /// Vide l'état en mémoire (déconnexion) : la base locale et les préférences
  /// par utilisateur sont purgées par ailleurs, on revient aux valeurs par
  /// défaut pour ne rien afficher de l'ancien compte.
  void clear() {
    _expenses = [];
    _debtTags = [];
    _currentUserId = null;
    _categories = _getDefaultCategories();
    _incomeCategories = _getDefaultIncomeCategories();
    notifyListeners();
  }

  List<String> _getDefaultCategories() {
    return ['Alimentation', 'Transport', 'Loisirs', 'Santé', 'Factures', 'Autre'];
  }

  List<String> _getDefaultIncomeCategories() {
    return [
      'Salaires',
      'Pension Retraite',
      'Honoraires',
      'Bénéfices',
      'Dividendes',
      'Vente De Bien',
      'Dons',
      'Héritages',
      'Autre'
    ];
  }
}
