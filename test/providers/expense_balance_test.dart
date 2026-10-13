import 'package:flutter_test/flutter_test.dart';
import 'package:monitrack/models/expense.dart';
import 'package:monitrack/providers/account_provider.dart';
import 'package:monitrack/providers/expense_provider.dart';
import 'package:monitrack/services/database_service.dart';

import '../balance_test_helpers.dart';

/// Méthodes d'`ExpenseProvider` qui écrivent une opération **et** un solde dans
/// la même transaction.
///
/// Ce qui est vérifié ici tient en une phrase : la ligne écrite et le solde
/// imputé doivent toujours parler de la même devise, et un taux manquant doit
/// tout annuler — la ligne comme le solde. Les assertions relisent donc la base
/// après chaque appel, y compris dans les cas de refus.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initialiserSqfliteFfi);

  late AccountProvider comptes;
  late ExpenseProvider depenses;

  setUp(() async {
    couperLeReseau();
    preparerPreferences(deviseProfil: 'XOF');
    await preparerBase();
  });

  /// Charge les deux providers sur l'état courant de la base. À appeler après
  /// les insertions de montage.
  Future<void> chargerProviders() async {
    comptes = AccountProvider();
    depenses = ExpenseProvider();
    await comptes.loadData();
    await depenses.loadData();
  }

  group('addExpenseWithBalance', () {
    test('la devise estampillée sur la ligne est celle utilisée pour '
        'l’imputation', () async {
      // Compte en euros, profil en XOF : si la ligne était estampillée avec la
      // devise du profil, le solde bougerait de 10 XOF (0,01 EUR) au lieu de
      // 10 EUR. La ligne et le solde doivent parler la même langue.
      await insererCompte('acc-eur', solde: 500, devise: 'EUR');
      await chargerProviders();

      final resultat = await depenses.addExpenseWithBalance(
        operation('op-1', montant: 10, compte: 'acc-eur'),
        accountProvider: comptes,
      );

      expect(resultat.isSuccess, isTrue);
      expect((await lireDepense('op-1'))!['currency'], 'EUR');
      expect(await soldeEnBase('acc-eur'), 490.0);
    });

    test('compte sans devise : la devise du profil est estampillée', () async {
      await insererCompte('acc-nul', solde: 100000);
      await chargerProviders();

      await depenses.addExpenseWithBalance(
        operation('op-2', montant: 5000, compte: 'acc-nul'),
        accountProvider: comptes,
      );

      expect((await lireDepense('op-2'))!['currency'], 'XOF');
      // Compte sans devise = « inconnue », donc celle du profil : identité.
      expect(await soldeEnBase('acc-nul'), 95000.0);
    });

    test('opération en devise étrangère : imputation convertie, devise de la '
        'ligne conservée', () async {
      await insererCompte('acc-xof', solde: 100000, devise: 'XOF');
      await chargerProviders();

      await depenses.addExpenseWithBalance(
        operation('op-3', montant: 10, devise: 'EUR', compte: 'acc-xof'),
        accountProvider: comptes,
      );

      expect((await lireDepense('op-3'))!['currency'], 'EUR');
      expect(await soldeEnBase('acc-xof'), 92500.0);
    });

    test('une entrée crédite le compte, une dépense le débite', () async {
      await insererCompte('acc-xof', solde: 100000, devise: 'XOF');
      await chargerProviders();

      await depenses.addExpenseWithBalance(
        operation('op-4', montant: 10, devise: 'EUR', compte: 'acc-xof',
            type: 'income'),
        accountProvider: comptes,
      );

      expect(await soldeEnBase('acc-xof'), 107500.0);
    });

    test('balanceAmount : on enregistre le total dû, seul le principal entre '
        'en caisse', () async {
      // Simulation de crédit : 12 000 dus, 10 000 encaissés.
      await insererCompte('acc-xof', solde: 100000, devise: 'XOF');
      await chargerProviders();

      await depenses.addExpenseWithBalance(
        operation('op-5', montant: 12000, compte: 'acc-xof', type: 'income'),
        accountProvider: comptes,
        balanceAmount: 10000,
      );

      expect((await lireDepense('op-5'))!['amount'], 12000.0);
      expect(await soldeEnBase('acc-xof'), 110000.0);
    });

    test('balanceAmount : le sens vient du type, pas du signe du montant',
        () async {
      await insererCompte('acc-xof', solde: 100000, devise: 'XOF');
      await chargerProviders();

      await depenses.addExpenseWithBalance(
        operation('op-6', montant: 12000, compte: 'acc-xof', type: 'income'),
        accountProvider: comptes,
        balanceAmount: -10000,
      );

      expect(await soldeEnBase('acc-xof'), 110000.0);
    });

    test('additionalExpenses : insérées dans la même transaction, sans toucher '
        'au solde', () async {
      await insererCompte('acc-xof', solde: 100000, devise: 'XOF');
      await chargerProviders();

      await depenses.addExpenseWithBalance(
        operation('op-7', montant: 5000, compte: 'acc-xof'),
        accountProvider: comptes,
        additionalExpenses: <Expense>[
          operation('op-7-e1', montant: 2500, compte: 'acc-xof',
              tresorerie: false, prevision: true),
          operation('op-7-e2', montant: 2500, compte: 'acc-xof',
              tresorerie: false, prevision: true),
        ],
      );

      expect(await nombreDeDepenses(), 3);
      expect(await lireDepense('op-7-e1'), isNotNull);
      expect(await soldeEnBase('acc-xof'), 95000.0);
    });

    test('opération hors trésorerie : la ligne est écrite, le solde ne bouge '
        'pas', () async {
      await insererCompte('acc-xof', solde: 100000, devise: 'XOF');
      await chargerProviders();

      await depenses.addExpenseWithBalance(
        operation('op-8', montant: 5000, compte: 'acc-xof', tresorerie: false),
        accountProvider: comptes,
        );

      expect(await lireDepense('op-8'), isNotNull);
      expect(await soldeEnBase('acc-xof'), 100000.0);
      // Aucune écriture de solde : le compte est resté synchronisé.
      expect((await lireCompte('acc-xof'))['is_synced'], 1);
    });

    test('opération sans compte : aucune imputation', () async {
      await insererCompte('acc-xof', solde: 100000, devise: 'XOF');
      await chargerProviders();

      await depenses.addExpenseWithBalance(
        operation('op-9', montant: 5000),
        accountProvider: comptes,
      );

      expect(await lireDepense('op-9'), isNotNull);
      expect(await soldeEnBase('acc-xof'), 100000.0);
    });

    test('taux manquant : ni la ligne ni le solde ne sont écrits', () async {
      await insererCompte('acc-eur', solde: 500, devise: 'EUR');
      await chargerProviders();

      final resultat = await depenses.addExpenseWithBalance(
        operation('op-10',
            montant: 10, devise: deviseSansTaux, compte: 'acc-eur'),
        accountProvider: comptes,
      );

      expect(resultat.status, BalanceWriteStatus.rateUnavailable);
      expect(resultat.isRateUnavailable, isTrue);
      expect(resultat.missingFrom, deviseSansTaux);
      expect(resultat.missingTo, 'EUR');
      expect(await lireDepense('op-10'), isNull);
      expect(await soldeEnBase('acc-eur'), 500.0);
      expect((await lireCompte('acc-eur'))['is_synced'], 1);
    });
  });

  group('updateExpenseWithBalance', () {
    test('même compte : seul le delta est imputé', () async {
      await insererCompte('acc-xof', solde: 100000, devise: 'XOF');
      await chargerProviders();
      await depenses.addExpenseWithBalance(
        operation('maj-1', montant: 10000, compte: 'acc-xof'),
        accountProvider: comptes,
      );
      expect(await soldeEnBase('acc-xof'), 90000.0);

      final origine = depenses.expenses.firstWhere((e) => e.id == 'maj-1');
      final resultat = await depenses.updateExpenseWithBalance(
        original: origine,
        updated: origine.copyWith(amount: 12000),
        accountProvider: comptes,
      );

      expect(resultat.isSuccess, isTrue);
      expect((await lireDepense('maj-1'))!['amount'], 12000.0);
      expect(await soldeEnBase('acc-xof'), 88000.0);
    });

    test('changement de compte entre deux devises : chaque solde est réajusté '
        'dans la sienne', () async {
      await insererCompte('acc-eur', solde: 500, devise: 'EUR');
      await insererCompte('acc-xof', solde: 100000, devise: 'XOF');
      await chargerProviders();
      await depenses.addExpenseWithBalance(
        operation('maj-2', montant: 10, devise: 'EUR', compte: 'acc-eur'),
        accountProvider: comptes,
      );
      expect(await soldeEnBase('acc-eur'), 490.0);

      final origine = depenses.expenses.firstWhere((e) => e.id == 'maj-2');
      await depenses.updateExpenseWithBalance(
        original: origine,
        updated: origine.copyWith(accountId: 'acc-xof'),
        accountProvider: comptes,
      );

      // L'ancien compte est rendu à son état d'avant (EUR → EUR, identité) et
      // le nouveau reçoit le montant converti (10 EUR = 7 500 XOF).
      expect(await soldeEnBase('acc-eur'), 500.0);
      expect(await soldeEnBase('acc-xof'), 92500.0);
    });

    test('passage dépense → revenu : le mouvement est inversé, pas annulé',
        () async {
      await insererCompte('acc-xof', solde: 100000, devise: 'XOF');
      await chargerProviders();
      await depenses.addExpenseWithBalance(
        operation('maj-3', montant: 5000, compte: 'acc-xof'),
        accountProvider: comptes,
      );
      expect(await soldeEnBase('acc-xof'), 95000.0);

      final origine = depenses.expenses.firstWhere((e) => e.id == 'maj-3');
      await depenses.updateExpenseWithBalance(
        original: origine,
        updated: origine.copyWith(type: 'income'),
        accountProvider: comptes,
      );

      // +5 000 (nouvelle entrée) − (−5 000) (ancienne dépense) = +10 000.
      expect(await soldeEnBase('acc-xof'), 105000.0);
    });

    test('delta nul : la ligne est modifiée, le compte n’est pas touché',
        () async {
      await insererCompte('acc-xof', solde: 100000, devise: 'XOF');
      await chargerProviders();
      await depenses.addExpenseWithBalance(
        operation('maj-4', montant: 5000, compte: 'acc-xof'),
        accountProvider: comptes,
      );

      // Le compte est remis « synchronisé » : toute écriture de solde ultérieure
      // le repasserait à 0, ce qui rend l'absence d'écriture observable.
      final db = await DatabaseService.instance.database;
      await db.update('accounts', <String, Object?>{'is_synced': 1},
          where: 'id = ?', whereArgs: ['acc-xof']);

      final origine = depenses.expenses.firstWhere((e) => e.id == 'maj-4');
      await depenses.updateExpenseWithBalance(
        original: origine,
        updated: origine.copyWith(title: 'Libellé corrigé'),
        accountProvider: comptes,
      );

      expect((await lireDepense('maj-4'))!['title'], 'Libellé corrigé');
      expect(await soldeEnBase('acc-xof'), 95000.0);
      expect((await lireCompte('acc-xof'))['is_synced'], 1,
          reason: 'un delta nul ne doit produire aucune écriture de solde');
    });

    test('la devise de l’opération n’est jamais réécrite à la modification',
        () async {
      await insererCompte('acc-xof', solde: 100000, devise: 'XOF');
      await chargerProviders();
      await depenses.addExpenseWithBalance(
        operation('maj-5', montant: 10, devise: 'EUR', compte: 'acc-xof'),
        accountProvider: comptes,
      );
      expect(await soldeEnBase('acc-xof'), 92500.0);

      final origine = depenses.expenses.firstWhere((e) => e.id == 'maj-5');
      // L'écran envoie une devise différente : elle doit être ignorée, et les
      // deux imputations rester en euros.
      await depenses.updateExpenseWithBalance(
        original: origine,
        updated: origine.copyWith(amount: 20, currency: 'XOF'),
        accountProvider: comptes,
      );

      expect((await lireDepense('maj-5'))!['currency'], 'EUR');
      // −20 EUR − (−10 EUR) = −10 EUR = −7 500 XOF.
      expect(await soldeEnBase('acc-xof'), 85000.0);
    });

    test('ligne héritée sans devise : aucune devise n’est posée à la '
        'modification', () async {
      // Contrat de la colonne : `NULL` vaut « devise inconnue, à interpréter
      // dans celle du profil ». Une modification ne doit pas en profiter pour
      // figer une devise, sans quoi le montant changerait de sens.
      await insererCompte('acc-eur', solde: 500, devise: 'EUR');
      await chargerProviders();
      await insererDepense(operation('maj-7', montant: 7500, compte: 'acc-eur'));
      await depenses.loadData();

      final origine = depenses.expenses.firstWhere((e) => e.id == 'maj-7');
      expect(origine.currency, isNull);

      await depenses.updateExpenseWithBalance(
        original: origine,
        updated: origine.copyWith(amount: 15000),
        accountProvider: comptes,
      );

      expect((await lireDepense('maj-7'))!['currency'], isNull);
      // Le delta de 7 500 est lu en XOF (devise du profil) : 10 EUR.
      expect(await soldeEnBase('acc-eur'), 490.0);
    });

    test('taux manquant : ni la ligne ni les soldes ne bougent', () async {
      await insererCompte('acc-eur', solde: 500, devise: 'EUR');
      await chargerProviders();
      await insererDepense(operation('maj-6',
          montant: 10, devise: deviseSansTaux, compte: 'acc-eur'));
      await depenses.loadData();

      final origine = depenses.expenses.firstWhere((e) => e.id == 'maj-6');
      final resultat = await depenses.updateExpenseWithBalance(
        original: origine,
        updated: origine.copyWith(amount: 20),
        accountProvider: comptes,
      );

      expect(resultat.isRateUnavailable, isTrue);
      expect((await lireDepense('maj-6'))!['amount'], 10.0);
      expect(await soldeEnBase('acc-eur'), 500.0);
    });
  });

  group('deleteExpenseAndAdjustBalance', () {
    test('réajustement converti : le solde revient exactement à sa valeur '
        'd’avant', () async {
      await insererCompte('acc-xof', solde: 100000, devise: 'XOF');
      await chargerProviders();
      await depenses.addExpenseWithBalance(
        operation('sup-1', montant: 10, devise: 'EUR', compte: 'acc-xof'),
        accountProvider: comptes,
      );
      expect(await soldeEnBase('acc-xof'), 92500.0);

      final resultat = await depenses.deleteExpenseAndAdjustBalance(
        depenses.expenses.firstWhere((e) => e.id == 'sup-1'),
        accountProvider: comptes,
      );

      expect(resultat.isSuccess, isTrue);
      expect(await soldeEnBase('acc-xof'), 100000.0,
          reason: 'saisie puis suppression ne doivent laisser aucun résidu');
      expect((await lireDepense('sup-1'))!['sync_action'], 'delete');
    });

    test('suppression d’une entrée : le solde est débité du montant converti',
        () async {
      await insererCompte('acc-xof', solde: 100000, devise: 'XOF');
      await chargerProviders();
      await insererDepense(operation('sup-2',
          montant: 10, devise: 'EUR', compte: 'acc-xof', type: 'income'));
      await depenses.loadData();

      await depenses.deleteExpenseAndAdjustBalance(
        depenses.expenses.firstWhere((e) => e.id == 'sup-2'),
        accountProvider: comptes,
      );

      expect(await soldeEnBase('acc-xof'), 92500.0);
    });

    test('ligne héritée sans devise : réajustement lu dans la devise du profil',
        () async {
      // Compte en euros, profil en XOF, ligne antérieure au palier 19 : le
      // montant est interprété dans la devise du profil, conformément au
      // contrat, donc converti avant d'être rendu au compte.
      await insererCompte('acc-eur', solde: 500, devise: 'EUR');
      await chargerProviders();
      await insererDepense(operation('sup-5', montant: 7500, compte: 'acc-eur'));
      await depenses.loadData();

      await depenses.deleteExpenseAndAdjustBalance(
        depenses.expenses.firstWhere((e) => e.id == 'sup-5'),
        accountProvider: comptes,
      );

      expect(await soldeEnBase('acc-eur'), 510.0);
    });

    test('opération sans compte : la ligne part, aucun solde n’est touché',
        () async {
      await insererCompte('acc-xof', solde: 100000, devise: 'XOF');
      await chargerProviders();
      await insererDepense(operation('sup-3', montant: 5000));
      await depenses.loadData();

      final resultat = await depenses.deleteExpenseAndAdjustBalance(
        depenses.expenses.firstWhere((e) => e.id == 'sup-3'),
        accountProvider: comptes,
      );

      expect(resultat.isSuccess, isTrue);
      expect((await lireDepense('sup-3'))!['sync_action'], 'delete');
      expect(await soldeEnBase('acc-xof'), 100000.0);
      expect((await lireCompte('acc-xof'))['is_synced'], 1);
    });

    test('taux manquant : rateUnavailable et la dépense est toujours là',
        () async {
      await insererCompte('acc-eur', solde: 500, devise: 'EUR');
      await chargerProviders();
      await insererDepense(operation('sup-4',
          montant: 10, devise: deviseSansTaux, compte: 'acc-eur'));
      await depenses.loadData();

      final resultat = await depenses.deleteExpenseAndAdjustBalance(
        depenses.expenses.firstWhere((e) => e.id == 'sup-4'),
        accountProvider: comptes,
      );

      expect(resultat.isRateUnavailable, isTrue);
      expect((await lireDepense('sup-4'))!['sync_action'], 'updated',
          reason: 'la suppression douce ne doit pas avoir été posée');
      expect(await soldeEnBase('acc-eur'), 500.0);
    });
  });

  group('deleteDebtTagAndAdjustBalances', () {
    /// Dette partagée entre deux comptes et deux devises, plus une ligne
    /// prévisionnelle hors trésorerie qui ne doit jamais être imputée.
    Future<void> monterDetteMultiDevise({String deviseTroisiemeLigne = 'EUR'}) async {
      await insererCompte('acc-eur', solde: 1000, devise: 'EUR');
      await insererCompte('acc-xof', solde: 100000, devise: 'XOF');
      await insererDepense(operation('det-1',
          montant: 10,
          devise: 'EUR',
          compte: 'acc-eur',
          type: 'income',
          tagDette: 'Ami'));
      await insererDepense(operation('det-2',
          montant: 6000, devise: 'XOF', compte: 'acc-xof', tagDette: 'Ami'));
      await insererDepense(operation('det-3',
          montant: 5,
          devise: deviseTroisiemeLigne,
          compte: 'acc-xof',
          tagDette: 'Ami'));
      await insererDepense(operation('det-4',
          montant: 999,
          devise: 'XOF',
          compte: 'acc-xof',
          tagDette: 'Ami',
          tresorerie: false,
          prevision: true));
      await chargerProviders();
    }

    test('plusieurs comptes et plusieurs devises : chaque ligne est rendue '
        'dans la sienne', () async {
      await monterDetteMultiDevise();

      final resultat = await depenses.deleteDebtTagAndAdjustBalances(
        'Ami',
        accountProvider: comptes,
      );

      expect(resultat.isSuccess, isTrue);
      // det-1 : entrée de 10 EUR annulée → 1 000 − 10.
      expect(await soldeEnBase('acc-eur'), 990.0);
      // det-2 : +6 000 XOF ; det-3 : +5 EUR = +3 750 XOF ; det-4 ignorée.
      expect(await soldeEnBase('acc-xof'), 109750.0);
      for (final id in <String>['det-1', 'det-2', 'det-3', 'det-4']) {
        expect((await lireDepense(id))!['sync_action'], 'delete',
            reason: 'toutes les lignes du tag partent, imputées ou non');
      }
    });

    test('lignes hors trésorerie ignorées : leur montant n’entre dans aucun '
        'solde', () async {
      // Le même montage sans la ligne hors trésorerie donnerait les mêmes
      // soldes : c'est ce que vérifie l'écart avec 999.
      await monterDetteMultiDevise();
      await depenses.deleteDebtTagAndAdjustBalances('Ami',
          accountProvider: comptes);

      expect(await soldeEnBase('acc-xof'), isNot(109750.0 + 999));
    });

    test('un seul taux manquant : rien n’est supprimé et aucun solde ne bouge',
        () async {
      await monterDetteMultiDevise(deviseTroisiemeLigne: deviseSansTaux);

      final resultat = await depenses.deleteDebtTagAndAdjustBalances(
        'Ami',
        accountProvider: comptes,
      );

      expect(resultat.isRateUnavailable, isTrue);
      expect(await soldeEnBase('acc-eur'), 1000.0);
      expect(await soldeEnBase('acc-xof'), 100000.0);
      for (final id in <String>['det-1', 'det-2', 'det-3', 'det-4']) {
        expect((await lireDepense(id))!['sync_action'], 'updated',
            reason: 'une dette à moitié effacée laisserait des soldes faux');
      }
    });
  });

  group('confirmScheduledExpenseDetailed', () {
    /// Dépense programmée en attente, telle que la crée l'écran de saisie.
    Expense programmee(String id, {String? devise, double montant = 10}) =>
        operation(id,
            montant: montant,
            devise: devise,
            compte: 'acc-xof',
            tresorerie: false,
            prevision: true,
            statutProgrammation: 'scheduled',
            rappel: DateTime(2026, 10, 1, 9));

    test('identifiant inconnu : notFound, aucune écriture', () async {
      await insererCompte('acc-xof', solde: 100000, devise: 'XOF');
      await chargerProviders();

      final resultat =
          await depenses.confirmScheduledExpenseDetailed('fantome');

      expect(resultat.status, BalanceWriteStatus.notFound);
      expect(await soldeEnBase('acc-xof'), 100000.0);
    });

    test('opération existante mais non programmée : notFound aussi', () async {
      await insererCompte('acc-xof', solde: 100000, devise: 'XOF');
      await insererDepense(operation('conf-0', montant: 5000, compte: 'acc-xof'));
      await chargerProviders();

      final resultat =
          await depenses.confirmScheduledExpenseDetailed('conf-0');

      expect(resultat.status, BalanceWriteStatus.notFound);
      expect(await soldeEnBase('acc-xof'), 100000.0);
    });

    test('succès : bascule en dépense réelle et solde converti', () async {
      await insererCompte('acc-xof', solde: 100000, devise: 'XOF');
      await insererDepense(programmee('conf-1', devise: 'EUR'));
      await chargerProviders();

      final resultat =
          await depenses.confirmScheduledExpenseDetailed('conf-1');

      expect(resultat.isSuccess, isTrue);
      expect(await soldeEnBase('acc-xof'), 92500.0);
      final ligne = (await lireDepense('conf-1'))!;
      expect(ligne['scheduleStatus'], isNull);
      expect(ligne['isPlanned'], 0);
      expect(ligne['isLinkedToCashFlow'], 1);
      expect(ligne['currency'], 'EUR',
          reason: 'la confirmation ne réécrit pas la devise de saisie');
    });

    test('taux manquant : la dépense reste programmée et le solde est intact',
        () async {
      await insererCompte('acc-xof', solde: 100000, devise: 'XOF');
      await insererDepense(programmee('conf-2', devise: deviseSansTaux));
      await chargerProviders();

      final resultat =
          await depenses.confirmScheduledExpenseDetailed('conf-2');

      expect(resultat.status, BalanceWriteStatus.rateUnavailable);
      expect(resultat.missingFrom, deviseSansTaux);
      expect(resultat.missingTo, 'XOF');
      expect(await soldeEnBase('acc-xof'), 100000.0);
      final ligne = (await lireDepense('conf-2'))!;
      expect(ligne['scheduleStatus'], 'scheduled');
      expect(ligne['isPlanned'], 1);
      expect(ligne['is_synced'], 1,
          reason: 'la ligne programmée n’a pas été touchée');
    });

    test('dépense programmée sans compte : confirmée sans imputation',
        () async {
      await insererCompte('acc-xof', solde: 100000, devise: 'XOF');
      await insererDepense(operation('conf-3',
          montant: 10,
          devise: 'EUR',
          tresorerie: false,
          prevision: true,
          statutProgrammation: 'scheduled',
          rappel: DateTime(2026, 10, 1, 9)));
      await chargerProviders();

      final resultat =
          await depenses.confirmScheduledExpenseDetailed('conf-3');

      expect(resultat.isSuccess, isTrue);
      expect(await soldeEnBase('acc-xof'), 100000.0);
      expect((await lireDepense('conf-3'))!['scheduleStatus'], isNull);
    });
  });
}
