import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite/sqflite.dart'
    show
        Database,
        OnDatabaseCreateFn,
        OnDatabaseOpenFn,
        OnDatabaseVersionChangeFn;

/// Chiffrement de la base SQLite locale — constat E3 de l'audit (sprint 5).
///
/// La base locale contient des montants, des noms et numéros de débiteurs, des
/// salaires et l'historique des opérations Mobile Money. Sur un appareil rooté,
/// sauvegardé ou volé, un fichier SQLite en clair se lit intégralement.
///
/// Ce module n'ouvre aucune base lui-même : le moteur est **injecté**
/// ([OuvertureBase]), ce qui permet de le remplacer par un double en test et
/// garde `database_service.dart` seul responsable du choix du moteur
/// (`sqflite_sqlcipher` en production).
///
/// Principes retenus :
///
/// * **Une clé aléatoire de 256 bits**, tirée de [Random.secure] à la première
///   ouverture chiffrée, conservée dans [FlutterSecureStorage]
///   (Keystore Android / Keychain iOS). Jamais dans les SharedPreferences,
///   jamais dérivée du code PIN — le PIN est court, changeable, et le dériver
///   rendrait la base illisible à chaque changement de PIN.
/// * **Migration en place d'une base existante en clair**, atomique et
///   idempotente : export vers un fichier temporaire, vérification, puis
///   bascule par renommage. Le fichier en clair n'est supprimé qu'une fois la
///   copie chiffrée vérifiée ([ChiffrementBase.ouvrir]).
/// * **Clé perdue** (restauration d'appareil, Keystore réinitialisé,
///   désinstallation partielle) : la base chiffrée devient définitivement
///   illisible. On repart alors d'une base vide plutôt que de bloquer
///   l'utilisateur — `SyncService.pull()` étant un rechargement complet, les
///   données déjà synchronisées reviennent du serveur.
/// * **Retour arrière** : `--dart-define=FIMUS_DB_CHIFFREMENT=false` rend la
///   couche inerte (cf. [ChiffrementBase.drapeauActif]).
///
/// Voir `docs/chiffrement-base-locale.md`.

// -----------------------------------------------------------------------------
// Moteur injecté
// -----------------------------------------------------------------------------

/// Ouverture d'une base par le moteur SQLCipher.
///
/// Signature volontairement calquée sur `sqflite_sqlcipher` : un
/// [motDePasse] nul ouvre le fichier **en clair** (c'est ce qui permet de lire
/// la base héritée pour la migrer).
typedef OuvertureBase = Future<Database> Function(
  String chemin, {
  String? motDePasse,
  int? version,
  OnDatabaseCreateFn? onCreate,
  OnDatabaseVersionChangeFn? onUpgrade,
  OnDatabaseOpenFn? onOpen,
  bool instanceUnique,
});

// -----------------------------------------------------------------------------
// Coffre de la clé
// -----------------------------------------------------------------------------

/// Accès au secret qui protège la base. Abstrait pour deux raisons : isoler
/// le stockage sécurisé (indisponible hors appareil) et distinguer
/// explicitement « clé absente » de « lecture impossible ».
abstract class CoffreCle {
  /// Clé enregistrée, ou `null` si le coffre n'en contient pas.
  /// Lève si le coffre lui-même est inaccessible.
  Future<String?> lire();

  Future<void> ecrire(String valeur);

  Future<void> supprimer();
}

/// Implémentation de production : Keystore (Android) / Keychain (iOS).
class CoffreCleSecurise implements CoffreCle {
  const CoffreCleSecurise({
    FlutterSecureStorage stockage = const FlutterSecureStorage(),
    this.entree = entreeParDefaut,
  }) : _stockage = stockage;

  /// Nom de l'entrée. Suffixé `_v1` : si le format de clé devait changer, une
  /// nouvelle entrée cohabiterait avec l'ancienne au lieu de l'écraser.
  static const String entreeParDefaut = 'fimus_cle_base_locale_v1';

  final FlutterSecureStorage _stockage;
  final String entree;

  @override
  Future<String?> lire() => _stockage.read(key: entree);

  @override
  Future<void> ecrire(String valeur) =>
      _stockage.write(key: entree, value: valeur);

  @override
  Future<void> supprimer() => _stockage.delete(key: entree);
}

// -----------------------------------------------------------------------------
// État d'un fichier de base
// -----------------------------------------------------------------------------

