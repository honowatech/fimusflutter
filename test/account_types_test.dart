import 'package:flutter_test/flutter_test.dart';
import 'package:monitrack/models/account_type.dart';
import 'package:monitrack/models/user_profile.dart';

void main() {
  group('AccountType Enum Tests', () {
    test('Correct parsing and attributes for Personnel (particulier)', () {
      final type = AccountType.fromString('particulier');
      expect(type, equals(AccountType.particulier));
      expect(type.label, equals('Personnel'));
      expect(type.isPersonal, isTrue);
      expect(type.isBusiness, isFalse);
      expect(type.hasUssdAgent, isFalse);
      expect(type.hasProducts, isFalse);
      expect(type.hasStaff, isFalse);
      expect(type.hasUssdMenu, isTrue);
    });

    test('Correct parsing and attributes for Petit commerce (petit_commerce)', () {
      final type = AccountType.fromString('petit_commerce');
      expect(type, equals(AccountType.petitCommerce));
      expect(type.label, equals('Petit commerce (vente)'));
      expect(type.isPersonal, isFalse);
      expect(type.isBusiness, isTrue);
      expect(type.hasUssdAgent, isFalse);
      expect(type.hasProducts, isTrue);
      expect(type.hasStaff, isFalse);
      expect(type.hasUssdMenu, isFalse);
    });

    test('Correct parsing and attributes for Entreprise (entreprise)', () {
      final type = AccountType.fromString('entreprise');
      expect(type, equals(AccountType.entreprise));
      expect(type.label, equals('Entreprise (Service)'));
      expect(type.isPersonal, isFalse);
      expect(type.isBusiness, isTrue);
      expect(type.hasUssdAgent, isFalse);
      expect(type.hasProducts, isFalse);
      expect(type.hasStaff, isTrue);
      expect(type.hasUssdMenu, isFalse);
    });

    test('Retrocompatibility: professional / professionnel migrated to entreprise', () {
      final type1 = AccountType.fromString('professional');
      final type2 = AccountType.fromString('professionnel');

      expect(type1, equals(AccountType.entreprise));
      expect(type2, equals(AccountType.entreprise));
      expect(type1.hasStaff, isTrue);
      expect(type1.hasUssdAgent, isFalse);
    });

    test('Correct parsing and attributes for Kiosque (kiosque)', () {
      final type = AccountType.fromString('kiosque');
      expect(type, equals(AccountType.kiosque));
      expect(type.label, equals('Kiosque (transfert d\'argent)'));
      expect(type.isPersonal, isFalse);
      expect(type.isBusiness, isTrue);
      expect(type.hasUssdAgent, isTrue);
      expect(type.hasProducts, isFalse);
      expect(type.hasStaff, isFalse);
      expect(type.hasUssdMenu, isTrue);
    });
  });

  group('UserProfile with 4 Account Types', () {
    test('Personnel Profile behavior', () {
      final profile = UserProfile(
        firstName: 'Paul',
        lastName: 'Biya',
        type: 'particulier',
      );

      expect(profile.accountType, equals(AccountType.particulier));
      expect(profile.isParticulier, isTrue);
      expect(profile.isCommercant, isFalse);
      expect(profile.isEntreprise, isFalse);
      expect(profile.isKiosque, isFalse);
      expect(profile.hasProducts, isFalse);
      expect(profile.hasStaff, isFalse);
      expect(profile.hasUssdAgent, isFalse);
      expect(profile.hasUssdMenu, isTrue);
    });

    test('Petit commerce Profile behavior', () {
      final profile = UserProfile(
        firstName: 'Fatou',
        lastName: 'Boutique',
        type: 'petit_commerce',
      );

      expect(profile.accountType, equals(AccountType.petitCommerce));
      expect(profile.isParticulier, isFalse);
      expect(profile.isCommercant, isTrue);
      expect(profile.isEntreprise, isFalse);
      expect(profile.isKiosque, isFalse);
      expect(profile.hasProducts, isTrue);
      expect(profile.hasStaff, isFalse);
      expect(profile.hasUssdAgent, isFalse);
      expect(profile.hasUssdMenu, isFalse);
    });

    test('Entreprise Profile behavior', () {
      final profile = UserProfile(
        firstName: 'Tech',
        lastName: 'Solutions',
        type: 'entreprise',
      );

      expect(profile.accountType, equals(AccountType.entreprise));
      expect(profile.isParticulier, isFalse);
      expect(profile.isCommercant, isFalse);
      expect(profile.isEntreprise, isTrue);
      expect(profile.isKiosque, isFalse);
      expect(profile.hasProducts, isFalse);
      expect(profile.hasStaff, isTrue);
      expect(profile.hasUssdAgent, isFalse);
      expect(profile.hasUssdMenu, isFalse);
    });

    test('Kiosque Profile behavior', () {
      final profile = UserProfile(
        firstName: 'Moussa',
        lastName: 'Kiosk',
        type: 'kiosque',
      );

      expect(profile.accountType, equals(AccountType.kiosque));
      expect(profile.isParticulier, isFalse);
      expect(profile.isCommercant, isFalse);
      expect(profile.isEntreprise, isFalse);
      expect(profile.isKiosque, isTrue);
      expect(profile.hasProducts, isFalse);
      expect(profile.hasStaff, isFalse);
      expect(profile.hasUssdAgent, isTrue);
      expect(profile.hasUssdMenu, isTrue);
    });
  });
}
