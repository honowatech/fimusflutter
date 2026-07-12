import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import 'account_provider.dart';
import 'expense_provider.dart';
import 'ussd_provider.dart';
import 'history_provider.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final SyncService _syncService = SyncService();

  AuthStatus _status = AuthStatus.unknown;
  Map<String, dynamic>? _user;
  bool _isSyncing = false;

  AuthStatus get status => _status;
  Map<String, dynamic>? get user => _user;
  bool get isSyncing => _isSyncing;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  /// Called on app startup to restore session.
  Future<void> checkAuthStatus(BuildContext context) async {
    final hasToken = await _authService.hasToken();
    if (hasToken) {
      // 1. Try to load cached user instantly
      final cachedUser = await _authService.getCachedUser();
      if (cachedUser != null) {
        _user = cachedUser;
      } else {
        // Fallback info if cache doesn't exist yet but we have a token
        _user = {'name': 'Utilisateur', 'email': ''};
      }
      _status = AuthStatus.authenticated;
      notifyListeners();

      // 2. Refresh from server in the background
      try {
        final freshUser = await _authService.getUser();
        _user = freshUser;
        await _authService.saveCachedUser(freshUser);
        notifyListeners();
        // Background pull on launch
        _backgroundSync(context);
      } on DioException catch (e) {
        // If the token is invalid (401), we MUST clear token and log out.
        // Otherwise (network timeout, offline), keep the current offline session.
        if (e.response?.statusCode == 401) {
          await logout();
        } else {
          _backgroundSync(context);
        }
      } catch (_) {
        _backgroundSync(context);
      }
    } else {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    }
  }

  Future<void> login(BuildContext context, String email, String password) async {
    final data = await _authService.login(email, password);
    _user = data['user'];
    if (_user != null) {
      await _authService.saveCachedUser(_user!);
    }
    _status = AuthStatus.authenticated;
    notifyListeners();
    _backgroundSync(context);
  }

  Future<void> register(
    BuildContext context, {
    required String name,
    required String email,
    required String password,
    required int countryId,
    required String type,
  }) async {
    final data = await _authService.register(
      name: name,
      email: email,
      password: password,
      countryId: countryId,
      type: type,
    );
    _user = data['user'];
    if (_user != null) {
      await _authService.saveCachedUser(_user!);
    }
    _status = AuthStatus.authenticated;
    notifyListeners();
    _backgroundSync(context);
  }

  Future<void> logout() async {
    await _authService.logout();
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<SyncResult> syncNow(BuildContext context) async {
    _isSyncing = true;
    notifyListeners();
    try {
      final result = await _syncService.fullSync();
      if (result.success && context.mounted) {
        context.read<AccountProvider>().loadData();
        context.read<ExpenseProvider>().loadData();
        context.read<UssdProvider>().loadData();
        context.read<HistoryProvider>().loadHistory();
      }
      return result;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  void _backgroundSync(BuildContext context) async {
    final result = await _syncService.fullSync();
    if (result.success && result.pulled > 0 && context.mounted) {
      context.read<AccountProvider>().loadData();
      context.read<ExpenseProvider>().loadData();
      context.read<UssdProvider>().loadData();
      context.read<HistoryProvider>().loadHistory();
    }
  }
}
