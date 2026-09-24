import 'package:flutter/foundation.dart';

import '../../utils/category_normalizer.dart';

/// Réglages des alertes locales de finances personnelles (sprint 4).
///
/// **Stockage** : SharedPreferences, clé `alerts_settings_v1`
/// (`AlertSettingsStore.settingsKey`), sérialisé en JSON. Il n'existe ni table
/// SQLite ni endpoint serveur pour ces réglages : ils sont donc
/// **locaux à l'appareil** et ne suivent pas
/// l'utilisateur d'un téléphone à l'autre (limite assumée, voir le rapport de
/// sprint pour le schéma de table proposé).
///
/// Objet **pur** : aucun plugin, aucun `BuildContext`. Toute la logique de
/// décision qui le consomme (`alert_evaluator.dart`) l'est aussi.
@immutable
class AlertSettings {
  /// Premier palier d'alerte budget, en pourcentage du budget mensuel.
  static const int budgetWarningPercent = 80;

  /// Second palier : budget atteint / dépassé.
  static const int budgetReachedPercent = 100;

  /// Ancienneté par défaut au-delà de laquelle des données encore en attente
  /// d'envoi déclenchent une alerte (risque de perte au changement de
  /// téléphone).
  static const int defaultUnsyncedThresholdHours = 48;

  /// Choix proposés dans l'écran de réglages.
  static const List<int> unsyncedThresholdChoices = <int>[24, 48, 72, 168];

  const AlertSettings({
    this.budgetAlertsEnabled = true,
    this.lowBalanceAlertsEnabled = true,
    this.unsyncedDataAlertsEnabled = true,
    this.categoryBudgets = const <String, double>{},
    this.accountThresholds = const <String, double>{},
    this.unsyncedThresholdHours = defaultUnsyncedThresholdHours,
  });

  /// Interrupteur « Seuil de budget par catégorie ».
  final bool budgetAlertsEnabled;

  /// Interrupteur « Solde bas par compte ».
  final bool lowBalanceAlertsEnabled;

  /// Interrupteur « Données non synchronisées ».
  final bool unsyncedDataAlertsEnabled;

  /// Budget mensuel par catégorie de dépense. Clé : nom de catégorie
  /// **normalisé** ([normalizeCategory]), valeur : montant strictement positif
  /// dans la devise du profil. Une catégorie absente n'est pas surveillée.
  final Map<String, double> categoryBudgets;

  /// Seuil de solde bas par compte. Clé : `Account.id`, valeur : montant
  /// (peut être 0 : « alerte dès que le compte passe en négatif »).
  final Map<String, double> accountThresholds;

  /// Ancienneté déclenchant l'alerte « données non synchronisées », en heures.
  final int unsyncedThresholdHours;

  /// `true` si au moins une alerte est active : permet à
  /// `LocalAlertsService.evaluate` de sortir immédiatement sans lire la base.
  bool get hasAnyAlertEnabled =>
      budgetAlertsEnabled || lowBalanceAlertsEnabled || unsyncedDataAlertsEnabled;

  /// `true` si l'évaluation des budgets a de quoi travailler.
  bool get budgetAlertsActive =>
      budgetAlertsEnabled && categoryBudgets.isNotEmpty;

  /// `true` si l'évaluation des soldes a de quoi travailler.
  bool get lowBalanceAlertsActive =>
      lowBalanceAlertsEnabled && accountThresholds.isNotEmpty;

  Duration get unsyncedThreshold => Duration(hours: unsyncedThresholdHours);

  /// Budget d'une catégorie, quelle que soit la casse saisie. `null` si la
  /// catégorie n'a pas de budget.
  double? budgetFor(String category) =>
      categoryBudgets[normalizeCategory(category)];

  /// Seuil d'un compte, `null` si le compte n'est pas surveillé.
  double? thresholdFor(String accountId) => accountThresholds[accountId];

  /// Définit (ou supprime si [amount] est `null` ou non strictement positif)
  /// le budget d'une catégorie. Fonction pure : renvoie une nouvelle instance.
  AlertSettings withCategoryBudget(String category, double? amount) {
    final key = normalizeCategory(category);
    if (key.isEmpty) return this;
    final next = Map<String, double>.from(categoryBudgets);
    if (amount == null || amount <= 0) {
      next.remove(key);
    } else {
      next[key] = amount;
    }
    return copyWith(categoryBudgets: next);
  }

  /// Définit (ou supprime si [amount] est `null`) le seuil d'un compte.
  ///
  /// Un seuil à 0 est **conservé** : « préviens-moi dès que ce compte passe
  /// sous zéro » est un réglage légitime. Seul `null` retire la surveillance.
  AlertSettings withAccountThreshold(String accountId, double? amount) {
    if (accountId.isEmpty) return this;
    final next = Map<String, double>.from(accountThresholds);
    if (amount == null) {
      next.remove(accountId);
    } else {
      next[accountId] = amount;
    }
    return copyWith(accountThresholds: next);
  }