/// Ce que contient réellement le fichier, indépendamment de ce que l'on croit.
enum EtatBase {
  /// Aucun fichier : première installation, ou base recréée.
  absent,

  /// En-tête `SQLite format 3` : base historique, non chiffrée.
  clair,

  /// En-tête quelconque : base chiffrée (SQLCipher chiffre aussi l'en-tête).
  chiffre,
}

/// Décision de reprise au démarrage, quand une migration précédente a été
/// interrompue (arrêt de l'application, batterie vide, crash).
enum ActionReprise {
  /// Rien à reprendre.
  aucune,

  /// La copie chiffrée est vérifiée et l'originale déjà écartée : il ne
  /// restait qu'à la mettre en place.
  terminerBascule,

  /// La bascule a eu lieu mais la sauvegarde n'a pas été effacée.
  effacerSauvegarde,

  /// L'export a été interrompu avant vérification : la copie partielle est
  /// jetée, la base en clair est intacte et sera migrée de nouveau.
  jeterTemporaire,

  /// Cas dégradé : plus de base ni de copie exploitable, mais une sauvegarde
  /// en clair existe — elle est remise en place.
  restaurerSauvegarde,
}

// -----------------------------------------------------------------------------
// Orchestration
// -----------------------------------------------------------------------------

/// Résultat d'une ouverture, au-delà de la poignée elle-même.
class ResultatOuverture {
  const ResultatOuverture(this.base, this.mode, {this.resynchronisationRequise = false});

  final Database base;
  final ModeOuverture mode;

  /// Vrai quand la base a été recréée vide : les données doivent être
  /// rechargées depuis le serveur (`SyncService.pull()`).
  final bool resynchronisationRequise;
}

enum ModeOuverture {
  /// Base déjà chiffrée, ouverte avec la clé du coffre.
  chiffree,

  /// Base neuve, créée directement chiffrée.
  chiffreeNeuve,

  /// Base héritée en clair, convertie pendant cette ouverture.
  chiffreeApresMigration,

  /// Clé perdue : la base illisible a été remplacée par une base vide.
  chiffreeApresPerteCle,

  /// Chiffrement inactif ou indisponible : ouverture en clair (comportement
  /// historique).
  claire,
}

/// Erreur signalant que le coffre est inaccessible alors qu'une base chiffrée
/// existe. On préfère échouer bruyamment plutôt que détruire des données sur
/// un incident potentiellement passager (Keystore verrouillé, appareil en
/// cours de déverrouillage).
class CoffreIndisponible implements Exception {
  CoffreIndisponible(this.cause);

  final Object cause;

  @override
  String toString() => 'CoffreIndisponible : $cause';
}

class ChiffrementBase {
  ChiffrementBase({
    required OuvertureBase ouvrirMoteur,
    CoffreCle coffre = const CoffreCleSecurise(),
    Random? alea,
  })  : _ouvrirMoteur = ouvrirMoteur,
        _coffre = coffre,
        _alea = alea;

  final OuvertureBase _ouvrirMoteur;
  final CoffreCle _coffre;
  final Random? _alea;

  // ---------------------------------------------------------------------------
  // Drapeau de retour arrière
  // ---------------------------------------------------------------------------

  /// Interrupteur de production : `--dart-define=FIMUS_DB_CHIFFREMENT=false`
  /// au build rend la couche inerte (les bases déjà chiffrées ne sont alors
  /// plus lisibles — cf. la procédure de retour arrière documentée).
  static const bool drapeauActif =
      bool.fromEnvironment('FIMUS_DB_CHIFFREMENT', defaultValue: true);

  /// Vrai sous `flutter test` : la suite tourne sur `sqflite_common_ffi`, qui
  /// n'embarque pas SQLCipher, et sans plugin de stockage sécurisé. Le
  /// chiffrement s'y désactive tout seul, sans qu'aucun test ait à le savoir.
  static final bool sousTest =
      !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  /// Chiffrement effectivement appliqué. Le web en est exclu : la base y vit
  /// dans IndexedDB via `sqflite_common_ffi_web`, que SQLCipher ne sert pas.
  static bool get actif => drapeauActif && !kIsWeb && !sousTest;

  // ---------------------------------------------------------------------------
  // Journal
  // ---------------------------------------------------------------------------

