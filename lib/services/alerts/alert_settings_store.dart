import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/notification_preferences.dart';
import '../../models/user_profile.dart';
import 'alert_settings.dart';
import 'alert_settings_sync.dart';
import 'alert_state.dart';

/// Persistance des réglages d'alertes, du journal de synchronisation des
/// seuils et de l'état anti-spam.
///
/// Clés utilisées :
///  * `alerts_settings_v1` — JSON de [AlertSettings], **cache de lecture** de
///    l'évaluateur (hors ligne) ;
///  * `alerts_settings_sync_v1` — journal des lignes de la section serveur
///    `alert_settings`, avec leur métadonnée locale `is_synced` ;
///  * `alerts_settings_sync_migrated_v1` — drapeau de la **migration
///    one-shot** des seuils déjà présents avant le sprint 7 ;
///  * `alerts_emission_state_v1` — JSON de [AlertEmissionState], **strictement
///    local** : il décrit ce que *cet* appareil a déjà affiché et n'est jamais
///    poussé ni descendu.
///
/// Le suffixe `_v1` permet d'abandonner un format devenu incompatible sans
/// migration : une clé inconnue est simplement ignorée et les valeurs par
/// défaut reprennent la main.
///
/// Portabilité : les budgets et les seuils **suivent** désormais l'utilisateur
/// d'un téléphone à l'autre, via `SyncService` (section `alert_settings`). Les
/// trois interrupteurs de famille et le délai, eux, viennent des préférences
/// serveur et ne sont ici qu'un miroir (voir [mirrorNotificationPreferences]).
class AlertSettingsStore {
  const AlertSettingsStore();

  static const String settingsKey = 'alerts_settings_v1';
  static const String stateKey = 'alerts_emission_state_v1';
  static const String syncKey = 'alerts_settings_sync_v1';
  static const String migrationKey = 'alerts_settings_sync_migrated_v1';

  /// Clé SharedPreferences du profil, écrite par `ProfileProvider` : source de
  /// la devise affichée dans les alertes.
  static const String profileKey = 'user_profile';

  /// Devise de repli, identique à celle de `ExpenseProvider`.
  static const String fallbackCurrency = 'XAF';

  // --- Réglages (cache de lecture de l'évaluateur) -------------------------

  Future<AlertSettings> readSettings() async {
    final decoded = await _readJson(settingsKey);
    if (decoded == null) return const AlertSettings();
    return AlertSettings.fromJson(decoded);
  }

  Future<void> writeSettings(AlertSettings settings) =>
      _writeJson(settingsKey, settings.toJson());

  /// Rafraîchit le miroir des trois interrupteurs et du délai depuis les
  /// préférences serveur. N'écrit rien si le miroir est déjà à jour.
  ///
  /// Appelé par `NotificationPreferencesProvider` après chaque lecture ou
  /// écriture réussie, et par `LocalAlertsService` avant chaque évaluation
  /// (filet de sécurité : le miroir converge même si une écriture a été
  /// manquée, et sans le moindre appel réseau).
  Future<AlertSettings> mirrorNotificationPreferences(
    NotificationPreferences preferences,
  ) async {
    final current = await readSettings();
    final next = current.withNotificationPreferences(preferences);
    if (!identical(next, current)) await writeSettings(next);
    return next;
  }

  // --- État anti-spam (jamais synchronisé) ---------------------------------

  Future<AlertEmissionState> readState() async {
    final decoded = await _readJson(stateKey);
    if (decoded == null) return AlertEmissionState.empty;
    return AlertEmissionState.fromJson(decoded);
  }

  Future<void> writeState(AlertEmissionState state) =>
      _writeJson(stateKey, state.toJson());

  /// Remet l'état anti-spam à zéro sans toucher aux réglages : utilisé quand
  /// l'utilisateur réactive une alerte et veut repartir d'une page blanche.
  Future<void> resetState() => writeState(AlertEmissionState.empty);

  // --- Journal de synchronisation des seuils ------------------------------

  /// Journal courant, indexé par clé métier (`kind|target`). La migration
  /// one-shot est déclenchée au passage : c'est le seul endroit qui la lance.
  Future<Map<String, AlertSettingRow>> readSyncRows() async {
    await ensureMigrated();
    return _readSyncRowsRaw();
  }

