import 'dart:convert';
// `Platform` sert uniquement à décrire l'appareil au login (`device_model`).
// Tous les accès sont gardés par `kIsWeb`, la plateforme web n'ayant pas
// `dart:io`.
import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../config/test_account.dart';
import '../utils/api_client.dart';
import '../utils/api_config.dart';

/// Gère l'authentification et les sessions multicomptes.
///
/// Plusieurs comptes peuvent rester connectés sur le même appareil : chaque
/// session est un couple (utilisateur, token) ; une seule est « active » à la
/// fois. Les méthodes historiques [getToken], [getCachedUser], [saveCachedUser]
/// et [hasToken] opèrent sur la session active, de sorte que SyncService,
/// NotificationService et les intercepteurs Dio fonctionnent sans changer.
///
/// Sécurité : les tokens ne sont écrits QUE dans [FlutterSecureStorage]
/// (Keystore / Keychain). Les SharedPreferences ne contiennent plus que des
/// données non sensibles (cartes utilisateur, identifiant du compte actif).
class AuthService {
  Dio get _dio => ApiClient.instance;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  String get _tokenKey => ApiConfig.env.scoped('auth_token');
  String get _userKey => ApiConfig.env.scoped('cached_user');
  String get _sessionsKey => ApiConfig.env.scoped('auth_sessions');
  String get _activeUserIdKey => ApiConfig.env.scoped('auth_active_user_id');
  static const String _deviceIdKey = 'device_id';

  /// Garde-fou anti-récursion pour la migration mono-session → multicompte.
  bool _legacyMigrated = false;

  /// Repli mémoire (durée de vie du processus) utilisé uniquement quand le
  /// stockage sécurisé est indisponible : Keystore/Keychain en erreur,
  /// plateforme sans implémentation du plugin (tests unitaires, web). La
  /// session reste utilisable jusqu'à la fermeture de l'application, mais
  /// aucun token n'est jamais écrit en clair sur le disque.
  static final Map<String, String> _memoryTokens = {};

  // Compte de test local : actif uniquement en debug ET si le mot de passe a
  // été fourni au lancement (`--dart-define=FIMUS_TEST_PASSWORD=...`).
  // Aucun identifiant n'est embarqué dans le binaire de production
  // (cf. lib/config/test_account.dart).
  static String get testAccountEmail => TestAccount.email;
  static String get testAccountPseudo => TestAccount.pseudo;

  static bool isTestAccount(Map<String, dynamic> user) => TestAccount.isUser(user);

  AuthService();

  // ---------------------------------------------------------------------------
  // MULTICOMPTE — appareil, sessions, comptes
  // ---------------------------------------------------------------------------

  /// Identité stable d'un utilisateur (uuid, sinon id numérique).
  static String? userIdOf(Map<String, dynamic> user) {
    final uuid = user['uuid']?.toString().trim();
    if (uuid != null && uuid.isNotEmpty) return uuid;
    final id = user['id']?.toString().trim();
    if (id != null && id.isNotEmpty) return id;
    return null;
  }

  String _sessionTokenKey(String userId) => '${_tokenKey}_$userId';

