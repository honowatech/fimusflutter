import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:monitrack/services/alerts/alert_state.dart';

/// Mémoire anti-spam : clés de période, marquages, purge mensuelle et
/// désérialisation tolérante.
void main() {
  group('periodKey', () {
    test('rend AAAA-MM avec un mois sur deux chiffres', () {
      expect(AlertEmissionState.periodKey(DateTime(2026, 9, 3)), '2026-09');
      expect(AlertEmissionState.periodKey(DateTime(2026, 12, 31)), '2026-12');
    });

    test('complète l année sur quatre chiffres', () {
      expect(AlertEmissionState.periodKey(DateTime(7, 1, 5)), '0007-01');
    });

    test('convertit en heure locale avant de découper le mois', () {
      final utc = DateTime.utc(2026, 10, 1, 0, 30);
      expect(
        AlertEmissionState.periodKey(utc),
        AlertEmissionState.periodKey(utc.toLocal()),
      );
    });
  });

  group('budgetStateKey et tierFor', () {
    test('compose la clé période|catégorie', () {
      expect(
        AlertEmissionState.budgetStateKey('2026-09', 'Transport'),
        '2026-09|Transport',
      );
    });

    test('rend 0 pour un couple jamais notifié', () {
      expect(AlertEmissionState.empty.tierFor('2026-09', 'Transport'), 0);
    });

    test('lit le palier enregistré', () {
      final etat = AlertEmissionState.empty
          .markBudgetTier('2026-09', 'Transport', 80);
      expect(etat.tierFor('2026-09', 'Transport'), 80);
      expect(etat.tierFor('2026-10', 'Transport'), 0);
      expect(etat.tierFor('2026-09', 'Loyer'), 0);
    });
  });

  group('markBudgetTier', () {
    test('ne redescend jamais un palier déjà atteint', () {
      final haut = AlertEmissionState.empty
          .markBudgetTier('2026-09', 'Transport', 100);
      final tentative = haut.markBudgetTier('2026-09', 'Transport', 80);
      expect(tentative, same(haut));
      expect(tentative.tierFor('2026-09', 'Transport'), 100);
    });

    test('remarquer le même palier ne crée pas d instance', () {
      final etat = AlertEmissionState.empty
          .markBudgetTier('2026-09', 'Transport', 80);
      expect(etat.markBudgetTier('2026-09', 'Transport', 80), same(etat));
    });

    test('ne modifie pas l instance d origine', () {
      const origine = AlertEmissionState.empty;
      origine.markBudgetTier('2026-09', 'Transport', 80);
      expect(origine.budgetTiers, isEmpty);
    });
  });

  group('armement et désarmement du solde bas', () {
    test('armer deux fois ne crée pas d instance', () {
      final arme = AlertEmissionState.empty.armLowBalance('acc-1');
      expect(arme.armLowBalance('acc-1'), same(arme));
    });

    test('désarmer un compte non armé ne crée pas d instance', () {
      const vide = AlertEmissionState.empty;
      expect(vide.disarmLowBalance('acc-1'), same(vide));
    });

    test('le désarmement ne touche que le compte visé', () {
      final etat = AlertEmissionState.empty
          .armLowBalance('acc-1')
          .armLowBalance('acc-2')
          .disarmLowBalance('acc-1');
      expect(etat.lowBalanceAccounts, {'acc-2'});
      expect(etat.isLowBalanceArmed('acc-1'), isFalse);
    });
  });

  group('pruneBudgetTiers', () {
    test('ne garde que les paliers du mois en cours', () {
      final etat = AlertEmissionState.empty
          .markBudgetTier('2026-07', 'Transport', 100)
          .markBudgetTier('2026-08', 'Loyer', 80)
          .markBudgetTier('2026-09', 'Transport', 80)
          .markBudgetTier('2026-09', 'Loyer', 100);
      final purge = etat.pruneBudgetTiers(DateTime(2026, 9, 15));
      expect(purge.budgetTiers, {
        '2026-09|Transport': 80,
        '2026-09|Loyer': 100,
      });
    });

    test('rend la même instance quand il n y a rien à purger', () {
      final etat = AlertEmissionState.empty
          .markBudgetTier('2026-09', 'Transport', 80);
      expect(etat.pruneBudgetTiers(DateTime(2026, 9, 30)), same(etat));
    });

    test('vide entièrement les paliers au changement de mois', () {
      final etat = AlertEmissionState.empty
          .markBudgetTier('2026-09', 'Transport', 100);
      expect(etat.pruneBudgetTiers(DateTime(2026, 10, 1)).budgetTiers, isEmpty);
    });

    test('préserve les autres mémoires', () {
      final etat = AlertEmissionState(
        budgetTiers: const {'2026-08|Transport': 100},
        lowBalanceAccounts: const {'acc-1'},
        lastUnsyncedAlertAt: DateTime(2026, 9, 1),
      );
      final purge = etat.pruneBudgetTiers(DateTime(2026, 9, 15));
      expect(purge.budgetTiers, isEmpty);
      expect(purge.lowBalanceAccounts, {'acc-1'});
      expect(purge.lastUnsyncedAlertAt, DateTime(2026, 9, 1));
    });

    test('conserve une catégorie contenant une barre verticale', () {
      final etat = AlertEmissionState.empty
          .markBudgetTier('2026-09', 'Eau | Gaz', 80);
      expect(
        etat.pruneBudgetTiers(DateTime(2026, 9, 15)).budgetTiers,
        {'2026-09|Eau | Gaz': 80},
      );
    });
  });

  group('fromJson tolérante', () {
    test('un objet vide rend l état vide', () {
      final etat = AlertEmissionState.fromJson(const {});
      expect(etat, AlertEmissionState.empty);
    });

    test('des paliers de mauvais type sont ignorés en bloc', () {
      final etat = AlertEmissionState.fromJson(const {
        'budget_tiers': ['2026-09|Transport'],
      });
      expect(etat.budgetTiers, isEmpty);
    });

    test('les paliers lisent les nombres et les chaînes numériques', () {
      final etat = AlertEmissionState.fromJson(const {
        'budget_tiers': {
          '2026-09|Transport': 80,
          '2026-09|Loyer': '100',
          '2026-09|Courses': 60.9,
        },
      });
      expect(etat.budgetTiers, {
        '2026-09|Transport': 80,
        '2026-09|Loyer': 100,
        '2026-09|Courses': 60,
      });
    });

    test('les paliers nuls, négatifs ou illisibles sont écartés', () {
      final etat = AlertEmissionState.fromJson(const {
        'budget_tiers': {
          '2026-09|A': 0,
          '2026-09|B': -80,
          '2026-09|C': 'beaucoup',
          '2026-09|D': null,
          '2026-09|E': 80,
        },
      });
      expect(etat.budgetTiers, {'2026-09|E': 80});
    });

    test('des comptes armés de mauvais type sont ignorés en bloc', () {
      final etat = AlertEmissionState.fromJson(const {
        'low_balance_accounts': 'acc-1',
      });
      expect(etat.lowBalanceAccounts, isEmpty);
    });

    test('les identifiants vides ou nuls sont filtrés, les autres normalisés',
        () {
      final etat = AlertEmissionState.fromJson(const {
        'low_balance_accounts': ['acc-1', '', '   ', null, 42, '  acc-2  '],
      });
      expect(etat.lowBalanceAccounts, {'acc-1', '42', 'acc-2'});
    });

    test('un horodatage illisible ou de mauvais type devient nul', () {
      expect(
        AlertEmissionState.fromJson(const {'last_unsynced_alert_at': 1789})
            .lastUnsyncedAlertAt,
        isNull,
      );
      expect(
        AlertEmissionState.fromJson(
          const {'last_unsynced_alert_at': 'hier soir'},
        ).lastUnsyncedAlertAt,
        isNull,
      );
      expect(
        AlertEmissionState.fromJson(const {'last_unsynced_alert_at': null})
            .lastUnsyncedAlertAt,
        isNull,
      );
    });

    test('un horodatage ISO valide est relu', () {
      final etat = AlertEmissionState.fromJson(
        const {'last_unsynced_alert_at': '2026-09-15T12:00:00.000'},
      );
      expect(etat.lastUnsyncedAlertAt, DateTime(2026, 9, 15, 12));
    });
  });

  group('aller-retour toJson / fromJson', () {
    test('un état complet survit au passage par JSON', () {
      final origine = AlertEmissionState(
        budgetTiers: const {'2026-09|Transport': 80, '2026-09|Loyer': 100},
        lowBalanceAccounts: const {'acc-1', 'acc-2'},
        lastUnsyncedAlertAt: DateTime(2026, 9, 15, 12, 30),
      );
      final relu = AlertEmissionState.fromJson(
        jsonDecode(jsonEncode(origine.toJson())) as Map<String, dynamic>,
      );
      expect(relu, origine);
      expect(relu.hashCode, origine.hashCode);
    });

    test('l état vide survit au passage par JSON', () {
      final relu = AlertEmissionState.fromJson(
        jsonDecode(jsonEncode(AlertEmissionState.empty.toJson()))
            as Map<String, dynamic>,
      );
      expect(relu, AlertEmissionState.empty);
    });

    test('un second aller-retour est stable', () {
      final origine = AlertEmissionState(
        budgetTiers: const {'2026-09|Transport': 80},
        lowBalanceAccounts: const {'acc-1'},
        lastUnsyncedAlertAt: DateTime(2026, 9, 15, 12, 30),
      );
      final un = AlertEmissionState.fromJson(
        jsonDecode(jsonEncode(origine.toJson())) as Map<String, dynamic>,
      );
      final deux = AlertEmissionState.fromJson(
        jsonDecode(jsonEncode(un.toJson())) as Map<String, dynamic>,
      );
      expect(deux, un);
      expect(jsonEncode(deux.toJson()), jsonEncode(un.toJson()));
    });
  });

  group('égalité', () {
    test('deux états de même contenu sont égaux quel que soit l ordre', () {
      final a = AlertEmissionState(
        budgetTiers: const {'2026-09|A': 80, '2026-09|B': 100},
        lowBalanceAccounts: const {'x', 'y'},
        lastUnsyncedAlertAt: DateTime(2026, 9, 1),
      );
      final b = AlertEmissionState(
        budgetTiers: const {'2026-09|B': 100, '2026-09|A': 80},
        lowBalanceAccounts: const {'y', 'x'},
        lastUnsyncedAlertAt: DateTime(2026, 9, 1),
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('un palier différent casse l égalité', () {
      expect(
        const AlertEmissionState(budgetTiers: {'2026-09|A': 80}),
        isNot(const AlertEmissionState(budgetTiers: {'2026-09|A': 100})),
      );
    });
  });
}
