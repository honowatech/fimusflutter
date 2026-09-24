import 'package:flutter/foundation.dart';

import '../../models/account.dart';
import '../../models/expense.dart';
import '../../models/notification_preferences.dart';
import '../../utils/category_normalizer.dart';
import 'alert_models.dart';
import 'alert_settings.dart';
import 'alert_state.dart';

/// Décision des alertes locales : **100 % pur**.
///
/// Aucun plugin, aucun `BuildContext`, aucun accès disque ni réseau. Tout ce
/// dont l'évaluation a besoin (réglages, état anti-spam, dépenses du mois,
/// comptes, photographie des données non synchronisées, heure courante) est
/// passé en paramètre. C'est le point d'entrée que couvriront les tests.

/// Nombre maximal d'alertes affichées en une seule évaluation.
///
/// Garde-fou : un utilisateur ayant vingt budgets qui basculent le même jour
/// (import, synchronisation massive) recevrait autant de notifications d'un
/// coup. Le surplus n'est **pas** marqué comme émis : il repartira à
/// l'évaluation suivante, par ordre de gravité.
const int maxAlertsPerRun = 5;

/// Résultat d'une évaluation.
@immutable
class AlertEvaluation {
  const AlertEvaluation({
    required this.toEmit,
    required this.deferred,
    required this.nextState,
  });

  const AlertEvaluation.none(this.nextState)
      : toEmit = const <PendingAlert>[],
        deferred = const <PendingAlert>[];

  /// Alertes à afficher immédiatement. [nextState] les a déjà marquées.
  final List<PendingAlert> toEmit;

  /// Alertes retenues (heures calmes, plafond [maxAlertsPerRun]).
  /// **Non marquées** : elles seront réexaminées à la prochaine évaluation.
  final List<PendingAlert> deferred;

  /// État anti-spam à persister.
  final AlertEmissionState nextState;

  bool get isEmpty => toEmit.isEmpty && deferred.isEmpty;
}

/// Gravité d'une alerte, du plus urgent (0) au moins urgent. Sert à choisir
/// quelles alertes passent quand le plafond [maxAlertsPerRun] est atteint.
/// Fonction pure.
int alertPriority(PendingAlert alert) => switch (alert) {
      BudgetThresholdAlert a =>
        a.tier >= AlertSettings.budgetReachedPercent ? 0 : 2,
      LowBalanceAlert _ => 1,
      UnsyncedDataAlert _ => 3,
    };

// --- Budgets par catégorie ---------------------------------------------------

/// `true` si [moment] tombe dans le même mois calendaire que [month]
/// (heure locale).
bool isSameMonth(DateTime moment, DateTime month) {
  final a = moment.toLocal();
  final b = month.toLocal();
  return a.year == b.year && a.month == b.month;
}

/// `true` si une dépense entre dans le calcul d'un budget mensuel.
///
/// Mêmes règles que `ExpenseProvider.getFilteredExpenses` (hors trésorerie et
/// lignes prévisionnelles exclues), plus l'exclusion explicite des dépenses
/// **programmées** non encore confirmées : tant qu'elle n'a pas eu lieu, une
/// dépense programmée ne consomme pas le budget.
bool countsTowardsBudget(Expense expense, DateTime month) {
  if (expense.type != 'expense') return false;
  if (!expense.isLinkedToCashFlow) return false;
  if (expense.isPlanned) return false;
  if (expense.scheduleStatus == 'scheduled') return false;
  return isSameMonth(expense.date, month);
}

/// Total dépensé par catégorie normalisée sur le mois de [month].
/// Fonction pure.
Map<String, double> monthlySpendByCategory({
  required Iterable<Expense> expenses,
  required DateTime month,
}) {
  final totals = <String, double>{};
  for (final expense in expenses) {
    if (!countsTowardsBudget(expense, month)) continue;
    final key = normalizeCategory(expense.category);
    if (key.isEmpty) continue;
    totals[key] = (totals[key] ?? 0) + expense.amount;
  }
  return totals;
}