  /// Événements de chiffrement de la dernière ouverture (migration, perte de
  /// clé, repli). Journal **distinct** de `DatabaseService.schemaIssues`, qui
  /// ne doit contenir que des écarts de schéma.
  static final List<String> _incidents = [];

  static List<String> get incidents => List.unmodifiable(_incidents);

  static void _journaliser(String message) {
    _incidents.add(message);
    debugPrint('[Chiffrement] $message');
  }

  // ---------------------------------------------------------------------------
  // Clé
  // ---------------------------------------------------------------------------

  /// Longueur de la clé, en octets (256 bits).
  static const int octetsCle = 32;

  /// Tire une clé de 256 bits et l'encode en base64 (44 caractères).
  ///
  /// SQLCipher dérive la clé de chiffrement de cette phrase secrète par
  /// PBKDF2-HMAC-SHA512 ; l'entropie réelle reste celle des 256 bits tirés.
  /// [alea] n'est injecté que par les tests : la production utilise
  /// [Random.secure].
  static String genererCle({Random? alea}) {
    final source = alea ?? Random.secure();
    final octets =
        List<int>.generate(octetsCle, (_) => source.nextInt(256), growable: false);
    return base64Encode(octets);
  }

  /// Erreur signalant que la clé n'ouvre pas le fichier, et non une panne
  /// quelconque. SQLCipher ne déchiffre pas l'en-tête avec une mauvaise clé et
  /// rend `SQLITE_NOTADB` — « file is not a database ». Fonction pure : c'est
  /// elle qui autorise la destruction du fichier, elle doit donc être stricte.
  static bool estErreurDeCle(Object erreur) {
    final message = erreur.toString().toLowerCase();
    return message.contains('not a database') ||
        message.contains('notadb') ||
        message.contains('file is encrypted');
  }

