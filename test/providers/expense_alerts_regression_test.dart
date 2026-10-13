import 'package:flutter_test/flutter_test.dart';
import 'package:monitrack/providers/account_provider.dart';
import 'package:monitrack/providers/expense_provider.dart';
import 'package:monitrack/services/alerts/alert_settings_store.dart';
import 'package:monitrack/services/alerts/alert_state.dart';
import 'package:monitrack/services/alerts/local_alerts_service.dart';
import 'package:monitrack/utils/category_normalizer.dart';

import '../balance_test_helpers.dart';

/// Non-régression des alertes locales après le passage à la conversion de
/// devise au centre.
///
/// La conversion a déplacé le calcul du solde dans `updateBalance` ; les deux
/// évaluations d'alerte qui pendaient à ce chemin (solde bas côté
/// `AccountProvider`, budget côté `ExpenseProvider`) doivent toujours partir.
///
/// Observation : l'affichage passe par le plugin de notifications, indisponible
/// en test. On observe donc l'**état anti-spam** (`alerts_emission_state_v1`),
/// qui est persisté *avant* la tentative d'affichage : c'est la trace qu'une
/// alerte a bien été retenue pour émission.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initialiserSqfliteFfi);

  const store = AlertSettingsStore();

  setUp(() async {
    couperLeReseau();
    preparerPreferences(deviseProfil: 'XOF');
    await preparerBase();
    // `LocalAlertsService` est un singleton avec un anti-rebond de 10 s : sans
    // cette remise à zéro, seul le premier test du fichier serait évalué.
    await LocalAlertsService.instance.clear();
  });

  /// Relit l'état anti-spam jusqu'à ce que [condition] soit vraie, ou rend le
  /// dernier état lu. Les évaluations sont lancées sans être attendues par les
  /// providers : il faut laisser tourner la boucle d'événements.
  Future<AlertEmissionState> etatAlertes(
      bool Function(AlertEmissionState) condition) async {
    var etat = await store.readState();
    for (var i = 0; i < 40 && !condition(etat); i++) {
      await pumpEventQueue(times: 5);
      etat = await store.readState();
    }
    return etat;
  }

  group('Alerte « solde bas »', () {
    test('un mouvement converti qui passe sous le seuil arme l’alerte',
        () async {
      await insererCompte('acc-xof', solde: 60000, devise: 'XOF');
      await store.saveAccountThreshold('acc-xof', 50000);
      final comptes = AccountProvider();
      await comptes.loadData();

      // 20 EUR = 15 000 XOF : c'est la conversion, et elle seule, qui fait
      // passer le compte sous son seuil. Un delta brut de 20 l'aurait laissé à
      // 59 980.
      await comptes.updateBalance('acc-xof', -20, operationCurrency: 'EUR');

      expect(await soldeEnBase('acc-xof'), 45000.0);
      final etat = await etatAlertes((e) => e.isLowBalanceArmed('acc-xof'));
      expect(etat.isLowBalanceArmed('acc-xof'), isTrue,
          reason: 'le franchissement du seuil doit déclencher l’évaluation');
    });

    test('un compte remonté au-dessus de son seuil est désarmé', () async {
      await insererCompte('acc-xof', solde: 40000, devise: 'XOF');
      await store.saveAccountThreshold('acc-xof', 50000);
      // L'alerte a déjà été émise sur ce compte lors d'un passage antérieur.
      await store.writeState(
        const AlertEmissionState(lowBalanceAccounts: <String>{'acc-xof'}),
      );
      final comptes = AccountProvider();
      await comptes.loadData();

      // +20 EUR = +15 000 XOF → 55 000, au-dessus du seuil.
      await comptes.updateBalance('acc-xof', 20, operationCurrency: 'EUR');

      expect(await soldeEnBase('acc-xof'), 55000.0);
      final etat = await etatAlertes((e) => !e.isLowBalanceArmed('acc-xof'));
      expect(etat.isLowBalanceArmed('acc-xof'), isFalse,
          reason: 'sans désarmement, la prochaine chute passerait inaperçue');
    });
  });

  group('Alerte « budget de catégorie »', () {
    test('une écriture de dépense déclenche l’évaluation du budget', () async {
      await insererCompte('acc-xof', solde: 100000, devise: 'XOF');
      await store.saveCategoryBudget('Transport', 10000);
      final comptes = AccountProvider();
      final depenses = ExpenseProvider();
      await comptes.loadData();
      await depenses.loadData();

      // 9 000 sur 10 000 : palier d'avertissement (80 %).
      await depenses.addExpenseWithBalance(
        operation('alerte-1',
            montant: 9000,
            categorie: 'Transport',
            compte: 'acc-xof',
            date: DateTime.now()),
        accountProvider: comptes,
      );

      final periode = AlertEmissionState.periodKey(DateTime.now());
      final categorie = normalizeCategory('Transport');
      final etat = await etatAlertes((e) => e.tierFor(periode, categorie) > 0);
      expect(etat.tierFor(periode, categorie), 80);
    });

    test('une dépense qui dépasse le budget marque directement le palier 100 %',
        () async {
      await insererCompte('acc-xof', solde: 100000, devise: 'XOF');
      await store.saveCategoryBudget('Transport', 10000);
      final comptes = AccountProvider();
      final depenses = ExpenseProvider();
      await comptes.loadData();
      await depenses.loadData();

      await depenses.addExpenseWithBalance(
        operation('alerte-2',
            montant: 12000,
            categorie: 'Transport',
            compte: 'acc-xof',
            date: DateTime.now()),
        accountProvider: comptes,
      );

      final periode = AlertEmissionState.periodKey(DateTime.now());
      final etat = await etatAlertes(
          (e) => e.tierFor(periode, normalizeCategory('Transport')) > 0);
      expect(etat.tierFor(periode, normalizeCategory('Transport')), 100);
    });

    test('une dépense dans une autre catégorie ne marque aucun palier',
        () async {
      await insererCompte('acc-xof', solde: 100000, devise: 'XOF');
      await store.saveCategoryBudget('Transport', 10000);
      final comptes = AccountProvider();
      final depenses = ExpenseProvider();
      await comptes.loadData();
      await depenses.loadData();

      await depenses.addExpenseWithBalance(
        operation('alerte-3',
            montant: 50000,
            categorie: 'Loisirs',
            compte: 'acc-xof',
            date: DateTime.now()),
        accountProvider: comptes,
      );

      final periode = AlertEmissionState.periodKey(DateTime.now());
      final etat = await etatAlertes(
          (e) => e.tierFor(periode, normalizeCategory('Loisirs')) > 0);
      expect(etat.tierFor(periode, normalizeCategory('Loisirs')), 0);
      expect(etat.tierFor(periode, normalizeCategory('Transport')), 0);
    });
  });

  group('Confirmation d une depense programmee', () {
    // Le solde y est ecrit en SQL direct, hors d'`AccountProvider` : ni
    // l'alerte « solde bas » ni l'evaluation du budget ne partaient de ce
    // chemin, alors qu'un commentaire du code affirmait le contraire.
    test('la confirmation evalue l alerte de solde bas', () async {
      await insererCompte('acc-xof', solde: 60000, devise: 'XOF');
      await store.saveAccountThreshold('acc-xof', 50000);
      // 20 EUR = 15 000 XOF : la conversion seule fait franchir le seuil.
      await insererDepense(operation('prog-1',
          montant: 20,
          devise: 'EUR',
          compte: 'acc-xof',
          categorie: 'Transport',
          prevision: true,
          statutProgrammation: 'scheduled',
          date: DateTime.now()));

      final depenses = ExpenseProvider();
      await depenses.loadData();
      final resultat = await depenses.confirmScheduledExpenseDetailed('prog-1');

      expect(resultat.isSuccess, isTrue);
      expect(await soldeEnBase('acc-xof'), 45000.0);
      final etat = await etatAlertes((e) => e.isLowBalanceArmed('acc-xof'));
      expect(etat.isLowBalanceArmed('acc-xof'), isTrue,
          reason: 'une confirmation qui vide un compte doit alerter comme '
              'n importe quel autre mouvement');
    });

    test('la confirmation evalue aussi le budget de la categorie', () async {
      await insererCompte('acc-xof', solde: 100000, devise: 'XOF');
      await store.saveCategoryBudget('Transport', 10000);
      await insererDepense(operation('prog-2',
          montant: 9000,
          devise: 'XOF',
          compte: 'acc-xof',
          categorie: 'Transport',
          prevision: true,
          statutProgrammation: 'scheduled',
          date: DateTime.now()));

      final depenses = ExpenseProvider();
      await depenses.loadData();
      await depenses.confirmScheduledExpenseDetailed('prog-2');

      final periode = AlertEmissionState.periodKey(DateTime.now());
      final categorie = normalizeCategory('Transport');
      final etat = await etatAlertes((e) => e.tierFor(periode, categorie) > 0);
      expect(etat.tierFor(periode, categorie), 80,
          reason: 'la depense confirmee compte dans le budget du mois');
    });
  });
}
