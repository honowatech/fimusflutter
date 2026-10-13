import 'package:flutter_test/flutter_test.dart';
import 'package:monitrack/utils/currency_converter.dart';
import 'package:monitrack/utils/formatters.dart';

/// Formatage multi-devise (`lib/utils/formatters.dart`).
///
/// L'enjeu n'est pas la ponctuation des milliers mais **quelle devise est
/// affichée** : avant le palier 19, un montant saisi en XOF lu depuis un profil
/// en EUR s'affichait « 50 000 EUR ». Chaque cas ci-dessous fixe une règle du
/// repli : devise de la ligne si connue, devise du profil sinon, et jamais de
/// mention « devise étrangère » sur une ligne dont la devise est inconnue.
void main() {
  const tauxActifs = <String, double>{
    'USD': 1.0,
    'EUR': 0.90,
    'XAF': 600.0,
    'XOF': 600.0,
  };

  group('label', () {
    test('la devise de la ligne prime quand elle est connue', () {
      expect(MoneyFormatter.label('XOF', 'EUR'), 'XOF');
    });

    test('une devise de ligne inconnue laisse celle du profil s’appliquer', () {
      expect(MoneyFormatter.label(null, 'EUR'), 'EUR');
      expect(MoneyFormatter.label('', 'EUR'), 'EUR');
      expect(MoneyFormatter.label('Dollars', 'EUR'), 'EUR');
    });

    test('les libellés hérités sont affichés en ISO, de part et d’autre', () {
      // Le profil par défaut de l'application porte encore 'CFA' : il doit
      // s'afficher 'XAF', sans quoi la même devise apparaîtrait sous deux noms.
      expect(MoneyFormatter.label(null, 'CFA'), 'XAF');
      expect(MoneyFormatter.label('€', 'CFA'), 'EUR');
      expect(MoneyFormatter.label('xof', 'CFA'), 'XOF');
    });

    test('devise de profil elle-même non ISO : rendue telle quelle en dernier '
        'recours plutôt que masquée', () {
      expect(MoneyFormatter.label(null, 'Bitcoin'), 'Bitcoin');
    });
  });

  group('isForeign', () {
    test('devise de ligne inconnue : jamais signalée comme étrangère', () {
      // C'est le cas de toutes les lignes antérieures au palier 19 : elles sont
      // réputées dans la devise du profil, il n'y a rien à signaler.
      expect(MoneyFormatter.isForeign(null, 'EUR'), isFalse);
      expect(MoneyFormatter.isForeign('', 'EUR'), isFalse);
      expect(MoneyFormatter.isForeign('Dollars', 'EUR'), isFalse);
    });

    test('devise connue et identique au profil : rien à signaler', () {
      expect(MoneyFormatter.isForeign('EUR', 'EUR'), isFalse);
    });

    test('alias et casse ne créent pas de faux positif', () {
      expect(MoneyFormatter.isForeign('€', 'EUR'), isFalse);
      expect(MoneyFormatter.isForeign('XAF', 'CFA'), isFalse);
      expect(MoneyFormatter.isForeign('xof', 'XOF'), isFalse);
    });

    test('devise connue et différente : seul cas signalé', () {
      expect(MoneyFormatter.isForeign('XOF', 'EUR'), isTrue);
      expect(MoneyFormatter.isForeign('EUR', 'CFA'), isTrue);
    });

    test('profil sans devise exploitable et ligne connue : signalé étranger',
        () {
      // Comportement actuel : la comparaison se fait sur le profil normalisé,
      // qui vaut null, donc différent d'une devise connue.
      expect(MoneyFormatter.isForeign('EUR', 'Bitcoin'), isTrue);
    });
  });

  group('format', () {
    test('montant suivi de la devise de la ligne', () {
      expect(
        MoneyFormatter.format(12500, rowCurrency: 'XOF', profileCurrency: 'EUR'),
        '12 500.00 XOF',
      );
    });

    test('montant suivi de la devise du profil quand la ligne n’en porte pas',
        () {
      expect(
        MoneyFormatter.format(12500, rowCurrency: null, profileCurrency: 'CFA'),
        '12 500.00 XAF',
      );
    });

    test('un montant négatif garde son signe, sans double signe', () {
      final rendu = MoneyFormatter.format(-1234.5,
          rowCurrency: 'XOF', profileCurrency: 'XOF');
      expect(rendu, '-1 234.50 XOF');
      expect(rendu.split('-').length, 2, reason: 'un seul signe moins');
    });

    test('decimalPlaces à null arrondit à l’unité et pose le signe lui-même',
        () {
      // XOF et XAF n'ont pas de décimales : c'est l'usage prévu de ce mode.
      expect(
        MoneyFormatter.format(1234.5,
            rowCurrency: 'XOF', profileCurrency: 'XOF', decimalPlaces: null),
        '1 235 XOF',
      );
      expect(
        MoneyFormatter.format(-1234.5,
            rowCurrency: 'XOF', profileCurrency: 'XOF', decimalPlaces: null),
        '-1 235 XOF',
      );
    });

    test('signed préfixe les montants strictement positifs seulement', () {
      expect(
        MoneyFormatter.format(1000,
            rowCurrency: 'EUR', profileCurrency: 'EUR', signed: true),
        '+1 000.00 EUR',
      );
      expect(
        MoneyFormatter.format(-1000,
            rowCurrency: 'EUR', profileCurrency: 'EUR', signed: true),
        '-1 000.00 EUR',
      );
      expect(
        MoneyFormatter.format(0,
            rowCurrency: 'EUR', profileCurrency: 'EUR', signed: true),
        '0.00 EUR',
        reason: 'un zéro n’est ni un gain ni une perte',
      );
    });

    test('la devise affichée est normalisée, jamais l’étiquette brute', () {
      expect(
        MoneyFormatter.format(10, rowCurrency: 'cfa', profileCurrency: 'EUR'),
        '10.00 XAF',
      );
    });

    test('l’extension formatMoney rend exactement le même texte', () {
      expect(
        1500.formatMoney('xof', profileCurrency: 'EUR'),
        MoneyFormatter.format(1500, rowCurrency: 'XOF', profileCurrency: 'EUR'),
      );
      expect(1500.formatMoney('xof', profileCurrency: 'EUR'), '1 500.00 XOF');
    });
  });

  group('formatConverted', () {
    test('une ligne en devise étrangère est convertie puis libellée dans la '
        'devise du profil', () {
      expect(
        MoneyFormatter.formatConverted(
          100,
          rowCurrency: 'EUR',
          profileCurrency: 'XAF',
          activeRates: tauxActifs,
        ),
        // 100 EUR → 100 / 0,90 × 600 = 66 666,67 XAF
        '66 666.67 XAF',
      );
    });

    test('une devise d’origine inconnue est réputée déjà dans celle du profil',
        () {
      expect(
        MoneyFormatter.formatConverted(
          5000,
          rowCurrency: null,
          profileCurrency: 'XOF',
          activeRates: tauxActifs,
        ),
        '5 000.00 XOF',
      );
    });

    test('une ligne déjà dans la devise du profil n’est pas convertie deux fois',
        () {
      expect(
        MoneyFormatter.formatConverted(
          5000,
          rowCurrency: 'XOF',
          profileCurrency: 'XOF',
          activeRates: tauxActifs,
        ),
        '5 000.00 XOF',
      );
    });

    test('agrégat mêlant deux devises : le total est homogène et libellé une '
        'seule fois', () {
      // Trois lignes d'un même écran de synthèse : une en XAF (devise du
      // profil), une en EUR, une sans devise donc réputée en XAF. C'est le cas
      // qui produisait « 12 100 XAF » alors que la ligne en EUR valait
      // 66 666 XAF.
      const lignes = <(double, String?)>[
        (6000.0, 'XAF'),
        (100.0, 'EUR'),
        (6000.0, null),
      ];
      const profil = 'XAF';

      var total = 0.0;
      for (final (montant, devise) in lignes) {
        total += CurrencyConverter.convertForDisplay(
          amount: montant,
          from: devise,
          to: profil,
          activeRates: tauxActifs,
        );
      }

      // 6 000 + 66 666,666… + 6 000
      expect(total, closeTo(6000.0 + 100.0 * 600.0 / 0.90 + 6000.0, 1e-6));
      expect(
        MoneyFormatter.formatConverted(
          total,
          rowCurrency: profil,
          profileCurrency: profil,
          activeRates: tauxActifs,
        ),
        '78 666.67 XAF',
      );

      // Le total brut, celui que produisait l'ancien code, est très différent :
      // c'est la preuve que le test ne serait pas vert par accident.
      final totalBrut =
          lignes.fold<double>(0.0, (somme, ligne) => somme + ligne.$1);
      expect(totalBrut, 12100.0);
      expect((total - totalBrut).abs(), greaterThan(60000.0));
    });

    test('taux indisponible pour l’agrégat : le montant reste brut, sans être '
        'requalifié', () {
      // `formatConverted` sert l'affichage, pas les soldes : il ne refuse
      // jamais de rendre un texte. Le contrat est que la devise annoncée est
      // celle du profil — une valeur non convertie y est donc possible, ce qui
      // interdit d'utiliser cette fonction pour un calcul.
      expect(
        MoneyFormatter.formatConverted(
          100,
          rowCurrency: 'ZZZ',
          profileCurrency: 'XAF',
          activeRates: tauxActifs,
        ),
        '100.00 XAF',
      );
    });

    test('decimalPlaces à null s’applique après conversion', () {
      expect(
        MoneyFormatter.formatConverted(
          100,
          rowCurrency: 'EUR',
          profileCurrency: 'XAF',
          activeRates: tauxActifs,
          decimalPlaces: null,
        ),
        '66 667 XAF',
      );
    });
  });
}
