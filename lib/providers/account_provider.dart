import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../models/account.dart';
import 'package:sqflite/sqflite.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';
import '../services/auth_service.dart';
import '../utils/api_config.dart';

class AccountProvider with ChangeNotifier {
  List<Account> _accounts = [];
  Future<void>? _loadFuture;

  List<Account> get accounts => _accounts;

  AccountProvider() {
    loadData();
  }

  Future<void> loadData() {
    _loadFuture ??= _performLoadData();
    return _loadFuture!;
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
    final updatedAccount = account.copyWith(updatedAt: DateTime.now());
    await db.insert('accounts', updatedAccount.toDbMap());
    _accounts.add(updatedAccount);
    notifyListeners();
    SyncService().push();
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
    }
  }

  double getTotalBalance() {
    return _accounts.fold(0.0, (sum, item) => sum + item.balance);
  }

  Future<void> shareAccount(String accountId, int contactId) async {
    final dio = Dio();
    dio.options.headers['Accept'] = 'application/json';
    final token = await AuthService().getToken();
    if (token != null) {
      dio.options.headers['Authorization'] = 'Bearer $token';
    }

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

  Future<List<Map<String, dynamic>>> getAccountMembers(String accountId) async {
    final dio = Dio();
    dio.options.headers['Accept'] = 'application/json';
    final token = await AuthService().getToken();
    if (token != null) {
      dio.options.headers['Authorization'] = 'Bearer $token';
    }

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
