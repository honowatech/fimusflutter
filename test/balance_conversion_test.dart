import 'package:flutter_test/flutter_test.dart';
import 'package:monitrack/providers/account_provider.dart';
import 'package:monitrack/utils/currency_converter.dart';

/// Cœur de conversion des soldes : `AccountProvider.convertAmountForAccountCurrency`.
///
/// Fonction statique et pure, mais c'est elle qui décide, pour **toutes** les
/// écritures de solde, entre trois issues aux conséquences très différentes :
/// rendre le montant tel quel, le convertir et l'arrondir, ou refuser
/// l'écriture. Les trois couches testées ici sont invisibles pour
/// `CurrencyConverter` (couvert par sa propre suite) :
///  * le **miroir de devise** quand le profil n'en porte aucune ;
///  * l'**arrondi** à la précision de la devise du compte, appliqué au seul
///    montant converti ;
///  * la traduction d'un taux absent en [BalanceConversionException].
void main() {
  // Taux « actifs » volontairement différents de la table de repli statique :
  // sans cet écart, un test ne saurait pas dire lequel des deux a servi.
  const tauxActifs = <String, double>{
    'USD': 1.0,
    'EUR': 0.80,
    'XAF': 600.0,
    'XOF': 600.0,
  };

  // Valeurs de la table de repli, recopiées pour que l'assertion échoue si
  // quelqu'un les modifie sans y penser.
  const repliEur = 0.92;
  const repliXof = 610.0;

  /// Raccourci : seuls `amount`, les devises et les taux changent d'un cas à
  /// l'autre, l'identifiant de compte ne sert qu'à l'exception.
  double convertir({
    required double montant,
    String? devisOperation,
    String? deviseCompte,
    String? deviseProfil,
    Map<String, double> taux = tauxActifs,
    String compte = 'acc-1',
  }) {
    return AccountProvider.convertAmountForAccountCurrency(
      accountId: compte,
      amount: montant,
      operationCurrency: devisOperation,
      accountCurrency: deviseCompte,
      profileCurrency: deviseProfil,
      activeRates: taux,
    );
  }

  group('Identité : aucun montant ne doit bouger sans raison', () {
    test('devises identiques : le montant est rendu bit pour bit, sans arrondi',
        () {
      // 61 042,37 sur un compte XOF n'a aucun sens métier, mais c'est ce que
      // contient une base antérieure au palier 19. Arrondir ici ferait bouger
      // des soldes existants sans qu'aucune conversion ait eu lieu.
      final resultat = convertir(
        montant: 61042.37,
        devisOperation: 'XOF',
        deviseCompte: 'XOF',
        deviseProfil: 'XOF',
      );
      expect(resultat, 61042.37,
          reason: 'aucun arrondi ne doit être appliqué à une identité');
    });

    test('identité : un montant plus petit que l’unité survit à un compte XOF',
        () {
      // Le piège inverse : 0,005 arrondi à l'unité vaudrait 0, et le mouvement
      // disparaîtrait purement et simplement.
      expect(
        convertir(
          montant: 0.005,
          devisOperation: 'XOF',
          deviseCompte: 'XOF',
          deviseProfil: 'XOF',
        ),
        0.005,
      );
    });

    test('aucune devise connue nulle part : monde d’avant le palier 19', () {
      expect(
        convertir(montant: 12.3456789),
        12.3456789,
      );
    });

    test('devise de l’opération seule connue : miroir, donc identité', () {
      // Le profil et le compte sont muets : rien n'indique qu'une conversion
      // soit nécessaire. Refuser ici bloquerait une base mono-devise saine.
      expect(
        convertir(montant: 7500.25, devisOperation: 'XOF'),
        7500.25,
      );
    });

    test('devise du compte seule connue : miroir, donc identité', () {
      expect(
        convertir(montant: 7500.25, deviseCompte: 'EUR'),
        7500.25,
      );
    });

    test('alias et casse ne créent pas de fausse conversion', () {
      // 'cfa' → XAF des deux côtés : identité, pas un taux XAF → XAF inventé.
      expect(
        convertir(
          montant: 1234.56,
          devisOperation: 'cfa',
          deviseCompte: 'XAF',
          deviseProfil: 'XAF',
        ),
        1234.56,
      );
    });
  });

  group('Conversion avec taux', () {
    test('taux actif : EUR imputé sur un compte XOF', () {
      // 600 / 0,80 = 750 XOF par euro.
      expect(
        convertir(
          montant: 10.0,
          devisOperation: 'EUR',
          deviseCompte: 'XOF',
          deviseProfil: 'XOF',
        ),
        7500.0,
      );
    });

    test('profil sans devise : la conversion a tout de même lieu', () {
      // Le profil manque (premier lancement, isolat de notification) mais les
      // deux côtés portent une devise : le miroir ne doit pas s'appliquer.
      expect(
        convertir(
          montant: 10.0,
          devisOperation: 'EUR',
          deviseCompte: 'XOF',
        ),
        7500.0,
      );
    });

    test('devise de l’opération inconnue : celle du profil prend le relais',
        () {
      // `null` ≠ « pas de conversion » : c'est « devise inconnue », donc celle
      // du profil, et une conversion reste possible.
      expect(
        convertir(
          montant: 10.0,
          deviseCompte: 'XOF',
          deviseProfil: 'EUR',
        ),
        7500.0,
      );
    });

    test('taux de repli statique : converti quand même, avec les valeurs de la '
        'table', () {
      // Hors ligne, aucun taux synchronisé : le repli est exploitable, ce n'est
      // pas un motif de refus.
      final attendu = (10.0 / repliEur) * repliXof; // 6630,43…
      expect(
        convertir(
          montant: 10.0,
          devisOperation: 'EUR',
          deviseCompte: 'XOF',
          deviseProfil: 'XOF',
          taux: const <String, double>{},
        ),
        attendu.roundToDouble(),
      );
      // Et surtout : différent du montant qu'aurait donné le taux actif.
      expect(
        convertir(
          montant: 10.0,
          devisOperation: 'EUR',
          deviseCompte: 'XOF',
          deviseProfil: 'XOF',
          taux: const <String, double>{},
        ),
        isNot(7500.0),
      );
    });

    test('un seul des deux taux synchronisé : l’autre vient du repli', () {
      // 610 (repli XOF) / 0,80 (actif EUR) = 762,5.
      expect(
        convertir(
          montant: 10.0,
          devisOperation: 'EUR',
          deviseCompte: 'XOF',
          deviseProfil: 'XOF',
          taux: const <String, double>{'EUR': 0.80},
        ),
        7625.0,
      );
    });

    test('un montant nul reste nul, conversion ou pas', () {
      expect(
        convertir(
          montant: 0.0,
          devisOperation: 'EUR',
          deviseCompte: 'XOF',
          deviseProfil: 'XOF',
        ),
        0.0,
      );
    });
  });

  group('Arrondi à la précision de la devise du compte', () {
    test('compte XOF : arrondi à l’unité', () {
      // 12,345 × 750 = 9 258,75 → 9 259, et non 9 258,75 en base.
      final resultat = convertir(
        montant: 12.345,
        devisOperation: 'EUR',
        deviseCompte: 'XOF',
        deviseProfil: 'XOF',
      );
      expect(resultat, 9259.0);
      expect(resultat, resultat.roundToDouble());
    });

    test('compte XAF : même règle que XOF', () {
      expect(
        convertir(
          montant: 12.345,
          devisOperation: 'EUR',
          deviseCompte: 'XAF',
          deviseProfil: 'XAF',
        ),
        9259.0,
      );
    });

    test('compte EUR : arrondi au centime, pas au-delà', () {
      // 12 347 × 0,8 / 600 = 16,462666… → 16,46.
      final resultat = convertir(
        montant: 12347.0,
        devisOperation: 'XOF',
        deviseCompte: 'EUR',
        deviseProfil: 'XOF',
      );
      expect(resultat, 16.46);
      expect((resultat * 100), (resultat * 100).roundToDouble(),
          reason: 'un solde en euros ne doit pas traîner de millièmes');
    });

    test('compte EUR : l’arrondi au centime absorbe le bruit flottant', () {
      // 12 000 × 0,8 / 600 vaut 16 en arithmétique exacte, mais 16,000000000000004
      // en double : sans arrondi, ce résidu s'accumulerait dans le solde.
      expect(
        convertir(
          montant: 12000.0,
          devisOperation: 'XOF',
          deviseCompte: 'EUR',
          deviseProfil: 'XOF',
        ),
        16.0,
      );
    });

    test('compte sans devise connue : arrondi au centime par défaut', () {
      // Cible = devise du profil (EUR) : la précision suit la devise
      // effectivement retenue, pas l'absence de colonne.
      expect(
        convertir(
          montant: 12347.0,
          devisOperation: 'XOF',
          deviseProfil: 'EUR',
        ),
        16.46,
      );
    });
  });

  group('Signe : un retrait doit rester un retrait', () {
    test('delta négatif converti : le signe est conservé', () {
      expect(
        convertir(
          montant: -10.0,
          devisOperation: 'EUR',
          deviseCompte: 'XOF',
          deviseProfil: 'XOF',
        ),
        -7500.0,
      );
    });

    test('l’arrondi d’un montant négatif s’éloigne de zéro comme son opposé',
        () {
      final retrait = convertir(
        montant: -12.345,
        devisOperation: 'EUR',
        deviseCompte: 'XOF',
        deviseProfil: 'XOF',
      );
      final depot = convertir(
        montant: 12.345,
        devisOperation: 'EUR',
        deviseCompte: 'XOF',
        deviseProfil: 'XOF',
      );
      expect(retrait, -9259.0);
      // Saisie puis suppression d'une même opération : les deux imputations
      // s'annulent exactement, sans résidu d'arrondi.
      expect(retrait + depot, 0.0);
    });
  });

  group('Taux absent : refus, jamais de montant approché', () {
    test('devise d’opération hors des taux actifs et de la table de repli', () {
      // 'SEK' est un code ISO valide (donc pas filtré par normalizeCode) mais
      // absent des deux sources de taux : c'est le cas qui doit lever.
      expect(
        () => convertir(
          montant: 10.0,
          devisOperation: 'SEK',
          deviseCompte: 'EUR',
          deviseProfil: 'EUR',
        ),
        throwsA(isA<BalanceConversionException>()),
      );
    });

    test('devise du compte hors table : refus symétrique', () {
      expect(
        () => convertir(
          montant: 10.0,
          devisOperation: 'EUR',
          deviseCompte: 'SEK',
          deviseProfil: 'EUR',
        ),
        throwsA(isA<BalanceConversionException>()),
      );
    });

    test('l’exception porte de quoi composer un message : compte, montant, '
        'devises', () {
      try {
        convertir(
          montant: -12345.67,
          devisOperation: 'SEK',
          deviseCompte: 'XOF',
          deviseProfil: 'XOF',
          compte: 'acc-epargne',
        );
        fail('une conversion sans taux doit lever');
      } on BalanceConversionException catch (e) {
        expect(e.accountId, 'acc-epargne');
        expect(e.amount, -12345.67);
        expect(e.from, 'SEK');
        expect(e.to, 'XOF');
        expect(e.message, contains('SEK → XOF'));
        expect(e.message, contains('acc-epargne'));
        expect(e.toString(), contains('BalanceConversionException'));
      }
    });

    test('une devise sans sous-unité mais sans taux lève aussi : l’arrondi ne '
        'rattrape rien', () {
      // KRW est bien dans la table des devises sans décimale, et absente des
      // taux : le refus doit primer sur la mise en forme.
      expect(
        () => convertir(
          montant: 10.0,
          devisOperation: 'EUR',
          deviseCompte: 'KRW',
          deviseProfil: 'EUR',
        ),
        throwsA(isA<BalanceConversionException>()),
      );
    });

    test('un montant nul avec taux absent lève aussi : le refus ne dépend pas '
        'du montant', () {
      expect(
        () => convertir(
          montant: 0.0,
          devisOperation: 'SEK',
          deviseCompte: 'EUR',
          deviseProfil: 'EUR',
        ),
        throwsA(isA<BalanceConversionException>()),
      );
    });
  });

  group('Marqueur « devise du compte supposée »', () {
    test('la sentinelle n’est pas un code ISO : aucune confusion possible', () {
      // C'est ce qui garantit qu'un appelant non migré ne peut pas être
      // interprété comme ayant précisé une devise réelle.
      expect(
        CurrencyConverter.normalizeCode(AccountProvider.deviseDuCompteSupposee),
        isNull,
      );
      expect(AccountProvider.deviseDuCompteSupposee.length, isNot(3));
    });
  });
}
