import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Hachage du code PIN, versionné.
///
/// Historique des formats stockés dans `FlutterSecureStorage` :
///  * `v0` (legacy absolu) : le PIN en clair (très anciennes installations) ;
///  * `v1` (`hashLegacy`)  : `sha256(pin + 'monitrack_salt_')`, sel statique
///    partagé par toutes les installations → table arc-en-ciel immédiate ;
///  * `v2` (`hashV2`)      : `sha256('<sel appareil>|<pin>')`, sel aléatoire
///    propre à l'appareil, mais une seule passe de SHA-256 : un PIN à 4
///    chiffres (10 000 possibilités) se force hors ligne en quelques
///    millisecondes si le stockage sécurisé est exfiltré ;
///  * `v3` (`hashV3`)      : PBKDF2-HMAC-SHA256, dérivation lente et
///    paramétrable. C'est le format écrit aujourd'hui.
///
/// Format v3, auto-porteur (le sel et le coût voyagent avec le condensat) :
///
///     v3$<iterations>$<sel>$<base64(dk)>
///
/// Le nombre d'itérations est stocké : il pourra être augmenté plus tard sans
/// invalider les empreintes existantes, chaque PIN étant réhaché au format
/// courant lors de la prochaine saisie correcte.
class PinHasher {
  PinHasher._();

  static const legacyStaticSalt = 'monitrack_salt_';
  static const v2Prefix = 'v2:';
  static const v3Prefix = 'v3';
  static const _separator = r'$';

  /// Coût PBKDF2 courant.
  ///
  /// Calibré à la mesure, pas au doigt mouillé. Banc d'essai de l'implémentation
  /// ci-dessous (Dart AOT, x64, `Hmac` de `package:crypto`) :
  ///
  ///     10 000 itérations ->  88 ms
  ///     50 000 itérations -> 449 ms
  ///    100 000 itérations -> 786 ms
  ///
  /// soit ~8 µs par itération. Le HMAC pur Dart coûte environ 50 fois plus
  /// qu'une implémentation native : les valeurs « standard » (50 000-100 000)
  /// dépasseraient largement la seconde sur un téléphone d'entrée de gamme,
  /// typiquement 4 à 6 fois plus lent que la machine de mesure. 20 000
  /// itérations tiennent ~160 ms ici et de l'ordre de 400-800 ms là-bas,
  /// dérivation exécutée dans un isolate (`compute`) pour ne pas figer l'UI.
  ///
  /// Le coût est stocké dans l'empreinte : il suffira de relever cette
  /// constante (ou de passer à un KDF natif) pour que les PIN soient réhachés
  /// à la volée à la prochaine saisie correcte, sans migration explicite.
  ///
  /// Effet sur l'attaque hors ligne : un PIN à 4 chiffres reste énumérable,
  /// mais chaque hypothèse coûte 20 000 HMAC au lieu d'un seul SHA-256 — la
  /// vraie défense reste le stockage sécurisé et la limitation de tentatives
  /// côté `SecurityProvider`.
  static const int currentIterations = 20000;

  /// Longueur de la clé dérivée, en octets (256 bits, comme SHA-256).
  static const int _keyLength = 32;

  // ---------------------------------------------------------------------------
  // Formats historiques (conservés pour la vérification et la migration)
  // ---------------------------------------------------------------------------

  static String hashV2(String pin, String salt) {
    final digest = sha256.convert(utf8.encode('$salt|$pin'));
    return '$v2Prefix$digest';
  }

  static String hashLegacy(String pin) {
    return sha256.convert(utf8.encode(pin + legacyStaticSalt)).toString();
  }

  static bool isV2(String stored) => stored.startsWith(v2Prefix);

  // ---------------------------------------------------------------------------
  // Format courant : v3 / PBKDF2-HMAC-SHA256
  // ---------------------------------------------------------------------------

  static bool isV3(String stored) => stored.startsWith('$v3Prefix$_separator');

  /// Calcule l'empreinte v3 d'un PIN. Opération volontairement lente : à
  /// appeler depuis un isolate (`compute(pinHashV3Worker, ...)`).
  static String hashV3(
    String pin,
    String salt, {
    int iterations = currentIterations,
  }) {
    final safeIterations = iterations < 1 ? currentIterations : iterations;
    final dk = _pbkdf2(
      utf8.encode(pin),
      utf8.encode(salt),
      safeIterations,
      _keyLength,
    );
    return [
      v3Prefix,
      '$safeIterations',
      salt,
      base64Encode(dk),
    ].join(_separator);
  }

