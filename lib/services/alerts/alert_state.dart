import 'package:flutter/foundation.dart';

import 'alert_settings.dart';

/// État d'émission des alertes locales : mémoire anti-spam.
///
/// **Stockage** : SharedPreferences, clé `'alerts_emission_state_v1'`
/// (`AlertSettingsStore.stateKey`), sérialisé en JSON.
///
/// Trois mémoires, une par famille d'alerte :
///  * [budgetTiers] — palier le plus haut déjà notifié pour un couple
///    (mois, catégorie). Une seule alerte « 80 % » et une seule alerte
///    « 100 % » par catégorie et par mois.
///  * [lowBalanceAccounts] — comptes actuellement « en alerte ». Tant qu'un
///    compte y figure, aucune nouvelle notification ; il en sort dès que son
///    solde repasse au-dessus du seuil.
///  * [lastUnsyncedAlertAt] — dernière alerte « données non synchronisées »,
///    répétée au plus une fois par 24 h.
///
/// Objet **pur** : aucun plugin, aucun `BuildContext`.
@immutable
class AlertEmissionState {
  /// Intervalle minimal entre deux alertes « données non synchronisées ».
  static const Duration unsyncedCooldown = Duration(hours: 24);

  const AlertEmissionState({
    this.budgetTiers = const <String, int>{},
    this.lowBalanceAccounts = const <String>{},
    this.lastUnsyncedAlertAt,
  });

  /// Clé : `budgetStateKey(période, catégorie)` (`"2026-09|Transport"`).
  /// Valeur : palier atteint, [AlertSettings.budgetWarningPercent] ou
  /// [AlertSettings.budgetReachedPercent].
  final Map<String, int> budgetTiers;

  /// Identifiants de comptes dont l'alerte de solde bas est encore « armée ».
  final Set<String> lowBalanceAccounts;

  final DateTime? lastUnsyncedAlertAt;

  static const AlertEmissionState empty = AlertEmissionState();

  /// Clé de période mensuelle (`"2026-09"`), en heure locale.
  static String periodKey(DateTime moment) {
    final local = moment.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}';
  }

  /// Clé d'état d'un budget : `"<période>|<catégorie normalisée>"`.
  static String budgetStateKey(String period, String normalizedCategory) =>
      '$period|$normalizedCategory';

  /// Palier déjà notifié pour une catégorie sur une période (0 si aucun).
  int tierFor(String period, String normalizedCategory) =>
      budgetTiers[budgetStateKey(period, normalizedCategory)] ?? 0;

  bool isLowBalanceArmed(String accountId) =>
      lowBalanceAccounts.contains(accountId);

  /// `true` si une alerte « données non synchronisées » peut être émise à
  /// [now] (jamais émise, ou dernière émission il y a plus de 24 h).
  ///
  /// Une horloge qui recule (changement manuel de date) rend la différence
  /// négative : on autorise alors l'émission plutôt que de bloquer l'alerte
  /// pendant une durée indéterminée.
  bool canEmitUnsynced(DateTime now) {
    final last = lastUnsyncedAlertAt;
    if (last == null) return true;
    final elapsed = now.difference(last);
    return elapsed.isNegative || elapsed >= unsyncedCooldown;
  }

  /// Enregistre un palier de budget atteint.
  AlertEmissionState markBudgetTier(
    String period,
    String normalizedCategory,
    int tier,
  ) {
    final next = Map<String, int>.from(budgetTiers);
    final key = budgetStateKey(period, normalizedCategory);
    if ((next[key] ?? 0) >= tier) return this;
    next[key] = tier;
    return copyWith(budgetTiers: next);
  }

  /// Arme l'alerte de solde bas d'un compte (une seule notification tant
  /// qu'elle reste armée).
  AlertEmissionState armLowBalance(String accountId) {
    if (lowBalanceAccounts.contains(accountId)) return this;
    return copyWith(
      lowBalanceAccounts: {...lowBalanceAccounts, accountId},
    );
  }

  /// Désarme l'alerte de solde bas (solde repassé au-dessus du seuil, ou
  /// seuil supprimé / compte disparu).
  AlertEmissionState disarmLowBalance(String accountId) {
    if (!lowBalanceAccounts.contains(accountId)) return this;
    final next = Set<String>.from(lowBalanceAccounts)..remove(accountId);
    return copyWith(lowBalanceAccounts: next);
  }

  AlertEmissionState markUnsyncedAlert(DateTime at) =>
      copyWith(lastUnsyncedAlertAt: at);

  /// Supprime les paliers de budget des mois révolus : sans cela la carte
  /// grossirait indéfiniment (une entrée par catégorie et par mois).
  /// Fonction pure.
  AlertEmissionState pruneBudgetTiers(DateTime now) {
    final current = periodKey(now);
    final next = <String, int>{
      for (final entry in budgetTiers.entries)
        if (entry.key.startsWith('$current|')) entry.key: entry.value,
    };
    if (next.length == budgetTiers.length) return this;
    return copyWith(budgetTiers: next);
  }

  /// [clearLastUnsyncedAlertAt] efface l'horodatage : `null` passé à
  /// [lastUnsyncedAlertAt] signifie « inchangé », il ne pouvait donc pas
  /// servir à réinitialiser l'anti-spam.
  AlertEmissionState copyWith({
    Map<String, int>? budgetTiers,
    Set<String>? lowBalanceAccounts,
    DateTime? lastUnsyncedAlertAt,
    bool clearLastUnsyncedAlertAt = false,
  }) {
    return AlertEmissionState(
      budgetTiers: budgetTiers ?? this.budgetTiers,
      lowBalanceAccounts: lowBalanceAccounts ?? this.lowBalanceAccounts,
      lastUnsyncedAlertAt: clearLastUnsyncedAlertAt
          ? null
          : (lastUnsyncedAlertAt ?? this.lastUnsyncedAlertAt),
    );
  }

  Map<String, dynamic> toJson() => {
        'budget_tiers': budgetTiers,
        'low_balance_accounts': lowBalanceAccounts.toList(),
        'last_unsynced_alert_at': lastUnsyncedAlertAt?.toIso8601String(),
      };

  factory AlertEmissionState.fromJson(Map<String, dynamic> json) {
    final tiers = <String, int>{};
    final rawTiers = json['budget_tiers'];
    if (rawTiers is Map) {
      rawTiers.forEach((key, value) {
        final tier = value is num
            ? value.toInt()
            : (value is String ? int.tryParse(value.trim()) : null);
        if (tier != null && tier > 0) tiers[key.toString()] = tier;
      });
    }

    final accounts = <String>{};
    final rawAccounts = json['low_balance_accounts'];
    if (rawAccounts is Iterable) {
      for (final id in rawAccounts) {
        final value = id?.toString().trim();
        if (value != null && value.isNotEmpty) accounts.add(value);
      }
    }

    final rawLast = json['last_unsynced_alert_at'];
    return AlertEmissionState(
      budgetTiers: tiers,
      lowBalanceAccounts: accounts,
      lastUnsyncedAlertAt:
          rawLast is String ? DateTime.tryParse(rawLast) : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AlertEmissionState &&
          mapEquals(other.budgetTiers, budgetTiers) &&
          setEquals(other.lowBalanceAccounts, lowBalanceAccounts) &&
          other.lastUnsyncedAlertAt == lastUnsyncedAlertAt;

  @override
  int get hashCode => Object.hash(
        Object.hashAllUnordered(
          budgetTiers.entries.map((e) => Object.hash(e.key, e.value)),
        ),
        Object.hashAllUnordered(lowBalanceAccounts),
        lastUnsyncedAlertAt,
      );
}
