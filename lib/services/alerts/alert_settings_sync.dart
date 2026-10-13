import 'package:flutter/foundation.dart';

import '../../utils/category_normalizer.dart';
import 'alert_settings.dart';

/// Portabilité des seuils d'alerte (sprint 7, contrat § 4.2).
///
/// Le serveur expose une section `alert_settings` dans `sync/push` et
/// `sync/pull`. C'est la **seule section sans `id`** : la clé métier est le
/// couple (`kind`, `target`). Ce fichier ne contient que des objets et des
/// fonctions **pures** — la persistance est dans `AlertSettingsStore`, l'envoi
/// dans `SyncService`.
///
/// Ce qui n'est **jamais** synchronisé : l'état anti-spam
/// (`alerts_emission_state_v1`). Il décrit ce que *cet* appareil a déjà
/// affiché ; le porter d'un téléphone à l'autre ferait taire des alertes que
/// le nouvel appareil n'a jamais montrées.

/// Famille d'un réglage portable. Les valeurs de fil sont celles du contrat.
enum AlertSettingKind {
  budget('budget'),
  lowBalance('low_balance');

  const AlertSettingKind(this.wire);

  /// Valeur de la clé `kind` du contrat.
  final String wire;

  /// Reconnaissance tolérante (`low_balance`, `lowBalance`, `LOW-BALANCE`…).
  static AlertSettingKind? fromWire(Object? raw) {
    if (raw == null) return null;
    final normalized =
        raw.toString().toLowerCase().replaceAll(RegExp(r'[_\-\s]'), '');
    for (final kind in AlertSettingKind.values) {
      if (kind.wire.replaceAll('_', '') == normalized) return kind;
    }
    return null;
  }
}

/// Actions de synchronisation acceptées par le contrat.
///
/// Le local note `deleted` ; `delete` est accepté à la relecture et à la
/// descente, comme partout ailleurs dans le protocole.
const String alertSyncActionCreated = 'created';
const String alertSyncActionUpdated = 'updated';
const String alertSyncActionDeleted = 'deleted';

/// Une ligne de la section `alert_settings`, augmentée des métadonnées locales
/// de synchronisation ([isSynced]) que le serveur ne voit jamais.
@immutable
class AlertSettingRow {
  const AlertSettingRow({
    required this.kind,
    required this.target,
    required this.amount,
    required this.updatedAt,
    this.enabled = true,
    this.syncAction = alertSyncActionCreated,
    this.isSynced = false,
  });

  final AlertSettingKind kind;

  /// Catégorie normalisée en Title case (`budget`) ou uuid de compte
  /// (`low_balance`).
  final String target;

  final double amount;

  /// Surveillance active pour *cette* cible. Une ligne désactivée est
  /// conservée (elle garde son montant) mais n'est pas surveillée.
  final bool enabled;

  /// Horodatage du dernier écrivain : c'est lui qui arbitre les conflits.
  final DateTime updatedAt;

  /// `created`, `updated` ou `deleted`.
  final String syncAction;

  /// `false` tant que la ligne n'a pas été acquittée par un push.
  final bool isSynced;

  /// Clé métier du contrat : le couple (`kind`, `target`), faute d'`id`.
  String get key => keyOf(kind, target);

  static String keyOf(AlertSettingKind kind, String target) =>
      '${kind.wire}|$target';

  bool get isDeleted =>
      syncAction == alertSyncActionDeleted || syncAction == 'delete';

  /// `true` si la ligne doit être surveillée par l'évaluateur.
  ///
  /// Un budget à ≤ 0 vaut suppression (règle du contrat) ; un seuil de solde
  /// bas à 0 est une valeur **valide** — « préviens-moi dès que ce compte
  /// passe sous zéro ».
  bool get isWatchable {
    if (isDeleted || !enabled) return false;
    if (kind == AlertSettingKind.budget && amount <= 0) return false;
    return amount.isFinite;
  }

