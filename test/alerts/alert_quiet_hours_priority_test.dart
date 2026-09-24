import 'package:flutter_test/flutter_test.dart';
import 'package:monitrack/models/expense.dart';
import 'package:monitrack/models/notification_preferences.dart';
import 'package:monitrack/services/alerts/alert_evaluator.dart';
import 'package:monitrack/services/alerts/alert_models.dart';
import 'package:monitrack/services/alerts/alert_settings.dart';
import 'package:monitrack/services/alerts/alert_state.dart';

import 'alert_test_helpers.dart';

/// Heures calmes (rétention sans marquage) et arbitrage par gravité quand le
/// plafond [maxAlertsPerRun] est atteint.
void main() {
  final maintenant = DateTime(2026, 9, 15, 12, 0);
  final nuit = DateTime(2026, 9, 15, 23, 30);

  /// Jeu de données produisant les trois familles d'alertes à la fois.
  const reglagesTroisFamilles = AlertSettings(
    categoryBudgets: {'Transport': 100},
    accountThresholds: {'acc-1': 1000},
  );

  final depensesTroisFamilles = <Expense>[depense(montant: 120)];

  AlertEvaluation evaluer({
    AlertSettings reglages = reglagesTroisFamilles,
    AlertEmissionState etat = AlertEmissionState.empty,
    List<Expense>? depenses,
    NotificationPreferences preferences = sansHeuresCalmes,
    DateTime? now,
  }) {
    return evaluateAlerts(
      settings: reglages,
      state: etat,
      notificationPreferences: preferences,
      expenses: depenses ?? depensesTroisFamilles,
      accounts: [compte(solde: 10)],
      unsynced: UnsyncedSnapshot(
        pendingCount: 9,
        oldestPendingAt: (now ?? maintenant).subtract(const Duration(days: 5)),
      ),
      now: now ?? maintenant,
      currency: 'XOF',
    );
  }

  group('heures calmes', () {
    test('les trois familles sont retenues sans rien afficher', () {
      final resultat = evaluer(preferences: avecHeuresCalmes, now: nuit);
      expect(resultat.toEmit, isEmpty);
      expect(resultat.deferred, hasLength(3));
      expect(
        resultat.deferred.map((a) => a.kind).toSet(),
        {
          LocalAlertKind.budgetThreshold,
          LocalAlertKind.lowBalance,
          LocalAlertKind.unsyncedData,
        },
      );
    });

    test('l état anti-spam n est pas marqué pendant les heures calmes', () {
      final resultat = evaluer(preferences: avecHeuresCalmes, now: nuit);
      expect(
        resultat.nextState.tierFor('2026-09', 'Transport'),
        0,
        reason: 'un palier marqué sans affichage perdrait l alerte à jamais',
      );
      expect(resultat.nextState.isLowBalanceArmed('acc-1'), isFalse);
      expect(resultat.nextState.lastUnsyncedAlertAt, isNull);
    });

    test('les alertes retenues sont affichées dès la sortie des heures calmes',
        () {
      final retenues = evaluer(preferences: avecHeuresCalmes, now: nuit);
      final matin = evaluer(
        etat: retenues.nextState,
        preferences: avecHeuresCalmes,
        now: DateTime(2026, 9, 16, 7, 0),
      );
      expect(matin.toEmit, hasLength(3));
      expect(matin.deferred, isEmpty);
      expect(matin.nextState.tierFor('2026-09', 'Transport'), 100);
      expect(matin.nextState.isLowBalanceArmed('acc-1'), isTrue);
      expect(matin.nextState.lastUnsyncedAlertAt, isNotNull);
    });

    test('07:00 pile est déjà hors de la plage 22:00 - 07:00', () {
      final resultat = evaluer(
        preferences: avecHeuresCalmes,
        now: DateTime(2026, 9, 16, 7, 0),
      );
      expect(resultat.toEmit, isNotEmpty);
    });

    test('21:59 est encore hors de la plage, 22:00 pile y entre', () {
      expect(
        evaluer(
          preferences: avecHeuresCalmes,
          now: DateTime(2026, 9, 15, 21, 59),
        ).toEmit,
        isNotEmpty,
      );
      expect(
        evaluer(
          preferences: avecHeuresCalmes,
          now: DateTime(2026, 9, 15, 22, 0),
        ).toEmit,
        isEmpty,
      );
    });

    test('les heures calmes désactivées n arrêtent rien la nuit', () {
      final resultat = evaluer(preferences: sansHeuresCalmes, now: nuit);
      expect(resultat.toEmit, hasLength(3));
      expect(resultat.deferred, isEmpty);
    });

    test('une plage de début égal à la fin ne retient rien', () {
      const plageNulle = NotificationPreferences(
        quietHoursEnabled: true,
        quietHoursStart: '22:00',
        quietHoursEnd: '22:00',
      );
      final resultat = evaluer(preferences: plageNulle, now: nuit);
      expect(resultat.toEmit, hasLength(3));
    });

    test('une plage en pleine journée retient aussi', () {
      const plageJour = NotificationPreferences(
        quietHoursEnabled: true,
        quietHoursStart: '09:00',
        quietHoursEnd: '17:00',
      );
      final resultat = evaluer(preferences: plageJour, now: maintenant);
      expect(resultat.toEmit, isEmpty);
      expect(resultat.deferred, hasLength(3));
    });
  });

  group('alertPriority', () {
    const budget = BudgetThresholdAlert(
      category: 'Transport',
      period: '2026-09',
      tier: AlertSettings.budgetReachedPercent,
      spent: 120,
      budget: 100,
      currency: 'XOF',
    );
    const budgetAvertissement = BudgetThresholdAlert(
      category: 'Transport',
      period: '2026-09',
      tier: AlertSettings.budgetWarningPercent,
      spent: 85,
      budget: 100,
      currency: 'XOF',
    );
    const solde = LowBalanceAlert(
      accountId: 'acc-1',
      accountName: 'Courant',
      balance: 10,
      threshold: 1000,
      currency: 'XOF',
    );
    const sync = UnsyncedDataAlert(pendingCount: 3, pendingSinceHours: 60);

    test('le budget dépassé passe avant le solde bas', () {
      expect(alertPriority(budget), lessThan(alertPriority(solde)));
    });

    test('le solde bas passe avant le simple avertissement de budget', () {
      expect(alertPriority(solde), lessThan(alertPriority(budgetAvertissement)));
    });

    test('les données non synchronisées ferment la marche', () {
      expect(
        alertPriority(sync),
        greaterThan(alertPriority(budgetAvertissement)),
      );
    });
  });

  group('plafond de 5 alertes par évaluation', () {
    /// Sept catégories au-delà de leur budget : deux de trop.
    const septCategories = AlertSettings(
      lowBalanceAlertsEnabled: false,
      unsyncedDataAlertsEnabled: false,
      categoryBudgets: {
        'Alpha': 100,
        'Bravo': 100,
        'Charlie': 100,
        'Delta': 100,
        'Echo': 100,
        'Foxtrot': 100,
        'Golf': 100,
      },
    );

    List<Expense> septDepassements() => [
          for (final c in const [
            'Alpha',
            'Bravo',
            'Charlie',
            'Delta',
            'Echo',
            'Foxtrot',
            'Golf',
          ])
            depense(id: 'exp-$c', categorie: c, montant: 150),
        ];

    test('exactement cinq alertes sont émises, le reste est reporté', () {
      final resultat = evaluateAlerts(
        settings: septCategories,
        state: AlertEmissionState.empty,
        notificationPreferences: sansHeuresCalmes,
        expenses: septDepassements(),
        accounts: const [],
        unsynced: const UnsyncedSnapshot.empty(),
        now: maintenant,
        currency: 'XOF',
      );
      expect(resultat.toEmit, hasLength(maxAlertsPerRun));
      expect(resultat.deferred, hasLength(2));
    });

    test('les alertes reportées ne sont pas marquées comme émises', () {
      final resultat = evaluateAlerts(
        settings: septCategories,
        state: AlertEmissionState.empty,
        notificationPreferences: sansHeuresCalmes,
        expenses: septDepassements(),
        accounts: const [],
        unsynced: const UnsyncedSnapshot.empty(),
        now: maintenant,
        currency: 'XOF',
      );
      for (final reportee in resultat.deferred.cast<BudgetThresholdAlert>()) {
        expect(
          resultat.nextState.tierFor('2026-09', reportee.category),
          0,
          reason: '${reportee.category} a été reportée, pas affichée',
        );
      }
      expect(resultat.nextState.budgetTiers, hasLength(maxAlertsPerRun));
    });

    test('le reliquat part à l évaluation suivante', () {
      final premiere = evaluateAlerts(
        settings: septCategories,
        state: AlertEmissionState.empty,
        notificationPreferences: sansHeuresCalmes,
        expenses: septDepassements(),
        accounts: const [],
        unsynced: const UnsyncedSnapshot.empty(),
        now: maintenant,
        currency: 'XOF',
      );
      final seconde = evaluateAlerts(
        settings: septCategories,
        state: premiere.nextState,
        notificationPreferences: sansHeuresCalmes,
        expenses: septDepassements(),
        accounts: const [],
        unsynced: const UnsyncedSnapshot.empty(),
        now: maintenant,
        currency: 'XOF',
      );
      expect(seconde.toEmit, hasLength(2));
      expect(seconde.deferred, isEmpty);
      expect(
        {
          ...premiere.toEmit.cast<BudgetThresholdAlert>().map((a) => a.category),
          ...seconde.toEmit.cast<BudgetThresholdAlert>().map((a) => a.category),
        },
        septCategories.categoryBudgets.keys.toSet(),
      );
    });

    test('le tri par gravité sacrifie les alertes les moins urgentes', () {
      // 4 budgets dépassés (gravité 0), 1 solde bas (1),
      // 1 avertissement de budget (2), 1 donnée non synchronisée (3).
      final resultat = evaluateAlerts(
        settings: const AlertSettings(
          categoryBudgets: {
            'Alpha': 100,
            'Bravo': 100,
            'Charlie': 100,
            'Delta': 100,
            'Zoulou': 100,
          },
          accountThresholds: {'acc-1': 1000},
        ),
        state: AlertEmissionState.empty,
        notificationPreferences: sansHeuresCalmes,
        expenses: [
          depense(id: 'a', categorie: 'Alpha', montant: 150),
          depense(id: 'b', categorie: 'Bravo', montant: 150),
          depense(id: 'c', categorie: 'Charlie', montant: 150),
          depense(id: 'd', categorie: 'Delta', montant: 150),
          depense(id: 'z', categorie: 'Zoulou', montant: 85),
        ],
        accounts: [compte(solde: 10)],
        unsynced: UnsyncedSnapshot(
          pendingCount: 4,
          oldestPendingAt: maintenant.subtract(const Duration(days: 5)),
        ),
        now: maintenant,
        currency: 'XOF',
      );

      expect(resultat.toEmit, hasLength(maxAlertsPerRun));
      expect(resultat.toEmit.last, isA<LowBalanceAlert>());
      expect(
        resultat.toEmit.take(4).map((a) => (a as BudgetThresholdAlert).category),
        ['Alpha', 'Bravo', 'Charlie', 'Delta'],
      );
      expect(resultat.deferred.map((a) => a.kind), [
        LocalAlertKind.budgetThreshold,
        LocalAlertKind.unsyncedData,
      ]);
      expect(
        (resultat.deferred.first as BudgetThresholdAlert).tier,
        AlertSettings.budgetWarningPercent,
      );
      // Rien n'est marqué pour les reportées.
      expect(resultat.nextState.tierFor('2026-09', 'Zoulou'), 0);
      expect(resultat.nextState.lastUnsyncedAlertAt, isNull);
    });

    test('l ordre des alertes est déterministe d une évaluation à l autre', () {
      List<String> graines() => evaluateAlerts(
            settings: septCategories,
            state: AlertEmissionState.empty,
            notificationPreferences: sansHeuresCalmes,
            expenses: septDepassements().reversed.toList(),
            accounts: const [],
            unsynced: const UnsyncedSnapshot.empty(),
            now: maintenant,
            currency: 'XOF',
          ).toEmit.map((a) => a.idSeed).toList();

      expect(graines(), graines());
      expect(graines(), [
        'alert_budget_2026-09_Alpha',
        'alert_budget_2026-09_Bravo',
        'alert_budget_2026-09_Charlie',
        'alert_budget_2026-09_Delta',
        'alert_budget_2026-09_Echo',
      ]);
    });
  });

  group('évaluation vide', () {
    test('sans candidate, l évaluation est vide mais purge l état', () {
      final etat = AlertEmissionState.empty
          .markBudgetTier('2026-07', 'Transport', 100);
      final resultat = evaluateAlerts(
        settings: const AlertSettings(),
        state: etat,
        notificationPreferences: sansHeuresCalmes,
        expenses: const [],
        accounts: const [],
        unsynced: const UnsyncedSnapshot.empty(),
        now: maintenant,
        currency: 'XOF',
      );
      expect(resultat.isEmpty, isTrue);
      expect(resultat.nextState.budgetTiers, isEmpty);
    });
  });
}
