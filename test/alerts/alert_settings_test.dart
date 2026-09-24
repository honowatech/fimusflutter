import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:monitrack/services/alerts/alert_settings.dart';

/// Réglages des alertes locales : valeurs par défaut, mutations pures et
/// désérialisation tolérante.
void main() {
  group('valeurs par défaut', () {
    test('les trois familles sont actives et les listes vides', () {
      const reglages = AlertSettings();
      expect(reglages.budgetAlertsEnabled, isTrue);
      expect(reglages.lowBalanceAlertsEnabled, isTrue);
      expect(reglages.unsyncedDataAlertsEnabled, isTrue);
      expect(reglages.categoryBudgets, isEmpty);
      expect(reglages.accountThresholds, isEmpty);
      expect(
        reglages.unsyncedThresholdHours,
        AlertSettings.defaultUnsyncedThresholdHours,
      );
    });

    test('hasAnyAlertEnabled ne tombe à faux que tout éteint', () {
      expect(const AlertSettings().hasAnyAlertEnabled, isTrue);
      expect(
        const AlertSettings(
          budgetAlertsEnabled: false,
          lowBalanceAlertsEnabled: false,
        ).hasAnyAlertEnabled,
        isTrue,
      );
      expect(
        const AlertSettings(
          budgetAlertsEnabled: false,
          lowBalanceAlertsEnabled: false,
          unsyncedDataAlertsEnabled: false,
        ).hasAnyAlertEnabled,
        isFalse,
      );
    });

    test('une famille active mais sans donnée n est pas « active »', () {
      const reglages = AlertSettings();
      expect(reglages.budgetAlertsActive, isFalse);
      expect(reglages.lowBalanceAlertsActive, isFalse);
    });

    test('une famille éteinte n est pas active même avec des données', () {
      const reglages = AlertSettings(
        budgetAlertsEnabled: false,
        lowBalanceAlertsEnabled: false,
        categoryBudgets: {'Transport': 100},
        accountThresholds: {'acc-1': 0},
      );
      expect(reglages.budgetAlertsActive, isFalse);
      expect(reglages.lowBalanceAlertsActive, isFalse);
    });
  });

  group('withCategoryBudget', () {
    test('normalise la casse de la catégorie', () {
      final reglages =
          const AlertSettings().withCategoryBudget('  tRANSPORT ', 250);
      expect(reglages.categoryBudgets, {'Transport': 250.0});
    });

    test('un montant nul, négatif ou absent retire le budget', () {
      final avec = const AlertSettings().withCategoryBudget('Transport', 250);
      expect(avec.withCategoryBudget('Transport', 0).categoryBudgets, isEmpty);
      expect(avec.withCategoryBudget('Transport', -5).categoryBudgets, isEmpty);
      expect(avec.withCategoryBudget('Transport', null).categoryBudgets,
          isEmpty);
    });

    test('une catégorie vide ne modifie rien', () {
      const origine = AlertSettings();
      expect(origine.withCategoryBudget('', 250), same(origine));
      expect(origine.withCategoryBudget('    ', 250), same(origine));
    });

    test('ne modifie pas l instance d origine', () {
      const origine = AlertSettings();
      origine.withCategoryBudget('Transport', 250);
      expect(origine.categoryBudgets, isEmpty);
    });

    test('budgetFor retrouve le budget quelle que soit la casse saisie', () {
      final reglages =
          const AlertSettings().withCategoryBudget('Transport', 250);
      expect(reglages.budgetFor('transport'), 250);
      expect(reglages.budgetFor('  TRANSPORT  '), 250);
      expect(reglages.budgetFor('Loyer'), isNull);
    });
  });

  group('withAccountThreshold', () {
    test('un identifiant vide ne modifie rien', () {
      const origine = AlertSettings();
      expect(origine.withAccountThreshold('', 100), same(origine));
    });

    test('un seuil négatif est accepté', () {
      final reglages =
          const AlertSettings().withAccountThreshold('acc-1', -5000);
      expect(reglages.thresholdFor('acc-1'), -5000);
    });

    test('thresholdFor rend null pour un compte non surveillé', () {
      expect(const AlertSettings().thresholdFor('acc-1'), isNull);
    });
  });

  group('fromJson tolérante', () {
    test('un objet vide rend les valeurs par défaut', () {
      expect(AlertSettings.fromJson(const {}), const AlertSettings());
    });

    test('les booléens acceptent nombres et chaînes reconnues', () {
      final reglages = AlertSettings.fromJson(const {
        'budget_alerts_enabled': 0,
        'low_balance_alerts_enabled': 'false',
        'unsynced_data_alerts_enabled': '1',
      });
      expect(reglages.budgetAlertsEnabled, isFalse);
      expect(reglages.lowBalanceAlertsEnabled, isFalse);
      expect(reglages.unsyncedDataAlertsEnabled, isTrue);
    });

    test('un booléen incompréhensible retombe sur le défaut', () {
      final reglages = AlertSettings.fromJson(const {
        'budget_alerts_enabled': 'peut-être',
        'low_balance_alerts_enabled': null,
      });
      expect(reglages.budgetAlertsEnabled, isTrue);
      expect(reglages.lowBalanceAlertsEnabled, isTrue);
    });

    test('des budgets de mauvais type sont ignorés en bloc', () {
      final reglages = AlertSettings.fromJson(const {
        'category_budgets': ['Transport'],
      });
      expect(reglages.categoryBudgets, isEmpty);
    });

    test('les budgets sont normalisés et filtrés à la relecture', () {
      final reglages = AlertSettings.fromJson(const {
        'category_budgets': {
          '  transport  ': 100,
          'LOYER': '250.5',
          'Cadeaux': -5,
          'Rien': 0,
          '   ': 80,
          'Illisible': 'beaucoup',
        },
      });
      expect(reglages.categoryBudgets, {'Transport': 100.0, 'Loyer': 250.5});
    });

    test('les seuils de compte gardent 0 et les valeurs négatives', () {
      final reglages = AlertSettings.fromJson(const {
        'account_thresholds': {'acc-1': 0, 'acc-2': -20, 'acc-3': '1500'},
      });
      expect(reglages.accountThresholds, {
        'acc-1': 0.0,
        'acc-2': -20.0,
        'acc-3': 1500.0,
      });
    });

    test('les seuils non finis sont rejetés', () {
      final reglages = AlertSettings.fromJson(const {
        'account_thresholds': {
          'acc-nan': 'NaN',
          'acc-inf': 'Infinity',
          'acc-ok': 500,
        },
      });
      expect(reglages.accountThresholds, {'acc-ok': 500.0});
    });

    test('les clés de compte sont détourées, les clés vides écartées', () {
      final reglages = AlertSettings.fromJson(const {
        'account_thresholds': {'  acc-1  ': 100, '   ': 50},
      });
      expect(reglages.accountThresholds, {'acc-1': 100.0});
    });

    test('la casse des identifiants de compte est préservée', () {
      final reglages = AlertSettings.fromJson(const {
        'account_thresholds': {'ACC-1': 100},
      });
      expect(reglages.thresholdFor('ACC-1'), 100);
      expect(reglages.thresholdFor('acc-1'), isNull);
    });
  });

  group('aller-retour toJson / fromJson', () {
    test('des réglages complets survivent au passage par JSON', () {
      const origine = AlertSettings(
        budgetAlertsEnabled: false,
        lowBalanceAlertsEnabled: true,
        unsyncedDataAlertsEnabled: false,
        categoryBudgets: {'Transport': 250.5, 'Loyer': 100},
        accountThresholds: {'acc-1': 0, 'acc-2': -20},
        unsyncedThresholdHours: 72,
      );
      final relu = AlertSettings.fromJson(
        jsonDecode(jsonEncode(origine.toJson())) as Map<String, dynamic>,
      );
      expect(relu, origine);
      expect(relu.hashCode, origine.hashCode);
    });

    test('un second aller-retour est stable', () {
      const origine = AlertSettings(
        categoryBudgets: {'Transport': 250.5},
        accountThresholds: {'acc-1': 0},
      );
      final un = AlertSettings.fromJson(
        jsonDecode(jsonEncode(origine.toJson())) as Map<String, dynamic>,
      );
      final deux = AlertSettings.fromJson(
        jsonDecode(jsonEncode(un.toJson())) as Map<String, dynamic>,
      );
      expect(deux, un);
      expect(jsonEncode(deux.toJson()), jsonEncode(un.toJson()));
    });
  });

  group('copyWith et égalité', () {
    test('copyWith ne touche que les champs fournis', () {
      const origine = AlertSettings(
        categoryBudgets: {'Transport': 100},
        unsyncedThresholdHours: 72,
      );
      final modifie = origine.copyWith(budgetAlertsEnabled: false);
      expect(modifie.budgetAlertsEnabled, isFalse);
      expect(modifie.categoryBudgets, origine.categoryBudgets);
      expect(modifie.unsyncedThresholdHours, 72);
    });

    test('deux réglages de même contenu sont égaux', () {
      const a = AlertSettings(
        categoryBudgets: {'A': 1, 'B': 2},
        accountThresholds: {'x': 0},
      );
      const b = AlertSettings(
        categoryBudgets: {'B': 2, 'A': 1},
        accountThresholds: {'x': 0},
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('un budget différent casse l égalité', () {
      expect(
        const AlertSettings(categoryBudgets: {'A': 1}),
        isNot(const AlertSettings(categoryBudgets: {'A': 2})),
      );
    });
  });
}
