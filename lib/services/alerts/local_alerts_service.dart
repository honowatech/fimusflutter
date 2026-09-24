import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../l10n/app_localizations.dart';
import '../../models/account.dart';
import '../../models/expense.dart';
import '../../models/notification_preferences.dart';
import '../notifications/local_notification_settings.dart';
import '../notifications/notification_texts.dart';
import '../notifications/reminder_plan.dart' show loadReminderPreferences;
import 'alert_evaluator.dart';
import 'alert_models.dart';
import 'alert_settings.dart';
import 'alert_settings_store.dart';
import 'alert_texts.dart';
import 'unsynced_probe.dart';

/// Compte rendu d'une évaluation, pour les appelants et les traces.
@immutable
class AlertRunReport {
  const AlertRunReport({
    this.emitted = const <PendingAlert>[],
    this.deferred = const <PendingAlert>[],
    this.skipped = false,
  });

  /// Alertes réellement affichées.
  final List<PendingAlert> emitted;

  /// Alertes retenues (heures calmes ou plafond par passage).
  final List<PendingAlert> deferred;

  /// `true` si l'évaluation n'a pas eu lieu (anti-rebond, ou toutes les
  /// alertes désactivées).
  final bool skipped;

  static const AlertRunReport skippedRun = AlertRunReport(skipped: true);
}

/// Alertes locales de finances personnelles : budget par catégorie, solde bas
/// par compte, données non synchronisées.
///
/// Rôle : **orchestration uniquement**. Il lit les réglages et l'état
/// (SharedPreferences), les préférences de notification (heures calmes), la
/// photographie des données non synchronisées (SQLite, lecture seule), délègue
/// **toute la décision** à `evaluateAlerts` (fonction pure), puis affiche les
/// alertes retenues et persiste le nouvel état anti-spam.
///
/// Il n'écrit dans aucune table, ne modifie aucun provider métier et ne prend
/// jamais de `BuildContext`.
class LocalAlertsService {
  LocalAlertsService({
    AlertSettingsStore? store,
    UnsyncedProbe? probe,
    FlutterLocalNotificationsPlugin? plugin,
    Future<NotificationPreferences> Function()? preferencesLoader,
  })  : _store = store ?? const AlertSettingsStore(),
        _probe = probe ?? const UnsyncedProbe(),
        // `FlutterLocalNotificationsPlugin()` est une fabrique singleton : on
        // partage l'instance déjà initialisée par `NotificationService`.
        _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
        _loadPreferences = preferencesLoader ?? loadReminderPreferences;

  /// Instance applicative. Les tests construisent la leur avec des doubles.
  static final LocalAlertsService instance = LocalAlertsService();

  /// Fenêtre anti-rebond : une opération déclenche souvent plusieurs
  /// notifications de providers à la suite (ajout de dépense + mise à jour du
  /// solde + synchronisation), qui ne doivent produire qu'une évaluation.
  static const Duration evaluationDebounce = Duration(seconds: 10);

  final AlertSettingsStore _store;
  final UnsyncedProbe _probe;
  final FlutterLocalNotificationsPlugin _plugin;
  final Future<NotificationPreferences> Function() _loadPreferences;

  DateTime? _lastRunAt;
  Future<AlertRunReport>? _inFlight;

  /// Réglages courants (lecture directe, pour un appelant qui n'a pas le
  /// provider sous la main).
  Future<AlertSettings> readSettings() => _store.readSettings();