  /// Identifiant anonyme de l'appareil, envoyé au serveur pour la limite
  /// multicompte (`max_accounts_per_device`). Généré une seule fois ;
  /// régénéré seulement si l'application est réinstallée.
  Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final id = const Uuid().v4();
    await prefs.setString(_deviceIdKey, id);
    return id;
  }

  /// Plateforme de l'appareil (`android`, `ios`, `web`…), envoyée au login et
  /// avec le jeton FCM. Le backend s'en sert comme repli quand
  /// [deviceModel] est absent (`UserKnownDevice::label()`).
  static String get devicePlatform =>
      kIsWeb ? 'web' : defaultTargetPlatform.name;

  /// Description lisible de l'appareil, envoyée au login sous la clé
  /// `device_model` pour que l'alerte « nouvelle connexion » nomme l'appareil
  /// au lieu d'annoncer « un nouvel appareil ».
  ///
  /// Limite assumée : `device_info_plus` n'est pas une dépendance du projet
  /// (et `pubspec.yaml` est hors périmètre de ce sprint), donc le vrai modèle
  /// commercial (« Pixel 7 ») n'est pas accessible. On envoie ce que
  /// `dart:io` sait dire — par ex. « Android 13 (SDK 33) » ou
  /// « Version 17.4 (Build 21E219) » — ce qui reste bien plus parlant qu'un
  /// libellé neutre. À remplacer par `DeviceInfoPlugin().androidInfo.model`
  /// dès que la dépendance sera ajoutée.
  static String? get deviceModel {
    if (kIsWeb) return null;
    try {
      final version = Platform.operatingSystemVersion.trim();
      final os = Platform.operatingSystem.trim();
      if (version.isEmpty) return os.isEmpty ? null : os;
      // `operatingSystemVersion` commence déjà par « Android … » sur Android,
      // mais pas sur iOS : on préfixe uniquement quand c'est nécessaire.
      if (version.toLowerCase().contains(os.toLowerCase())) return version;
      return '$os $version';
    } catch (_) {
      // Plateforme sans implémentation (tests unitaires) : on n'envoie rien,
      // le serveur se rabat sur `platform`.
      return null;
    }
  }

  /// Champs d'identification de l'appareil communs aux trois points d'entrée
  /// d'authentification (login, register, Google). Extraits ici pour qu'un
  /// seul endroit décide de ce qui part au serveur.
  static Map<String, dynamic> deviceFields(String? deviceId) {
    final model = deviceModel;
    return {
      if (deviceId != null && deviceId.isNotEmpty) 'device_id': deviceId,
      'platform': devicePlatform,
      if (model != null && model.isNotEmpty) 'device_model': model,
    };
  }

  /// Action « Ce n'était pas moi » de l'alerte `new_login`.
  ///
  /// Coupe côté serveur toutes les sessions et tous les jetons FCM **sauf**
  /// ceux de cet appareil : d'où l'envoi systématique de [getDeviceId] — sans
  /// lui le serveur supprime aussi nos propres jetons (cf.
  /// `SecurityController::revokeOtherSessions`).
  ///
  /// [endpoint] vient du payload (`action_endpoint`) : le chemin n'est pas
  /// figé dans l'application. Renvoie `null` si l'appel a échoué.
  Future<RevokeOtherSessionsResult?> revokeOtherSessions({
    String? endpoint,
  }) async {
    try {
      final response = await _dio.post(
        _resolveApiUrl(endpoint, '/security/revoke-other-sessions'),
        data: {'device_id': await getDeviceId()},
      );
      final data = response.data;
      if (response.statusCode != 200 || data is! Map) return null;
      return RevokeOtherSessionsResult.fromJson(
        Map<String, dynamic>.from(data),
      );
    } catch (e) {
      debugPrint('Error revoking other sessions: $e');
      return null;
    }
  }

  /// Résout un chemin fourni par le serveur en URL absolue.
  ///
  /// Le payload envoie `/api/security/...` alors que [ApiConfig.baseUrl] se
  /// termine déjà par `/api` : concaténer tel quel donnerait `/api/api/...`.
  static String _resolveApiUrl(String? endpoint, String fallbackPath) {
    final base = ApiConfig.baseUrl;
    final raw = endpoint?.trim();
    if (raw == null || raw.isEmpty) return '$base$fallbackPath';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    var path = raw.startsWith('/') ? raw : '/$raw';
    if (base.endsWith('/api') && path.startsWith('/api/')) {
      path = path.substring(4);
    }
    return '$base$path';
  }

  /// Limite multicompte configurée dans le backoffice (défaut 2). Repli sur
  /// la valeur par défaut si le serveur est injoignable.
  Future<int> fetchMaxAccountsPerDevice() async {
    try {
      final response = await _dio.get(ApiConfig.appSettings);
      final data = response.data;
      if (data is Map && data['max_accounts_per_device'] != null) {
        final value = (data['max_accounts_per_device'] as num).toInt();
        if (value >= 1) return value;
      }
    } catch (_) {}
    return 2;
  }

  /// Comptes enregistrés sur cet appareil (cartes utilisateur complètes),
  /// du plus anciennement activé au plus récent.
  Future<List<Map<String, dynamic>>> listSessions() async {
    await _ensureLegacyMigrated();
    return _readSessionsRaw();
  }

  /// Identifiant du compte actif, ou null si aucune session.
  Future<String?> getActiveUserId() async {
    await _ensureLegacyMigrated();
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString(_activeUserIdKey);
      if (id == null || id.isEmpty) return null;
      final known = await _readSessionsRaw();
      for (final u in known) {
        if (userIdOf(u) == id) return id;
      }
      return null;
    } catch (_) {}
    return null;
  }

  /// Ajoute (ou met à jour) la session d'un compte avec son token et la
  /// définit comme session active.
  Future<void> addOrUpdateSession(
      Map<String, dynamic> user, String? token) async {
    final userId = userIdOf(user);
    if (userId == null) return;
    await _ensureLegacyMigrated();

    if (token != null && token.isNotEmpty) {
      // Stockage sécurisé uniquement : jamais de copie en clair.
      await _secureWrite(_sessionTokenKey(userId), token);
    }

    final sessions = await _readSessionsRaw();
    sessions.removeWhere((u) => userIdOf(u) == userId);
    sessions.add(Map<String, dynamic>.from(user));
    await _saveSessions(sessions);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeUserIdKey, userId);
    await saveLastUserId(userId);
  }

  /// Active la session d'un compte déjà enregistré sur cet appareil.
  /// Retourne false si aucune session n'existe pour ce compte.
  Future<bool> switchAccount(String userId) async {
    await _ensureLegacyMigrated();
    final sessions = await _readSessionsRaw();
    Map<String, dynamic>? match;
    for (final u in sessions) {
      if (userIdOf(u) == userId) {
        match = u;
        break;
      }
    }
    if (match == null) return false;

    sessions.removeWhere((u) => userIdOf(u) == userId);
    sessions.add(match); // le plus récemment actif reste en fin de liste
    await _saveSessions(sessions);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeUserIdKey, userId);
    await saveLastUserId(userId);
    return true;
  }

  /// Supprime la session d'un compte : révocation serveur (token + slot
  /// multicompte, best-effort) puis suppression locale. Si c'était la session
  /// active, la plus récente des sessions restantes devient active.
  Future<void> removeSession(String userId) async {
    await _ensureLegacyMigrated();
    final wasActive = await getActiveUserId() == userId;
    final token = await _readSessionToken(userId);

    if (token != null &&
        token.isNotEmpty &&
        token != 'test-local-token') {
      final dio = Dio(BaseOptions(headers: {'Accept': 'application/json'}));
      dio.options.headers['Authorization'] = 'Bearer $token';
      if (wasActive) {
        // Le token FCM de l'appareil n'est enregistré que pour le compte
        // actif : on ne le révoque que dans ce cas.
        try {
          final fcmToken = await FirebaseMessaging.instance.getToken();
          if (fcmToken != null) {
            await dio.post('${ApiConfig.baseUrl}/users/revoke-fcm-token',
                data: {'fcm_token': fcmToken});
          }
          await FirebaseMessaging.instance.deleteToken();
        } catch (_) {}
      }
      try {
        await dio.post(ApiConfig.logout,
            data: {'device_id': await getDeviceId()});
      } catch (_) {}
    }

    await _deleteSessionToken(userId);
    final sessions = await _readSessionsRaw();
    sessions.removeWhere((u) => userIdOf(u) == userId);
    await _saveSessions(sessions);

    if (wasActive) {
      final prefs = await SharedPreferences.getInstance();
      if (sessions.isEmpty) {
        await prefs.remove(_activeUserIdKey);
      } else {
        await prefs.setString(
            _activeUserIdKey, userIdOf(sessions.last) ?? '');
      }
    }
  }

  /// Supprime localement la session active (token invalide côté serveur,
  /// p.ex. 401) sans appel réseau. N'active PAS automatiquement une autre
  /// session : la bascule implique de changer de base et de recharger
  /// l'application, ce qui ne peut pas se faire sûrement depuis un
  /// intercepteur — c'est orchestré par AuthProvider.
  Future<void> removeActiveSession() async {
    await _ensureLegacyMigrated();
    final activeId = await getActiveUserId();
    if (activeId == null) return;

    await _deleteSessionToken(activeId);
    final sessions = await _readSessionsRaw();
    sessions.removeWhere((u) => userIdOf(u) == activeId);
    await _saveSessions(sessions);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_activeUserIdKey);
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // SESSION ACTIVE — API historique (token / utilisateur en cache)
  // ---------------------------------------------------------------------------

  Future<String?> getToken() async {
    final activeId = await getActiveUserId();
    if (activeId == null) return null;
    return _readSessionToken(activeId);
  }

  Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  Future<Map<String, dynamic>?> getCachedUser() async {
    final activeId = await getActiveUserId();
    if (activeId == null) return null;
    final sessions = await _readSessionsRaw();
    for (final u in sessions) {
      if (userIdOf(u) == activeId) return u;
    }
    return null;
  }

  Future<void> saveCachedUser(Map<String, dynamic> user) async {
    final userId = userIdOf(user);
    if (userId == null) return;
    await _ensureLegacyMigrated();

    final sessions = await _readSessionsRaw();
    final index = sessions.indexWhere((u) => userIdOf(u) == userId);
    if (index == -1) {
      sessions.add(Map<String, dynamic>.from(user));
    } else {
      sessions[index] = Map<String, dynamic>.from(user);
    }
    await _saveSessions(sessions);
    await saveLastUserId(userId);
  }

  // ---------------------------------------------------------------------------
  // STOCKAGE INTERNE DES SESSIONS
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> _readSessionsRaw() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_sessionsKey);
      if (raw == null || raw.isEmpty) return [];
      final decoded = json.decode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .where((u) => userIdOf(u) != null)
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<void> _saveSessions(List<Map<String, dynamic>> sessions) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sessionsKey, json.encode(sessions));
    } catch (_) {}
  }

  /// Lit le token d'une session. Le stockage sécurisé (ou son repli mémoire)
  /// est la seule source : aucun repli sur les SharedPreferences. Les copies
  /// en clair laissées par les anciennes versions sont récupérées par
  /// [_ensureLegacyMigrated], appelée avant toute lecture.
  Future<String?> _readSessionToken(String userId) =>
      _secureRead(_sessionTokenKey(userId));

  Future<void> _deleteSessionToken(String userId) async {
    final key = _sessionTokenKey(userId);
    await _secureDelete(key);
    try {
      // Purge d'une éventuelle copie en clair laissée par une ancienne version.
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } catch (_) {}
  }

  Future<String?> _secureRead(String key) async {
    try {
      final value = await _storage.read(key: key);
      if (value != null && value.isNotEmpty) return value;
    } catch (_) {}
    final cached = _memoryTokens[key];
    return (cached != null && cached.isNotEmpty) ? cached : null;
  }

  /// Écrit un token dans le stockage sécurisé. Retourne false si seul le repli
  /// mémoire a pu être alimenté (session perdue au prochain lancement).
  Future<bool> _secureWrite(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
      _memoryTokens.remove(key);
      return true;
    } catch (_) {}
    _memoryTokens[key] = value;
    return false;
  }

  Future<void> _secureDelete(String key) async {
    _memoryTokens.remove(key);
    try {
      await _storage.delete(key: key);
    } catch (_) {}
  }

  /// Migration one-shot des anciens stockages, exécutée AVANT toute lecture de
  /// token (tous les points d'entrée publics l'appellent) :
  ///
  /// 1. ancien stockage mono-session (`auth_token` / `cached_user`) : il
  ///    devient la première session multicompte ;
  /// 2. tokens de session écrits en clair dans les SharedPreferences par les
  ///    versions antérieures : ils sont recopiés dans le stockage sécurisé.
  ///
  /// Toutes les copies en clair sont ensuite effacées. Aucun utilisateur déjà
  /// connecté n'est déconnecté : le token change seulement de magasin.
  Future<void> _ensureLegacyMigrated() async {
    if (_legacyMigrated) return;
    _legacyMigrated = true;
    try {
      final sessions = await _readSessionsRaw();
      if (sessions.isEmpty) {
        String? legacyToken;
        try {
          legacyToken = await _storage.read(key: _tokenKey);
        } catch (_) {}
        Map<String, dynamic>? legacyUser;
        try {
          final raw = await _storage.read(key: _userKey);
          if (raw != null && raw.isNotEmpty) {
            legacyUser = Map<String, dynamic>.from(json.decode(raw));
          }
        } catch (_) {}
        final prefs = await SharedPreferences.getInstance();
        legacyToken ??= prefs.getString(_tokenKey);
        legacyUser ??= _decodeUserJson(prefs.getString(_userKey));

        if (legacyToken != null &&
            legacyToken.isNotEmpty &&
            legacyUser != null) {
          final userId = userIdOf(legacyUser);
          if (userId != null) {
            await _secureWrite(_sessionTokenKey(userId), legacyToken);
            sessions.add(legacyUser);
            await _saveSessions(sessions);
            await prefs.setString(_activeUserIdKey, userId);
            await saveLastUserId(userId);
            // Les données de l'ancienne base partagée appartiennent à ce
            // compte : il sera le seul à pouvoir les hériter.
            await prefs.setString(legacyDbOwnerKey(ApiConfig.env), userId);
          }
        }
      }
      final kept = await _migratePlaintextSessionTokens(sessions);
      await _deleteLegacyKeys(keep: kept);
    } catch (_) {}
  }

  /// Recopie dans le stockage sécurisé les tokens de session encore écrits en
  /// clair par les versions antérieures, pour ne déconnecter personne. Le
  /// stockage sécurisé fait foi s'il contient déjà le token.
  ///
  /// Retourne les clés en clair volontairement conservées (recopie impossible).
  Future<Set<String>> _migratePlaintextSessionTokens(
      List<Map<String, dynamic>> sessions) async {
    final kept = <String>{};
    final prefs = await SharedPreferences.getInstance();
    for (final user in sessions) {
      final userId = userIdOf(user);
      if (userId == null) continue;
      final key = _sessionTokenKey(userId);
      final plaintext = prefs.getString(key);
      if (plaintext == null || plaintext.isEmpty) continue;

      final secure = await _secureRead(key);
      if (secure == null || secure.isEmpty) {
        if (!await _secureWrite(key, plaintext)) {
          // Stockage sécurisé momentanément indisponible : on laisse la copie
          // en clair pour retenter au prochain lancement plutôt que de perdre
          // définitivement la session. Elle sera effacée dès que la recopie
          // aura réussi.
          kept.add(key);
          continue;
        }
      }
      await prefs.remove(key);
    }
    return kept;
  }

  static Map<String, dynamic>? _decodeUserJson(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = json.decode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return null;
  }

  /// Efface l'ancien stockage mono-session et TOUTE copie de token restée en
  /// clair dans les SharedPreferences (`auth_token`, `auth_token_dev` et les
  /// clés de session `auth_token[_dev]_<userId>`), sauf celles de [keep].
  Future<void> _deleteLegacyKeys({Set<String> keep = const {}}) async {
    await _secureDelete(_tokenKey);
    try {
      await _storage.delete(key: _userKey);
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userKey);
      // `auth_token` préfixe aussi `auth_token_dev` : en production le balayage
      // nettoie les deux environnements ; en dev seules les clés `_dev` sont
      // concernées. Aucune autre clé applicative ne commence par `auth_token`
      // (le compte actif est sous `auth_active_user_id`, les cartes
      // utilisateur sous `auth_sessions`).
      for (final key in prefs.getKeys().toList()) {
        if (key.startsWith(_tokenKey) && !keep.contains(key)) {
          await prefs.remove(key);
        }
      }
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // IDENTITÉ DU DERNIER COMPTE (diagnostics / filet de sécurité historique)
  // ---------------------------------------------------------------------------

  String get _lastUserIdKey => ApiConfig.env.scoped('last_user_id');

  /// Propriétaire de l'ancienne base partagée (pré-multicompte) : seul ce
  /// compte peut hériter des données locales lors du passage aux bases par
  /// compte. Défini lors de la migration de l'ancienne session mono-compte.
  static String legacyDbOwnerKey(AppEnvironment env) =>
      env.scoped('db_legacy_owner');

  /// [env] : environnement actif par défaut.
  Future<String?> getLegacyDbOwner([AppEnvironment? env]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(legacyDbOwnerKey(env ?? ApiConfig.env));
    } catch (_) {}
    return null;
  }

  Future<String?> getLastUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_lastUserIdKey);
    } catch (_) {}
    return null;
  }

  Future<void> saveLastUserId(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastUserIdKey, userId);
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // AUTHENTIFICATION
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> login(String email, String password,
      {String? deviceId}) async {
    // Mode test : authentification 100% locale (local storage uniquement,
    // aucun appel réseau, aucune BD requise). Jamais actif hors debug :
    // [kDebugMode] est élagué à la compilation, la branche et les identifiants
    // qu'elle référence ne subsistent pas dans le binaire de production.
    if (kDebugMode &&
        ApiConfig.isDevMode &&
        TestAccount.matches(email, password)) {
      final token = 'test-local-token';
      final user = <String, dynamic>{
        'id': 1,
        'uuid': 'test-local-user',
        'name': 'Fimus Track',
        'email': testAccountEmail,
        'pseudo': testAccountPseudo,
        'user_code': testAccountPseudo,
        'type': 'particulier',
        'profile_complete': true,
        'photoUrl': '',
        'country': {'id': 39, 'name': 'Cameroun', 'currency': 'XAF'},
      };
      // L'enregistrement de la session est orchestré par AuthProvider (ordre
      // push ancien compte → activation → bascule de base).
      return {'access_token': token, 'user': user};
    }

    try {
      final response = await _dio.post(
        ApiConfig.login,
        data: {
          'email': email,
          'password': password,
          // `device_id`, `platform` et `device_model` : sans eux l'alerte de
          // nouvelle connexion annonce « un nouvel appareil » (cf.
          // LoginDeviceGuard côté backend).
          ...deviceFields(deviceId),
        },
      );

      return response.data;
    } on DioException catch (e) {
      _throwIfDeviceAccountLimit(e);
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required int countryId,
    required String type,
    required String pseudo,
    String? deviceId,
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.register,
        data: {
          'name': name,
          'email': email,
          'password': password,
          'password_confirmation': password,
          'country_id': countryId,
          'type': type,
          'pseudo': pseudo,
          ...deviceFields(deviceId),
        },
      );

      return response.data;
    } on DioException catch (e) {
      _throwIfDeviceAccountLimit(e);
      throw _handleError(e);
    }
  }

  Future<void> forgotPassword(String email) async {
    try {
      await _dio.post(
        ApiConfig.forgotPassword,
        data: {'email': email},
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> loginWithGoogle({
    required String idToken,
    String? name,
    String? type,
    int? countryId,
    String? pseudo,
    String? deviceId,
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.googleAuth,
        data: {
          'id_token': idToken,
          if (name != null) 'name': name,
          if (type != null) 'type': type,
          if (countryId != null) 'country_id': countryId,
          if (pseudo != null) 'pseudo': pseudo,
          ...deviceFields(deviceId),
        },
      );

      return response.data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 422) {
        final code = e.response?.data['code'];
        final message = e.response?.data['message'] ?? '';
        if (code == 'REGISTRATION_INCOMPLETE' ||
            message.contains('informations supplémentaires') ||
            message.contains('type') ||
            message.contains('country_id')) {
          throw GoogleAuthNeedsRegistrationException(message);
        }
        if (code == 'PSEUDO_TAKEN') {
          throw PseudoTakenException(message);
        }
      }
      if (e.response?.statusCode == 401) {
        final code = e.response?.data['code'];
        if (code == 'INVALID_GOOGLE_TOKEN') {
          throw InvalidGoogleTokenException(e.response?.data['message'] ?? 'Token invalide');
        }
      }
      _throwIfDeviceAccountLimit(e);
      throw _handleError(e);
    }
  }

  /// Déconnexion serveur de la session active : révocation FCM + token +
  /// libération du slot multicompte (device_id). Ne touche pas aux sessions
  /// locales — l'orchestration (purge, bascule) est faite par AuthProvider.
  Future<void> logoutServer() async {
    try {
      final token = await getToken();
      if (token != null && token.isNotEmpty && token != 'test-local-token') {
        try {
          final fcmToken = await FirebaseMessaging.instance.getToken();
          if (fcmToken != null) {
            await _dio.post('${ApiConfig.baseUrl}/users/revoke-fcm-token',
                data: {'fcm_token': fcmToken});
          }
          await FirebaseMessaging.instance.deleteToken();
        } catch (_) {}
        await _dio.post(ApiConfig.logout,
            data: {'device_id': await getDeviceId()});
      }
    } catch (_) {
      // Continue même si la déconnexion serveur échoue : la suppression locale
      // du token prime.
    }
  }

  Future<Map<String, dynamic>> getUser() async {
    try {
      final response = await _dio.get(ApiConfig.user);
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> updatePseudo(String newPseudo) async {
    try {
      await _dio.post(ApiConfig.updatePseudo, data: {'pseudo': newPseudo});
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> completeProfile({
    required String pseudo,
    required int countryId,
    required String type,
  }) async {
    try {
      final response = await _dio.post(
        '${ApiConfig.baseUrl}/user/complete-profile',
        data: {
          'pseudo': pseudo,
          'country_id': countryId,
          'type': type,
        },
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Liste restreinte des 3 pays pour le mode test / développement
  static const List<Map<String, dynamic>> testCountries = [
    {
      'id': 39,
      'name': 'Cameroun',
      'code': 'CM',
      'currency': 'XAF',
      'flag': '🇨🇲',
    },
    {
      'id': 40,
      'name': 'Canada',
      'code': 'CA',
      'currency': 'CAD',
      'flag': '🇨🇦',
    },
    {
      'id': 163,
      'name': 'Royaume-Uni',
      'code': 'GB',
      'currency': 'GBP',
      'flag': '🇬🇧',
    },
  ];

  Future<List<dynamic>> getCountries() async {
    if (ApiConfig.isDevMode) {
      try {
        final response = await _dio.get(ApiConfig.countries).timeout(const Duration(seconds: 3));
        if (response.data is List) {
          final list = response.data as List;
          const testNames = {'Cameroun', 'Canada', 'Royaume-Uni', 'United Kingdom'};
          final filtered = list.where((item) {
            final name = item is Map ? (item['name']?.toString() ?? '') : '';
            return testNames.contains(name);
          }).toList();
          if (filtered.isNotEmpty) {
            return filtered;
          }
        }
      } catch (_) {}
      return testCountries;
    }

    try {
      final response = await _dio.get(ApiConfig.countries);
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> updateCountry(int countryId) async {
    try {
      await _dio.post(
        ApiConfig.updateCountry,
        data: {'country_id': countryId},
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> deleteAccount() async {
    try {
      await _dio.delete(ApiConfig.user);
    } on DioException catch (e) {
      throw _handleError(e);
    } finally {
      // La suppression serveur efface les tokens et les slots multicompte
      // (cascade) ; il reste à retirer la session locale.
      await removeActiveSession();
    }
  }

  Future<Map<String, double>> fetchExchangeRates() async {
    try {
      final response = await _dio.get(ApiConfig.exchangeRates);
      final Map<String, dynamic> data = response.data;
      return data.map((key, value) => MapEntry(key, (value as num).toDouble()));
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Traduit la réponse 422 DEVICE_ACCOUNT_LIMIT du serveur (limite de
  /// comptes par appareil atteinte) en exception typée.
  void _throwIfDeviceAccountLimit(DioException e) {
    final data = e.response?.data;
    if (e.response?.statusCode == 422 &&
        data is Map &&
        data['code'] == 'DEVICE_ACCOUNT_LIMIT') {
      throw DeviceAccountLimitException(
        data['message']?.toString() ?? '',
        max: (data['max_accounts_per_device'] as num?)?.toInt() ?? 2,
      );
    }
  }

  String _handleError(DioException e) {
    if (e.response != null) {
      if (e.response?.statusCode == 429) {
        // En frontend pur (sans context l10n facile),
        // les messages sont déjà envoyés correctement au niveau UI via Dio interceptor
        // mais pour garder la localisation, l'idéal serait de retourner le code
        // ou d'avoir le context, mais ici on va juste parser le retry-after.
        final retryAfter = e.response?.headers.value('retry-after');
        if (retryAfter != null) {
          return 'TOO_MANY_REQUESTS_RETRY:$retryAfter';
        }
        return 'TOO_MANY_REQUESTS';
      }
      if (e.response?.statusCode == 422) {
        final errors = e.response?.data['errors'] as Map<String, dynamic>?;
        if (errors != null && errors.isNotEmpty) {
          return errors.values.first.first.toString();
        }
        return e.response?.data['message'] ?? 'Validation Error';
      }
      return e.response?.data['message'] ?? 'An error occurred';
    }
    return 'Network Error. Please check your connection.';
  }
}

/// Réponse de `POST /api/security/revoke-other-sessions` :
/// `{message, revoked_sessions, revoked_devices}`.
class RevokeOtherSessionsResult {
  final String message;

  /// Nombre de sessions API (jetons Sanctum) coupées.
  final int revokedSessions;

  /// Nombre d'appareils dont le jeton FCM a été supprimé.
  final int revokedDevices;

  const RevokeOtherSessionsResult({
    this.message = '',
    this.revokedSessions = 0,
    this.revokedDevices = 0,
  });

  factory RevokeOtherSessionsResult.fromJson(Map<String, dynamic> json) {
    return RevokeOtherSessionsResult(
      message: json['message']?.toString() ?? '',
      revokedSessions: _asInt(json['revoked_sessions']),
      revokedDevices: _asInt(json['revoked_devices']),
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class GoogleAuthNeedsRegistrationException implements Exception {
  final String message;
  GoogleAuthNeedsRegistrationException(this.message);
  @override
  String toString() => message;
}

class PseudoTakenException implements Exception {
  final String message;
  PseudoTakenException(this.message);
  @override
  String toString() => message;
}

class InvalidGoogleTokenException implements Exception {
  final String message;
  InvalidGoogleTokenException(this.message);
  @override
  String toString() => message;
}

/// Limite multicompte atteinte sur cet appareil : le serveur refuse la
/// connexion d'un compte supplémentaire.
class DeviceAccountLimitException implements Exception {
  final String message;
  final int max;
  DeviceAccountLimitException(this.message, {this.max = 2});
  @override
  String toString() => message;
}