  /// Une clé exploitable est du base64 décodable pesant [octetsCle] octets.
  /// Une entrée tronquée (écriture interrompue) est ainsi détectée au lieu
  /// d'être utilisée telle quelle, ce qui rendrait la base illisible plus tard.
  static bool cleValide(String? cle) {
    if (cle == null || cle.isEmpty) return false;
    try {
      return base64Decode(cle).length == octetsCle;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Lecture de l'état du fichier
  // ---------------------------------------------------------------------------

  /// En-tête d'un fichier SQLite non chiffré : « SQLite format 3\0 ».
  static final List<int> enteteClair =
      List<int>.unmodifiable(latin1.encode('SQLite format 3\u0000'));

  /// Déduit l'état d'une base de ses premiers octets. Fonction pure : c'est
  /// elle qui distingue « à migrer » de « déjà chiffrée », sans jamais faire
  /// confiance à un marqueur applicatif (SharedPreferences effacées,
  /// application réinstallée par-dessus les données…).
  static EtatBase etatDepuisEntete(List<int>? premiersOctets) {
    if (premiersOctets == null || premiersOctets.isEmpty) return EtatBase.absent;
    if (premiersOctets.length < enteteClair.length) return EtatBase.chiffre;
    for (var i = 0; i < enteteClair.length; i++) {
      if (premiersOctets[i] != enteteClair[i]) return EtatBase.chiffre;
    }
    return EtatBase.clair;
  }

  /// Lecture sur disque de [etatDepuisEntete].
  static Future<EtatBase> etatFichier(String chemin) async {
    final fichier = File(chemin);
    if (!fichier.existsSync()) return EtatBase.absent;
    if (fichier.lengthSync() == 0) return EtatBase.absent;
    final poignee = await fichier.open();
    try {
      return etatDepuisEntete(await poignee.read(enteteClair.length));
    } finally {
      await poignee.close();
    }
  }

  // ---------------------------------------------------------------------------
  // Chemins de travail
  // ---------------------------------------------------------------------------

  /// Copie chiffrée en cours de construction.
  static String cheminTemporaire(String chemin) => '$chemin.chiffre-tmp';

  /// Base en clair mise de côté le temps de la bascule.
  static String cheminSauvegarde(String chemin) => '$chemin.clair-sauvegarde';

  /// Fichiers annexes de SQLite. Un `-wal` orphelin laissé à côté d'un
  /// nouveau fichier de base est interprété par SQLite comme appartenant à
  /// celui-ci : les oublier corromprait la base migrée.
  static List<String> annexes(String chemin) =>
      ['$chemin-wal', '$chemin-shm', '$chemin-journal'];

  // ---------------------------------------------------------------------------
  // Reprise d'une migration interrompue
  // ---------------------------------------------------------------------------

  /// Décide, à partir de la seule présence des trois fichiers, ce qu'il reste
  /// à faire d'une migration interrompue. Fonction pure : c'est le cœur de la
  /// garantie « idempotente et atomique », et le point le plus facile à
  /// couvrir par des tests.
  ///
  /// Invariant qui fonde la table : la sauvegarde n'est créée qu'**après**
  /// vérification de la copie chiffrée. Si elle existe, la copie temporaire
  /// est donc fiable.
  static ActionReprise decider({
    required bool base,
    required bool temporaire,
    required bool sauvegarde,
  }) {
    if (sauvegarde) {
      if (base) return ActionReprise.effacerSauvegarde;
      if (temporaire) return ActionReprise.terminerBascule;
      return ActionReprise.restaurerSauvegarde;
    }
    if (temporaire) return ActionReprise.jeterTemporaire;
    return ActionReprise.aucune;
  }

  Future<void> _reprendreMigrationInterrompue(String chemin) async {
    final temporaire = cheminTemporaire(chemin);
    final sauvegarde = cheminSauvegarde(chemin);
    final action = decider(
      // Variantes synchrones : trois `stat` au démarrage, et le lint
      // `avoid_slow_async_io` du projet proscrit leurs équivalents asynchrones.
      base: File(chemin).existsSync(),
      temporaire: File(temporaire).existsSync(),
      sauvegarde: File(sauvegarde).existsSync(),
    );
    switch (action) {
      case ActionReprise.aucune:
        return;
      case ActionReprise.jeterTemporaire:
        _journaliser('migration interrompue avant vérification : copie '
            'partielle écartée, la base en clair est intacte');
        await _supprimer(temporaire, avecAnnexes: true);
      case ActionReprise.terminerBascule:
        _journaliser('migration interrompue pendant la bascule : mise en '
            'place de la copie chiffrée déjà vérifiée');
        await File(temporaire).rename(chemin);
        await _supprimer(sauvegarde, avecAnnexes: true);
      case ActionReprise.effacerSauvegarde:
        _journaliser('migration terminée lors d\'un démarrage précédent : '
            'suppression de la sauvegarde en clair');
        await _supprimer(sauvegarde, avecAnnexes: true);
      case ActionReprise.restaurerSauvegarde:
        _journaliser('migration interrompue : remise en place de la base en '
            'clair sauvegardée');
        await File(sauvegarde).rename(chemin);
    }
  }

  // ---------------------------------------------------------------------------
  // Ouverture
  // ---------------------------------------------------------------------------

  /// Ouvre [chemin] chiffrée, en migrant la base héritée si nécessaire.
  ///
  /// Les rappels de schéma ([onCreate], [onUpgrade], [onOpen]) sont ceux de
  /// `DatabaseService` : la migration de chiffrement préserve
  /// `PRAGMA user_version`, si bien que les paliers de schéma s'enchaînent
  /// ensuite exactement comme sur une base en clair.
  Future<ResultatOuverture> ouvrir(
    String chemin, {
    required int version,
    OnDatabaseCreateFn? onCreate,
    OnDatabaseVersionChangeFn? onUpgrade,
    OnDatabaseOpenFn? onOpen,
  }) async {
    _incidents.clear();

    await _reprendreMigrationInterrompue(chemin);

    var etat = await etatFichier(chemin);
    var mode = switch (etat) {
      EtatBase.absent => ModeOuverture.chiffreeNeuve,
      EtatBase.clair => ModeOuverture.chiffreeApresMigration,
      EtatBase.chiffre => ModeOuverture.chiffree,
    };

    String? cleLue;
    try {
      cleLue = await _coffre.lire();
    } catch (e) {
      // Coffre inaccessible : sur une base chiffrée, détruire serait
      // irréversible pour un incident peut-être passager.
      if (etat == EtatBase.chiffre) {
        _journaliser('coffre inaccessible, base chiffrée non ouverte : $e');
        throw CoffreIndisponible(e);
      }
      _journaliser('coffre inaccessible, ouverture en clair (repli) : $e');
      return ResultatOuverture(
        await _ouvrirEnClair(chemin,
            version: version,
            onCreate: onCreate,
            onUpgrade: onUpgrade,
            onOpen: onOpen),
        ModeOuverture.claire,
      );
    }

    final String cle;
    if (cleValide(cleLue)) {
      cle = cleLue!;
    } else {
      if (etat == EtatBase.chiffre) {
        // Restauration d'appareil, Keystore réinitialisé, entrée corrompue :
        // le contenu est définitivement illisible.
        _journaliser('clé absente ou invalide alors que la base est chiffrée : '
            'base remplacée par une base vide, resynchronisation requise');
        await _supprimer(chemin, avecAnnexes: true);
        etat = EtatBase.absent;
        mode = ModeOuverture.chiffreeApresPerteCle;
      }
      cle = genererCle(alea: _alea);
      await _coffre.ecrire(cle);
    }

    if (etat == EtatBase.clair) {
      try {
        await _migrerVersChiffre(chemin, cle);
      } catch (e) {
        // La base en clair est intacte (elle n'est écartée qu'après une copie
        // vérifiée). Bloquer l'utilisateur au démarrage serait disproportionné :
        // on reprend le comportement historique, l'incident est journalisé et
        // la migration sera retentée au prochain lancement.
        _journaliser('migration impossible, ouverture en clair (repli) : $e');
        return ResultatOuverture(
          await _ouvrirEnClair(chemin,
              version: version,
              onCreate: onCreate,
              onUpgrade: onUpgrade,
              onOpen: onOpen),
          ModeOuverture.claire,
        );
      }
    }

    try {
      final base = await _ouvrirMoteur(
        chemin,
        motDePasse: cle,
        version: version,
        onCreate: onCreate,
        onUpgrade: onUpgrade,
        onOpen: onOpen,
      );
      return ResultatOuverture(base, mode,
          resynchronisationRequise: mode == ModeOuverture.chiffreeApresPerteCle);
    } catch (e) {
      // Seule une erreur d'authentification justifie de détruire le fichier.
      // Toute autre panne (disque plein, palier de schéma en échec, plugin
      // absent) doit remonter : la détruire serait irréversible.
      if (etat != EtatBase.chiffre || !estErreurDeCle(e)) rethrow;
      // La clé du coffre n'ouvre pas ce fichier : base issue d'une autre
      // installation (restauration de sauvegarde applicative), ou clé
      // régénérée entre-temps. Même issue que la clé perdue.
      _journaliser('la clé du coffre n\'ouvre pas la base ($e) : base '
          'remplacée par une base vide, resynchronisation requise');
      await _supprimer(chemin, avecAnnexes: true);
      final base = await _ouvrirMoteur(
        chemin,
        motDePasse: cle,
        version: version,
        onCreate: onCreate,
        onUpgrade: onUpgrade,
        onOpen: onOpen,
      );
      return ResultatOuverture(base, ModeOuverture.chiffreeApresPerteCle,
          resynchronisationRequise: true);
    }
  }

  Future<Database> _ouvrirEnClair(
    String chemin, {
    required int version,
    OnDatabaseCreateFn? onCreate,
    OnDatabaseVersionChangeFn? onUpgrade,
    OnDatabaseOpenFn? onOpen,
  }) =>
      _ouvrirMoteur(
        chemin,
        version: version,
        onCreate: onCreate,
        onUpgrade: onUpgrade,
        onOpen: onOpen,
      );

  // ---------------------------------------------------------------------------
  // Migration clair → chiffré
  // ---------------------------------------------------------------------------

  /// Convertit la base en clair de [chemin] en base chiffrée avec [cle].
  ///
  /// Déroulé, dans cet ordre strict :
  ///
  /// 1. export SQLCipher vers un fichier temporaire ;
  /// 2. **vérification** de la copie (version de schéma, tables, nombre de
  ///    lignes par table) ;
  /// 3. mise de côté de la base en clair ;
  /// 4. bascule de la copie à la place de l'originale ;
  /// 5. suppression de la sauvegarde et des fichiers annexes.
  ///
  /// Toute interruption laisse un état que [decider] sait reprendre, et la
  /// base en clair n'est jamais supprimée avant l'étape 5.
  Future<void> _migrerVersChiffre(String chemin, String cle) async {
    final temporaire = cheminTemporaire(chemin);
    final sauvegarde = cheminSauvegarde(chemin);
    await _supprimer(temporaire, avecAnnexes: true);

    final debut = DateTime.now();

    // 1. Export. La source est ouverte sans mot de passe (donc en clair) et
    // sans `version` : aucun rappel de migration de schéma ne doit tourner
    // ici, on copie la base telle qu'elle est.
    final source = await _ouvrirMoteur(chemin, instanceUnique: false);
    Map<String, int> inventaire;
    int versionSchema;
    try {
      versionSchema = _premierEntier(await source.rawQuery('PRAGMA user_version'));
      inventaire = await _inventaire(source);
      await source.execute(
          'ATTACH DATABASE ? AS chiffree KEY ?', [temporaire, cle]);
      await source.rawQuery("SELECT sqlcipher_export('chiffree')");
      // `sqlcipher_export` ne recopie pas la version de schéma : sans cette
      // ligne, la base migrée serait vue comme une base neuve et tous les
      // paliers seraient rejoués.
      await source.execute('PRAGMA chiffree.user_version = $versionSchema');
      await source.execute('DETACH DATABASE chiffree');
    } catch (_) {
      // L'`ATTACH` crée déjà le fichier : une copie inexploitable ne doit pas
      // survivre à l'échec. [decider] la jetterait au démarrage suivant, mais
      // autant ne pas la laisser traîner.
      await source.close();
      await _supprimer(temporaire, avecAnnexes: true);
      rethrow;
    }
    await source.close();

    // 2. Vérification : la copie s'ouvre bien avec la clé et contient
    // exactement les mêmes tables et le même nombre de lignes.
    final copie = await _ouvrirMoteur(temporaire,
        motDePasse: cle, instanceUnique: false);
    try {
      final versionCopie =
          _premierEntier(await copie.rawQuery('PRAGMA user_version'));
      if (versionCopie != versionSchema) {
        throw StateError('version de schéma non reprise '
            '($versionCopie au lieu de $versionSchema)');
      }
      final inventaireCopie = await _inventaire(copie);
      if (!mapEquals(inventaire, inventaireCopie)) {
        throw StateError('contenu non conforme après export : '
            '$inventaire attendu, $inventaireCopie obtenu');
      }
    } catch (e) {
      await copie.close();
      await _supprimer(temporaire, avecAnnexes: true);
      _journaliser('migration abandonnée, base en clair conservée : $e');
      rethrow;
    }
    await copie.close();
    // Une fermeture propre repointe le journal WAL dans le fichier et le
    // supprime ; s'il en restait un, il deviendrait orphelin au renommage.
    for (final annexe in annexes(temporaire)) {
      await _supprimer(annexe);
    }

    // 3-5. Bascule.
    await File(chemin).rename(sauvegarde);
    for (final annexe in annexes(chemin)) {
      await _supprimer(annexe);
    }
    await File(temporaire).rename(chemin);
    await _supprimer(sauvegarde, avecAnnexes: true);

    final lignes = inventaire.values.fold<int>(0, (a, b) => a + b);
    _journaliser('base migrée en chiffré : ${inventaire.length} tables, '
        '$lignes lignes, ${DateTime.now().difference(debut).inMilliseconds} ms');
  }

  /// Nombre de lignes par table applicative. Les tables internes de SQLite
  /// (`sqlite_sequence`, index internes) sont écartées : `sqlcipher_export`
  /// les régénère et leur contenu n'est pas comparable.
  static Future<Map<String, int>> _inventaire(Database base) async {
    final tables = await base.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' "
      "AND name NOT LIKE 'sqlite_%'",
    );
    final inventaire = <String, int>{};
    for (final ligne in tables) {
      final nom = ligne['name'].toString();
      inventaire[nom] =
          _premierEntier(await base.rawQuery('SELECT COUNT(*) FROM "$nom"'));
    }
    return inventaire;
  }

  static int _premierEntier(List<Map<String, Object?>> lignes) {
    if (lignes.isEmpty) return 0;
    final valeur = lignes.first.values.first;
    if (valeur is int) return valeur;
    return int.tryParse('$valeur') ?? 0;
  }

  // ---------------------------------------------------------------------------
  // Utilitaires fichiers
  // ---------------------------------------------------------------------------

  static Future<void> _supprimer(String chemin,
      {bool avecAnnexes = false}) async {
    final fichier = File(chemin);
    if (fichier.existsSync()) {
      await fichier.delete();
    }
    if (avecAnnexes) {
      for (final annexe in annexes(chemin)) {
        await _supprimer(annexe);
      }
    }
  }
}
