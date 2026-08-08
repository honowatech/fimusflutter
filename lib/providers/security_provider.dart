import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class SecurityProvider extends ChangeNotifier {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final LocalAuthentication _localAuth = LocalAuthentication();

  static const String _appLockPrefKey = 'security_app_lock_enabled';
  static const String _biometricPrefKey = 'security_biometric_enabled';
  static const String _pinSecureKey = 'security_app_lock_pin';
  static const String _failedAttemptsKey = 'security_failed_attempts';
  static const String _lockoutUntilKey = 'security_lockout_until';

  bool _isAppLockEnabled = false;
  bool _isBiometricEnabled = false;
  bool _isAppUnlocked = false;
  bool _isBiometricsAvailable = false;
  int _failedAttempts = 0;
  DateTime? _lockoutUntil;

  bool get isAppLockEnabled => _isAppLockEnabled;
  bool get isBiometricEnabled => _isBiometricEnabled;
  bool get isAppUnlocked => _isAppUnlocked;
  bool get isBiometricsAvailable => _isBiometricsAvailable;
  int get failedAttempts => _failedAttempts;
  DateTime? get lockoutUntil => _lockoutUntil;
  bool get isLockedOut => _lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!);

  String _hashPin(String pin) {
    var bytes = utf8.encode(pin + 'monitrack_salt_'); // Added a static salt
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  SecurityProvider() {
    _initSecuritySettings();
  }

  Future<void> _initSecuritySettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isAppLockEnabled = prefs.getBool(_appLockPrefKey) ?? false;
    _isBiometricEnabled = prefs.getBool(_biometricPrefKey) ?? false;
    
    _failedAttempts = prefs.getInt(_failedAttemptsKey) ?? 0;
    final lockoutStr = prefs.getString(_lockoutUntilKey);
    if (lockoutStr != null) {
      _lockoutUntil = DateTime.tryParse(lockoutStr);
    }

    // If lock is not enabled, mark as unlocked
    if (!_isAppLockEnabled) {
      _isAppUnlocked = true;
    } else {
      _isAppUnlocked = false;
    }

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
    final prefs = await SharedPreferences.getInstance();
    
    if (isLockedOut) {
      return false; // Still locked out
    }
    
    if (_lockoutUntil != null && DateTime.now().isAfter(_lockoutUntil!)) {
      _failedAttempts = 0;
      _lockoutUntil = null;
      await prefs.remove(_failedAttemptsKey);
      await prefs.remove(_lockoutUntilKey);
      notifyListeners();
    }

    final savedPinInfo = await _secureStorage.read(key: _pinSecureKey);
    if (savedPinInfo == null) return false;

    final inputHash = _hashPin(pin);

    if (savedPinInfo == inputHash || savedPinInfo == pin) {
      _isAppUnlocked = true;
      _failedAttempts = 0;
      await prefs.remove(_failedAttemptsKey);
      await prefs.remove(_lockoutUntilKey);
      
      // Auto upgrade unhashed pin
      if (savedPinInfo == pin) {
         await _secureStorage.write(key: _pinSecureKey, value: inputHash);
      }
      
      notifyListeners();
      return true;
    }
    
    _failedAttempts++;
    await prefs.setInt(_failedAttemptsKey, _failedAttempts);
    
    if (_failedAttempts >= 5) {
       _lockoutUntil = DateTime.now().add(const Duration(minutes: 1));
       await prefs.setString(_lockoutUntilKey, _lockoutUntil!.toIso8601String());
    }
    notifyListeners();
    return false;
  }

  /// Authenticate with Biometrics (Fingerprint/Face ID).
  Future<bool> authenticateWithBiometrics() async {
    if (!_isAppLockEnabled || !_isBiometricEnabled || !_isBiometricsAvailable) {
      return false;
    }

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
    final inputHash = _hashPin(pin);
    await _secureStorage.write(key: _pinSecureKey, value: inputHash);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_appLockPrefKey, true);
    
    _isAppLockEnabled = true;
    _isAppUnlocked = true;
    notifyListeners();
  }

  /// Disable App Lock. Must verify with current PIN.
  Future<bool> disableAppLock(String pin) async {
    final savedPin = await _secureStorage.read(key: _pinSecureKey);
    final inputHash = _hashPin(pin);
    if (savedPin != inputHash && savedPin != pin) {
      return false;
    }

    await _secureStorage.delete(key: _pinSecureKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_appLockPrefKey, false);
    await prefs.setBool(_biometricPrefKey, false);

    _isAppLockEnabled = false;
    _isBiometricEnabled = false;
    _isAppUnlocked = true;
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

  /// Change existing PIN.
  Future<bool> changePin(String oldPin, String newPin) async {
    final savedPin = await _secureStorage.read(key: _pinSecureKey);
    final oldInputHash = _hashPin(oldPin);
    if (savedPin != oldInputHash && savedPin != oldPin) {
      return false;
    }

    final newHash = _hashPin(newPin);
    await _secureStorage.write(key: _pinSecureKey, value: newHash);
    _isAppUnlocked = true;
    notifyListeners();
    return true;
  }
}
