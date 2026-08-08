import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../services/notification_service.dart';
import 'account_provider.dart';
import 'expense_provider.dart';
import 'ussd_provider.dart';
import 'history_provider.dart';
import 'profile_provider.dart';

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

  String? get userPseudo {
    if (_user == null) return null;
    final p = _user!['pseudo'] ?? _user!['user_code'] ?? _user!['username'];
    if (p != null && p.toString().trim().isNotEmpty) {
      return p.toString().trim();
    }
    return null;
  }

  bool get isProfileComplete {
    if (_user == null) return false;
    if (userPseudo == null) return false;
    if (_user!.containsKey('profile_complete')) {
      return _user!['profile_complete'] == true;
    }
    return true;
  }

  Future<void> checkAuthStatus(BuildContext context) async {
    try {
      final hasToken = await _authService.hasToken();
      if (hasToken) {
        // 1. Try to load cached user instantly
        final cachedUser = await _authService.getCachedUser();
        if (cachedUser != null) {
          _user = cachedUser;
          if (context.mounted) _updateProfile(context, cachedUser);
        } else {
          // Fallback info if cache doesn't exist yet but we have a token
          _user = {'name': 'Utilisateur', 'email': ''};
        }
        _status = AuthStatus.authenticated;
        notifyListeners();

        // 2. Refresh from server asynchronously in the background (non-blocking for startup/splash screen)
        _refreshUserAndSyncInBackground(context);
      } else {
        _status = AuthStatus.unauthenticated;
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error checking auth status: $e");
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    }
  }

  void _refreshUserAndSyncInBackground(BuildContext context) async {
    try {
      final freshUser = await _authService.getUser();
      _user = freshUser;
      await _authService.saveCachedUser(freshUser);
      if (context.mounted) _updateProfile(context, freshUser);
      notifyListeners();
      // Background pull on launch
      if (context.mounted) _backgroundSync(context);
    } on DioException catch (e) {
      // If the token is invalid (401), we MUST clear token and log out.
      // Otherwise (network timeout, offline), keep the current offline session.
      if (e.response?.statusCode == 401) {
        await logout();
      } else {
        if (context.mounted) _backgroundSync(context);
      }
    } catch (_) {
      if (context.mounted) _backgroundSync(context);
    }
  }

  Future<void> login(BuildContext context, String email, String password) async {
    final data = await _authService.login(email, password);
    _user = data['user'];
    if (_user != null) {
      await _authService.saveCachedUser(_user!);
      if (context.mounted) _updateProfile(context, _user!);
    }
    _status = AuthStatus.authenticated;
    notifyListeners();
    _backgroundSync(context);
  }

  Future<void> loginWithGoogle(
    BuildContext context, {
    required String idToken,
    String? name,
    String? type,
    int? countryId,
    String? pseudo,
  }) async {
    final data = await _authService.loginWithGoogle(
      idToken: idToken,
      name: name,
      type: type,
      countryId: countryId,
      pseudo: pseudo,
    );
    _user = data['user'];
    if (_user != null) {
      await _authService.saveCachedUser(_user!);
      if (context.mounted) _updateProfile(context, _user!);
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
    required String pseudo,
  }) async {
    final data = await _authService.register(
      name: name,
      email: email,
      password: password,
      countryId: countryId,
      type: type,
      pseudo: pseudo,
    );
    _user = data['user'];
    if (_user != null) {
      await _authService.saveCachedUser(_user!);
      if (context.mounted) _updateProfile(context, _user!);
    }
    _status = AuthStatus.authenticated;
    notifyListeners();
    _backgroundSync(context);
  }

  Future<void> forgotPassword(BuildContext context, String email) async {
    await _authService.forgotPassword(email);
  }

  Future<void> updatePseudo(String newPseudo) async {
    await _authService.updatePseudo(newPseudo);
    if (_user != null) {
      _user!['pseudo'] = newPseudo;
      _user!['user_code'] = newPseudo;
      await _authService.saveCachedUser(_user!);
      notifyListeners();
    }
  }

  Future<void> completeProfile(
    BuildContext context, {
    required String pseudo,
    required int countryId,
    required String type,
  }) async {
    final data = await _authService.completeProfile(
      pseudo: pseudo,
      countryId: countryId,
      type: type,
    );
    _user = data['user'];
    if (_user != null) {
      await _authService.saveCachedUser(_user!);
      if (context.mounted) _updateProfile(context, _user!);
    }
    notifyListeners();
  }

  Future<void> logout() async {
    await _authService.logout();
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<void> deleteAccount() async {
    await _authService.deleteAccount();
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  void _updateProfile(BuildContext context, Map<String, dynamic> userMap) {
    final profileProvider = context.read<ProfileProvider>();
    final countryMap = userMap['country'] as Map<String, dynamic>?;
    final countryName = countryMap != null ? countryMap['name'] : 'Tous';

    // Resolve currency from the backend country data or local CountriesData.
    String? currency;
    if (countryMap != null && countryMap['currency'] != null && (countryMap['currency'] as String).isNotEmpty) {
      currency = countryMap['currency'] as String;
    } else if (countryName != null && countryName != 'Tous') {
      currency = profileProvider.currencyForCountry(countryName);
    }
    
    final fullName = userMap['name'] as String? ?? 'Utilisateur';
    final parts = fullName.split(' ');
    final firstName = parts.first;
    final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

    final userType = userMap['type'] as String? ?? userMap['user_type'] as String? ?? profileProvider.profile.type;

    profileProvider.updateProfile(profileProvider.profile.copyWith(
      firstName: firstName,
      lastName: lastName,
      country: countryName,
      currency: currency,
      type: userType,
    ));
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
    NotificationService().syncFcmToken();
    final result = await _syncService.fullSync();
    if (result.success && result.pulled > 0 && context.mounted) {
      context.read<AccountProvider>().loadData();
      context.read<ExpenseProvider>().loadData();
      context.read<UssdProvider>().loadData();
      context.read<HistoryProvider>().loadHistory();
    }
  }
}