/// Palier franchi pour un couple (dépensé, budget) : 100, 80 ou 0.
/// Fonction pure.
int budgetTierFor(double spent, double budget) {
  if (budget <= 0) return 0;
  final ratio = spent / budget;
  if (ratio >= 1) return AlertSettings.budgetReachedPercent;
  if (ratio >= AlertSettings.budgetWarningPercent / 100) {
    return AlertSettings.budgetWarningPercent;
  }
  return 0;
}

/// Alertes de budget candidates : une par catégorie dont le palier franchi est
/// **strictement supérieur** à celui déjà notifié ce mois-ci.
///
/// Un passage direct de 0 % à 110 % ne produit donc qu'une seule alerte
/// (« budget dépassé »), pas deux. Fonction pure.
List<BudgetThresholdAlert> evaluateBudgetAlerts({
  required AlertSettings settings,
  required AlertEmissionState state,
  required Iterable<Expense> expenses,
  required DateTime now,
  required String currency,
}) {
  if (!settings.budgetAlertsActive) return const <BudgetThresholdAlert>[];
  final period = AlertEmissionState.periodKey(now);
  final spendByCategory =
      monthlySpendByCategory(expenses: expenses, month: now);

  final alerts = <BudgetThresholdAlert>[];
  settings.categoryBudgets.forEach((category, budget) {
    final spent = spendByCategory[category] ?? 0;
    final tier = budgetTierFor(spent, budget);
    if (tier == 0) return;
    if (tier <= state.tierFor(period, category)) return;
    alerts.add(BudgetThresholdAlert(
      category: category,
      period: period,
      tier: tier,
      spent: spent,
      budget: budget,
      currency: currency,
    ));
  });
  return alerts;
}

// --- Solde bas par compte ----------------------------------------------------

/// Sortie de l'évaluation des soldes : les alertes candidates et l'état
/// débarrassé des comptes revenus au-dessus de leur seuil.
@immutable
class LowBalanceEvaluation {
  const LowBalanceEvaluation({required this.candidates, required this.state});

  final List<LowBalanceAlert> candidates;

  /// État avec les **désarmements** déjà appliqués. Un désarmement n'affiche
  /// rien : il est donc appliqué même pendant les heures calmes.
  final AlertEmissionState state;
}

/// Alertes de solde bas candidates.
///
/// Anti-spam : un compte passé sous son seuil est « armé » ; il ne produit
/// plus d'alerte tant qu'il n'est pas repassé **au-dessus ou égal** au seuil.
/// Les comptes disparus ou dont le seuil a été retiré sont désarmés.
/// Fonction pure.
LowBalanceEvaluation evaluateLowBalanceAlerts({
  required AlertSettings settings,
  required AlertEmissionState state,
  required Iterable<Account> accounts,
  required String currency,
}) {
  // Famille désactivée : aucune alerte n'est produite, mais les désarmements
  // sont tout de même appliqués (ils n'affichent rien). Sans cela, un compte
  // armé avant la désactivation le resterait, et la première chute sous le
  // seuil après réactivation passerait inaperçue.
  final muted = !settings.lowBalanceAlertsEnabled;

  var next = state;
  final candidates = <LowBalanceAlert>[];
  final seen = <String>{};

  for (final account in accounts) {
    final threshold = settings.thresholdFor(account.id);
    if (threshold == null) continue;
    seen.add(account.id);

    final below = account.balance < threshold;
    if (!below) {
      next = next.disarmLowBalance(account.id);
      continue;
    }
    if (muted || next.isLowBalanceArmed(account.id)) continue;
    candidates.add(LowBalanceAlert(
      accountId: account.id,
      accountName: account.name,
      balance: account.balance,
      threshold: threshold,
      currency: currency,
    ));
  }

  // Nettoyage : comptes supprimés, ou dont le seuil a été retiré.
  for (final armed in state.lowBalanceAccounts) {
    if (!seen.contains(armed)) next = next.disarmLowBalance(armed);
  }

  return LowBalanceEvaluation(candidates: candidates, state: next);
}

