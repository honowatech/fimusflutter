import 'package:flutter_test/flutter_test.dart';
import 'package:monitrack/models/expense.dart';
import 'package:monitrack/models/notification_preferences.dart';
import 'package:monitrack/services/alerts/alert_evaluator.dart';
import 'package:monitrack/services/alerts/alert_models.dart';
import 'package:monitrack/services/alerts/alert_settings.dart';
import 'package:monitrack/services/alerts/alert_state.dart';

import 'alert_test_helpers.dart';

/// Alertes « seuil de budget par catégorie » : paliers 80 % / 100 %, anti-spam
/// mensuel, périmètre des dépenses comptabilisées.
void main() {
  AlertEvaluation evaluer({
    required AlertSettings reglages,
    AlertEmissionState etat = AlertEmissionState.empty,
    List<Expense> depenses = const <Expense>[],
    DateTime? maintenant,
    NotificationPreferences preferences = sansHeuresCalmes,
  }) {
    return evaluateAlerts(
      settings: reglages,
      state: etat,
      notificationPreferences: preferences,
      expenses: depenses,
      accounts: const [],
      unsynced: const UnsyncedSnapshot.empty(),
      now: maintenant ?? moisCourant,
      currency: 'XOF',
    );
  }

  group('budgetTierFor', () {
    test('ne franchit aucun palier sous 80 % du budget', () {
      expect(budgetTierFor(79.99, 100), 0);
    });

    test('franchit le palier 80 % exactement à 80 %', () {
      expect(budgetTierFor(80, 100), AlertSettings.budgetWarningPercent);
    });

    test('franchit le palier 100 % exactement à 100 %', () {
      expect(budgetTierFor(100, 100), AlertSettings.budgetReachedPercent);
    });

    test('reste au palier 100 % au-delà du budget', () {
      expect(budgetTierFor(250, 100), AlertSettings.budgetReachedPercent);
    });

    test('ne franchit aucun palier quand le budget est nul ou négatif', () {
      expect(budgetTierFor(500, 0), 0);
      expect(budgetTierFor(500, -10), 0);
    });
  });

  group('countsTowardsBudget', () {
    test('compte une dépense ordinaire du mois', () {
      expect(countsTowardsBudget(depense(montant: 10), moisCourant), isTrue);
    });

    test('exclut les revenus', () {
      expect(
        countsTowardsBudget(depense(montant: 10, type: 'income'), moisCourant),
        isFalse,
      );
    });

    test('exclut les lignes prévisionnelles', () {
      expect(
        countsTowardsBudget(depense(montant: 10, prevision: true), moisCourant),
        isFalse,
      );
    });

    test('exclut les dépenses programmées non encore confirmées', () {
      expect(
        countsTowardsBudget(
          depense(montant: 10, statutProgrammation: 'scheduled'),
          moisCourant,
        ),
        isFalse,
      );
    });

    test('compte une dépense programmée déjà confirmée', () {
      expect(
        countsTowardsBudget(
          depense(montant: 10, statutProgrammation: 'confirmed'),
          moisCourant,
        ),
        isTrue,
      );
    });

    test('exclut les opérations hors trésorerie', () {
      expect(
        countsTowardsBudget(
          depense(montant: 10, tresorerie: false),
          moisCourant,
        ),
        isFalse,
      );
    });

    test('exclut une dépense du mois précédent', () {
      expect(
        countsTowardsBudget(
          depense(montant: 10, date: DateTime(2026, 8, 31, 23, 59)),
          moisCourant,
        ),
        isFalse,
      );
    });

    test('exclut le même mois d une autre année', () {
      expect(
        countsTowardsBudget(
          depense(montant: 10, date: DateTime(2025, 9, 15)),
          moisCourant,
        ),
        isFalse,
      );
    });

    test('compte le premier et le dernier jour du mois', () {
      expect(
        countsTowardsBudget(
          depense(montant: 10, date: DateTime(2026, 9, 1, 0, 0)),
          moisCourant,
        ),
        isTrue,
      );
      expect(
        countsTowardsBudget(
          depense(montant: 10, date: DateTime(2026, 9, 30, 23, 59, 59)),
          moisCourant,
        ),
        isTrue,
      );
    });
  });

  group('monthlySpendByCategory', () {
    test('agrège les catégories de casse différente sous une clé unique', () {
      final totaux = monthlySpendByCategory(
        expenses: [
          depense(id: 'a', categorie: 'transport', montant: 10),
          depense(id: 'b', categorie: 'TRANSPORT', montant: 20),
          depense(id: 'c', categorie: '  transport  ', montant: 5),
        ],
        month: moisCourant,
      );
      expect(totaux, {'Transport': 35});
    });

    test('ignore les catégories vides ou réduites à des espaces', () {
      final totaux = monthlySpendByCategory(
        expenses: [
          depense(id: 'a', categorie: '   ', montant: 10),
          depense(id: 'b', categorie: 'Loyer', montant: 20),
        ],
        month: moisCourant,
      );
      expect(totaux, {'Loyer': 20});
    });

    test('exclut revenus, prévisions et dépenses programmées du total', () {
      final totaux = monthlySpendByCategory(
        expenses: [
          depense(id: 'a', categorie: 'Transport', montant: 30),
          depense(
            id: 'b',
            categorie: 'Transport',
            montant: 100,
            type: 'income',
          ),
          depense(
            id: 'c',
            categorie: 'Transport',
            montant: 100,
            prevision: true,
          ),
          depense(
            id: 'd',
            categorie: 'Transport',
            montant: 100,
            statutProgrammation: 'scheduled',
          ),
        ],
        month: moisCourant,
      );
      expect(totaux, {'Transport': 30});
    });

    test('rend une carte vide sans dépense éligible', () {
      expect(
        monthlySpendByCategory(expenses: const [], month: moisCourant),
        isEmpty,
      );
    });
  });

  group('paliers émis une seule fois par mois et par catégorie', () {
    const reglages = AlertSettings(
      categoryBudgets: {'Transport': 100},
      lowBalanceAlertsEnabled: false,
      unsyncedDataAlertsEnabled: false,
    );

    test('émet le palier 80 % puis plus rien tant qu on reste sous 100 %', () {
      final premiere = evaluer(
        reglages: reglages,
        depenses: [depense(montant: 85)],
      );
      expect(premiere.toEmit, hasLength(1));
      final alerte = premiere.toEmit.single as BudgetThresholdAlert;
      expect(alerte.tier, AlertSettings.budgetWarningPercent);
      expect(alerte.category, 'Transport');
      expect(alerte.period, '2026-09');
      expect(alerte.spent, 85);
      expect(alerte.consumedPercent, 85);

      // Deuxième passage : même mois, dépenses accrues mais toujours < 100 %.
      final seconde = evaluer(
        reglages: reglages,
        etat: premiere.nextState,
        depenses: [depense(montant: 85), depense(id: 'exp-2', montant: 10)],
      );
      expect(seconde.toEmit, isEmpty);
      expect(seconde.deferred, isEmpty);
    });

    test('émet le palier 100 % après le palier 80 % déjà notifié', () {
      final etat =
          AlertEmissionState.empty.markBudgetTier('2026-09', 'Transport', 80);
      final resultat = evaluer(
        reglages: reglages,
        etat: etat,
        depenses: [depense(montant: 120)],
      );
      expect(resultat.toEmit, hasLength(1));
      final alerte = resultat.toEmit.single as BudgetThresholdAlert;
      expect(alerte.tier, AlertSettings.budgetReachedPercent);
      expect(alerte.consumedPercent, 120);
    });

    test('un passage direct de 0 à 110 % ne produit qu une seule alerte', () {
      final resultat = evaluer(
        reglages: reglages,
        depenses: [depense(montant: 110)],
      );
      expect(resultat.toEmit, hasLength(1));
      final alerte = resultat.toEmit.single as BudgetThresholdAlert;
      expect(alerte.tier, AlertSettings.budgetReachedPercent);
      expect(
        resultat.nextState.tierFor('2026-09', 'Transport'),
        AlertSettings.budgetReachedPercent,
      );

      // Rien de plus à l'évaluation suivante.
      final suivante = evaluer(
        reglages: reglages,
        etat: resultat.nextState,
        depenses: [depense(montant: 110)],
      );
      expect(suivante.toEmit, isEmpty);
    });

    test('le palier 100 % déjà notifié bloque toute alerte du même mois', () {
      final etat =
          AlertEmissionState.empty.markBudgetTier('2026-09', 'Transport', 100);
      final resultat = evaluer(
        reglages: reglages,
        etat: etat,
        depenses: [depense(montant: 500)],
      );
      expect(resultat.toEmit, isEmpty);
    });

    test('un nouveau mois purge les paliers et réautorise l alerte', () {
      final etat =
          AlertEmissionState.empty.markBudgetTier('2026-08', 'Transport', 100);
      final resultat = evaluer(
        reglages: reglages,
        etat: etat,
        depenses: [depense(montant: 120)],
      );
      expect(resultat.toEmit, hasLength(1));
      expect(
        (resultat.toEmit.single as BudgetThresholdAlert).period,
        '2026-09',
      );
      // Le palier du mois révolu a disparu de l'état persisté.
      expect(resultat.nextState.budgetTiers.keys, ['2026-09|Transport']);
    });

    test('les catégories de casse différente partagent le même anti-spam', () {
      final premiere = evaluer(
        reglages: reglages,
        depenses: [depense(categorie: 'transport', montant: 60)],
      );
      expect(premiere.toEmit, isEmpty, reason: '60 % ne franchit aucun palier');

      final seconde = evaluer(
        reglages: reglages,
        depenses: [
          depense(id: 'a', categorie: 'transport', montant: 60),
          depense(id: 'b', categorie: 'TRANSPORT', montant: 45),
        ],
      );
      expect(seconde.toEmit, hasLength(1));
      final alerte = seconde.toEmit.single as BudgetThresholdAlert;
      expect(alerte.tier, AlertSettings.budgetReachedPercent);
      expect(alerte.spent, 105);
    });
  });

  group('budget modifié en cours de mois', () {
    test('un budget relevé au-delà des dépenses ne réémet pas d alerte', () {
      final etat =
          AlertEmissionState.empty.markBudgetTier('2026-09', 'Transport', 100);
      final resultat = evaluer(
        reglages: const AlertSettings(
          categoryBudgets: {'Transport': 300},
          lowBalanceAlertsEnabled: false,
          unsyncedDataAlertsEnabled: false,
        ),
        etat: etat,
        depenses: [depense(montant: 110)],
      );
      expect(resultat.toEmit, isEmpty);
      // Le palier reste mémorisé : redescendre ne « rembobine » pas l'état.
      expect(resultat.nextState.tierFor('2026-09', 'Transport'), 100);
    });

    test('un budget relevé qui ramène à 80 % ne réémet pas le palier 80 %', () {
      final etat =
          AlertEmissionState.empty.markBudgetTier('2026-09', 'Transport', 100);
      final resultat = evaluer(
        reglages: const AlertSettings(
          categoryBudgets: {'Transport': 130},
          lowBalanceAlertsEnabled: false,
          unsyncedDataAlertsEnabled: false,
        ),
        etat: etat,
        depenses: [depense(montant: 110)],
      );
      expect(resultat.toEmit, isEmpty);
    });

    test('un budget abaissé sous les dépenses déclenche le palier 100 %', () {
      final etat =
          AlertEmissionState.empty.markBudgetTier('2026-09', 'Transport', 80);
      final resultat = evaluer(
        reglages: const AlertSettings(
          categoryBudgets: {'Transport': 90},
          lowBalanceAlertsEnabled: false,
          unsyncedDataAlertsEnabled: false,
        ),
        etat: etat,
        depenses: [depense(montant: 95)],
      );
      expect(resultat.toEmit, hasLength(1));
      expect(
        (resultat.toEmit.single as BudgetThresholdAlert).tier,
        AlertSettings.budgetReachedPercent,
      );
    });
  });

  group('interrupteurs et cas sans matière', () {
    test('aucune alerte de budget quand l interrupteur est coupé', () {
      final resultat = evaluer(
        reglages: const AlertSettings(
          budgetAlertsEnabled: false,
          categoryBudgets: {'Transport': 100},
          lowBalanceAlertsEnabled: false,
          unsyncedDataAlertsEnabled: false,
        ),
        depenses: [depense(montant: 500)],
      );
      expect(resultat.isEmpty, isTrue);
    });

    test('aucune alerte quand aucune catégorie n a de budget', () {
      final resultat = evaluer(
        reglages: const AlertSettings(
          lowBalanceAlertsEnabled: false,
          unsyncedDataAlertsEnabled: false,
        ),
        depenses: [depense(montant: 500)],
      );
      expect(resultat.isEmpty, isTrue);
    });

    test('une catégorie sans dépense du mois ne produit pas d alerte', () {
      final resultat = evaluer(
        reglages: const AlertSettings(
          categoryBudgets: {'Transport': 100},
          lowBalanceAlertsEnabled: false,
          unsyncedDataAlertsEnabled: false,
        ),
        depenses: [depense(categorie: 'Loyer', montant: 500)],
      );
      expect(resultat.isEmpty, isTrue);
    });
  });
}
