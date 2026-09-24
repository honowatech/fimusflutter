import 'package:flutter_test/flutter_test.dart';
import 'package:monitrack/services/alerts/alert_evaluator.dart';
import 'package:monitrack/services/alerts/alert_models.dart';
import 'package:monitrack/services/alerts/alert_settings.dart';
import 'package:monitrack/services/alerts/alert_state.dart';

import 'alert_test_helpers.dart';

/// Alerte « données non synchronisées » : ancienneté minimale, anti-spam 24 h,
/// ancienneté indémontrable.
void main() {
  final maintenant = DateTime(2026, 9, 15, 12, 0);

  UnsyncedDataAlert? evaluerSonde({
    AlertSettings reglages = const AlertSettings(),
    AlertEmissionState etat = AlertEmissionState.empty,
    required UnsyncedSnapshot photo,
    DateTime? now,
  }) {
    return evaluateUnsyncedAlert(
      settings: reglages,
      state: etat,
      snapshot: photo,
      now: now ?? maintenant,
    );
  }

  group('seuil d ancienneté', () {
    test('rien quand la plus ancienne ligne a moins de 48 h', () {
      final alerte = evaluerSonde(
        photo: UnsyncedSnapshot(
          pendingCount: 12,
          oldestPendingAt: maintenant.subtract(const Duration(hours: 47, minutes: 59)),
        ),
      );
      expect(alerte, isNull);
    });

    test('alerte dès 48 h révolues', () {
      final alerte = evaluerSonde(
        photo: UnsyncedSnapshot(
          pendingCount: 12,
          oldestPendingAt: maintenant.subtract(const Duration(hours: 48)),
        ),
      );
      expect(alerte, isNotNull);
      expect(alerte!.pendingCount, 12);
      expect(alerte.pendingSinceHours, 48);
    });

    test('l ancienneté rapportée est tronquée à l heure', () {
      final alerte = evaluerSonde(
        photo: UnsyncedSnapshot(
          pendingCount: 3,
          oldestPendingAt:
              maintenant.subtract(const Duration(hours: 73, minutes: 59)),
        ),
      );
      expect(alerte!.pendingSinceHours, 73);
    });

    test('un délai personnalisé de 24 h avance le déclenchement', () {
      final reglages = const AlertSettings(unsyncedThresholdHours: 24);
      final alerte = evaluerSonde(
        reglages: reglages,
        photo: UnsyncedSnapshot(
          pendingCount: 1,
          oldestPendingAt: maintenant.subtract(const Duration(hours: 30)),
        ),
      );
      expect(alerte, isNotNull);
    });

    test('un délai personnalisé de 168 h retarde le déclenchement', () {
      final reglages = const AlertSettings(unsyncedThresholdHours: 168);
      final alerte = evaluerSonde(
        reglages: reglages,
        photo: UnsyncedSnapshot(
          pendingCount: 1,
          oldestPendingAt: maintenant.subtract(const Duration(hours: 100)),
        ),
      );
      expect(alerte, isNull);
    });
  });

  group('délai personnalisé borné à la désérialisation', () {
    test('une valeur nulle ou négative retombe sur 48 h', () {
      expect(
        AlertSettings.fromJson(const {'unsynced_threshold_hours': 0})
            .unsyncedThresholdHours,
        AlertSettings.defaultUnsyncedThresholdHours,
      );
      expect(
        AlertSettings.fromJson(const {'unsynced_threshold_hours': -12})
            .unsyncedThresholdHours,
        AlertSettings.defaultUnsyncedThresholdHours,
      );
    });

    test('une valeur démesurée est plafonnée à 720 h', () {
      expect(
        AlertSettings.fromJson(const {'unsynced_threshold_hours': 99999})
            .unsyncedThresholdHours,
        720,
      );
    });

    test('une chaîne numérique est acceptée, une chaîne libre non', () {
      expect(
        AlertSettings.fromJson(const {'unsynced_threshold_hours': '72'})
            .unsyncedThresholdHours,
        72,
      );
      expect(
        AlertSettings.fromJson(const {'unsynced_threshold_hours': 'jamais'})
            .unsyncedThresholdHours,
        AlertSettings.defaultUnsyncedThresholdHours,
      );
    });

    test('tous les choix proposés à l écran traversent la désérialisation', () {
      for (final heures in AlertSettings.unsyncedThresholdChoices) {
        expect(
          AlertSettings.fromJson({'unsynced_threshold_hours': heures})
              .unsyncedThresholdHours,
          heures,
        );
      }
    });

    test('le seuil se traduit en Duration', () {
      expect(
        const AlertSettings(unsyncedThresholdHours: 72).unsyncedThreshold,
        const Duration(hours: 72),
      );
    });
  });

  group('anti-spam de 24 h', () {
    test('rien si la dernière alerte date de moins de 24 h', () {
      final etat = AlertEmissionState.empty
          .markUnsyncedAlert(maintenant.subtract(const Duration(hours: 23)));
      final alerte = evaluerSonde(
        etat: etat,
        photo: UnsyncedSnapshot(
          pendingCount: 5,
          oldestPendingAt: maintenant.subtract(const Duration(hours: 200)),
        ),
      );
      expect(alerte, isNull);
    });

    test('alerte de nouveau après 24 h révolues', () {
      final etat = AlertEmissionState.empty
          .markUnsyncedAlert(maintenant.subtract(const Duration(hours: 24)));
      final alerte = evaluerSonde(
        etat: etat,
        photo: UnsyncedSnapshot(
          pendingCount: 5,
          oldestPendingAt: maintenant.subtract(const Duration(hours: 200)),
        ),
      );
      expect(alerte, isNotNull);
    });

    test('une horloge qui recule ne bloque pas l alerte', () {
      final etat = AlertEmissionState.empty
          .markUnsyncedAlert(maintenant.add(const Duration(days: 40)));
      expect(etat.canEmitUnsynced(maintenant), isTrue);
    });

    test('canEmitUnsynced autorise la toute première émission', () {
      expect(AlertEmissionState.empty.canEmitUnsynced(maintenant), isTrue);
    });
  });

  group('ancienneté indémontrable et file vide', () {
    test('rien quand oldestPendingAt est nul malgré des lignes en attente', () {
      final alerte = evaluerSonde(
        photo: const UnsyncedSnapshot(pendingCount: 42),
      );
      expect(alerte, isNull);
    });

    test('rien quand la file est vide', () {
      final alerte = evaluerSonde(photo: const UnsyncedSnapshot.empty());
      expect(alerte, isNull);
    });

    test('rien quand pendingCount est négatif', () {
      final alerte = evaluerSonde(
        photo: UnsyncedSnapshot(
          pendingCount: -3,
          oldestPendingAt: maintenant.subtract(const Duration(days: 30)),
        ),
      );
      expect(alerte, isNull);
    });

    test('rien quand l interrupteur est coupé', () {
      final alerte = evaluerSonde(
        reglages: const AlertSettings(unsyncedDataAlertsEnabled: false),
        photo: UnsyncedSnapshot(
          pendingCount: 5,
          oldestPendingAt: maintenant.subtract(const Duration(days: 30)),
        ),
      );
      expect(alerte, isNull);
    });
  });

  group('intégration dans evaluateAlerts', () {
    test('l émission horodate l état anti-spam', () {
      final resultat = evaluateAlerts(
        settings: const AlertSettings(
          budgetAlertsEnabled: false,
          lowBalanceAlertsEnabled: false,
        ),
        state: AlertEmissionState.empty,
        notificationPreferences: sansHeuresCalmes,
        expenses: const [],
        accounts: const [],
        unsynced: UnsyncedSnapshot(
          pendingCount: 7,
          oldestPendingAt: maintenant.subtract(const Duration(hours: 60)),
        ),
        now: maintenant,
        currency: 'XOF',
      );
      expect(resultat.toEmit, hasLength(1));
      expect(resultat.toEmit.single, isA<UnsyncedDataAlert>());
      expect(resultat.nextState.lastUnsyncedAlertAt, maintenant);
    });

    test('une seconde évaluation immédiate n émet rien', () {
      const reglages = AlertSettings(
        budgetAlertsEnabled: false,
        lowBalanceAlertsEnabled: false,
      );
      final photo = UnsyncedSnapshot(
        pendingCount: 7,
        oldestPendingAt: maintenant.subtract(const Duration(hours: 60)),
      );
      final premiere = evaluateAlerts(
        settings: reglages,
        state: AlertEmissionState.empty,
        notificationPreferences: sansHeuresCalmes,
        expenses: const [],
        accounts: const [],
        unsynced: photo,
        now: maintenant,
        currency: 'XOF',
      );
      final seconde = evaluateAlerts(
        settings: reglages,
        state: premiere.nextState,
        notificationPreferences: sansHeuresCalmes,
        expenses: const [],
        accounts: const [],
        unsynced: photo,
        now: maintenant.add(const Duration(hours: 1)),
        currency: 'XOF',
      );
      expect(seconde.isEmpty, isTrue);
    });
  });

  group('UnsyncedSnapshot.combine', () {
    test('agrège les compteurs et retient l horodatage le plus ancien', () {
      final agrege = UnsyncedSnapshot.combine([
        UnsyncedSnapshot(
          pendingCount: 2,
          oldestPendingAt: DateTime(2026, 9, 10),
        ),
        UnsyncedSnapshot(
          pendingCount: 3,
          oldestPendingAt: DateTime(2026, 9, 2),
        ),
        UnsyncedSnapshot(
          pendingCount: 1,
          oldestPendingAt: DateTime(2026, 9, 12),
        ),
      ]);
      expect(agrege.pendingCount, 6);
      expect(agrege.oldestPendingAt, DateTime(2026, 9, 2));
    });

    test('ignore les horodatages absents sans perdre les compteurs', () {
      final agrege = UnsyncedSnapshot.combine([
        const UnsyncedSnapshot(pendingCount: 4),
        UnsyncedSnapshot(
          pendingCount: 1,
          oldestPendingAt: DateTime(2026, 9, 5),
        ),
      ]);
      expect(agrege.pendingCount, 5);
      expect(agrege.oldestPendingAt, DateTime(2026, 9, 5));
    });

    test('rend une photo vide pour une liste vide', () {
      final agrege = UnsyncedSnapshot.combine(const []);
      expect(agrege.pendingCount, 0);
      expect(agrege.oldestPendingAt, isNull);
      expect(agrege.isEmpty, isTrue);
    });

    test('rend un horodatage nul quand aucune partie n en porte', () {
      final agrege = UnsyncedSnapshot.combine(const [
        UnsyncedSnapshot(pendingCount: 2),
        UnsyncedSnapshot(pendingCount: 3),
      ]);
      expect(agrege.pendingCount, 5);
      expect(agrege.oldestPendingAt, isNull);
    });

    test('isEmpty distingue une file vide d une file peuplée', () {
      expect(const UnsyncedSnapshot.empty().isEmpty, isTrue);
      expect(const UnsyncedSnapshot(pendingCount: 0).isEmpty, isTrue);
      expect(const UnsyncedSnapshot(pendingCount: 1).isEmpty, isFalse);
    });

    test('deux photos identiques sont égales et partagent leur empreinte', () {
      final a = UnsyncedSnapshot(
        pendingCount: 3,
        oldestPendingAt: DateTime(2026, 9, 5),
      );
      final b = UnsyncedSnapshot(
        pendingCount: 3,
        oldestPendingAt: DateTime(2026, 9, 5),
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(const UnsyncedSnapshot(pendingCount: 3)));
    });
  });
}
