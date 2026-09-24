import 'package:flutter_test/flutter_test.dart';
import 'package:monitrack/utils/pin_hasher.dart';

void main() {
  group('PBKDF2-HMAC-SHA256', () {
    // Vecteurs de référence calculés avec `hashlib.pbkdf2_hmac` (Python) :
    // ils valident l'implémentation manuelle de PBKDF2, y compris la
    // sémantique du compteur d'itérations (c = 1 -> un seul HMAC).
    test('respecte les vecteurs de référence', () {
      expect(
        PinHasher.hashV3('password', 'salt', iterations: 1),
        r'v3$1$salt$Eg+2z/z4syxD5yJSVsT4N6hlSMkszDVICAWYfLcL4Xs=',
      );
      expect(
        PinHasher.hashV3('password', 'salt', iterations: 2),
        r'v3$2$salt$rk0Mla9rRtMtCt/5KPBt0CowP47zwlHf1uLYWpVHTEM=',
      );
      expect(
        PinHasher.hashV3('password', 'salt', iterations: 4096),
        r'v3$4096$salt$xeR41ZKIyEGqUw22hFxMjZYok6ABzk4RpJY4c6qYE0o=',
      );
    });
  });

  group('Format v3', () {
    test('est auto-porteur : version, coût, sel et condensat', () {
      final stored = PinHasher.hashV3('1234', 'ZGV2aWNlLXNhbHQ=', iterations: 1000);
      final parts = stored.split(r'$');

      expect(parts, hasLength(4));
      expect(parts[0], 'v3');
      expect(parts[1], '1000');
      expect(parts[2], 'ZGV2aWNlLXNhbHQ=');
      expect(parts[3], isNotEmpty);
      expect(PinHasher.isV3(stored), isTrue);
      expect(PinHasher.isV2(stored), isFalse);

      final params = PinHasher.parseV3(stored);
      expect(params!.iterations, 1000);
      expect(params.salt, 'ZGV2aWNlLXNhbHQ=');
    });

    test('est déterministe et dépend du PIN comme du sel', () {
      final a = PinHasher.hashV3('1234', 'sel-a', iterations: 500);
      final b = PinHasher.hashV3('1234', 'sel-a', iterations: 500);
      final autrePin = PinHasher.hashV3('4321', 'sel-a', iterations: 500);
      final autreSel = PinHasher.hashV3('1234', 'sel-b', iterations: 500);

      expect(a, b);
      expect(a, isNot(autrePin));
      expect(a, isNot(autreSel));
    });

    test('le coût courant est celui de la constante publiée', () {
      final stored = PinHasher.hashV3('1234', 'sel');
      expect(PinHasher.parseV3(stored)!.iterations, PinHasher.currentIterations);
    });

    test('une empreinte corrompue ne valide jamais un PIN', () {
      for (final corrompu in [
        r'v3$',
        r'v3$1000$sel',
        r'v3$zero$sel$aaaa',
        r'v3$1000$$aaaa',
        r'v3$0$sel$aaaa',
      ]) {
        expect(PinHasher.parseV3(corrompu), isNull, reason: corrompu);
        expect(PinHasher.matches('1234', corrompu, 'sel'), isFalse,
            reason: corrompu);
      }
    });
  });

  group('Vérification tous formats', () {
    const pin = '1234';
    const salt = 'device-salt';

    test('accepte le PIN en clair, v1, v2 et v3', () {
      expect(PinHasher.matches(pin, pin, salt), isTrue);
      expect(PinHasher.matches(pin, PinHasher.hashLegacy(pin), salt), isTrue);
      expect(PinHasher.matches(pin, PinHasher.hashV2(pin, salt), salt), isTrue);
      expect(
        PinHasher.matches(pin, PinHasher.hashV3(pin, salt, iterations: 500), salt),
        isTrue,
      );
    });

    test('refuse un mauvais PIN dans chaque format', () {
      expect(PinHasher.matches('0000', pin, salt), isFalse);
      expect(PinHasher.matches('0000', PinHasher.hashLegacy(pin), salt), isFalse);
      expect(PinHasher.matches('0000', PinHasher.hashV2(pin, salt), salt), isFalse);
      expect(
        PinHasher.matches('0000', PinHasher.hashV3(pin, salt, iterations: 500), salt),
        isFalse,
      );
    });

    test('la vérification v3 ignore le sel appareil passé en argument', () {
      // Le sel est lu dans l'empreinte : même si l'entrée dédiée du stockage
      // sécurisé a disparu, un PIN v3 reste vérifiable.
      final stored = PinHasher.hashV3(pin, salt, iterations: 500);
      expect(PinHasher.matches(pin, stored, ''), isTrue);
      expect(PinHasher.matches(pin, stored, 'un-autre-sel'), isTrue);
    });

    test('matchesAsync délègue la dérivation v3 au runner fourni', () async {
      var appels = 0;
      Future<String> runner(List<Object> args) async {
        appels++;
        return PinHasher.hashV3(
          args[0] as String,
          args[1] as String,
          iterations: args[2] as int,
        );
      }

      final stored = PinHasher.hashV3(pin, salt, iterations: 500);
      expect(await PinHasher.matchesAsync(pin, stored, salt, runner: runner), isTrue);
      expect(await PinHasher.matchesAsync('0000', stored, salt, runner: runner), isFalse);
      expect(appels, 2);

      // Formats non-v3 : pas d'isolate, la vérification est immédiate.
      final v2 = PinHasher.hashV2(pin, salt);
      expect(await PinHasher.matchesAsync(pin, v2, salt, runner: runner), isTrue);
      expect(appels, 2);
    });

    test('le worker d\'isolate produit la même empreinte', () {
      expect(
        pinHashV3Worker(<Object>[pin, salt, 500]),
        PinHasher.hashV3(pin, salt, iterations: 500),
      );
    });
  });

  group('Migration v0/v1/v2 -> v3', () {
    const pin = '1234';
    const salt = 'device-salt';

    test('tout format antérieur est marqué à réhacher', () {
      expect(PinHasher.needsRehash(pin), isTrue); // PIN en clair
      expect(PinHasher.needsRehash(PinHasher.hashLegacy(pin)), isTrue); // v1
      expect(PinHasher.needsRehash(PinHasher.hashV2(pin, salt)), isTrue); // v2
    });

    test('une empreinte v3 au coût courant n\'est pas réhachée', () {
      expect(PinHasher.needsRehash(PinHasher.hashV3(pin, salt)), isFalse);
    });

    test('une empreinte v3 à coût insuffisant est réhachée', () {
      final faible = PinHasher.hashV3(pin, salt, iterations: 500);
      expect(PinHasher.needsRehash(faible), isTrue);
      // ... mais elle reste vérifiable avec son propre coût, sinon la
      // migration à la volée serait impossible.
      expect(PinHasher.matches(pin, faible, salt), isTrue);
    });

    test('scénario complet : PIN v1 vérifié puis réhaché en v3', () {
      // 1. Installation historique : sel statique partagé.
      var stored = PinHasher.hashLegacy(pin);
      expect(PinHasher.matches(pin, stored, salt), isTrue);
      expect(PinHasher.needsRehash(stored), isTrue);

      // 2. Première saisie correcte après mise à jour : réécriture en v3.
      stored = PinHasher.hashV3(pin, salt, iterations: 500);

      // 3. Déverrouillages suivants : le v3 valide, l'ancien PIN n'est plus
      //    reconnaissable via le sel statique.
      expect(PinHasher.matches(pin, stored, salt), isTrue);
      expect(PinHasher.matches('0000', stored, salt), isFalse);
      expect(stored.startsWith(PinHasher.legacyStaticSalt), isFalse);
    });
  });

  group('Non-régression des formats historiques', () {
    test('v2 reste inchangé', () {
      expect(PinHasher.hashV2('1234', 'abc'),
          startsWith(PinHasher.v2Prefix));
      expect(PinHasher.hashV2('1234', 'abc'), PinHasher.hashV2('1234', 'abc'));
      expect(PinHasher.hashV2('1234', 'abc'), isNot(PinHasher.hashLegacy('1234')));
    });

    test('v1 reste un SHA-256 hexadécimal de 64 caractères', () {
      final legacy = PinHasher.hashLegacy('1234');
      expect(legacy, hasLength(64));
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(legacy), isTrue);
    });
  });
}
