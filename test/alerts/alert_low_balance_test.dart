import 'package:flutter_test/flutter_test.dart';
import 'package:monitrack/models/account.dart';
import 'package:monitrack/models/notification_preferences.dart';
import 'package:monitrack/services/alerts/alert_evaluator.dart';
import 'package:monitrack/services/alerts/alert_models.dart';
import 'package:monitrack/services/alerts/alert_settings.dart';
import 'package:monitrack/services/alerts/alert_state.dart';

import 'alert_test_helpers.dart';

/// Alertes « solde bas » : armement sous le seuil, désarmement au retour
/// au-dessus, nettoyage des comptes disparus.
void main() {
  const reglages = AlertSettings(
    budgetAlertsEnabled: false,
    unsyncedDataAlertsEnabled: false,
    accountThresholds: {'acc-1': 1000},
  );

  AlertEvaluation evaluer({
    AlertSettings parametres = reglages,
    AlertEmissionState etat = AlertEmissionState.empty,
    List<Account> comptes = const <Account>[],
    NotificationPreferences preferences = sansHeuresCalmes,
    DateTime? maintenant,
  }) {
    return evaluateAlerts(
      settings: parametres,
      state: etat,
      notificationPreferences: preferences,
      expenses: const [],
      accounts: comptes,
      unsynced: const UnsyncedSnapshot.empty(),
      now: maintenant ?? moisCourant,
      currency: 'XOF',
    );
  }

  group('armement', () {
    test('un solde sous le seuil arme le compte et émet une alerte', () {
      final resultat = evaluer(comptes: [compte(solde: 500)]);
      expect(resultat.toEmit, hasLength(1));
      final alerte = resultat.toEmit.single as LowBalanceAlert;
      expect(alerte.accountId, 'acc-1');
      expect(alerte.balance, 500);
      expect(alerte.threshold, 1000);
      expect(resultat.nextState.isLowBalanceArmed('acc-1'), isTrue);
    });

    test('un solde exactement au seuil ne déclenche rien', () {
      final resultat = evaluer(comptes: [compte(solde: 1000)]);
      expect(resultat.isEmpty, isTrue);
      expect(resultat.nextState.isLowBalanceArmed('acc-1'), isFalse);
    });

    test('une seule alerte tant que le solde reste sous le seuil', () {
      final premiere = evaluer(comptes: [compte(solde: 500)]);
      final seconde = evaluer(
        etat: premiere.nextState,
        comptes: [compte(solde: 120)],
      );
      expect(seconde.toEmit, isEmpty);
      expect(seconde.deferred, isEmpty);
      expect(seconde.nextState.isLowBalanceArmed('acc-1'), isTrue);
    });

    test('un compte sans seuil configuré est ignoré', () {
      final resultat = evaluer(comptes: [compte(id: 'acc-9', solde: -5000)]);
      expect(resultat.isEmpty, isTrue);
    });
  });

  group('désarmement', () {
    test('le retour au-dessus du seuil désarme et réautorise une alerte', () {
      final armee =
          AlertEmissionState.empty.armLowBalance('acc-1');

      final remontee = evaluer(etat: armee, comptes: [compte(solde: 2500)]);
      expect(remontee.toEmit, isEmpty);
      expect(remontee.nextState.isLowBalanceArmed('acc-1'), isFalse);

      final rechute = evaluer(
        etat: remontee.nextState,
        comptes: [compte(solde: 300)],
      );
      expect(rechute.toEmit, hasLength(1));
      expect(rechute.toEmit.single, isA<LowBalanceAlert>());
    });

    test('le désarmement s applique aussi pendant les heures calmes', () {
      final armee = AlertEmissionState.empty.armLowBalance('acc-1');
      final nuit = DateTime(2026, 9, 15, 23, 30);

      final resultat = evaluer(
        etat: armee,
        comptes: [compte(solde: 2500)],
        preferences: avecHeuresCalmes,
        maintenant: nuit,
      );

      expect(
        resultat.nextState.isLowBalanceArmed('acc-1'),
        isFalse,
        reason: 'un désarmement différé ferait perdre l alerte suivante',
      );
    });

    test('un désarmement nocturne permet une alerte dès le matin', () {
      final armee = AlertEmissionState.empty.armLowBalance('acc-1');

      // 23 h 30 : le solde est remonté, rien n'est affiché mais on désarme.
      final nuit = evaluer(
        etat: armee,
        comptes: [compte(solde: 2500)],
        preferences: avecHeuresCalmes,
        maintenant: DateTime(2026, 9, 15, 23, 30),
      );

      // 09 h 00 : le solde a rechuté, l'alerte doit repartir.
      final matin = evaluer(
        etat: nuit.nextState,
        comptes: [compte(solde: 100)],
        preferences: avecHeuresCalmes,
        maintenant: DateTime(2026, 9, 16, 9, 0),
      );
      expect(matin.toEmit, hasLength(1));
      expect(
        (matin.toEmit.single as LowBalanceAlert).balance,
        100,
      );
    });

    test('un compte supprimé est désarmé', () {
      final armee = AlertEmissionState.empty.armLowBalance('acc-1');
      final resultat = evaluer(etat: armee, comptes: const []);
      expect(resultat.nextState.lowBalanceAccounts, isEmpty);
    });

    test('le retrait du seuil désarme le compte', () {
      final armee = AlertEmissionState.empty.armLowBalance('acc-1');
      final resultat = evaluer(
        parametres: reglages.withAccountThreshold('acc-1', null),
        etat: armee,
        comptes: [compte(solde: 10)],
      );
      expect(resultat.toEmit, isEmpty);
      expect(resultat.nextState.isLowBalanceArmed('acc-1'), isFalse);
    });
  });

  group('seuil à zéro', () {
    const seuilZero = AlertSettings(
      budgetAlertsEnabled: false,
      unsyncedDataAlertsEnabled: false,
      accountThresholds: {'acc-1': 0},
    );

    test('un seuil à 0 reste une valeur de surveillance valide', () {
      expect(seuilZero.thresholdFor('acc-1'), 0);
      expect(seuilZero.lowBalanceAlertsActive, isTrue);
    });

    test('un solde négatif déclenche l alerte avec un seuil à 0', () {
      final resultat = evaluer(
        parametres: seuilZero,
        comptes: [compte(solde: -250)],
      );
      expect(resultat.toEmit, hasLength(1));
      expect((resultat.toEmit.single as LowBalanceAlert).threshold, 0);
    });

    test('un solde nul ne déclenche pas l alerte avec un seuil à 0', () {
      final resultat = evaluer(
        parametres: seuilZero,
        comptes: [compte(solde: 0)],
      );
      expect(resultat.isEmpty, isTrue);
    });

    test('withAccountThreshold conserve 0 et ne supprime que sur null', () {
      final avecZero = const AlertSettings().withAccountThreshold('acc-1', 0);
      expect(avecZero.accountThresholds, {'acc-1': 0.0});
      final retire = avecZero.withAccountThreshold('acc-1', null);
      expect(retire.accountThresholds, isEmpty);
    });
  });

  group('interrupteur et comptes multiples', () {
    test('aucune alerte quand l interrupteur solde bas est coupé', () {
      final resultat = evaluer(
        parametres: const AlertSettings(
          budgetAlertsEnabled: false,
          unsyncedDataAlertsEnabled: false,
          lowBalanceAlertsEnabled: false,
          accountThresholds: {'acc-1': 1000},
        ),
        comptes: [compte(solde: -100)],
      );
      expect(resultat.isEmpty, isTrue);
    });

    test('chaque compte surveillé a son propre armement', () {
      const deuxComptes = AlertSettings(
        budgetAlertsEnabled: false,
        unsyncedDataAlertsEnabled: false,
        accountThresholds: {'acc-1': 1000, 'acc-2': 500},
      );
      final premier = evaluer(
        parametres: deuxComptes,
        comptes: [
          compte(id: 'acc-1', solde: 200),
          compte(id: 'acc-2', solde: 900),
        ],
      );
      expect(premier.toEmit, hasLength(1));
      expect((premier.toEmit.single as LowBalanceAlert).accountId, 'acc-1');

      final second = evaluer(
        parametres: deuxComptes,
        etat: premier.nextState,
        comptes: [
          compte(id: 'acc-1', solde: 200),
          compte(id: 'acc-2', solde: 100),
        ],
      );
      expect(second.toEmit, hasLength(1));
      expect((second.toEmit.single as LowBalanceAlert).accountId, 'acc-2');
      expect(second.nextState.lowBalanceAccounts, {'acc-1', 'acc-2'});
    });
  });

  group('evaluateLowBalanceAlerts, appelé directement', () {
    test(
        'famille désactivée : aucune alerte, mais les désarmements sont '
        'appliqués', () {
      final armee = AlertEmissionState.empty.armLowBalance('acc-1');

      // Compte disparu : il doit être désarmé même interrupteur coupé.
      final sansCompte = evaluateLowBalanceAlerts(
        settings: const AlertSettings(lowBalanceAlertsEnabled: false),
        state: armee,
        accounts: const [],
        currency: 'XOF',
      );
      expect(sansCompte.candidates, isEmpty);
      expect(sansCompte.state.isLowBalanceArmed('acc-1'), isFalse,
          reason: 'un désarmement n affiche rien : il ne doit pas être '
              'suspendu par l interrupteur');

      // Solde remonté au-dessus du seuil : même chose.
      final remonte = evaluateLowBalanceAlerts(
        settings: const AlertSettings(
          lowBalanceAlertsEnabled: false,
          accountThresholds: {'acc-1': 1000},
        ),
        state: armee,
        accounts: [compte(id: 'acc-1', solde: 5000)],
        currency: 'XOF',
      );
      expect(remonte.candidates, isEmpty);
      expect(remonte.state.isLowBalanceArmed('acc-1'), isFalse);

      // Toujours sous le seuil : rien n'est émis et rien n'est armé.
      final sousLeSeuil = evaluateLowBalanceAlerts(
        settings: const AlertSettings(
          lowBalanceAlertsEnabled: false,
          accountThresholds: {'acc-2': 1000},
        ),
        state: AlertEmissionState.empty,
        accounts: [compte(id: 'acc-2', solde: 10)],
        currency: 'XOF',
      );
      expect(sousLeSeuil.candidates, isEmpty);
      expect(sousLeSeuil.state.isLowBalanceArmed('acc-2'), isFalse);
    });

    test('désarme un compte remonté et arme rien de plus', () {
      final armee = AlertEmissionState.empty
          .armLowBalance('acc-1')
          .armLowBalance('acc-2');
      final resultat = evaluateLowBalanceAlerts(
        settings: const AlertSettings(
          accountThresholds: {'acc-1': 1000, 'acc-2': 1000},
        ),
        state: armee,
        accounts: [
          compte(id: 'acc-1', solde: 5000),
          compte(id: 'acc-2', solde: 10),
        ],
        currency: 'XOF',
      );
      expect(resultat.candidates, isEmpty);
      expect(resultat.state.lowBalanceAccounts, {'acc-2'});
    });
  });
}
