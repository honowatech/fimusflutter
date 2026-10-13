import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/alerts/alert_settings.dart';
import '../services/alerts/alert_settings_store.dart';
import '../services/alerts/local_alerts_service.dart';
import '../services/sync_service.dart';

/// Budgets par catégorie et seuils de solde bas, exposés à l'écran
/// « Profil → Notifications ».
///
/// **Source de vérité des interrupteurs** : depuis le sprint 7, les trois
/// interrupteurs de famille (budget, solde bas, données non synchronisées) et
/// le délai d'ancienneté vivent dans les préférences serveur
/// (`NotificationPreferencesProvider`, clés `notify_budget_threshold`,
/// `notify_low_balance`, `notify_unsynced_data`, `unsynced_threshold_hours`).
/// Ce provider ne les écrit plus : `AlertSettings` n'en garde qu'un miroir
/// hors ligne, rafraîchi par `AlertSettingsStore.mirrorNotificationPreferences`.
/// Il ne reste ici que ce dont le serveur ne décide pas : **quelles** cibles
/// sont surveillées et **à quel montant**.
///
/// Ces montants sont désormais **portables** : chaque écriture pose une ligne
/// en attente dans le journal de synchronisation et déclenche un `push()`. Le
/// verrou de push de `SyncService` absorbe les rafales (réglage de plusieurs
/// budgets à la suite).
///
/// Après toute modification, l'état anti-spam **n'est pas** remis à zéro : un
/// utilisateur qui remonte un budget ne doit pas recevoir une seconde fois
/// l'alerte « 80 % » du mois en cours. La méthode [resetEmissionState] le
/// permet explicitement.
class AlertSettingsProvider extends ChangeNotifier {
  AlertSettingsProvider({
    AlertSettingsStore? store,
    LocalAlertsService? service,
    SyncService? sync,
  })  : _store = store ?? const AlertSettingsStore(),
        _service = service ?? LocalAlertsService.instance,
        _sync = sync ?? SyncService();

  final AlertSettingsStore _store;
  final LocalAlertsService _service;
  final SyncService _sync;

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
  ///
  /// Déclenche au passage la **migration one-shot** des seuils déjà réglés vers
  /// le journal de synchronisation, puis un `push()` s'il y a de quoi envoyer :
  /// sans cela, un utilisateur qui n'ouvre plus l'écran ne verrait jamais ses
  /// anciens réglages remonter.
  Future<void> load() async {
    if (_loaded || _isLoading) return;
    _isLoading = true;
    notifyListeners();
    try {
      _settings = await _store.readSettings();
      _loaded = true;
      unawaited(_pushIfPending());
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Relecture forcée (retour sur l'écran, ou hydratation par un `sync/pull`).
  Future<void> reload() {
    _loaded = false;
    return load();
  }

  // --- Budgets et seuils ---------------------------------------------------

  /// Définit le budget mensuel d'une catégorie. [amount] `null` (ou ≤ 0)
  /// retire la surveillance de cette catégorie — c'est la règle du contrat
  /// serveur : un budget à ≤ 0 vaut suppression.
  Future<void> setCategoryBudget(String category, double? amount) =>
      _apply(() => _store.saveCategoryBudget(category, amount));

  /// Définit le seuil de solde bas d'un compte. [amount] `null` retire la
  /// surveillance ; 0 reste un seuil valide.
  Future<void> setAccountThreshold(String accountId, double? amount) =>
      _apply(() => _store.saveAccountThreshold(accountId, amount));

  // --- Maintenance ---------------------------------------------------------

  /// Autorise à nouveau les alertes déjà vues (paliers de budget du mois,
  /// comptes armés, dernière alerte de synchronisation).
  ///
  /// Purement local : l'état anti-spam n'est jamais synchronisé.
  Future<void> resetEmissionState() => _service.resetEmissionState();

  /// Déconnexion / changement de compte : les budgets d'un utilisateur ne
  /// doivent pas s'appliquer au suivant. Efface aussi le journal et le drapeau
  /// de migration, pour que le compte suivant reparte d'une migration neuve.
  Future<void> clear() async {
    _settings = const AlertSettings();
    _loaded = false;
    await _service.clear();
    notifyListeners();
  }

  Future<void> _apply(Future<AlertSettings> Function() write) async {
    _isSaving = true;
    notifyListeners();
    try {
      _settings = await write();
      _loaded = true;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
    // Hors du `finally` : l'envoi ne doit pas retarder l'affichage.
    unawaited(_pushIfPending());
  }

  /// Envoie le journal s'il reste des lignes non acquittées. Ne lève jamais :
  /// hors ligne, les lignes repartiront au prochain push.
  Future<void> _pushIfPending() async {
    try {
      final pending = await _store.readPendingPush();
      if (pending.isEmpty) return;
      await _sync.push();
    } catch (e) {
      debugPrint('Error pushing alert settings: $e');
    }
  }
}
