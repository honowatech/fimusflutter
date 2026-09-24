import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:monitrack/services/alerts/alert_models.dart';
import 'package:monitrack/services/notifications/reminder_ids.dart';
import 'package:monitrack/utils/notification_channels.dart';

/// Identité des alertes locales : graines d'identifiant, identifiants de
/// notification, payload.
void main() {
  BudgetThresholdAlert budget({
    String categorie = 'Transport',
    String periode = '2026-09',
    int palier = 100,
    double depense = 120,
    double budget = 100,
  }) {
    return BudgetThresholdAlert(
      category: categorie,
      period: periode,
      tier: palier,
      spent: depense,
      budget: budget,
      currency: 'XOF',
    );
  }

  LowBalanceAlert solde({String compte = 'acc-1'}) => LowBalanceAlert(
        accountId: compte,
        accountName: 'Compte courant',
        balance: 120,
        threshold: 1000,
        currency: 'XOF',
      );

  const sync = UnsyncedDataAlert(pendingCount: 7, pendingSinceHours: 63);

  group('localAlertTypeOf', () {
    test('chaque famille porte le type attendu', () {
      expect(
        localAlertTypeOf(LocalAlertKind.budgetThreshold),
        NotificationChannels.budgetThresholdType,
      );
      expect(
        localAlertTypeOf(LocalAlertKind.lowBalance),
        NotificationChannels.lowBalanceType,
      );
      expect(
        localAlertTypeOf(LocalAlertKind.unsyncedData),
        NotificationChannels.unsyncedDataType,
      );
    });

    test('les trois types sont distincts', () {
      final types =
          LocalAlertKind.values.map(localAlertTypeOf).toSet();
      expect(types, hasLength(LocalAlertKind.values.length));
    });

    test('les trois types sont routés vers le canal des alertes', () {
      for (final kind in LocalAlertKind.values) {
        expect(
          NotificationChannels.androidChannelIdForType(localAlertTypeOf(kind)),
          NotificationChannels.alerts,
          reason: '$kind doit rester sur le canal des alertes locales',
        );
      }
    });
  });

  group('idSeed', () {
    test('le budget dépend du mois et de la catégorie, pas du palier', () {
      expect(budget().idSeed, 'alert_budget_2026-09_Transport');
      expect(budget(palier: 80).idSeed, budget(palier: 100).idSeed);
      expect(
        budget(periode: '2026-10').idSeed,
        isNot(budget(periode: '2026-09').idSeed),
      );
      expect(
        budget(categorie: 'Loyer').idSeed,
        isNot(budget(categorie: 'Transport').idSeed),
      );
    });

    test('le solde bas dépend du compte', () {
      expect(solde().idSeed, 'alert_low_balance_acc-1');
      expect(solde(compte: 'acc-2').idSeed, isNot(solde().idSeed));
    });

    test('les données non synchronisées ont une graine unique et fixe', () {
      expect(sync.idSeed, 'alert_unsynced_data');
      expect(
        const UnsyncedDataAlert(pendingCount: 1, pendingSinceHours: 99).idSeed,
        sync.idSeed,
      );
    });
  });

  group('notificationId', () {
    test('tient sur 31 bits positifs', () {
      for (final alerte in <PendingAlert>[budget(), solde(), sync]) {
        expect(alerte.notificationId, greaterThanOrEqualTo(0));
        expect(alerte.notificationId, lessThanOrEqualTo(0x7fffffff));
      }
    });

    test('est stable pour une même graine', () {
      expect(budget().notificationId, budget().notificationId);
      expect(budget(palier: 80).notificationId, budget().notificationId);
    });

    test('les trois familles ne se marchent pas dessus', () {
      final ids = <int>{
        budget().notificationId,
        solde().notificationId,
        sync.notificationId,
      };
      expect(ids, hasLength(3));
    });

    test('aucune collision entre alertes d un même parc réaliste', () {
      final ids = <int, String>{};
      void enregistrer(String graine, int id) {
        expect(
          ids.containsKey(id),
          isFalse,
          reason: 'collision entre "$graine" et "${ids[id]}"',
        );
        ids[id] = graine;
      }

      const categories = [
        'Transport',
        'Loyer',
        'Courses',
        'Santé',
        'Loisirs',
        'Éducation',
        'Cadeaux',
        'Épargne',
      ];
      for (var mois = 1; mois <= 12; mois++) {
        final periode = '2026-${mois.toString().padLeft(2, '0')}';
        for (final categorie in categories) {
          final alerte = budget(categorie: categorie, periode: periode);
          enregistrer(alerte.idSeed, alerte.notificationId);
        }
      }
      for (var i = 0; i < 40; i++) {
        final alerte = solde(compte: 'compte-uuid-$i');
        enregistrer(alerte.idSeed, alerte.notificationId);
      }
      enregistrer(sync.idSeed, sync.notificationId);
    });

    test('aucune collision avec les rappels locaux existants', () {
      final alertes = <int>{
        budget().notificationId,
        solde().notificationId,
        sync.notificationId,
        for (var i = 0; i < 40; i++) solde(compte: 'exp-$i').notificationId,
      };
      final rappels = <int>{
        for (var i = 0; i < 40; i++) ReminderIds.debtNotificationId('exp-$i'),
        for (var i = 0; i < 40; i++)
          ReminderIds.scheduledExpenseNotificationId('exp-$i'),
      };
      expect(alertes.intersection(rappels), isEmpty);
    });
  });

  group('payload', () {
    test('le budget transporte son type, sa source et son identité', () {
      final decode = jsonDecode(budget(palier: 80).payload)
          as Map<String, dynamic>;
      expect(decode, {
        'type': NotificationChannels.budgetThresholdType,
        'source': 'local_alert',
        'category': 'Transport',
        'period': '2026-09',
        'tier': 80,
      });
    });

    test('le solde bas transporte l identifiant du compte', () {
      final decode = jsonDecode(solde().payload) as Map<String, dynamic>;
      expect(decode['type'], NotificationChannels.lowBalanceType);
      expect(decode['source'], 'local_alert');
      expect(decode['account_id'], 'acc-1');
    });

    test('les données non synchronisées transportent volume et ancienneté',
        () {
      final decode = jsonDecode(sync.payload) as Map<String, dynamic>;
      expect(decode['type'], NotificationChannels.unsyncedDataType);
      expect(decode['pending_count'], 7);
      expect(decode['pending_since_hours'], 63);
    });

    test('la source distingue ces alertes des rappels et des pushs', () {
      for (final alerte in <PendingAlert>[budget(), solde(), sync]) {
        final decode = jsonDecode(alerte.payload) as Map<String, dynamic>;
        expect(decode['source'], 'local_alert');
        expect(decode['source'], isNot('local'));
      }
    });

    test('notificationType reflète la famille', () {
      expect(
        budget().notificationType,
        NotificationChannels.budgetThresholdType,
      );
      expect(solde().notificationType, NotificationChannels.lowBalanceType);
      expect(sync.notificationType, NotificationChannels.unsyncedDataType);
    });
  });

  group('consumedPercent', () {
    test('arrondit au pourcentage entier le plus proche', () {
      expect(budget(depense: 126, budget: 150).consumedPercent, 84);
      expect(budget(depense: 84.5, budget: 100).consumedPercent, 85);
      expect(budget(depense: 84.4, budget: 100).consumedPercent, 84);
    });

    test('peut dépasser 100', () {
      expect(budget(depense: 310, budget: 100).consumedPercent, 310);
    });

    test('rend 0 pour un budget nul ou négatif, sans division par zéro', () {
      expect(budget(depense: 500, budget: 0).consumedPercent, 0);
      expect(budget(depense: 500, budget: -10).consumedPercent, 0);
    });
  });
}