  AlertSettingRow copyWith({
    double? amount,
    bool? enabled,
    DateTime? updatedAt,
    String? syncAction,
    bool? isSynced,
  }) {
    return AlertSettingRow(
      kind: kind,
      target: target,
      amount: amount ?? this.amount,
      enabled: enabled ?? this.enabled,
      updatedAt: updatedAt ?? this.updatedAt,
      syncAction: syncAction ?? this.syncAction,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  /// Corps envoyé au serveur. Sans `id` : la section n'en a pas.
  Map<String, dynamic> toPushJson() => {
        'kind': kind.wire,
        'target': target,
        'amount': amount,
        'enabled': enabled,
        'sync_action': isDeleted ? alertSyncActionDeleted : syncAction,
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };

  /// Forme persistée localement (contrat + métadonnée locale).
  Map<String, dynamic> toStoreJson() => {
        ...toPushJson(),
        'is_synced': isSynced,
      };

  /// Relecture d'une ligne du journal local. `null` si elle est illisible :
  /// une préférence corrompue ne doit jamais faire perdre les alertes.
  static AlertSettingRow? fromStoreJson(Object? raw) =>
      _parse(raw, defaultIsSynced: false);

  /// Relecture d'une ligne descendue du serveur : elle est par construction
  /// déjà synchronisée.
  static AlertSettingRow? fromServerJson(Object? raw) =>
      _parse(raw, defaultIsSynced: true);

  static AlertSettingRow? _parse(Object? raw, {required bool defaultIsSynced}) {
    if (raw is! Map) return null;
    final kind = AlertSettingKind.fromWire(raw['kind']);
    if (kind == null) return null;

    final rawTarget = raw['target']?.toString() ?? '';
    final target = kind == AlertSettingKind.budget
        ? normalizeCategory(rawTarget)
        : rawTarget.trim();
    if (target.isEmpty) return null;

    final amount = _asAmount(raw['amount']);
    if (amount == null) return null;

    final action = raw['sync_action']?.toString().toLowerCase();
    final syncAction = switch (action) {
      'delete' || 'deleted' => alertSyncActionDeleted,
      'created' => alertSyncActionCreated,
      _ => alertSyncActionUpdated,
    };

    return AlertSettingRow(
      kind: kind,
      target: target,
      amount: amount,
      enabled: _asBool(raw['enabled'], true),
      updatedAt: DateTime.tryParse(raw['updated_at']?.toString() ?? '')
              ?.toLocal() ??
          // Sans horodatage, la ligne est réputée très ancienne : elle ne peut
          // pas gagner un arbitrage « dernier écrivain ».
          DateTime.fromMillisecondsSinceEpoch(0),
      syncAction: syncAction,
      isSynced: _asBool(raw['is_synced'], defaultIsSynced),
    );
  }

  static double? _asAmount(Object? value) {
    final parsed = value is num
        ? value.toDouble()
        : (value is String ? double.tryParse(value.trim()) : null);
    if (parsed == null || !parsed.isFinite) return null;
    return parsed;
  }

  static bool _asBool(Object? value, bool fallback) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') return true;
      if (normalized == 'false' || normalized == '0') return false;
    }
    return fallback;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AlertSettingRow &&
          other.kind == kind &&
          other.target == target &&
          other.amount == amount &&
          other.enabled == enabled &&
          other.updatedAt == updatedAt &&
          other.syncAction == syncAction &&
          other.isSynced == isSynced;

  @override
  int get hashCode => Object.hash(
        kind,
        target,
        amount,
        enabled,
        updatedAt,
        syncAction,
        isSynced,
      );

  @override
  String toString() =>
      'AlertSettingRow($key, $amount, enabled: $enabled, $syncAction, '
      'synced: $isSynced, $updatedAt)';
}

/// Relit un journal local complet (liste JSON), en écartant les lignes
/// illisibles. Fonction pure.
Map<String, AlertSettingRow> decodeAlertSettingRows(Object? raw) {
  if (raw is! List) return <String, AlertSettingRow>{};
  final rows = <String, AlertSettingRow>{};
  for (final item in raw) {
    final row = AlertSettingRow.fromStoreJson(item);
    if (row == null) continue;
    // Dernier écrivain gagnant, même en cas de doublon dans le fichier.
    final existing = rows[row.key];
    if (existing != null && existing.updatedAt.isAfter(row.updatedAt)) continue;
    rows[row.key] = row;
  }
  return rows;
}

List<Map<String, dynamic>> encodeAlertSettingRows(
        Iterable<AlertSettingRow> rows) =>
    rows.map((row) => row.toStoreJson()).toList();

/// Fusionne les lignes descendues du serveur dans le journal local.
///
/// **Dernier écrivain gagnant**, arbitré sur `updated_at` :
///  * une ligne locale non encore poussée mais **plus récente** est conservée
///    telle quelle (elle repartira au prochain push) ;
///  * sinon la version serveur remplace la locale et devient synchronisée.
///
/// À égalité stricte d'horodatage, le serveur l'emporte : c'est la seule
/// convention qui fasse converger deux appareils.
///
/// Fonction pure : c'est ici que les tests d'arbitrage se placent.
Map<String, AlertSettingRow> mergePulledAlertSettings({
  required Map<String, AlertSettingRow> local,
  required Iterable<AlertSettingRow> remote,
}) {
  final merged = Map<String, AlertSettingRow>.from(local);
  for (final row in remote) {
    final current = merged[row.key];
    if (current != null &&
        !current.isSynced &&
        current.updatedAt.isAfter(row.updatedAt)) {
      continue;
    }
    // Un budget à ≤ 0 vaut suppression (règle du contrat) : la ligne n'est pas
    // insérée, et une ligne locale devenue caduque est retirée. Un seuil de
    // solde bas à 0, lui, est une valeur valide et suit le chemin normal.
    if (row.kind == AlertSettingKind.budget && row.amount <= 0) {
      merged.remove(row.key);
      continue;
    }
    // Le pull exclut les lignes supprimées ; une ligne descendue est donc
    // vivante, et son action locale devient « à jour ».
    merged[row.key] = row.copyWith(
      syncAction: alertSyncActionUpdated,
      isSynced: true,
    );
  }
  return merged;
}

/// Projette le journal sur les deux cartes que lit l'évaluateur (fonction
/// pure). Les interrupteurs de famille et le délai ne sont **pas** touchés :
/// ils viennent des préférences serveur (voir `AlertSettings`).
AlertSettings projectAlertSettings(
  AlertSettings base,
  Iterable<AlertSettingRow> rows,
) {
  final budgets = <String, double>{};
  final thresholds = <String, double>{};
  for (final row in rows) {
    if (!row.isWatchable) continue;
    switch (row.kind) {
      case AlertSettingKind.budget:
        budgets[row.target] = row.amount;
      case AlertSettingKind.lowBalance:
        thresholds[row.target] = row.amount;
    }
  }
  return base.copyWith(
    categoryBudgets: budgets,
    accountThresholds: thresholds,
  );
}

/// Journal de départ construit à partir de réglages déjà présents en
/// SharedPreferences : c'est le cœur de la **migration one-shot**.
///
/// Sans elle, les budgets et seuils réglés avant le sprint 7 ne remonteraient
/// jamais : le journal serait vide, donc aucun push. Toutes les lignes
/// produites sont `created` et non synchronisées ; `enabled` vaut `true` (un
/// montant enregistré était par définition surveillé — la coupure par famille
/// vit désormais dans les préférences serveur).
///
/// Fonction pure ; son caractère « une seule fois » est porté par le drapeau
/// `AlertSettingsStore.migrationKey`.
List<AlertSettingRow> migrationRowsFrom(
  AlertSettings settings, {
  required DateTime now,
}) {
  final rows = <AlertSettingRow>[];
  settings.categoryBudgets.forEach((category, amount) {
    if (amount <= 0) return; // ≤ 0 vaut suppression : rien à porter.
    rows.add(AlertSettingRow(
      kind: AlertSettingKind.budget,
      target: normalizeCategory(category),
      amount: amount,
      updatedAt: now,
    ));
  });
  settings.accountThresholds.forEach((accountId, amount) {
    final target = accountId.trim();
    if (target.isEmpty || !amount.isFinite) return;
    // Un seuil à 0 est conservé : c'est une valeur valide.
    rows.add(AlertSettingRow(
      kind: AlertSettingKind.lowBalance,
      target: target,
      amount: amount,
      updatedAt: now,
    ));
  });
  return rows;
}
