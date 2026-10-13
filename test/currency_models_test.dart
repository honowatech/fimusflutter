import 'package:flutter_test/flutter_test.dart';
import 'package:monitrack/models/account.dart';
import 'package:monitrack/models/expense.dart';

/// Devise portée par les modèles (`lib/models/expense.dart`,
/// `lib/models/account.dart`).
///
/// Les deux constructeurs passent la devise par `CurrencyConverter.normalizeCode`
/// : c'est la porte d'entrée unique de la colonne du palier 19. Ce qui est
/// vérifié ici, c'est qu'aucun aller-retour (base ou réseau) ne peut la perdre,
/// l'inventer, ou la réécrire à l'occasion d'une copie.
void main() {
  Expense depense({String? devise}) => Expense(
        id: 'dep-1',
        title: 'Taxi',
        amount: 2500.0,
        category: 'Transport',
        date: DateTime(2026, 3, 1, 8, 30),
        currency: devise,
        accountId: 'cpt-1',
        note: 'course du matin',
        type: 'expense',
      );

  Account compte({String? devise}) => Account(
        id: 'cpt-1',
        name: 'Caisse',
        balance: 125000.0,
        currency: devise,
        type: 'cash',
        updatedAt: DateTime(2026, 3, 1, 9),
      );

  group('Expense : normalisation à la construction', () {
    test('devise absente : la ligne reste « devise inconnue »', () {
      expect(depense().currency, isNull);
      expect(depense(devise: '').currency, isNull);
      expect(depense(devise: '   ').currency, isNull);
    });

    test('devise en minuscules : remontée en ISO majuscules', () {
      expect(depense(devise: 'xof').currency, 'XOF');
      expect(depense(devise: ' eur ').currency, 'EUR');
    });

    test('libellé hérité : résolu en code ISO', () {
      expect(depense(devise: 'CFA').currency, 'XAF');
      expect(depense(devise: '€').currency, 'EUR');
    });

    test('libellé non ISO : rejeté plutôt que deviné', () {
      // Mieux vaut un NULL assumé — interprété dans la devise du profil —
      // qu'un code inventé dans une base financière.
      expect(depense(devise: 'Dollars').currency, isNull);
      expect(depense(devise: 'FCFA').currency, isNull);
    });
  });

  group('Expense : aller-retour base', () {
    test('devise absente : la clé existe et vaut NULL, et revient à null', () {
      final carte = depense().toDbMap();
      expect(carte.containsKey('currency'), isTrue,
          reason: 'la colonne doit être écrite explicitement, sinon un UPDATE '
              'partiel laisserait une valeur héritée');
      expect(carte['currency'], isNull);
      expect(Expense.fromDbMap(carte).currency, isNull);
    });

    test('devise connue : conservée à l’identique', () {
      final carte = depense(devise: 'XOF').toDbMap();
      expect(carte['currency'], 'XOF');
      expect(Expense.fromDbMap(carte).currency, 'XOF');
    });

    test('devise en minuscules : normalisée avant écriture', () {
      expect(depense(devise: 'xof').toDbMap()['currency'], 'XOF');
    });

    test('alias : écrit en ISO, pas sous son libellé d’origine', () {
      expect(depense(devise: 'CFA').toDbMap()['currency'], 'XAF');
    });

    test('valeur héritée illisible en base : relue comme devise inconnue', () {
      // Une base réelle peut contenir du bruit (import, ancien sélecteur) : la
      // lecture doit retomber sur « inconnue », jamais propager la valeur.
      final carte = depense(devise: 'XOF').toDbMap()
        ..['currency'] = 'Dollars';
      expect(Expense.fromDbMap(carte).currency, isNull);
    });

    test('l’aller-retour complet préserve aussi le montant et le compte', () {
      final relue = Expense.fromDbMap(depense(devise: 'eur').toDbMap());
      expect(relue.currency, 'EUR');
      expect(relue.amount, 2500.0);
      expect(relue.accountId, 'cpt-1');
      expect(relue.id, 'dep-1');
    });
  });

  group('Expense : aller-retour JSON', () {
    test('devise absente : null de bout en bout', () {
      final json = depense().toJson();
      expect(json.containsKey('currency'), isTrue);
      expect(json['currency'], isNull);
      expect(Expense.fromJson(json).currency, isNull);
    });

    test('devise connue, minuscule ou alias : normalisée dans les deux sens',
        () {
      expect(Expense.fromJson(depense(devise: 'XOF').toJson()).currency, 'XOF');
      expect(Expense.fromJson(depense(devise: 'xof').toJson()).currency, 'XOF');
      expect(Expense.fromJson(depense(devise: 'CFA').toJson()).currency, 'XAF');
    });

    test('devise absente de la charge JSON reçue du serveur : pas d’exception',
        () {
      final recu = <String, dynamic>{
        'id': 'dep-serveur',
        'title': 'Achat',
        'amount': 900,
        'category': 'Autre',
        'date': '2026-02-02T10:00:00.000',
      };
      expect(Expense.fromJson(recu).currency, isNull);
    });

    test('devise reçue en minuscules du serveur : normalisée à l’entrée', () {
      final recu = <String, dynamic>{
        'id': 'dep-serveur',
        'title': 'Achat',
        'amount': 900,
        'category': 'Autre',
        'date': '2026-02-02T10:00:00.000',
        'currency': 'eur',
      };
      expect(Expense.fromJson(recu).currency, 'EUR');
    });
  });

  group('Expense : copyWith et confirmation', () {
    test('copyWith d’un autre champ conserve la devise', () {
      final origine = depense(devise: 'XOF');
      final copie = origine.copyWith(amount: 9999.0, title: 'Moto');
      expect(copie.currency, 'XOF');
      expect(copie.amount, 9999.0);
    });

    test('copyWith conserve aussi une devise inconnue', () {
      expect(depense().copyWith(amount: 1.0).currency, isNull);
    });

    test('copyWith normalise une nouvelle devise', () {
      expect(depense(devise: 'XOF').copyWith(currency: 'cfa').currency, 'XAF');
    });

    test('copyWith ne peut pas effacer une devise déjà posée', () {
      // Limitation assumée du patron `?? this.currency` : passer null vaut
      // « ne change pas ». C'est aligné sur le contrat — la devise n'est jamais
      // réécrite après la création.
      expect(depense(devise: 'XOF').copyWith(currency: null).currency, 'XOF');
    });

    test('confirmAsRealExpense conserve la devise de saisie', () {
      final programmee = Expense(
        id: 'dep-prog',
        title: 'Loyer',
        amount: 300000.0,
        category: 'Logement',
        date: DateTime(2026, 4, 1),
        currency: 'xof',
        isPlanned: true,
        scheduleStatus: 'scheduled',
        dueDate: DateTime(2026, 4, 1),
      );
      final confirmee =
          programmee.confirmAsRealExpense(newDate: DateTime(2026, 4, 2));

      expect(confirmee.currency, 'XOF',
          reason: 'la confirmation ne doit pas requalifier la devise');
      expect(confirmee.amount, 300000.0);
      expect(confirmee.id, 'dep-prog');
      expect(confirmee.isPlanned, isFalse);
      expect(confirmee.scheduleStatus, isNull);
      expect(confirmee.date, DateTime(2026, 4, 2));
    });

    test('confirmAsRealExpense conserve aussi une devise inconnue', () {
      final programmee = Expense(
        id: 'dep-prog-2',
        title: 'Loyer',
        amount: 300000.0,
        category: 'Logement',
        date: DateTime(2026, 4, 1),
        isPlanned: true,
        scheduleStatus: 'scheduled',
      );
      expect(programmee.confirmAsRealExpense().currency, isNull);
    });
  });

  group('Account : devise du solde', () {
    test('devise absente, minuscule ou alias à la construction', () {
      expect(compte().currency, isNull);
      expect(compte(devise: 'xof').currency, 'XOF');
      expect(compte(devise: 'CFA').currency, 'XAF');
      expect(compte(devise: 'Dollars').currency, isNull);
    });

    test('aller-retour base : clé présente, valeur conservée', () {
      final sansDevise = compte().toDbMap();
      expect(sansDevise.containsKey('currency'), isTrue);
      expect(sansDevise['currency'], isNull);
      expect(Account.fromDbMap(sansDevise).currency, isNull);

      final avecDevise = compte(devise: 'eur').toDbMap();
      expect(avecDevise['currency'], 'EUR');
      final relu = Account.fromDbMap(avecDevise);
      expect(relu.currency, 'EUR');
      expect(relu.balance, 125000.0);
      expect(relu.name, 'Caisse');
    });

    test('aller-retour JSON : devise normalisée dans les deux sens', () {
      expect(Account.fromJson(compte(devise: 'CFA').toJson()).currency, 'XAF');
      expect(Account.fromJson(compte().toJson()).currency, isNull);
    });

    test('devise absente de la charge serveur : pas d’exception', () {
      expect(
        Account.fromJson(const <String, dynamic>{
          'id': 'cpt-serveur',
          'name': 'Compte distant',
          'balance': 42.5,
        }).currency,
        isNull,
      );
    });

    test('copyWith conserve la devise, en pose une normalisée, et ne l’efface '
        'pas', () {
      final origine = compte(devise: 'XAF');
      expect(origine.copyWith(balance: 1.0).currency, 'XAF');
      expect(origine.copyWith(currency: 'eur').currency, 'EUR');
      expect(origine.copyWith(currency: null).currency, 'XAF');
      expect(compte().copyWith(name: 'Autre').currency, isNull);
    });
  });
}
