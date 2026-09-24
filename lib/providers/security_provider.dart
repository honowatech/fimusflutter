import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'dart:convert';
import 'dart:math';
import '../utils/pin_hasher.dart';

/// Dérivation du PIN dans un isolate : le PBKDF2 dure plusieurs centaines de
/// millisecondes, il ne doit jamais s'exécuter sur le thread UI.
Future<String> _hashInIsolate(List<Object> args) =>
    compute(pinHashV3Worker, args);

class SecurityProvider extends ChangeNotifier {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final LocalAuthentication _localAuth = LocalAuthentication();

  static const String _appLockPrefKey = 'security_app_lock_enabled';
  static const String _biometricPrefKey = 'security_biometric_enabled';
  static const String _pinSecureKey = 'security_app_lock_pin';
  static const String _pinSaltKey = 'security_pin_salt';

  /// Anciennes clés SharedPreferences : lisibles et modifiables sur un appareil
  /// rooté (un `adb shell` suffisait à remettre le compteur d'échecs à zéro).
  /// Conservées uniquement le temps de migrer leur valeur.
  static const String _legacyFailedAttemptsPrefKey = 'security_failed_attempts';
  static const String _legacyLockoutUntilPrefKey = 'security_lockout_until';

  /// Compteurs anti-force brute, désormais dans le stockage sécurisé.
  static const String _failedAttemptsSecureKey = 'security_failed_attempts_v2';
  static const String _lockoutUntilSecureKey = 'security_lockout_until_v2';
  static const String _reauthRequiredSecureKey = 'security_reauth_required';

  /// Nombre d'échecs consécutifs déclenchant le palier de blocage suivant.
  static const int attemptsPerStep = 5;

  /// Paliers de blocage successifs : 5 échecs -> 1 min, 10 -> 5 min,
  /// 15 -> 15 min, 20 -> 60 min (puis 60 min pour tout palier suivant).
  static const List<Duration> lockoutSteps = <Duration>[
    Duration(minutes: 1),
    Duration(minutes: 5),
    Duration(minutes: 15),
    Duration(minutes: 60),
  ];

  /// Au-delà de ce nombre d'échecs **cumulés**, le code PIN ne suffit plus :
  /// l'utilisateur doit se réauthentifier complètement (mot de passe) depuis
  /// l'écran de connexion. Les données locales ne sont pas effacées.
  static const int maxFailedAttempts = 25;

  bool _isAppLockEnabled = false;
  bool _isBiometricEnabled = false;
  bool _isAppUnlocked = false;
  bool _isBiometricsAvailable = false;
  bool _isSettingsLoaded = false;
  int _failedAttempts = 0;
  DateTime? _lockoutUntil;
  bool _requiresFullReauth = false;

  /// Les préférences de verrouillage ont-elles fini d'être lues ?
  ///
  /// Avant cela, `isAppLockEnabled` vaut `false` par défaut : tout appelant qui
  /// décide d'agir selon l'état du verrou (file d'intentions de notification)
  /// doit attendre ce drapeau, sous peine d'ouvrir un écran par-dessus le
  /// LockScreen qui va s'afficher juste après.
  bool get isSettingsLoaded => _isSettingsLoaded;