  /// Paramètres relus depuis une empreinte v3, ou `null` si le format est
  /// invalide (empreinte corrompue ou tronquée).
  static PinHashParams? parseV3(String stored) {
    if (!isV3(stored)) return null;
    final parts = stored.split(_separator);
    if (parts.length != 4) return null;
    final iterations = int.tryParse(parts[1]);
    if (iterations == null || iterations < 1) return null;
    if (parts[2].isEmpty || parts[3].isEmpty) return null;
    return PinHashParams(iterations: iterations, salt: parts[2]);
  }

  /// L'empreinte stockée doit-elle être réécrite au format courant ?
  ///
  /// Vrai pour le PIN en clair, v1, v2, une empreinte v3 illisible, ou une
  /// empreinte v3 dont le coût est inférieur au coût courant.
  static bool needsRehash(String stored) {
    final params = parseV3(stored);
    if (params == null) return true;
    return params.iterations < currentIterations;
  }

  // ---------------------------------------------------------------------------
  // Vérification
  // ---------------------------------------------------------------------------

  /// Vérifie un PIN contre l'empreinte stockée, quel que soit son format.
  ///
  /// [salt] n'est utilisé que pour les empreintes v2 ; en v3 le sel est lu dans
  /// l'empreinte elle-même. Attention : pour une empreinte v3 cet appel est
  /// volontairement coûteux — utiliser [matchesAsync] côté UI.
  static bool matches(String pin, String stored, String salt) {
    if (isV3(stored)) {
      final params = parseV3(stored);
      if (params == null) return false;
      return _constantTimeEquals(
        hashV3(pin, params.salt, iterations: params.iterations),
        stored,
      );
    }
    // PIN stocké en clair (installations antérieures au hachage).
    if (_constantTimeEquals(stored, pin)) return true;
    if (isV2(stored)) {
      return _constantTimeEquals(stored, hashV2(pin, salt));
    }
    return _constantTimeEquals(stored, hashLegacy(pin));
  }

  /// Même sémantique que [matches], mais la dérivation v3 est déportée dans un
  /// isolate pour ne pas bloquer l'interface pendant le déverrouillage.
  ///
  /// [runner] permet d'injecter `compute` (l'implémentation par défaut reste
  /// synchrone afin que ce fichier ne dépende pas de Flutter et reste testable).
  static Future<bool> matchesAsync(
    String pin,
    String stored,
    String salt, {
    Future<String> Function(List<Object> args)? runner,
  }) async {
    if (!isV3(stored)) return matches(pin, stored, salt);
    final params = parseV3(stored);
    if (params == null) return false;
    final args = <Object>[pin, params.salt, params.iterations];
    final candidate =
        runner == null ? pinHashV3Worker(args) : await runner(args);
    return _constantTimeEquals(candidate, stored);
  }

  // ---------------------------------------------------------------------------
  // PBKDF2-HMAC-SHA256 (RFC 8018, §5.2)
  // ---------------------------------------------------------------------------

  static Uint8List _pbkdf2(
    List<int> password,
    List<int> salt,
    int iterations,
    int keyLength,
  ) {
    final hmac = Hmac(sha256, password);
    final blockCount = (keyLength + _keyLength - 1) ~/ _keyLength;
    final output = Uint8List(blockCount * _keyLength);

    for (var block = 1; block <= blockCount; block++) {
      final seed = Uint8List(salt.length + 4)
        ..setRange(0, salt.length, salt)
        ..[salt.length] = (block >> 24) & 0xff
        ..[salt.length + 1] = (block >> 16) & 0xff
        ..[salt.length + 2] = (block >> 8) & 0xff
        ..[salt.length + 3] = block & 0xff;

      var u = Uint8List.fromList(hmac.convert(seed).bytes);
      final accumulator = Uint8List.fromList(u);

      for (var i = 1; i < iterations; i++) {
        u = Uint8List.fromList(hmac.convert(u).bytes);
        for (var k = 0; k < _keyLength; k++) {
          accumulator[k] ^= u[k];
        }
      }
      output.setRange((block - 1) * _keyLength, block * _keyLength, accumulator);
    }

    return Uint8List.sublistView(output, 0, keyLength);
  }

  /// Comparaison à temps constant : aucune fuite par canal temporel sur le
  /// préfixe commun des deux chaînes.
  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}

/// Paramètres de coût relus depuis une empreinte v3.
class PinHashParams {
  const PinHashParams({required this.iterations, required this.salt});

  final int iterations;
  final String salt;
}

/// Point d'entrée pour `compute()` : `args = [pin, sel, itérations]`.
///
/// Doit rester une fonction de premier niveau pour être envoyable à un isolate.
String pinHashV3Worker(List<Object> args) => PinHasher.hashV3(
      args[0] as String,
      args[1] as String,
      iterations: args[2] as int,
    );
