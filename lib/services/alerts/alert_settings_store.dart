import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/user_profile.dart';
import 'alert_settings.dart';
import 'alert_state.dart';

/// Persistance des réglages d'alertes et de l'état anti-spam.
///
/// **Limite assumée** : SharedPreferences, donc stockage *local à l'appareil*.
/// Faute de table SQLite (hors périmètre de ce sprint) et d'endpoint serveur,
/// les budgets et les seuils de solde **ne suivent pas l'utilisateur** lors
/// d'un changement de téléphone ni d'une réinstallation. Un schéma de table et
/// une API sont proposés dans le rapport de sprint pour lever cette limite.
///
/// Clés utilisées (documentées ici et dans le rapport) :
///  * `alerts_settings_v1` — JSON de [AlertSettings] ;
///  * `alerts_emission_state_v1` — JSON de [AlertEmissionState].
///
/// Le suffixe `_v1` permet d'abandonner un format devenu incompatible sans
/// migration : une clé inconnue est simplement ignorée et les valeurs par
/// défaut reprennent la main.
class AlertSettingsStore {
  const AlertSettingsStore();

  static const String settingsKey = 'alerts_settings_v1';
  static const String stateKey = 'alerts_emission_state_v1';

  /// Clé SharedPreferences du profil, écrite par `ProfileProvider` : source de
  /// la devise affichée dans les alertes.
  static const String profileKey = 'user_profile';

  /// Devise de repli, identique à celle de `ExpenseProvider`.
  static const String fallbackCurrency = 'XAF';

  Future<AlertSettings> readSettings() async {
    final decoded = await _readJson(settingsKey);
    if (decoded == null) return const AlertSettings();
    return AlertSettings.fromJson(decoded);
  }

  Future<void> writeSettings(AlertSettings settings) =>
      _writeJson(settingsKey, settings.toJson());

  Future<AlertEmissionState> readState() async {
    final decoded = await _readJson(stateKey);
    if (decoded == null) return AlertEmissionState.empty;
    return AlertEmissionState.fromJson(decoded);
  }

  Future<void> writeState(AlertEmissionState state) =>
      _writeJson(stateKey, state.toJson());

  /// Devise du profil local. Lue à chaque évaluation : elle ne change qu'au
  /// profil et l'alerte doit afficher la devise courante.
  Future<String> readCurrency() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(profileKey);
      if (raw == null || raw.isEmpty) return fallbackCurrency;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return fallbackCurrency;
      final currency =
          UserProfile.fromJson(Map<String, dynamic>.from(decoded)).currency;
      return currency.isEmpty ? fallbackCurrency : currency;
    } catch (e) {
      debugPrint('Error reading currency for alerts: $e');
      return fallbackCurrency;
    }
  }

  /// Remet l'état anti-spam à zéro sans toucher aux réglages : utilisé quand
  /// l'utilisateur réactive une alerte et veut repartir d'une page blanche.
  Future<void> resetState() => writeState(AlertEmissionState.empty);

  /// Efface réglages **et** état (déconnexion / changement de compte : les
  /// budgets d'un utilisateur ne doivent pas s'appliquer au suivant).
  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(settingsKey);
      await prefs.remove(stateKey);
    } catch (e) {
      debugPrint('Error clearing alert settings: $e');
    }
  }

  Future<Map<String, dynamic>?> _readJson(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return Map<String, dynamic>.from(decoded);
    } catch (e) {
      debugPrint('Error reading $key: $e');
      return null;
    }
  }

  Future<void> _writeJson(String key, Map<String, dynamic> value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(value));
    } catch (e) {
      debugPrint('Error writing $key: $e');
    }
  }
}
