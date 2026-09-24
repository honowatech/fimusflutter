import 'package:flutter/foundation.dart';

import '../services/alerts/alert_settings.dart';
import '../services/alerts/alert_settings_store.dart';
import '../services/alerts/local_alerts_service.dart';

/// Réglages des alertes locales, exposés à l'écran
/// « Profil → Notifications ».
///
/// Purement local : aucune requête réseau, donc aucun état d'erreur serveur ni
/// mise à jour optimiste à annuler, contrairement à
/// `NotificationPreferencesProvider`. Les écritures vont directement en
/// SharedPreferences via `AlertSettingsStore`.
///
/// Après toute modification, l'état anti-spam **n'est pas** remis à zéro : un
/// utilisateur qui remonte un budget ne doit pas recevoir une seconde fois
/// l'alerte « 80 % » du mois en cours. La méthode [resetEmissionState] le
/// permet explicitement.
class AlertSettingsProvider extends ChangeNotifier {
  AlertSettingsProvider({AlertSettingsStore? store, LocalAlertsService? service})
      : _store = store ?? const AlertSettingsStore(),
        _service = service ?? LocalAlertsService.instance;

  final AlertSettingsStore _store;
  final LocalAlertsService _service;

  AlertSettings _settings = const AlertSettings();
  bool _isLoading = false;
  bool _isSaving = false;
  bool _loaded = false;

  AlertSettings get settings => _settings;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get isBusy => _isLoading || _isSaving;

  /// Charge les réglages depuis le stockage local. Idempotent : les appels
  /// suivants ne relisent pas le disque (sauf [reload]).
  Future<void> load() async {
    if (_loaded || _isLoading) return;
    _isLoading = true;
    notifyListeners();
    try {
      _settings = await _store.readSettings();
      _loaded = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Relecture forcée (retour sur l'écran après une modification externe).
  Future<void> reload() {
    _loaded = false;
    return load();
  }

  // --- Interrupteurs -------------------------------------------------------

  Future<void> setBudgetAlertsEnabled(bool value) =>
      _apply(_settings.copyWith(budgetAlertsEnabled: value));

  Future<void> setLowBalanceAlertsEnabled(bool value) =>
      _apply(_settings.copyWith(lowBalanceAlertsEnabled: value));

  Future<void> setUnsyncedDataAlertsEnabled(bool value) =>
      _apply(_settings.copyWith(unsyncedDataAlertsEnabled: value));

  Future<void> setUnsyncedThresholdHours(int hours) =>
      _apply(_settings.copyWith(unsyncedThresholdHours: hours));

  // --- Budgets et seuils ---------------------------------------------------

  /// Définit le budget mensuel d'une catégorie. [amount] `null` (ou ≤ 0)
  /// retire la surveillance de cette catégorie.
  Future<void> setCategoryBudget(String category, double? amount) =>
      _apply(_settings.withCategoryBudget(category, amount));

  /// Définit le seuil de solde bas d'un compte. [amount] `null` retire la
  /// surveillance ; 0 reste un seuil valide.
  Future<void> setAccountThreshold(String accountId, double? amount) =>
      _apply(_settings.withAccountThreshold(accountId, amount));

  // --- Maintenance ---------------------------------------------------------

  /// Autorise à nouveau les alertes déjà vues (paliers de budget du mois,
  /// comptes armés, dernière alerte de synchronisation).
  Future<void> resetEmissionState() => _service.resetEmissionState();

  /// Déconnexion / changement de compte : les budgets d'un utilisateur ne
  /// doivent pas s'appliquer au suivant.
  Future<void> clear() async {
    _settings = const AlertSettings();
    _loaded = false;
    await _service.clear();
    notifyListeners();
  }

  Future<void> _apply(AlertSettings next) async {
    if (next == _settings) return;
    _settings = next;
    _isSaving = true;
    notifyListeners();
    try {
      await _store.writeSettings(next);
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