  bool get isAppLockEnabled => _isAppLockEnabled;
  bool get isBiometricEnabled => _isBiometricEnabled;
  bool get isAppUnlocked => _isAppUnlocked;
  bool get isBiometricsAvailable => _isBiometricsAvailable;
  int get failedAttempts => _failedAttempts;
  DateTime? get lockoutUntil => _lockoutUntil;
  bool get isLockedOut =>
      _lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!);

  /// Seuil d'échecs atteint : le déverrouillage par PIN est définitivement
  /// refusé jusqu'à une reconnexion complète par mot de passe.
  bool get requiresFullReauth => _requiresFullReauth;

  /// Temps restant avant de pouvoir ressaisir un PIN (`Duration.zero` si libre).
  Duration get remainingLockout {
    if (_lockoutUntil == null) return Duration.zero;
    final remaining = _lockoutUntil!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Essais restants avant le prochain blocage. On n'expose que la marge du
  /// palier courant, jamais le compteur cumulé ni le seuil de déconnexion :
  /// inutile d'indiquer à un attaquant où il en est de son budget global.
  int get remainingAttemptsBeforeLockout {
    if (isLockedOut || _requiresFullReauth) return 0;
    return attemptsPerStep - (_failedAttempts % attemptsPerStep);
  }

  /// Durée du blocage déclenché par le palier courant.
  Duration _currentLockoutDuration() {
    final stepIndex = (_failedAttempts ~/ attemptsPerStep) - 1;
    if (stepIndex < 0) return lockoutSteps.first;
    return lockoutSteps[min(stepIndex, lockoutSteps.length - 1)];
  }

  Future<String> _getOrCreateSalt() async {
    var salt = await _secureStorage.read(key: _pinSaltKey);
    if (salt == null || salt.isEmpty) {
      final random = Random.secure();
      final bytes = List<int>.generate(16, (_) => random.nextInt(256));
      salt = base64Encode(bytes);
      await _secureStorage.write(key: _pinSaltKey, value: salt);
    }
    return salt;
  }

  /// Empreinte au format courant (v3 / PBKDF2), calculée hors thread UI.
  Future<String> _hashPin(String pin) async {
    final salt = await _getOrCreateSalt();
    return _hashInIsolate(<Object>[pin, salt, PinHasher.currentIterations]);
  }

  /// Vérification d'un PIN contre l'empreinte stockée, tous formats confondus.
  ///
  /// En v3 le sel voyage dans l'empreinte : inutile de toucher au stockage
  /// sécurisé pour le relire (et surtout inutile d'en créer un si l'entrée a
  /// disparu).
  Future<bool> _verifyPin(String pin, String stored) async {
    final salt = PinHasher.isV3(stored) ? '' : await _getOrCreateSalt();
    return PinHasher.matchesAsync(pin, stored, salt, runner: _hashInIsolate);
  }

  SecurityProvider() {
    _initSecuritySettings();
  }

  Future<void> _initSecuritySettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isAppLockEnabled = prefs.getBool(_appLockPrefKey) ?? false;
      _isBiometricEnabled = prefs.getBool(_biometricPrefKey) ?? false;

      await _loadCounters(prefs);

      // If lock is not enabled, mark as unlocked
      if (!_isAppLockEnabled) {
        _isAppUnlocked = true;
      } else {
        _isAppUnlocked = false;
      }
    } catch (e) {
      // Préférences illisibles : on reste sur les valeurs par défaut, mais le
      // drapeau doit passer à true pour ne pas bloquer indéfiniment les
      // consommateurs qui l'attendent.
      debugPrint('Error loading security settings: $e');
      _isAppUnlocked = !_isAppLockEnabled;
      _failClosed();
    }

    _isSettingsLoaded = true;
    notifyListeners();

    // Defer local_auth hardware & root checks post-launch to prevent main thread jank
    Future.microtask(() async {
      try {
        final isDeviceSupported = await _localAuth.isDeviceSupported();
        final canCheckBiometrics = await _localAuth.canCheckBiometrics;
        _isBiometricsAvailable = isDeviceSupported && canCheckBiometrics;
      } catch (_) {
        _isBiometricsAvailable = false;
      }
      notifyListeners();
    });
  }

  // ---------------------------------------------------------------------------
  // Compteurs anti-force brute (stockage sécurisé)
  // ---------------------------------------------------------------------------

  /// Lit les compteurs dans le stockage sécurisé, en migrant au passage les
  /// valeurs éventuellement présentes dans les SharedPreferences.
  Future<void> _loadCounters(SharedPreferences prefs) async {
    try {
      final storedAttempts =
          await _secureStorage.read(key: _failedAttemptsSecureKey);
      final storedLockout =
          await _secureStorage.read(key: _lockoutUntilSecureKey);
      final storedReauth =
          await _secureStorage.read(key: _reauthRequiredSecureKey);

      if (storedAttempts == null && storedLockout == null) {
        // Première exécution après mise à jour : on récupère l'état des
        // anciennes clés SharedPreferences avant de les supprimer, sinon un
        // utilisateur déjà bloqué repartirait avec un compteur neuf.
        final legacyAttempts = prefs.getInt(_legacyFailedAttemptsPrefKey) ?? 0;
        final legacyLockout = prefs.getString(_legacyLockoutUntilPrefKey);
        _failedAttempts = legacyAttempts;
        _lockoutUntil =
            legacyLockout == null ? null : DateTime.tryParse(legacyLockout);
        await _persistCounters();
      } else {
        _failedAttempts = int.tryParse(storedAttempts ?? '0') ?? 0;
        _lockoutUntil =
            storedLockout == null ? null : DateTime.tryParse(storedLockout);
      }
      _requiresFullReauth =
          storedReauth == 'true' || _failedAttempts >= maxFailedAttempts;

      await _clearLegacyCounterPrefs(prefs);
    } catch (e) {
      debugPrint('Error loading lockout counters: $e');
      _failClosed();
    }
  }

  /// Stockage sécurisé illisible : on préfère bloquer un utilisateur légitime
  /// une minute plutôt que d'offrir à un attaquant un compteur remis à zéro en
  /// corrompant volontairement le keystore. Le palier repart au minimum et
  /// réescalade normalement en cas de nouveaux échecs.
  void _failClosed() {
    if (!_isAppLockEnabled) return;
    _failedAttempts = max(_failedAttempts, attemptsPerStep);
    _lockoutUntil = DateTime.now().add(lockoutSteps.first);
  }

  Future<void> _persistCounters() async {
    try {
      await _secureStorage.write(
        key: _failedAttemptsSecureKey,
        value: '$_failedAttempts',
      );
      if (_lockoutUntil == null) {
        await _secureStorage.delete(key: _lockoutUntilSecureKey);
      } else {
        await _secureStorage.write(
          key: _lockoutUntilSecureKey,
          value: _lockoutUntil!.toIso8601String(),
        );
      }
      if (_requiresFullReauth) {
        await _secureStorage.write(
          key: _reauthRequiredSecureKey,
          value: 'true',
        );
      } else {
        await _secureStorage.delete(key: _reauthRequiredSecureKey);
      }
    } catch (e) {
      // L'écriture a échoué : l'état en mémoire reste appliqué pour la session
      // en cours, on ne relâche jamais la contrainte.
      debugPrint('Error persisting lockout counters: $e');
    }
  }

  Future<void> _clearLegacyCounterPrefs(SharedPreferences prefs) async {
    try {
      await prefs.remove(_legacyFailedAttemptsPrefKey);
      await prefs.remove(_legacyLockoutUntilPrefKey);
    } catch (_) {}
  }

  Future<void> _resetCounters() async {
    _failedAttempts = 0;
    _lockoutUntil = null;
    _requiresFullReauth = false;
    await _persistCounters();
  }

  /// À appeler depuis l'écran de verrouillage quand le compte à rebours arrive
  /// à zéro : rafraîchit l'affichage sans remettre le compteur cumulé à zéro
  /// (c'était le défaut historique : attendre 1 minute redonnait 5 essais
  /// indéfiniment, soit ~7 200 essais par jour).
  void refreshLockoutState() {
    if (_lockoutUntil != null && !isLockedOut) {
      notifyListeners();
    }
  }

  /// Lock the application (usually when backgrounded).
  void lockApp() {
    if (_isAppLockEnabled) {
      _isAppUnlocked = false;
      notifyListeners();
    }
  }

  /// Temporarily unlock the application for this session.
  void setUnlocked(bool unlocked) {
    _isAppUnlocked = unlocked;
    notifyListeners();
  }

  /// Authenticate with PIN code.
  Future<bool> authenticateWithPin(String pin) async {
    if (_requiresFullReauth) return false;
    if (isLockedOut) return false;

    final savedPinInfo = await _secureStorage.read(key: _pinSecureKey);
    if (savedPinInfo == null) return false;

    if (await _verifyPin(pin, savedPinInfo)) {
      _isAppUnlocked = true;
      await _resetCounters();

      // Migration transparente : tout format antérieur (PIN en clair, v1 à sel
      // statique, v2 SHA-256 salé, ou v3 à coût inférieur) est réécrit au
      // format courant dès la première saisie correcte.
      if (PinHasher.needsRehash(savedPinInfo)) {
        try {
          final upgraded = await _hashPin(pin);
          await _secureStorage.write(key: _pinSecureKey, value: upgraded);
        } catch (e) {
          debugPrint('Error upgrading PIN hash: $e');
        }
      }

      notifyListeners();
      return true;
    }

    _failedAttempts++;
    if (_failedAttempts % attemptsPerStep == 0) {
      _lockoutUntil = DateTime.now().add(_currentLockoutDuration());
    }
    if (_failedAttempts >= maxFailedAttempts) {
      _requiresFullReauth = true;
    }
    await _persistCounters();
    notifyListeners();
    return false;
  }

  /// Authenticate with Biometrics (Fingerprint/Face ID).
  Future<bool> authenticateWithBiometrics() async {
    if (!_isAppLockEnabled || !_isBiometricEnabled || !_isBiometricsAvailable) {
      return false;
    }
    // La biométrie ne doit pas servir de contournement du blocage progressif.
    if (isLockedOut || _requiresFullReauth) return false;

    try {
      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Veuillez vous authentifier pour déverrouiller l\'application',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      if (didAuthenticate) {
        _isAppUnlocked = true;
        // Succès d'un facteur fort : le compteur cumulé repart à zéro.
        await _resetCounters();
        notifyListeners();
        return true;
      }
    } catch (_) {
      // Failed to authenticate using biometrics
    }
    return false;
  }

  /// Enable App Lock with a new PIN.
  Future<void> enableAppLock(String pin) async {
    final inputHash = await _hashPin(pin);
    await _secureStorage.write(key: _pinSecureKey, value: inputHash);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_appLockPrefKey, true);

    _isAppLockEnabled = true;
    _isAppUnlocked = true;
    await _resetCounters();
    notifyListeners();
  }

  /// Disable App Lock. Must verify with current PIN.
  Future<bool> disableAppLock(String pin) async {
    final savedPin = await _secureStorage.read(key: _pinSecureKey);
    if (savedPin == null) return false;
    if (!await _verifyPin(pin, savedPin)) {
      return false;
    }

    await _secureStorage.delete(key: _pinSecureKey);
    await _secureStorage.delete(key: _pinSaltKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_appLockPrefKey, false);
    await prefs.setBool(_biometricPrefKey, false);

    _isAppLockEnabled = false;
    _isBiometricEnabled = false;
    _isAppUnlocked = true;
    await _resetCounters();
    notifyListeners();
    return true;
  }

  /// Toggle Biometric configuration.
  Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricPrefKey, enabled);
    _isBiometricEnabled = enabled;
    notifyListeners();
  }

  /// Réinitialise le verrou applicatif (déconnexion) : un nouveau compte ne
  /// doit pas être bloqué par le code PIN de l'ancien, et la sortie de secours
  /// « code PIN oublié → déconnexion » doit réellement déverrouiller l'app.
  ///
  /// C'est aussi le chemin de sortie du blocage définitif ([requiresFullReauth])
  /// : la réauthentification complète par mot de passe purge les compteurs,
  /// sans toucher aux données locales de l'utilisateur.
  Future<void> resetAppLock() async {
    try {
      await _secureStorage.delete(key: _pinSecureKey);
      await _secureStorage.delete(key: _pinSaltKey);
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_appLockPrefKey);
    await prefs.remove(_biometricPrefKey);
    await _clearLegacyCounterPrefs(prefs);

    _isAppLockEnabled = false;
    _isBiometricEnabled = false;
    _isAppUnlocked = true;
    await _resetCounters();
    notifyListeners();
  }

  /// Change existing PIN.
  Future<bool> changePin(String oldPin, String newPin) async {
    final savedPin = await _secureStorage.read(key: _pinSecureKey);
    if (savedPin == null) return false;
    if (_requiresFullReauth || isLockedOut) return false;
    if (!await _verifyPin(oldPin, savedPin)) {
      return false;
    }

    final newHash = await _hashPin(newPin);
    await _secureStorage.write(key: _pinSecureKey, value: newHash);
    _isAppUnlocked = true;
    await _resetCounters();
    notifyListeners();
    return true;
  }
}