  /// Évalue les trois alertes à partir de données **déjà chargées** par les
  /// providers métier.
  ///
  /// [expenses] : les dépenses connues (`ExpenseProvider.expenses`) ; seules
  /// celles du mois en cours sont retenues par l'évaluateur.
  /// [accounts] : les comptes connus (`AccountProvider.accounts`).
  /// [force] : ignore l'anti-rebond (changement de réglage, action explicite).
  ///
  /// Ne lève jamais : toute erreur est tracée et renvoie un rapport vide.
  Future<AlertRunReport> evaluate({
    required Iterable<Expense> expenses,
    required Iterable<Account> accounts,
    DateTime? now,
    bool force = false,
  }) {
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;

    final last = _lastRunAt;
    final moment = now ?? DateTime.now();
    if (!force &&
        last != null &&
        moment.difference(last) < evaluationDebounce &&
        !moment.difference(last).isNegative) {
      return Future.value(AlertRunReport.skippedRun);
    }

    // La liste des providers peut changer pendant l'évaluation (await) : on
    // fige une copie avant tout point d'attente.
    final expensesSnapshot = List<Expense>.unmodifiable(expenses);
    final accountsSnapshot = List<Account>.unmodifiable(accounts);

    final future = _run(expensesSnapshot, accountsSnapshot, moment)
        .whenComplete(() {
      _lastRunAt = DateTime.now();
      _inFlight = null;
    });
    _inFlight = future;
    return future;
  }

  Future<AlertRunReport> _run(
    List<Expense> expenses,
    List<Account> accounts,
    DateTime now,
  ) async {
    try {
      final settings = await _store.readSettings();
      if (!settings.hasAnyAlertEnabled) {
        // Tout est coupé : on ne notifie rien, mais on purge les paliers des
        // mois écoulés, sans quoi la carte d'état ne redescendrait jamais.
        final stale = await _store.readState();
        final pruned = stale.pruneBudgetTiers(now);
        if (!identical(pruned, stale)) await _store.writeState(pruned);
        return AlertRunReport.skippedRun;
      }

      final state = await _store.readState();
      final preferences = await _loadPreferences();
      final currency = await _store.readCurrency();

      // La sonde SQLite n'est déclenchée que si l'alerte correspondante est
      // active : inutile d'interroger cinq tables pour rien.
      final unsynced = settings.unsyncedDataAlertsEnabled
          ? await _probe.read()
          : const UnsyncedSnapshot.empty();

      final evaluation = evaluateAlerts(
        settings: settings,
        state: state,
        notificationPreferences: preferences,
        expenses: expenses,
        accounts: accounts,
        unsynced: unsynced,
        now: now,
        currency: currency,
      );

      if (evaluation.nextState != state) {
        await _store.writeState(evaluation.nextState);
      }
      if (evaluation.toEmit.isEmpty) {
        return AlertRunReport(deferred: evaluation.deferred);
      }

      final texts = await NotificationTexts.loadLocale();
      final emitted = <PendingAlert>[];
      for (final alert in evaluation.toEmit) {
        if (await _show(alert, texts)) emitted.add(alert);
      }

      debugPrint('Local alerts: ${emitted.length} shown, '
          '${evaluation.deferred.length} deferred');
      return AlertRunReport(
        emitted: emitted,
        deferred: evaluation.deferred,
      );
    } catch (e) {
      debugPrint('Error evaluating local alerts: $e');
      return const AlertRunReport();
    }
  }

  /// Affiche une alerte. Renvoie `false` si le plugin n'a pas pu l'afficher
  /// (non initialisé, permission refusée) : l'état anti-spam a déjà été
  /// persisté, on ne réessaiera donc pas en boucle pour la même situation.
  Future<bool> _show(PendingAlert alert, AppLocalizations texts) async {
    try {
      await _plugin.show(
        id: alert.notificationId,
        title: AlertTexts.titleFor(alert, texts),
        body: AlertTexts.bodyFor(alert, texts),
        notificationDetails:
            pushNotificationDetails(alert.notificationType, l10n: texts),
        payload: alert.payload,
      );
      return true;
    } catch (e) {
      debugPrint('Error showing local alert ${alert.notificationType}: $e');
      return false;
    }
  }

  /// Remet l'anti-spam à zéro (les alertes déjà vues pourront se reproduire).
  Future<void> resetEmissionState() => _store.resetState();

  /// Efface réglages et état : à appeler à la déconnexion.
  Future<void> clear() async {
    _lastRunAt = null;
    await _store.clear();
  }
}
