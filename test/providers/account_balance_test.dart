import 'package:flutter_test/flutter_test.dart';
import 'package:monitrack/providers/account_provider.dart';

import '../balance_test_helpers.dart';

/// `AccountProvider.updateBalance` : le seul passage par lequel une écriture de
/// solde a lieu.
///
/// Le point à couvrir n'est pas l'addition mais les **trois sens** du paramètre
/// `operationCurrency`, dont deux se ressemblent dangereusement :
///  * un code ISO → conversion depuis cette devise ;
///  * `null` → « devise inconnue » au sens du contrat, donc celle du profil,
///    conversion possible ;
///  * absent (sentinelle) → delta déjà dans la devise du compte, aucune
///    conversion, comportement des appelants non encore migrés.
///
/// Toutes les assertions de solde lisent la **base** : un solde juste en mémoire
/// et faux en base est précisément le défaut qui ne se signale pas.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initialiserSqfliteFfi);

  setUp(() async {
    couperLeReseau();
    // Profil en euros et compte en XOF : tout écart de sens entre les trois
    // valeurs d'`operationCurrency` devient visible dans le solde.
    preparerPreferences(deviseProfil: 'EUR');
    await preparerBase();
  });

  /// Provider chargé sur l'état courant de la base.
  Future<AccountProvider> providerCharge() async {
    final provider = AccountProvider();
    await provider.loadData();
    return provider;
  }

  group('operationCurrency absent : le delta est déjà dans la devise du compte',
      () {
    test('sans operationCurrency, le delta est appliqué brut', () async {
      await insererCompte('acc-xof', solde: 100000, devise: 'XOF');
      final provider = await providerCharge();

      // Appelant non migré : -10 est déjà un montant en XOF, même si le profil
      // est en euros. Le convertir donnerait -7 500.
      await provider.updateBalance('acc-xof', -10);

      expect(await soldeEnBase('acc-xof'), 99990.0);
    });

    test('la sentinelle passée explicitement a le même effet que son absence',
        () async {
      await insererCompte('acc-xof', solde: 100000, devise: 'XOF');
      final provider = await providerCharge();

      await provider.updateBalance(
        'acc-xof',
        -10,
        operationCurrency: AccountProvider.deviseDuCompteSupposee,
      );

      expect(await soldeEnBase('acc-xof'), 99990.0);
    });

    test('la sentinelle court-circuite toute lecture de taux', () async {
      // Aucun taux en cache et un compte dans une devise hors table : si la
      // conversion était tentée, elle lèverait. Elle ne doit pas l'être.
      preparerPreferences(deviseProfil: 'EUR', taux: const {});
      await insererCompte('acc-sek', solde: 500, devise: deviseSansTaux);
      final provider = await providerCharge();

      await provider.updateBalance('acc-sek', -10);

      expect(await soldeEnBase('acc-sek'), 490.0);
    });
  });

  group('operationCurrency renseigné', () {
    test('devise identique à celle du compte : le delta est appliqué tel quel',
        () async {
      await insererCompte('acc-xof', solde: 100000, devise: 'XOF');
      final provider = await providerCharge();

      await provider.updateBalance('acc-xof', -5000, operationCurrency: 'XOF');

      expect(await soldeEnBase('acc-xof'), 95000.0);
    });

    test('devise différente : le solde bouge du montant converti', () async {
      await insererCompte('acc-xof', solde: 100000, devise: 'XOF');
      final provider = await providerCharge();

      await provider.updateBalance('acc-xof', -10, operationCurrency: 'EUR');

      expect(await soldeEnBase('acc-xof'), 100000.0 - 10 * tauxEurVersXof);
      // L'état en mémoire doit raconter la même histoire que la base.
      expect(provider.accounts.single.balance, 92500.0);
    });

    test('operationCurrency null : la devise du profil est appliquée, donc '
        'convertie', () async {
      // Même appel que « sans operationCurrency », au seul `null` près : le
      // solde doit pourtant être différent.
      await insererCompte('acc-xof', solde: 100000, devise: 'XOF');
      final provider = await providerCharge();

      await provider.updateBalance('acc-xof', -10, operationCurrency: null);

      expect(await soldeEnBase('acc-xof'), 92500.0);
    });

    test('le montant converti est arrondi à l’unité sur un compte XOF',
        () async {
      await insererCompte('acc-xof', solde: 100000, devise: 'XOF');
      final provider = await providerCharge();

      // 12,345 EUR × 750 = 9 258,75 → 9 259.
      await provider.updateBalance('acc-xof', -12.345,
          operationCurrency: 'EUR');

      expect(await soldeEnBase('acc-xof'), 90741.0);
    });

    test('une écriture de solde repasse le compte en « à synchroniser »',
        () async {
      await insererCompte('acc-xof', solde: 100000, devise: 'XOF');
      final provider = await providerCharge();

      await provider.updateBalance('acc-xof', -10, operationCurrency: 'EUR');

      final ligne = await lireCompte('acc-xof');
      expect(ligne['is_synced'], 0);
      expect(ligne['sync_action'], 'updated');
      expect(ligne['updated_at'], isNot(DateTime(2026, 1, 1).toIso8601String()));
      // La devise du compte n'est jamais réécrite par un mouvement.
      expect(ligne['currency'], 'XOF');
    });
  });

  group('Taux indisponible : rien n’est écrit', () {
    test('exception levée et solde inchangé en base', () async {
      await insererCompte('acc-eur', solde: 500, devise: 'EUR');
      final provider = await providerCharge();

      await expectLater(
        provider.updateBalance('acc-eur', -10,
            operationCurrency: deviseSansTaux),
        throwsA(isA<BalanceConversionException>()),
      );

      expect(await soldeEnBase('acc-eur'), 500.0);
      expect(provider.accounts.single.balance, 500.0);
      // Aucune écriture du tout : la ligne est restée synchronisée.
      expect((await lireCompte('acc-eur'))['is_synced'], 1);
    });

    test('compte inconnu du provider : aucune écriture, aucune exception',
        () async {
      await insererCompte('acc-xof', solde: 100000, devise: 'XOF');
      final provider = await providerCharge();

      await provider.updateBalance('acc-absent', -10,
          operationCurrency: 'EUR');

      expect(await soldeEnBase('acc-xof'), 100000.0);
      expect(await lireDepense('acc-absent'), isNull);
    });
  });

  group('convertDeltaForAccount : vérification avant toute transaction', () {
    test('la devise du compte est lue dans l’état du provider', () async {
      await insererCompte('acc-xof', solde: 100000, devise: 'XOF');
      final provider = await providerCharge();

      expect(
        await provider.convertDeltaForAccount(
          accountId: 'acc-xof',
          amount: -10,
          operationCurrency: 'EUR',
        ),
        -7500.0,
      );
    });

    test('des taux passés en paramètre prennent le pas sur ceux du cache',
        () async {
      await insererCompte('acc-xof', solde: 100000, devise: 'XOF');
      final provider = await providerCharge();

      // 1 200 / 0,80 = 1 500 XOF par euro, au lieu de 750 en cache.
      expect(
        await provider.convertDeltaForAccount(
          accountId: 'acc-xof',
          amount: -10,
          operationCurrency: 'EUR',
          activeRates: const <String, double>{'EUR': 0.80, 'XOF': 1200.0},
        ),
        -15000.0,
      );
    });

    test('taux manquant : l’échec part avant toute écriture', () async {
      await insererCompte('acc-eur', solde: 500, devise: 'EUR');
      final provider = await providerCharge();

      await expectLater(
        provider.convertDeltaForAccount(
          accountId: 'acc-eur',
          amount: -10,
          operationCurrency: deviseSansTaux,
        ),
        throwsA(isA<BalanceConversionException>()),
      );
      expect(await soldeEnBase('acc-eur'), 500.0);
    });
  });
}
