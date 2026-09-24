import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/notification_preferences.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../utils/api_client.dart';
import '../utils/api_config.dart';

/// Cause d'échec de la dernière opération, pour permettre à l'UI d'afficher un
/// message localisé sans dépendre du texte renvoyé par le serveur.
enum NotificationPreferencesError { fetch, update }

class NotificationPreferencesProvider extends ChangeNotifier {
  /// Clé du cache local. Les préférences sont relues hors ligne par les
  /// modules de rappels locaux (filtrage des notifications programmées).
  static const String cacheKey = 'notification_preferences_cache';

  NotificationPreferences? _preferences;
  bool _isLoading = false;
  bool _isSaving = false;
  NotificationPreferencesError? _lastError;

  Dio get _dio => ApiClient.instance;

  NotificationPreferences? get preferences => _preferences;

  /// Préférences effectives : celles connues, sinon les valeurs par défaut.
  NotificationPreferences get effectivePreferences =>
      _preferences ?? const NotificationPreferences();

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  NotificationPreferencesError? get lastError => _lastError;
  bool get hasError => _lastError != null;

  Future<String?> _token() => AuthService().getToken();

  void clearError() {
    if (_lastError == null) return;
    _lastError = null;
    notifyListeners();
  }

  // --- Cache local ---------------------------------------------------------

  /// Recharge les préférences depuis le stockage local. À appeler avant
  /// [fetchPreferences] pour afficher immédiatement les dernières valeurs
  /// connues, y compris hors ligne.
  Future<void> loadCachedPreferences() async {
    if (_preferences != null) return;
    final cached = await readCachedPreferences();
    if (cached == null || _preferences != null) return;
    _preferences = cached;
    notifyListeners();
  }

  /// Lecture du cache sans passer par le provider : utilisable depuis un
  /// isolat ou un service de rappels locaux.
  static Future<NotificationPreferences?> readCachedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(cacheKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return NotificationPreferences.fromJson(
        Map<String, dynamic>.from(decoded),
      );
    } catch (e) {
      debugPrint('Error reading cached notification preferences: $e');
      return null;
    }
  }

  Future<void> _cachePreferences(NotificationPreferences value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(cacheKey, jsonEncode(value.toJson()));
    } catch (e) {
      debugPrint('Error caching notification preferences: $e');
    }
  }

  /// Supprime le cache local (déconnexion / changement de compte).
  Future<void> clearCache() async {
    _preferences = null;
    _lastError = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(cacheKey);
    } catch (e) {
      debugPrint('Error clearing cached notification preferences: $e');
    }
    notifyListeners();
  }

  // --- Réseau --------------------------------------------------------------

  Future<void> fetchPreferences() async {
    final token = await _token();
    if (token == null) return;

    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      final response = await _dio.get(
        '${ApiConfig.baseUrl}/users/notification-preferences',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200 && response.data is Map) {
        final fetched = NotificationPreferences.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
        _preferences = fetched;
        await _cachePreferences(fetched);
      } else {
        _lastError = NotificationPreferencesError.fetch;
      }
    } catch (e) {
      debugPrint('Error fetching notification preferences: $e');
      _lastError = NotificationPreferencesError.fetch;
      // Repli hors ligne : on garde/restaure la dernière valeur connue.
      _preferences ??= await readCachedPreferences();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Applique [newPrefs] de façon optimiste puis les envoie au serveur.
  /// En cas d'échec (réponse non 200, corps inattendu ou exception), l'état
  /// précédent est restauré et [lastError] est renseigné.
  ///
  /// Renvoie `true` si le serveur a bien enregistré la modification.
  Future<bool> updatePreferences(NotificationPreferences newPrefs) async {
    final token = await _token();
    if (token == null) return false;

    final previous = _preferences;
    _preferences = newPrefs;
    _isSaving = true;
    _lastError = null;
    notifyListeners();

    try {
      final response = await _dio.post(
        '${ApiConfig.baseUrl}/users/notification-preferences',
        data: newPrefs.toJson(),
        options: Options(headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        }),
      );

      if (response.statusCode == 200) {
        // Le serveur fait foi quand il renvoie l'objet complet ; sinon on
        // conserve la valeur envoyée.
        final confirmed = response.data is Map
            ? NotificationPreferences.fromJson(
                Map<String, dynamic>.from(response.data as Map),
              )
            : newPrefs;
        _preferences = confirmed;
        await _cachePreferences(confirmed);
        // Les rappels locaux déjà planifiés lisent ce cache : sans cette
        // réconciliation, une nouvelle heure de rappel ou des heures calmes
        // ne s'appliqueraient qu'aux rappels créés ensuite.
        unawaited(NotificationService().reconcileAfterPreferencesChange());
        return true;
      }

      _rollback(previous);
      return false;
    } catch (e) {
      debugPrint('Error updating notification preferences: $e');
      _rollback(previous);
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  void _rollback(NotificationPreferences? previous) {
    _preferences = previous;
    _lastError = NotificationPreferencesError.update;
  }
}
