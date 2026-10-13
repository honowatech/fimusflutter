import 'package:flutter_test/flutter_test.dart';
import 'package:monitrack/utils/currency_converter.dart';

/// Couche de conversion du palier 19 (`lib/utils/currency_converter.dart`).
///
/// Le point sensible n'est pas l'arithmétique — elle est linéaire — mais le
/// **contrat de repli** : ce qui vaut « devise inconnue », ce qui vaut
/// « identité », et surtout ce qui vaut « je refuse de produire un montant ».
/// Un montant non converti additionné à un solde est une erreur silencieuse ;
/// ces cas limites sont donc testés un par un.
void main() {
  // Taux « actifs » plausibles, volontairement différents de la table de repli
  // statique : c'est la seule façon de distinguer un taux vivant d'un taux
  // approché dans les assertions.
  const tauxActifs = <String, double>{
    'USD': 1.0,
    'EUR': 0.90,
    'XAF': 600.0,
    'XOF': 600.0,
  };

  // Valeurs de la table de repli, recopiées ici pour que l'assertion échoue si
  // quelqu'un les modifie sans y penser.
  const repliEur = 0.92;
  const repliXaf = 610.0;

  group('normalizeCode', () {
    test('un code ISO en minuscules est remonté en majuscules', () {
      expect(CurrencyConverter.normalizeCode('xof'), 'XOF');
    });

    test('les libellés hérités du sélecteur manuel sont résolus en ISO', () {
      expect(CurrencyConverter.normalizeCode('CFA'), 'XAF');
      expect(CurrencyConverter.normalizeCode('€'), 'EUR');
      expect(CurrencyConverter.normalizeCode('\$'), 'USD');
      expect(CurrencyConverter.normalizeCode('£'), 'GBP');
    });

    test('les espaces autour du code sont ignorés', () {
      expect(CurrencyConverter.normalizeCode(' eur '), 'EUR');
      expect(CurrencyConverter.normalizeCode('\tXOF\n'), 'XOF');
    });

    test('un libellé qui n’est pas un code ISO vaut « devise inconnue »', () {
      // « Dollars » fait bien trois lettres de plus qu'un code ISO : il ne doit
      // surtout pas être tronqué ni deviné en USD.
      expect(CurrencyConverter.normalizeCode('Dollars'), isNull);
      expect(CurrencyConverter.normalizeCode('FCFA'), isNull);
      expect(CurrencyConverter.normalizeCode('EU'), isNull);
      expect(CurrencyConverter.normalizeCode('EU1'), isNull);
    });

    test('une valeur vide ou absente vaut « devise inconnue »', () {
      expect(CurrencyConverter.normalizeCode(null), isNull);
      expect(CurrencyConverter.normalizeCode(''), isNull);
      expect(CurrencyConverter.normalizeCode('   '), isNull);
    });

    test('une valeur non textuelle est passée par toString sans planter', () {
      expect(CurrencyConverter.normalizeCode(42), isNull);
    });

    test('normalizeCode est idempotent', () {
      final unePasse = CurrencyConverter.normalizeCode('cfa');
      expect(unePasse, 'XAF');
      expect(CurrencyConverter.normalizeCode(unePasse), 'XAF');
    });
  });

  group('resolveForNewOperation', () {
    test('la devise du compte imputé est prioritaire sur celle du profil', () {
      expect(
        CurrencyConverter.resolveForNewOperation(
            accountCurrency: 'EUR', profileCurrency: 'XOF'),
        'EUR',
      );
    });

    test('sans compte imputé, la devise du profil est reprise', () {
      expect(
        CurrencyConverter.resolveForNewOperation(
            accountCurrency: null, profileCurrency: 'XOF'),
        'XOF',
      );
    });

    test('une devise de compte non reconnue laisse le profil reprendre la main',
        () {
      // Le repli doit se faire sur le profil, pas rendre le libellé brut : la
      // colonne n'accepte que de l'ISO ou du NULL.
      expect(
        CurrencyConverter.resolveForNewOperation(
            accountCurrency: 'Dollars', profileCurrency: 'CFA'),
        'XAF',
      );
    });

    test('rien de connu des deux côtés : la devise reste inconnue', () {
      expect(
        CurrencyConverter.resolveForNewOperation(
            accountCurrency: null, profileCurrency: null),
        isNull,
      );
      expect(
        CurrencyConverter.resolveForNewOperation(
            accountCurrency: '', profileCurrency: 'Bitcoin'),
        isNull,
      );
    });
  });

  group('strictRate face à getRate', () {
    test('devise inconnue : strictRate renonce là où getRate rend 1.0', () {
      // C'est LA distinction qui protège les soldes : `getRate` rend une
      // identité, qui additionnerait 10 unités d'une devise inconnue à un
      // compte en XAF comme s'il s'agissait de 10 XAF.
      const inconnue = 'ZZZ';
      expect(
        CurrencyConverter.getRate(
            from: inconnue, to: 'XAF', activeRates: tauxActifs),
        1.0,
        reason: 'comportement historique de getRate, à ne pas utiliser pour un '
            'solde',
      );
      expect(
        CurrencyConverter.strictRate(
            from: inconnue, to: 'XAF', activeRates: tauxActifs),
        isNull,
        reason: 'une absence de taux doit rester une absence',
      );
    });

    test('devise cible inconnue : même asymétrie', () {
      expect(
        CurrencyConverter.getRate(
            from: 'EUR', to: 'ZZZ', activeRates: tauxActifs),
        1.0,
      );
      expect(
        CurrencyConverter.strictRate(
            from: 'EUR', to: 'ZZZ', activeRates: tauxActifs),
        isNull,
      );
    });

    test('code en minuscules : les deux fonctions normalisent la casse', () {
      // `getRate` ne comparait que des chaînes brutes : 'xof' n'étant ni égal
      // à 'EUR' ni présent dans les tables, elle retombait sur 1.0, soit un
      // taux faux d'un facteur 660 sans le moindre signalement.
      expect(
        CurrencyConverter.getRate(
            from: 'xof', to: 'EUR', activeRates: const {}),
        closeTo(repliEur / 610.0, 1e-12),
        reason: 'la casse ne doit plus produire un taux de 1.0',
      );
      expect(
        CurrencyConverter.strictRate(
            from: 'xof', to: 'EUR', activeRates: const {}),
        closeTo(repliEur / 610.0, 1e-12),
      );
    });

    test('devises identiques : identité dans les deux cas', () {
      expect(
        CurrencyConverter.strictRate(
            from: 'XAF', to: 'XAF', activeRates: tauxActifs),
        1.0,
      );
      // Alias et casse comprises : 'CFA' et 'xaf' désignent la même devise.
      expect(
        CurrencyConverter.strictRate(
            from: 'CFA', to: 'xaf', activeRates: tauxActifs),
        1.0,
      );
    });

    test('taux actifs prioritaires sur la table de repli', () {
      expect(
        CurrencyConverter.strictRate(
            from: 'EUR', to: 'XAF', activeRates: tauxActifs),
        closeTo(600.0 / 0.90, 1e-9),
      );
      expect(
        CurrencyConverter.strictRate(
            from: 'EUR', to: 'XAF', activeRates: const {}),
        closeTo(repliXaf / repliEur, 1e-9),
      );
    });

    test('un seul des deux taux connu des taux actifs : repli sur l’autre', () {
      // EUR vient des taux actifs, GBP de la table de repli : le taux est
      // exploitable, c'est un mélange assumé.
      final taux = CurrencyConverter.strictRate(
          from: 'EUR', to: 'GBP', activeRates: tauxActifs);
      expect(taux, closeTo(0.79 / 0.90, 1e-9));
    });
  });

  group('amountForAccount', () {
    test('devises identiques : identité, montant intact et taux à 1', () {
      final r = CurrencyConverter.amountForAccount(
        amount: 12500.0,
        operationCurrency: 'XOF',
        accountCurrency: 'XOF',
        profileCurrency: 'XOF',
        activeRates: tauxActifs,
      );
      expect(r.outcome, ConversionOutcome.identity);
      expect(r.amount, 12500.0);
      expect(r.rate, 1.0);
      expect(r.isUsable, isTrue);
      expect(r.approximate, isFalse);
      expect(r.from, 'XOF');
      expect(r.to, 'XOF');
    });

    test('alias et casse ne créent pas de fausse conversion', () {
      // 'cfa' sur un compte 'XAF' est la même devise : convertir ici
      // reviendrait à multiplier un solde par un taux croisé inventé.
      final r = CurrencyConverter.amountForAccount(
        amount: 5000.0,
        operationCurrency: 'cfa',
        accountCurrency: 'XAF',
        profileCurrency: 'XAF',
        activeRates: tauxActifs,
      );
      expect(r.outcome, ConversionOutcome.identity);
      expect(r.amount, 5000.0);
    });

    test('EUR sur un compte XAF avec taux connu : montant converti', () {
      final r = CurrencyConverter.amountForAccount(
        amount: 100.0,
        operationCurrency: 'EUR',
        accountCurrency: 'XAF',
        profileCurrency: 'XAF',
        activeRates: tauxActifs,
      );
      expect(r.outcome, ConversionOutcome.converted);
      expect(r.amount, closeTo(100.0 * 600.0 / 0.90, 1e-6));
      expect(r.from, 'EUR');
      expect(r.to, 'XAF');
      expect(r.approximate, isFalse,
          reason: 'les deux devises viennent des taux actifs');
      expect(r.isUsable, isTrue);
    });

    test('le signe d’un delta négatif est conservé par la conversion', () {
      // Un retrait doit rester un retrait : c'est exactement le delta passé à
      // `updateBalance` lors d'une suppression d'opération.
      final r = CurrencyConverter.amountForAccount(
        amount: -100.0,
        operationCurrency: 'EUR',
        accountCurrency: 'XAF',
        profileCurrency: 'XAF',
        activeRates: tauxActifs,
      );
      expect(r.outcome, ConversionOutcome.converted);
      expect(r.amount, isNotNull);
      expect(r.amount!, lessThan(0));
      expect(r.amount, closeTo(-100.0 * 600.0 / 0.90, 1e-6));
    });

    test('conversion linéaire : deux deltas opposés s’annulent exactement', () {
      const montant = 4321.75;
      final credit = CurrencyConverter.amountForAccount(
        amount: montant,
        operationCurrency: 'EUR',
        accountCurrency: 'XOF',
        profileCurrency: 'XOF',
        activeRates: tauxActifs,
      );
      final debit = CurrencyConverter.amountForAccount(
        amount: -montant,
        operationCurrency: 'EUR',
        accountCurrency: 'XOF',
        profileCurrency: 'XOF',
        activeRates: tauxActifs,
      );
      expect(credit.amount! + debit.amount!, closeTo(0.0, 1e-9));
    });

    test('taux issu de la table de repli : converti mais signalé approximatif',
        () {
      final r = CurrencyConverter.amountForAccount(
        amount: 100.0,
        operationCurrency: 'EUR',
        accountCurrency: 'XAF',
        profileCurrency: 'XAF',
        activeRates: const {},
      );
      expect(r.outcome, ConversionOutcome.converted);
      expect(r.approximate, isTrue,
          reason: 'un taux hors ligne doit être journalisable comme approché');
      expect(r.isUsable, isTrue,
          reason: 'approximatif n’est pas une raison de refuser l’écriture');
      expect(r.amount, closeTo(100.0 * repliXaf / repliEur, 1e-6));
    });

    test('une seule des deux devises absente des taux actifs suffit à marquer '
        'le résultat approximatif', () {
      final r = CurrencyConverter.amountForAccount(
        amount: 100.0,
        operationCurrency: 'EUR',
        accountCurrency: 'GBP',
        profileCurrency: 'EUR',
        activeRates: tauxActifs, // contient EUR, pas GBP
      );
      expect(r.outcome, ConversionOutcome.converted);
      expect(r.approximate, isTrue);
    });

    test('devise absente des taux et du repli : rateUnavailable sans montant',
        () {
      final r = CurrencyConverter.amountForAccount(
        amount: 100.0,
        operationCurrency: 'ZZZ',
        accountCurrency: 'XAF',
        profileCurrency: 'XAF',
        activeRates: tauxActifs,
      );
      expect(r.outcome, ConversionOutcome.rateUnavailable);
      expect(r.amount, isNull,
          reason: 'aucun appelant ne doit pouvoir récupérer un montant brut');
      expect(r.rate, isNull);
      expect(r.isUsable, isFalse);
      // Les devises effectives restent lisibles pour le diagnostic.
      expect(r.from, 'ZZZ');
      expect(r.to, 'XAF');
      expect(r.diagnostic, contains('indisponible'));
    });

    test('le repli explicite d’amountOr est le seul moyen d’obtenir un double',
        () {
      final r = CurrencyConverter.amountForAccount(
        amount: 100.0,
        operationCurrency: 'ZZZ',
        accountCurrency: 'XAF',
        profileCurrency: 'XAF',
        activeRates: tauxActifs,
      );
      expect(r.amountOr(0.0), 0.0);
      expect(r.amountOr(-1.0), -1.0);
    });

    test('devise de l’opération inconnue : repli sur celle du profil', () {
      // Ligne antérieure au palier 19 imputée sur un compte en EUR, profil en
      // XAF : la ligne est réputée en XAF, donc convertie.
      final r = CurrencyConverter.amountForAccount(
        amount: 6000.0,
        operationCurrency: null,
        accountCurrency: 'EUR',
        profileCurrency: 'XAF',
        activeRates: tauxActifs,
      );
      expect(r.outcome, ConversionOutcome.converted);
      expect(r.from, 'XAF');
      expect(r.to, 'EUR');
      expect(r.amount, closeTo(6000.0 * 0.90 / 600.0, 1e-9));
    });

    test('devise du compte inconnue : repli sur celle du profil', () {
      final r = CurrencyConverter.amountForAccount(
        amount: 10.0,
        operationCurrency: 'EUR',
        accountCurrency: null,
        profileCurrency: 'XOF',
        activeRates: tauxActifs,
      );
      expect(r.outcome, ConversionOutcome.converted);
      expect(r.to, 'XOF');
      expect(r.amount, closeTo(10.0 * 600.0 / 0.90, 1e-9));
    });

    test('opération et compte sans devise avec le même profil : identité '
        '(non-régression du monde d’avant le palier 19)', () {
      final r = CurrencyConverter.amountForAccount(
        amount: 7500.0,
        operationCurrency: null,
        accountCurrency: null,
        profileCurrency: 'XAF',
        activeRates: tauxActifs,
      );
      expect(r.outcome, ConversionOutcome.identity);
      expect(r.amount, 7500.0);
      expect(r.from, 'XAF');
      expect(r.to, 'XAF');
    });

    test('aucune devise nulle part : identité, montant rendu tel quel', () {
      final r = CurrencyConverter.amountForAccount(
        amount: 7500.0,
        operationCurrency: null,
        accountCurrency: null,
        profileCurrency: null,
        activeRates: tauxActifs,
      );
      expect(r.outcome, ConversionOutcome.identity,
          reason: 'comportement actuel : un profil sans devise ne bloque pas '
              'les écritures existantes',
      );
      expect(r.amount, 7500.0);
      expect(r.from, isNull);
      expect(r.to, isNull);
      expect(r.isUsable, isTrue);
    });

    test('profil sans devise mais compte connu : aucun montant produit', () {
      // Une seule devise exploitable : impossible de savoir si une conversion
      // est nécessaire. Rendre l'identité laisserait imputer 100 EUR sur un
      // compte en XAF comme 100 XAF — c'est précisément ce que cette fonction
      // existe pour empêcher, donc elle refuse de produire un montant.
      final r = CurrencyConverter.amountForAccount(
        amount: 100.0,
        operationCurrency: null,
        accountCurrency: 'EUR',
        profileCurrency: null,
        activeRates: tauxActifs,
      );
      expect(r.outcome, ConversionOutcome.rateUnavailable);
      expect(r.amount, isNull);
      expect(r.isUsable, isFalse);
      expect(r.to, 'EUR');
    });

    test('devise d opération connue mais ni compte ni profil : refus aussi',
        () {
      final r = CurrencyConverter.amountForAccount(
        amount: 100.0,
        operationCurrency: 'EUR',
        accountCurrency: null,
        profileCurrency: null,
        activeRates: tauxActifs,
      );
      expect(r.outcome, ConversionOutcome.rateUnavailable);
      expect(r.amount, isNull);
    });

    test('un montant nul reste nul quelle que soit la conversion', () {
      final r = CurrencyConverter.amountForAccount(
        amount: 0.0,
        operationCurrency: 'EUR',
        accountCurrency: 'XAF',
        profileCurrency: 'XAF',
        activeRates: tauxActifs,
      );
      expect(r.outcome, ConversionOutcome.converted);
      expect(r.amount, 0.0);
    });

    test('le diagnostic nomme les devises et le régime du taux', () {
      final approche = CurrencyConverter.amountForAccount(
        amount: 1.0,
        operationCurrency: 'EUR',
        accountCurrency: 'XAF',
        profileCurrency: 'XAF',
        activeRates: const {},
      );
      expect(approche.diagnostic, contains('EUR'));
      expect(approche.diagnostic, contains('XAF'));
      expect(approche.diagnostic, contains('repli'));

      final identite = CurrencyConverter.amountForAccount(
        amount: 1.0,
        operationCurrency: 'XAF',
        accountCurrency: 'XAF',
        profileCurrency: 'XAF',
        activeRates: tauxActifs,
      );
      expect(identite.diagnostic, contains('aucune conversion'));
    });
  });

  group('convert et convertForDisplay', () {
    test('une devise d’origine inconnue laisse le montant intact', () {
      expect(
        CurrencyConverter.convertForDisplay(
            amount: 5000.0, from: null, to: 'EUR', activeRates: tauxActifs),
        5000.0,
      );
      expect(
        CurrencyConverter.convertForDisplay(
            amount: 5000.0,
            from: 'Dollars',
            to: 'EUR',
            activeRates: tauxActifs),
        5000.0,
        reason: 'aucune conversion ne doit être devinée à partir d’un libellé',
      );
    });

    test('convertForDisplay normalise la devise d’origine avant de convertir',
        () {
      // `convert` seul ne normalise pas la casse ; passer par
      // `convertForDisplay` est ce qui rend 'xof' exploitable.
      expect(
        CurrencyConverter.convertForDisplay(
            amount: 6000.0, from: 'xof', to: 'EUR', activeRates: tauxActifs),
        closeTo(6000.0 * 0.90 / 600.0, 1e-9),
      );
    });

    test('un aller-retour de conversion revient au montant d’origine', () {
      const depart = 123456.0;
      final enEuros = CurrencyConverter.convert(
          amount: depart, from: 'XAF', to: 'EUR', activeRates: tauxActifs);
      final retour = CurrencyConverter.convert(
          amount: enEuros, from: 'EUR', to: 'XAF', activeRates: tauxActifs);
      expect(retour, closeTo(depart, 1e-6));
    });

    test('alias : CFA et XAF sont la même devise, aucun taux appliqué', () {
      expect(
        CurrencyConverter.convert(
            amount: 1000.0, from: 'CFA', to: 'XAF', activeRates: tauxActifs),
        1000.0,
      );
    });
  });
}