// --- Données non synchronisées -----------------------------------------------

/// Alerte « données non synchronisées », ou `null`.
///
/// Conditions cumulatives : alerte activée, au moins une ligne en attente,
/// ancienneté connue et supérieure au seuil configuré (48 h par défaut), et
/// délai anti-spam de 24 h écoulé depuis la dernière alerte.
/// Fonction pure.
UnsyncedDataAlert? evaluateUnsyncedAlert({
  required AlertSettings settings,
  required AlertEmissionState state,
  required UnsyncedSnapshot snapshot,
  required DateTime now,
}) {
  if (!settings.unsyncedDataAlertsEnabled) return null;
  if (snapshot.isEmpty) return null;
  final oldest = snapshot.oldestPendingAt;
  if (oldest == null) return null;

  final age = now.difference(oldest);
  if (age < settings.unsyncedThreshold) return null;
  if (!state.canEmitUnsynced(now)) return null;

  return UnsyncedDataAlert(
    pendingCount: snapshot.pendingCount,
    pendingSinceHours: age.inHours,
  );
}

// --- Évaluation complète -----------------------------------------------------

/// Évalue les trois familles d'alertes et produit l'état anti-spam suivant.
///
/// Heures calmes : une alerte locale est **immédiate**, on ne peut pas la
/// décaler comme un rappel planifié. Pendant la plage calme, les alertes sont
/// donc retenues (`deferred`) sans être marquées : la première évaluation
/// postérieure à la plage les affichera. Les désarmements de solde bas, eux,
/// s'appliquent toujours (ils n'affichent rien).
///
/// Fonction pure : c'est le point d'entrée principal des tests.
AlertEvaluation evaluateAlerts({
  required AlertSettings settings,
  required AlertEmissionState state,
  required NotificationPreferences notificationPreferences,
  required Iterable<Expense> expenses,
  required Iterable<Account> accounts,
  required UnsyncedSnapshot unsynced,
  required DateTime now,
  required String currency,
}) {
  var next = state.pruneBudgetTiers(now);

  final candidates = <PendingAlert>[
    ...evaluateBudgetAlerts(
      settings: settings,
      state: next,
      expenses: expenses,
      now: now,
      currency: currency,
    ),
  ];

  final lowBalance = evaluateLowBalanceAlerts(
    settings: settings,
    state: next,
    accounts: accounts,
    currency: currency,
  );
  next = lowBalance.state;
  candidates.addAll(lowBalance.candidates);

  final unsyncedAlert = evaluateUnsyncedAlert(
    settings: settings,
    state: next,
    snapshot: unsynced,
    now: now,
  );
  if (unsyncedAlert != null) candidates.add(unsyncedAlert);

  if (candidates.isEmpty) return AlertEvaluation.none(next);

  // Tri par gravité, puis par identifiant pour un ordre déterministe (deux
  // alertes de même gravité doivent toujours sortir dans le même ordre).
  candidates.sort((a, b) {
    final byPriority = alertPriority(a).compareTo(alertPriority(b));
    return byPriority != 0 ? byPriority : a.idSeed.compareTo(b.idSeed);
  });

  if (notificationPreferences.isWithinQuietHours(now)) {
    return AlertEvaluation(
      toEmit: const <PendingAlert>[],
      deferred: candidates,
      nextState: next,
    );
  }

  final toEmit = candidates.take(maxAlertsPerRun).toList();
  final deferred = candidates.skip(maxAlertsPerRun).toList();

  for (final alert in toEmit) {
    next = switch (alert) {
      BudgetThresholdAlert a =>
        next.markBudgetTier(a.period, a.category, a.tier),
      LowBalanceAlert a => next.armLowBalance(a.accountId),
      UnsyncedDataAlert _ => next.markUnsyncedAlert(now),
    };
  }

  return AlertEvaluation(
    toEmit: toEmit,
    deferred: deferred,
    nextState: next,
  );
}
