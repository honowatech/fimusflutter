import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'alert_settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../services/notification_service.dart';
import '../services/database_service.dart';
import 'account_provider.dart';
import 'expense_provider.dart';
import 'ussd_provider.dart';
import 'history_provider.dart';
import 'profile_provider.dart';
import 'contact_provider.dart';
import 'notification_provider.dart';
import 'security_provider.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final SyncService _syncService = SyncService();

  AuthStatus _status = AuthStatus.unknown;
  Map<String, dynamic>? _user;
  bool _isSyncing = false;
  int _maxAccountsPerDevice = 2;
  List<Map<String, dynamic>> _sessions = [];

  AuthStatus get status => _status;
  Map<String, dynamic>? get user => _user;
  bool get isSyncing => _isSyncing;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  /// Comptes enregistrés sur cet appareil (multicompte).
  List<Map<String, dynamic>> get sessions => _sessions;

  /// Limite multicompte configurée dans le backoffice (défaut 2).
  int get maxAccountsPerDevice => _maxAccountsPerDevice;

  /// Vrai s'il reste un emplacement pour connecter un compte supplémentaire.
  bool get canAddAccount => _sessions.length < _maxAccountsPerDevice;

  /// Vrai si la session courante est le compte de test local (mode test).
  bool get _isLocalTestAccount =>
      _user != null && AuthService.isTestAccount(_user!);

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
          // Base propre au compte actif (isolation multicompte). Au premier
          // démarrage après mise à jour, l'ancienne base partagée est copiée
          // puis les providers sont rechargés depuis la base du compte.
          final switchedDb = await _switchToActiveUserDatabase();
          if (context.mounted) _updateProfile(context, cachedUser);
          if (switchedDb && context.mounted) _reloadAppData(context);
        } else {
          // Fallback info if cache doesn't exist yet but we have a token
          _user = {'name': 'Utilisateur', 'email': ''};
        }
        _status = AuthStatus.authenticated;
        await _loadSessions();
        notifyListeners();

        // 2. Refresh from server asynchronously in the background (non-blocking for startup/splash screen)
        _refreshUserAndSyncInBackground(context);
      } else {
        _status = AuthStatus.unauthenticated;
        await _loadSessions();
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error checking auth status: $e");
      _status = AuthStatus.unauthenticated;
      await _loadSessions();
      notifyListeners();
    }
  }

  void _refreshUserAndSyncInBackground(BuildContext context) async {
    // Compte de test local : pas de rafraîchissement serveur (aucune BD),
    // la session est gérée uniquement via le stockage local.
    if (_isLocalTestAccount) return;
    try {
      final freshUser = await _authService.getUser();
      _user = freshUser;
      await _authService.saveCachedUser(freshUser);
      if (context.mounted) _updateProfile(context, freshUser);
      notifyListeners();
      // Background pull on launch
      if (context.mounted) _backgroundSync(context);
    } on DioException catch (e) {
      // If the token is invalid (401), la session est morte : on la retire
      // et on bascule vers un éventuel autre compte SANS purger ses données
      // locales (elles seront réutilisées à sa reconnexion).
      // Otherwise (network timeout, offline), keep the current offline session.
      if (e.response?.statusCode == 401) {
        await handleInvalidSession(context);
      } else {
        if (context.mounted) _backgroundSync(context);
      }
    } catch (_) {
      if (context.mounted) _backgroundSync(context);
    }
  }

  Future<void> login(BuildContext context, String email, String password) async {
    final deviceId = await _authService.getDeviceId();
    // Sauvegarde des données locales de l'éventuel compte actif avant la
    // bascule (le push utilise encore son token).
    await _pushCurrentAccountData();
    final data = await _authService.login(email, password, deviceId: deviceId);
    await _activateNewSession(context, data);
  }

  Future<void> loginWithGoogle(
    BuildContext context, {
    required String idToken,
    String? name,
    String? type,
    int? countryId,
    String? pseudo,
  }) async {
    final deviceId = await _authService.getDeviceId();
    await _pushCurrentAccountData();
    final data = await _authService.loginWithGoogle(
      idToken: idToken,
      name: name,
      type: type,
      countryId: countryId,
      pseudo: pseudo,
      deviceId: deviceId,
    );
    await _activateNewSession(context, data);
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
    final deviceId = await _authService.getDeviceId();
    await _pushCurrentAccountData();
    final data = await _authService.register(
      name: name,
      email: email,
      password: password,
      countryId: countryId,
      type: type,
      pseudo: pseudo,
      deviceId: deviceId,
    );
    await _activateNewSession(context, data);
  }

  /// Enregistre la session du compte fraîchement authentifié (ajout ou
  /// re-connexion), bascule sur sa base dédiée et synchronise.
  Future<void> _activateNewSession(
      BuildContext context, Map<String, dynamic> data) async {
    final user = data['user'];
    _user = user is Map ? Map<String, dynamic>.from(user) : null;
    if (_user != null) {
      await _authService.addOrUpdateSession(
          _user!, data['access_token'] as String?);
      final userId = AuthService.userIdOf(_user!);
      if (userId != null) {
        await _switchToUserDatabase(userId);
      }
      if (context.mounted) _updateProfile(context, _user!);
    }
    _status = AuthStatus.authenticated;
    await _loadSessions();
    notifyListeners();
    if (context.mounted) _reloadAppData(context);
    _backgroundSync(context);
  }

  /// Bascule vers un compte déjà connecté sur cet appareil, sans mot de
  /// passe. Retourne false si aucune session n'existe pour ce compte.
  Future<bool> switchAccount(BuildContext context, String userId) async {
    final current = await _authService.getActiveUserId();
    if (userId == current) return true;

    await _pushCurrentAccountData();
    final switched = await _authService.switchAccount(userId);
    if (!switched) return false;

    _user = await _authService.getCachedUser();
    await _switchToUserDatabase(userId);
    if (_user != null && context.mounted) _updateProfile(context, _user!);
    _status = AuthStatus.authenticated;
    await _loadSessions();
    notifyListeners();
    if (context.mounted) _reloadAppData(context);
    _refreshUserAndSyncInBackground(context);
    return true;
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
      await _loadSessions();
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

  /// Déconnexion du compte actif : push final, déconnexion serveur (le slot
  /// multicompte de l'appareil est libéré), purge de SA base locale, puis
  /// bascule vers le compte restant le plus récent — ou retour au login.
  Future<void> logout({BuildContext? context}) async {
    // Dernier push pour ne pas perdre les modifications non synchronisées
    // du compte déconnecté (silencieux si hors ligne).
    await _pushCurrentAccountData();
    await _authService.logoutServer();

    // Purge de la base du compte — avant toute bascule, la base active est
    // encore la sienne.
    final loggedOutUserId = await _authService.getActiveUserId();
    try {
      await DatabaseService.instance.clearAllData();
    } catch (e) {
      debugPrint("Purge DB error: $e");
    }

    if (loggedOutUserId != null) {
      await _authService.removeSession(loggedOutUserId);
    }
    await _afterAccountLeft(context);
  }

  Future<void> deleteAccount({BuildContext? context}) async {
    final deletedUserId = await _authService.getActiveUserId();
    // Suppression serveur (les tokens et slots multicompte sont casscadés)
    // + retrait de la session locale.
    await _authService.deleteAccount();

    // Les données locales du compte supprimé ne doivent plus exister.
    try {
      await DatabaseService.instance.clearAllData();
    } catch (e) {
      debugPrint("Purge DB error: $e");
    }

    if (deletedUserId != null && await _authService.getActiveUserId() == null) {
      final sessions = await _authService.listSessions();
      if (sessions.isNotEmpty) {
        final next = AuthService.userIdOf(sessions.last);
        if (next != null) await _authService.switchAccount(next);
      }
    }
    await _afterAccountLeft(context);
  }

  /// Session invalide (401) : retire la session morte et bascule vers un
  /// éventuel compte restant SANS purge — les données locales du compte
  /// restent dans sa base dédiée et seront réutilisées à sa reconnexion.
  Future<void> handleInvalidSession(BuildContext? context) async {
    await _authService.removeActiveSession();
    if (await _authService.getActiveUserId() == null) {
      final sessions = await _authService.listSessions();
      if (sessions.isNotEmpty) {
        final next = AuthService.userIdOf(sessions.last);
        if (next != null) await _authService.switchAccount(next);
      }
    }
    await _afterAccountLeft(context, purgeLocalState: false);
  }

  /// Après le départ d'un compte (logout, suppression, session invalide) :
  /// bascule vers le compte restant le plus récent, ou nettoie l'état local
  /// et retourne à l'écran de connexion.
  Future<void> _afterAccountLeft(BuildContext? context,
      {bool purgeLocalState = true}) async {
    // Les budgets, seuils de solde et l'état anti-spam des alertes locales
    // sont propres à un compte : sans cette purge, ils s'appliqueraient au
    // compte suivant sur le même appareil.
    if (context != null && context.mounted) {
      unawaited(context.read<AlertSettingsProvider>().clear());
    }
    final nextUserId = await _authService.getActiveUserId();
    if (nextUserId != null) {
      _user = await _authService.getCachedUser();
      await _switchToUserDatabase(nextUserId);
      if (_user != null && context != null && context.mounted) {
        _updateProfile(context, _user!);
      }
      _status = AuthStatus.authenticated;
      await _loadSessions();
      notifyListeners();
      if (context != null && context.mounted) _reloadAppData(context);
      if (context != null && context.mounted) {
        _refreshUserAndSyncInBackground(context);
      }
    } else {
      if (purgeLocalState) {
        await _purgeLocalData(context, purgeDatabase: false);
      }
      _user = null;
      _status = AuthStatus.unauthenticated;
      await _loadSessions();
      notifyListeners();
    }
  }

  /// Rafraîchit la limite multicompte depuis le backoffice (défaut 2 hors
  /// ligne). À appeler avant d'afficher l'UI « Ajouter un compte ».
  Future<void> refreshAppSettings() async {
    final max = await _authService.fetchMaxAccountsPerDevice();
    if (max != _maxAccountsPerDevice) {
      _maxAccountsPerDevice = max;
      notifyListeners();
    }
  }

  /// Avant d'activer un autre compte : pousse les modifications locales non
  /// synchronisées du compte courant (silencieux si hors ligne / test local).
  Future<void> _pushCurrentAccountData() async {
    if (_user == null) return;
    if (AuthService.isTestAccount(_user!)) return;
    if (await _authService.getActiveUserId() == null) return;
    try {
      await _syncService.push();
    } catch (_) {}
  }

  Future<bool> _switchToActiveUserDatabase() async {
    final userId = await _authService.getActiveUserId();
    if (userId == null) return false;
    return _switchToUserDatabase(userId);
  }

  /// Bascule vers la base du compte donné, avec héritage éventuel de
  /// l'ancienne base partagée si ce compte en est le propriétaire.
  Future<bool> _switchToUserDatabase(String userId) async {
    return DatabaseService.instance.switchToUserDatabase(
      userId,
      legacyDbOwner: await _authService.getLegacyDbOwner(),
    );
  }

  Future<void> _loadSessions() async {
    _sessions = await _authService.listSessions();
  }

  /// Recharge les providers depuis la base du compte actif (après une
  /// bascule de compte ou de base).
  void _reloadAppData(BuildContext context) {
    context.read<AccountProvider>().loadData();
    context.read<ExpenseProvider>().loadData();
    context.read<UssdProvider>().loadData();
    context.read<HistoryProvider>().loadHistory();
    context.read<ContactProvider>().fetchContacts();
    context.read<NotificationProvider>().fetch();
  }

  /// Purge les données locales du compte (préférences par utilisateur, état
  /// en mémoire des providers, verrou PIN). La base SQLite est purgée par
  /// l'appelant ([logout] / [deleteAccount]) pendant qu'elle est encore la
  /// base du compte concerné.
  Future<void> _purgeLocalData(BuildContext? context,
      {bool purgeDatabase = true}) async {
    if (purgeDatabase) {
      try {
        await DatabaseService.instance.clearAllData();
      } catch (e) {
        debugPrint("Purge DB error: $e");
      }
    }

    // Clés par utilisateur du stockage local (catégories et tags de dette
    // personnalisés). Le catalogue USSD de référence (cached_reference_ussd)
    // est générique, sans donnée personnelle : il est conservé.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_profile');
      await prefs.remove('expense_categories');
      await prefs.remove('income_categories');
      await prefs.remove('debt_tags');
      await prefs.remove('ussd_categories');
      await prefs.remove('deleted_category_keys');
    } catch (_) {}

    // Réinitialisation de l'état en mémoire des providers, sinon les écrans
    // continuent d'afficher les données de l'ancien compte jusqu'au prochain
    // loadData.
    if (context != null && context.mounted) {
      context.read<AccountProvider>().clear();
      context.read<ExpenseProvider>().clear();
      context.read<UssdProvider>().clear();
      context.read<HistoryProvider>().clear();
      context.read<ContactProvider>().clear();
      context.read<NotificationProvider>().clear();
      await context.read<ProfileProvider>().reset();
      await context.read<SecurityProvider>().resetAppLock();
    }
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
    if (_isLocalTestAccount) return;
    NotificationService().syncFcmToken();
    await refreshAppSettings();
    final result = await _syncService.fullSync();
    if (result.success && result.pulled > 0 && context.mounted) {
      context.read<AccountProvider>().loadData();
      context.read<ExpenseProvider>().loadData();
      context.read<UssdProvider>().loadData();
      context.read<HistoryProvider>().loadHistory();
    }
  }
}