  AlertSettings copyWith({
    bool? budgetAlertsEnabled,
    bool? lowBalanceAlertsEnabled,
    bool? unsyncedDataAlertsEnabled,
    Map<String, double>? categoryBudgets,
    Map<String, double>? accountThresholds,
    int? unsyncedThresholdHours,
  }) {
    return AlertSettings(
      budgetAlertsEnabled: budgetAlertsEnabled ?? this.budgetAlertsEnabled,
      lowBalanceAlertsEnabled:
          lowBalanceAlertsEnabled ?? this.lowBalanceAlertsEnabled,
      unsyncedDataAlertsEnabled:
          unsyncedDataAlertsEnabled ?? this.unsyncedDataAlertsEnabled,
      categoryBudgets: categoryBudgets ?? this.categoryBudgets,
      accountThresholds: accountThresholds ?? this.accountThresholds,
      unsyncedThresholdHours:
          unsyncedThresholdHours ?? this.unsyncedThresholdHours,
    );
  }

  Map<String, dynamic> toJson() => {
        'budget_alerts_enabled': budgetAlertsEnabled,
        'low_balance_alerts_enabled': lowBalanceAlertsEnabled,
        'unsynced_data_alerts_enabled': unsyncedDataAlertsEnabled,
        'category_budgets': categoryBudgets,
        'account_thresholds': accountThresholds,
        'unsynced_threshold_hours': unsyncedThresholdHours,
      };

  /// Désérialisation tolérante : un champ absent ou d'un type inattendu
  /// reprend sa valeur par défaut (une préférence illisible ne doit jamais
  /// faire perdre les alertes).
  factory AlertSettings.fromJson(Map<String, dynamic> json) {
    return AlertSettings(
      budgetAlertsEnabled: _asBool(json['budget_alerts_enabled'], true),
      lowBalanceAlertsEnabled:
          _asBool(json['low_balance_alerts_enabled'], true),
      unsyncedDataAlertsEnabled:
          _asBool(json['unsynced_data_alerts_enabled'], true),
      categoryBudgets: _asAmountMap(
        json['category_budgets'],
        normalizeKey: true,
        positiveOnly: true,
      ),
      accountThresholds: _asAmountMap(json['account_thresholds']),
      unsyncedThresholdHours: _asHours(
        json['unsynced_threshold_hours'],
        defaultUnsyncedThresholdHours,
      ),
    );
  }

  static bool _asBool(dynamic value, bool fallback) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') return true;
      if (normalized == 'false' || normalized == '0') return false;
    }
    return fallback;
  }

  static int _asHours(dynamic value, int fallback) {
    final parsed = value is num
        ? value.toInt()
        : (value is String ? int.tryParse(value.trim()) : null);
    if (parsed == null || parsed <= 0) return fallback;
    // Borne haute : un mois. Au-delà l'alerte n'aurait plus de sens.
    return parsed > 720 ? 720 : parsed;
  }

  static Map<String, double> _asAmountMap(
    dynamic value, {
    bool normalizeKey = false,
    bool positiveOnly = false,
  }) {
    if (value is! Map) return const <String, double>{};
    final result = <String, double>{};
    value.forEach((key, raw) {
      final name = normalizeKey
          ? normalizeCategory(key.toString())
          : key.toString().trim();
      if (name.isEmpty) return;
      final amount = raw is num
          ? raw.toDouble()
          : (raw is String ? double.tryParse(raw.trim()) : null);
      if (amount == null || !amount.isFinite) return;
      if (positiveOnly && amount <= 0) return;
      result[name] = amount;
    });
    return result;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AlertSettings &&
          other.budgetAlertsEnabled == budgetAlertsEnabled &&
          other.lowBalanceAlertsEnabled == lowBalanceAlertsEnabled &&
          other.unsyncedDataAlertsEnabled == unsyncedDataAlertsEnabled &&
          other.unsyncedThresholdHours == unsyncedThresholdHours &&
          mapEquals(other.categoryBudgets, categoryBudgets) &&
          mapEquals(other.accountThresholds, accountThresholds);

  @override
  int get hashCode => Object.hash(
        budgetAlertsEnabled,
        lowBalanceAlertsEnabled,
        unsyncedDataAlertsEnabled,
        unsyncedThresholdHours,
        Object.hashAllUnordered(
          categoryBudgets.entries.map((e) => Object.hash(e.key, e.value)),
        ),
        Object.hashAllUnordered(
          accountThresholds.entries.map((e) => Object.hash(e.key, e.value)),
        ),
      );
}