  Future<Map<String, AlertSettingRow>> _readSyncRowsRaw() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(syncKey);
      if (raw == null || raw.isEmpty) return <String, AlertSettingRow>{};
      return decodeAlertSettingRows(jsonDecode(raw));
    } catch (e) {
      debugPrint('Error reading $syncKey: $e');
      return <String, AlertSettingRow>{};
    }
  }

  /// Écrit le journal. Renvoie `false` si l'écriture a échoué — le drapeau de
  /// migration ne doit pas être posé sur un journal qui n'a pas été enregistré.
  Future<bool> _writeSyncRows(Map<String, AlertSettingRow> rows) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(
        syncKey,
        jsonEncode(encodeAlertSettingRows(rows.values)),
      );
    } catch (e) {
      debugPrint('Error writing $syncKey: $e');
      return false;
    }
  }

  /// **Migration one-shot** des seuils déjà réglés avant le sprint 7.
  ///
  /// Sans elle, le journal partirait vide et les budgets et seuils existants ne
  /// remonteraient jamais au serveur. Elle est :
  ///  * **idempotente** — gardée par le drapeau [migrationKey], posé même
  ///    quand il n'y avait rien à migrer, et les lignes déjà présentes dans le
  ///    journal ne sont pas écrasées ;
  ///  * **sans réseau** — elle ne fait que remplir le journal ; c'est le
  ///    premier `push()` venu qui l'envoie.
  Future<void> ensureMigrated() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(migrationKey) == true) return;

      final settings = await readSettings();
      final existing = await _readSyncRowsRaw();
      final now = DateTime.now();
      var changed = false;
      for (final row in migrationRowsFrom(settings, now: now)) {
        // Une ligne déjà connue du journal (pull antérieur, écriture récente)
        // fait autorité : la migration ne la réécrit pas.
        if (existing.containsKey(row.key)) continue;
        existing[row.key] = row;
        changed = true;
      }
      // Le drapeau n'est posé que si le journal a bien été enregistré : sinon
      // la migration sera retentée au prochain passage, sans perte.
      if (changed && !await _writeSyncRows(existing)) return;
      await prefs.setBool(migrationKey, true);
      debugPrint('Alert settings migration: ${existing.length} row(s) queued');
    } catch (e) {
      // Drapeau non posé : la migration sera retentée au prochain passage.
      debugPrint('Error migrating alert settings to sync journal: $e');
    }
  }

  /// Lignes à envoyer au prochain `sync/push` (journal non acquitté).
  Future<List<AlertSettingRow>> readPendingPush() async {
    final rows = await readSyncRows();
    final pending = rows.values.where((row) => !row.isSynced).toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return pending;
  }

  /// Acquitte les lignes envoyées.
  ///
  /// Le rapprochement se fait sur le couple (clé métier, `updated_at`) : une
  /// modification faite pendant l'envoi porte un horodatage différent et reste
  /// donc en attente au lieu d'être perdue. Les suppressions acquittées sont
  /// retirées du journal (leur pierre tombale n'a plus d'objet).
  Future<void> markPushed(Iterable<AlertSettingRow> sent) async {
    if (sent.isEmpty) return;
    final rows = await _readSyncRowsRaw();
    var changed = false;
    for (final row in sent) {
      final current = rows[row.key];
      if (current == null || current.updatedAt != row.updatedAt) continue;
      if (current.isDeleted) {
        rows.remove(row.key);
      } else {
        rows[row.key] = current.copyWith(
          syncAction: alertSyncActionUpdated,
          isSynced: true,
        );
      }
      changed = true;
    }
    if (changed) await _writeSyncRows(rows);
  }

  /// Applique la section `alert_settings` d'un `sync/pull`.
  ///
  /// Le serveur exclut déjà les lignes supprimées et fournit `updated_at` :
  /// l'arbitrage est un **dernier écrivain gagnant** pur (voir
  /// [mergePulledAlertSettings]). Le cache de lecture est reprojeté ensuite,
  /// ce qui **hydrate** budgets et seuils, y compris au premier lancement sur
  /// un appareil neuf (journal vide, migration sans rien à porter).
  ///
  /// Renvoie le nombre de lignes serveur retenues.
  Future<int> applyPulledRows(Object? section) async {
    if (section is! List) return 0;
    final remote = <AlertSettingRow>[];
    for (final item in section) {
      final row = AlertSettingRow.fromServerJson(item);
      // Une ligne supprimée ne devrait pas descendre ; si elle descend, elle
      // est ignorée plutôt que réinsérée.
      if (row == null || row.isDeleted) continue;
      remote.add(row);
    }

    // La migration passe **avant** la fusion : les seuils réglés hors ligne
    // deviennent des lignes en attente et peuvent gagner l'arbitrage.
    final local = await readSyncRows();
    if (remote.isEmpty) return 0;

    final merged = mergePulledAlertSettings(local: local, remote: remote);
    await _writeSyncRows(merged);
    await _reprojectAndRead(merged);
    return remote.length;
  }

  // --- Écritures utilisateur ----------------------------------------------

  /// Enregistre le budget mensuel d'une catégorie. [amount] `null` ou ≤ 0 vaut
  /// **suppression** (règle du contrat).
  ///
  /// Met à jour le journal (ligne en attente) **et** le cache de lecture, dans
  /// cet ordre, pour qu'une évaluation concurrente ne voie jamais un cache
  /// plus avancé que le journal.
  Future<AlertSettings> saveCategoryBudget(
    String category,
    double? amount, {
    DateTime? now,
  }) =>
      _saveRow(
        kind: AlertSettingKind.budget,
        target: category,
        amount: amount == null || amount <= 0 ? null : amount,
        now: now,
      );

  /// Enregistre le seuil de solde bas d'un compte. Seul `null` supprime : un
  /// seuil à 0 est une **valeur valide** à conserver.
  Future<AlertSettings> saveAccountThreshold(
    String accountId,
    double? amount, {
    DateTime? now,
  }) =>
      _saveRow(
        kind: AlertSettingKind.lowBalance,
        target: accountId,
        amount: amount,
        now: now,
      );

  Future<AlertSettings> _saveRow({
    required AlertSettingKind kind,
    required String target,
    required double? amount,
    DateTime? now,
  }) async {
    final rows = await readSyncRows();
    final normalized = AlertSettingRow.fromStoreJson({
      'kind': kind.wire,
      'target': target,
      // Une suppression conserve le dernier montant connu : le serveur reçoit
      // une ligne complète, et le champ n'est de toute façon pas lu.
      'amount': amount ?? 0,
      'updated_at': (now ?? DateTime.now()).toIso8601String(),
    });
    if (normalized == null) return readSettings();

    final existing = rows[normalized.key];
    if (amount == null) {
      // Rien à supprimer côté serveur si la ligne n'y est jamais montée.
      if (existing == null) {
        return _reprojectAndRead(rows);
      }
      if (!existing.isSynced && existing.syncAction == alertSyncActionCreated) {
        rows.remove(normalized.key);
      } else {
        rows[normalized.key] = existing.copyWith(
          syncAction: alertSyncActionDeleted,
          updatedAt: normalized.updatedAt,
          isSynced: false,
        );
      }
    } else {
      rows[normalized.key] = normalized.copyWith(
        syncAction: existing == null || !existing.isSynced
            ? alertSyncActionCreated
            : alertSyncActionUpdated,
        isSynced: false,
      );
    }
    await _writeSyncRows(rows);
    return _reprojectAndRead(rows);
  }

  Future<AlertSettings> _reprojectAndRead(
      Map<String, AlertSettingRow> rows) async {
    final current = await readSettings();
    final next = projectAlertSettings(current, rows.values);
    if (next != current) await writeSettings(next);
    return next;
  }

  // --- Devise --------------------------------------------------------------

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

  // --- Maintenance ---------------------------------------------------------

  /// Efface réglages, journal de synchronisation, drapeau de migration **et**
  /// état (déconnexion / changement de compte : les budgets d'un utilisateur
  /// ne doivent pas s'appliquer au suivant, et le compte suivant doit repartir
  /// d'une migration neuve).
  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(settingsKey);
      await prefs.remove(stateKey);
      await prefs.remove(syncKey);
      await prefs.remove(migrationKey);
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
