import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/account.dart';
import 'package:sqflite/sqflite.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';
import '../utils/currency_converter.dart';
import '../models/user_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/alerts/local_alerts_service.dart';
import '../utils/api_client.dart';
import '../utils/api_config.dart';

class AccountProvider with ChangeNotifier {
  List<Account> _accounts = [];
  Future<void>? _loadFuture;

  List<Account> get accounts => _accounts;

  AccountProvider() {
    loadData();
  }

  Future<void> loadData() {
    return _loadFuture ??= _performLoadData();
  }

  Future<void> _performLoadData() async {
    try {
      final db = await DatabaseService.instance.database;
      final List<Map<String, dynamic>> maps = await db.query('accounts');
      
      _accounts = maps.map((e) => Account.fromDbMap(e)).toList();
      notifyListeners();
    } finally {
      _loadFuture = null;
    }
  }

  Future<void> addAccount(Account account, {DatabaseExecutor? executor}) async {
    final db = executor ?? await DatabaseService.instance.database;
    // Devise du compte figée à la création (devise du profil), jamais
    // réécrite ensuite : un changement de pays ne doit pas réinterpréter un
    // solde existant.
    final withCurrency = account.currency == null
        ? account.copyWith(currency: await _profileCurrency())
        : account;
    final updatedAccount = withCurrency.copyWith(updatedAt: DateTime.now());
    await db.insert('accounts', updatedAccount.toDbMap());
    _accounts.add(updatedAccount);
    notifyListeners();
    SyncService().push();
  }

  /// Devise du profil lue localement (SharedPreferences), comme le fait déjà
  /// `ExpenseProvider` : ce provider n'a pas accès à `ProfileProvider`.
  Future<String?> _profileCurrency() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profileJson = prefs.getString('user_profile');
      if (profileJson == null) return null;
      return CurrencyConverter.normalizeCode(
          UserProfile.fromJson(json.decode(profileJson)).currency);
    } catch (e) {
      debugPrint('Erreur de lecture de la devise du profil: $e');
      return null;
    }
  }

  Future<void> updateAccount(Account account, {DatabaseExecutor? executor}) async {
    final db = executor ?? await DatabaseService.instance.database;
    final updatedAccount = account.copyWith(updatedAt: DateTime.now());
    await db.update(
      'accounts',
      {
        ...updatedAccount.toDbMap(),
        'is_synced': 0,
        'sync_action': 'updated',
        'updated_at': updatedAccount.updatedAt!.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [updatedAccount.id],
    );
    
    final index = _accounts.indexWhere((a) => a.id == updatedAccount.id);
    if (index != -1) {
      _accounts[index] = updatedAccount;
      notifyListeners();
    }
    SyncService().push();
  }

  Future<void> deleteAccount(String id, {DatabaseExecutor? executor}) async {
    final db = executor ?? await DatabaseService.instance.database;
    await db.update(
      'accounts',
      {
        'sync_action': 'delete',
        'is_synced': 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    
    _accounts.removeWhere((a) => a.id == id);
    notifyListeners();
    SyncService().push();
  }

  Future<void> updateBalance(String accountId, double amountDelta, {DatabaseExecutor? executor}) async {
    final index = _accounts.indexWhere((a) => a.id == accountId);
    if (index != -1) {
      final account = _accounts[index];
      final updatedAccount = account.copyWith(balance: account.balance + amountDelta);
      await updateAccount(updatedAccount, executor: executor);
      // Alerte « solde bas » : évaluée ici plutôt que dans l'écran appelant,
      // pour couvrir aussi les mouvements déclenchés par une confirmation de
      // dépense programmée ou par une synchronisation.
      unawaited(LocalAlertsService.instance
          .evaluate(expenses: const [], accounts: _accounts));
    }
  }

  double getTotalBalance() {
    return _accounts.fold(0.0, (sum, item) => sum + item.balance);
  }

  /// Vide l'état en mémoire (déconnexion) : la base locale est purgée par
  /// ailleurs, l'UI ne doit plus afficher les données de l'ancien compte.
  void clear() {
    _accounts = [];
    notifyListeners();
  }

  Future<void> shareAccount(String accountId, int contactId) async {
    final dio = ApiClient.instance;

    try {
      final response = await dio.post(
        '${ApiConfig.baseUrl}/accounts/$accountId/share',
        data: {'contact_id': contactId},
      );

      if (response.statusCode == 200) {
        // Update account locally
        final index = _accounts.indexWhere((a) => a.id == accountId);
        if (index != -1) {
          final updatedAccount = _accounts[index].copyWith(isShared: true);
          await updateAccount(updatedAccount);
        }
      }
    } catch (e) {
      throw Exception('Erreur lors du partage du compte : $e');
    }
  }

  Future<void> shareAccountWithMultiple(String accountId, List<int> contactIds) async {
    if (contactIds.isEmpty) return;
    
    final dio = ApiClient.instance;

    int successCount = 0;
    List<String> errors = [];

    for (final contactId in contactIds) {
      try {
        final response = await dio.post(
          '${ApiConfig.baseUrl}/accounts/$accountId/share',
          data: {'contact_id': contactId},
        );
        if (response.statusCode == 200) {
          successCount++;
        }
      } catch (e) {
        debugPrint('Erreur partage contact $contactId: $e');
        errors.add(e.toString());
      }
    }

    if (successCount > 0) {
      final index = _accounts.indexWhere((a) => a.id == accountId);
      if (index != -1) {
        final updatedAccount = _accounts[index].copyWith(isShared: true);
        await updateAccount(updatedAccount);
      }
    }

    if (successCount == 0 && errors.isNotEmpty) {
      throw Exception(errors.first);
    }
  }

  Future<List<Map<String, dynamic>>> getAccountMembers(String accountId) async {
    final dio = ApiClient.instance;

    try {
      final response = await dio.get('${ApiConfig.baseUrl}/accounts/$accountId/members');
      if (response.statusCode == 200) {
        final data = response.data;
        return List<Map<String, dynamic>>.from(data['members'] ?? []);
      }
      return [];
    } catch (e) {
      debugPrint('Erreur lors de la récupération des membres : $e');
      return [];
    }
  }
}
