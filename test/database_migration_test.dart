import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:monitrack/models/expense.dart';
import 'package:monitrack/services/database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('migration v12 → v14 : created_at et les colonnes de programmation sont ajoutées', () async {
    // Base "prod" (monitrack.db) : aucun autre test ne l'utilise, on peut la
    // recréer librement pour simuler une installation de la v1.1 (schéma v12,
    // sans created_at ni dueDate/scheduleStatus/reminderAt).
    final dbPath = p.join(await getDatabasesPath(), 'monitrack.db');
    final file = File(dbPath);
    if (file.existsSync()) file.deleteSync();

    final legacyUpdatedAt = DateTime(2025, 6, 1, 10, 30).toIso8601String();

    final oldDb = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 12,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE accounts (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              balance REAL NOT NULL DEFAULT 0.0,
              type TEXT,
              icon TEXT,
              color TEXT,
              isDefault INTEGER DEFAULT 0,
              is_shared INTEGER DEFAULT 0,
              owner_name TEXT,
              owner_id INTEGER,
              is_synced INTEGER DEFAULT 0,
              sync_action TEXT DEFAULT 'created',
              updated_at TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE expenses (
              id TEXT PRIMARY KEY,
              title TEXT NOT NULL,
              amount REAL NOT NULL,
              category TEXT NOT NULL,
              date TEXT NOT NULL,
              paymentMethod TEXT NOT NULL DEFAULT '',
              type TEXT,
              accountId TEXT,
              debtTag TEXT,
              isLinkedToCashFlow INTEGER DEFAULT 1,
              isPlanned INTEGER DEFAULT 0,
              note TEXT,
              debtorName TEXT,
              debtorPhoneNumber TEXT,
              debtorUserId TEXT,
              creatorId TEXT,
              creatorName TEXT,
              debtStatus TEXT DEFAULT 'pending',
              interestRate REAL,
              repaymentDuration INTEGER,
              durationUnit TEXT,
              repaymentFrequency TEXT,
              installmentAmount REAL,
              is_synced INTEGER DEFAULT 0,
              sync_action TEXT DEFAULT 'created',
              updated_at TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE ussd_history (
              id TEXT PRIMARY KEY,
              operationName TEXT NOT NULL,
              providerName TEXT NOT NULL,
              ussdCode TEXT NOT NULL,
              date TEXT NOT NULL,
              status TEXT DEFAULT 'success',
              response TEXT,
              is_synced INTEGER DEFAULT 0,
              sync_action TEXT DEFAULT 'created',
              updated_at TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE ussd_operations (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              provider TEXT NOT NULL,
              category TEXT NOT NULL,
              defaultTemplate TEXT NOT NULL,
              customTemplate TEXT,
              requiredFields TEXT,
              is_enabled INTEGER DEFAULT 1,
              is_synced INTEGER DEFAULT 0,
              sync_action TEXT DEFAULT 'created',
              updated_at TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE telecom_operators (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              userPhoneNumber TEXT,
              country TEXT NOT NULL,
              is_synced INTEGER DEFAULT 0,
              sync_action TEXT DEFAULT 'created',
              updated_at TEXT
            )
          ''');
        },
      ),
    );
    await oldDb.insert('expenses', {
      'id': 'legacy-with-updated',
      'title': 'Ancienne dépense',
      'amount': 5000.0,
      'category': 'Autre',
      'date': DateTime(2025, 1, 10).toIso8601String(),
      'paymentMethod': '',
      'type': 'expense',
      'isLinkedToCashFlow': 1,
      'isPlanned': 0,
      'debtStatus': 'pending',
      'is_synced': 0,
      'sync_action': 'created',
      'updated_at': legacyUpdatedAt,
    });
    await oldDb.insert('expenses', {
      'id': 'legacy-no-updated',
      'title': 'Ancienne dépense sans date de modif',
      'amount': 1000.0,
      'category': 'Autre',
      'date': DateTime(2024, 12, 1).toIso8601String(),
      'paymentMethod': '',
      'type': 'expense',
      'isLinkedToCashFlow': 1,
      'isPlanned': 0,
      'debtStatus': 'pending',
      'is_synced': 0,
      'sync_action': 'created',
    });
    await oldDb.close();

    // Réouverture par le service courant (version 14) : onUpgrade 12 → 14 puis onOpen.
    final db = await DatabaseService.instance.database;

    final columnNames = (await db.rawQuery('PRAGMA table_info(expenses)'))
        .map((c) => c['name'] as String)
        .toSet();
    for (final column in [
      'created_at',
      'updated_at',
      'dueDate',
      'scheduleStatus',
      'reminderAt',
    ]) {
      expect(columnNames, contains(column), reason: 'colonne manquante : $column');
    }

    // Backfill : la date d'enregistrement reprend updated_at quand elle existe.
    final legacy = await db.query('expenses',
        where: 'id = ?', whereArgs: ['legacy-with-updated']);
    expect(legacy.single['created_at'], legacyUpdatedAt);

    final legacyNoUpdated = await db.query('expenses',
        where: 'id = ?', whereArgs: ['legacy-no-updated']);
    expect(legacyNoUpdated.single['created_at'], isNull);

    // L'INSERT complet (avec created_at/updated_at) ne doit plus échouer :
    // c'est exactement la requête qui plantait avant la migration.
    await db.insert('expenses', Expense(
      id: 'new-row',
      title: 'Nouvelle dépense',
      amount: 2500.0,
      category: 'Autre',
      date: DateTime(2026, 8, 22),
    ).toDbMap());
  });

  // ---------------------------------------------------------------------------
  // Paliers de migration vers la version courante du schéma (constat M5)
  // ---------------------------------------------------------------------------

  group('paliers de migration vers la version courante', () {
    tearDown(() async {
      // Le service est un singleton : sans fermeture, la base d'un cas de test
      // resterait active pour le suivant.
      await DatabaseService.instance.close();
    });

    test('migration v17 → v18 : les trois colonnes orphelines sont rattrapées',
        () async {
      const fichier = 'mig_v17_vers_v18.db';
      await _creerBaseHeritee(fichier, 17, _schemaHeriteV17(),
          amorcer: (db) async {
        await db.insert('ussd_operations', {
          'id': 'op-1',
          'name': 'Transfert',
          'provider': 'MTN',
          'category': 'transfer',
          'defaultTemplate': '*126*1*{montant}#',
          'is_enabled': 1,
          'is_synced': 1,
          'sync_action': 'updated',
          'updated_at': '2025-05-01T08:00:00.000',
        });
        await db.insert('telecom_operators', {
          'id': 'op-mtn',
          'name': 'MTN',
          'country': 'Cameroun',
          'is_synced': 1,
          'sync_action': 'updated',
          'updated_at': '2025-05-01T08:00:00.000',
        });
      });

      final db = await _ouvrirParLeService(fichier);

      expect(await _versionUtilisateur(db), DatabaseService.schemaVersion,
          reason: 'la base doit être estampillée à la version courante');

      // Les trois colonnes que seul l'ancien filet `onOpen` posait.
      expect(await _colonnes(db, 'ussd_operations'),
          containsAll(['customTemplate', 'requiredFields']));
      expect(
          await _colonnes(db, 'telecom_operators'), contains('userPhoneNumber'));

      // `ALTER TABLE ADD COLUMN` ajoute toujours en fin de table : leur
      // position prouve qu'elles ont bien été rattrapées sur la table
      // existante, et non obtenues par une recréation de la table.
      expect((await _ordreColonnes(db, 'ussd_operations')).sublist(9),
          ['customTemplate', 'requiredFields']);
      expect((await _ordreColonnes(db, 'telecom_operators')).last,
          'userPhoneNumber');

      // Les données héritées survivent, les colonnes rattrapées valant NULL.
      final operation = await db
          .query('ussd_operations', where: 'id = ?', whereArgs: ['op-1']);
      expect(operation.single['defaultTemplate'], '*126*1*{montant}#');
      expect(operation.single['customTemplate'], isNull);
      expect(operation.single['requiredFields'], isNull);
      final operateur = await db
          .query('telecom_operators', where: 'id = ?', whereArgs: ['op-mtn']);
      expect(operateur.single['userPhoneNumber'], isNull);

      // Écriture utilisant les colonnes rattrapées : c'est l'INSERT qui
      // échouait sur une base v17 une fois le filet retiré.
      await db.insert('ussd_operations', {
        'id': 'op-2',
        'name': 'Retrait',
        'provider': 'Orange',
        'category': 'withdraw',
        'defaultTemplate': '*150*1#',
        'customTemplate': '*150*1*{montant}#',
        'requiredFields': '["montant"]',
        'is_enabled': 1,
        'is_synced': 0,
        'sync_action': 'created',
        'updated_at': '2026-01-01T00:00:00.000',
      });
      final ajoutee = await db
          .query('ussd_operations', where: 'id = ?', whereArgs: ['op-2']);
      expect(ajoutee.single['customTemplate'], '*150*1*{montant}#');

      expect(await DatabaseService.describeSchemaGaps(db), isEmpty);
      expect(DatabaseService.schemaIssues, isEmpty,
          reason: 'une migration nominale ne doit journaliser aucun écart');
    });

    test(
        'migration v14 → v18 : les tables des paliers 15 à 17 sont créées et '
        'les colonnes orphelines rattrapées', () async {
      const fichier = 'mig_v14_vers_v18.db';
      await _creerBaseHeritee(fichier, 14, _schemaHeriteV14(),
          amorcer: (db) async {
        await db.insert('expenses', _depenseHeritee('dep-v14'));
      });

      final db = await _ouvrirParLeService(fichier);

      expect(await _versionUtilisateur(db), DatabaseService.schemaVersion);
      expect(
        await _tables(db),
        containsAll([
          'categories', // palier 15
          'products', // palier 16
          'staff_members', // palier 16
          'inbox_notifications', // palier 17
        ]),
      );

      // Une table créée par un palier l'est au schéma courant complet, dans
      // l'ordre de référence (aucun `ALTER` n'a eu à la compléter ensuite).
      expect(await _ordreColonnes(db, 'inbox_notifications'),
          ['id', 'type', 'data', 'read_at', 'created_at', 'updated_at']);
      expect(await _ordreColonnes(db, 'categories'),
          ['id', 'name', 'type', 'is_synced', 'sync_action', 'updated_at']);

      expect(await _colonnes(db, 'ussd_operations'),
          containsAll(['customTemplate', 'requiredFields']));
      expect(
          await _colonnes(db, 'telecom_operators'), contains('userPhoneNumber'));

      // La dépense héritée n'est pas perdue en route.
      expect(
          (await db.query('expenses', where: 'id = ?', whereArgs: ['dep-v14']))
              .single['title'],
          'Dépense v14');

      expect(await DatabaseService.describeSchemaGaps(db), isEmpty);
      expect(DatabaseService.schemaIssues, isEmpty);
    });

    test('migration v12 → v18 : paliers 13, 14 et 18 enchaînés sur la même base',
        () async {
      const fichier = 'mig_v12_vers_v18.db';
      const modifieeLe = '2025-03-04T12:00:00.000';
      await _creerBaseHeritee(fichier, 12, _schemaHeriteV12(),
          amorcer: (db) async {
        await db.insert('expenses', {
          ..._depenseHeritee('dep-datee'),
          'title': 'Dépense datée',
          'updated_at': modifieeLe,
        });
        await db.insert('expenses', _depenseHeritee('dep-sans-date'));
      });

      final db = await _ouvrirParLeService(fichier);

      expect(await _versionUtilisateur(db), DatabaseService.schemaVersion);

      // Paliers 13 et 14 : colonnes ajoutées dans l'ordre des paliers, en fin
      // de table.
      final ordreDepenses = await _ordreColonnes(db, 'expenses');
      expect(ordreDepenses.sublist(ordreDepenses.length - 4),
          ['scheduleStatus', 'reminderAt', 'created_at', 'currency']);

      // Palier 14 : reprise de created_at depuis updated_at, et uniquement là
      // où updated_at existe.
      expect(
          (await db.query('expenses', where: 'id = ?', whereArgs: ['dep-datee']))
              .single['created_at'],
          modifieeLe);
      expect(
          (await db.query('expenses',
                  where: 'id = ?', whereArgs: ['dep-sans-date']))
              .single['created_at'],
          isNull);

      // Palier 18.
      expect(await _colonnes(db, 'ussd_operations'),
          containsAll(['customTemplate', 'requiredFields']));
      expect(
          await _colonnes(db, 'telecom_operators'), contains('userPhoneNumber'));

      expect(await DatabaseService.describeSchemaGaps(db), isEmpty);
      expect(DatabaseService.schemaIssues, isEmpty);
    });

    test(
        'base neuve : aucun palier rejoué, schéma complet dans l’ordre de '
        'référence', () async {
      const fichier = 'mig_base_neuve.db';
      await _supprimerFichier(fichier);

      final db = await _ouvrirParLeService(fichier);

      expect(await _versionUtilisateur(db), DatabaseService.schemaVersion);
      expect(
        await _tables(db),
        containsAll([
          'accounts',
          'expenses',
          'ussd_history',
          'ussd_operations',
          'telecom_operators',
          'categories',
          'products',
          'staff_members',
          'inbox_notifications',
        ]),
      );

      // Sur une base créée d'un bloc, chaque colonne est à sa place déclarée.
      // Un palier rejoué (ALTER) l'aurait repoussée en fin de table : cette
      // égalité d'ordre est la preuve qu'aucun n'a tourné.
      expect(await _ordreColonnes(db, 'ussd_operations'), [
        'id',
        'name',
        'provider',
        'category',
        'defaultTemplate',
        'customTemplate',
        'requiredFields',
        'is_enabled',
        'is_synced',
        'sync_action',
        'updated_at',
      ]);
      expect(await _ordreColonnes(db, 'telecom_operators'), [
        'id',
        'name',
        'userPhoneNumber',
        'country',
        'is_synced',
        'sync_action',
        'updated_at',
      ]);
      expect((await _ordreColonnes(db, 'expenses')).sublist(24), [
        'scheduleStatus',
        'reminderAt',
        'created_at',
        'is_synced',
        'sync_action',
        'updated_at',
        'currency',
      ]);

      expect(await DatabaseService.describeSchemaGaps(db), isEmpty);
      expect(DatabaseService.schemaIssues, isEmpty);
    });

    test('idempotence : une seconde ouverture ne modifie plus le schéma',
        () async {
      const fichier = 'mig_idempotence.db';
      await _creerBaseHeritee(fichier, 17, _schemaHeriteV17());

      final premiere = await _ouvrirParLeService(fichier);
      final empreinteApresMigration = await _empreinteSchema(premiere);
      // La migration a bien touché au schéma la première fois.
      expect(
          empreinteApresMigration['ussd_operations'], contains('customTemplate'));
      await DatabaseService.instance.close();

      final seconde = await _ouvrirParLeService(fichier);
      final empreinteSecondeOuverture = await _empreinteSchema(seconde);

      // `ALTER TABLE ADD COLUMN` réécrit le `CREATE TABLE` mémorisé dans
      // sqlite_master : une empreinte inchangée signifie qu'aucun ALTER n'a
      // été exécuté à la seconde ouverture.
      expect(empreinteSecondeOuverture, empreinteApresMigration);
      expect(await _versionUtilisateur(seconde), DatabaseService.schemaVersion);
      expect(await DatabaseService.describeSchemaGaps(seconde), isEmpty);
      expect(DatabaseService.schemaIssues, isEmpty);

      // Et une troisième, pour écarter un état intermédiaire.
      await DatabaseService.instance.close();
      final troisieme = await _ouvrirParLeService(fichier);
      expect(await _empreinteSchema(troisieme), empreinteApresMigration);
      expect(DatabaseService.schemaIssues, isEmpty);
    });

    test('table absente sur une base annoncée v17 : le palier 18 la recrée',
        () async {
      const fichier = 'mig_table_absente.db';
      final schema = Map<String, String>.from(_schemaHeriteV17())
        ..remove('inbox_notifications')
        ..remove('products');
      await _creerBaseHeritee(fichier, 17, schema);

      final db = await _ouvrirParLeService(fichier);

      expect(await _tables(db), containsAll(['inbox_notifications', 'products']));
      expect(await _ordreColonnes(db, 'products'), [
        'id',
        'name',
        'price',
        'photo_path',
        'description',
        'created_at',
        'updated_at',
        'is_synced',
        'sync_action',
      ]);
      expect(await DatabaseService.describeSchemaGaps(db), isEmpty);
      expect(DatabaseService.schemaIssues, isEmpty,
          reason: 'une table recréée par le rattrapage est un cas prévu, '
              'pas une anomalie');
    });

    test(
        'colonne NOT NULL non ajoutable : l’écart est journalisé et les autres '
        'rattrapages se poursuivent', () async {
      const fichier = 'mig_colonne_non_ajoutable.db';
      final schema = Map<String, String>.from(_schemaHeriteV17());
      // `name TEXT NOT NULL` sans valeur par défaut : SQLite refuse de
      // l'ajouter par `ALTER TABLE`. Le service doit le signaler, pas le
      // taire, et enchaîner sur les colonnes et tables suivantes.
      schema['telecom_operators'] = '''
        CREATE TABLE telecom_operators (
          id TEXT PRIMARY KEY,
          country TEXT NOT NULL,
          is_synced INTEGER DEFAULT 0,
          sync_action TEXT DEFAULT 'created',
          updated_at TEXT
        )
      ''';
      await _creerBaseHeritee(fichier, 17, schema);

      final db = await _ouvrirParLeService(fichier);

      final anomalies = DatabaseService.schemaIssues;
      expect(
        anomalies,
        contains(allOf(
          contains('telecom_operators.name'),
          contains('non ajoutable'),
        )),
        reason: 'le refus de SQLite doit être journalisé, pas avalé',
      );
      expect(
        anomalies,
        contains(allOf(
          contains('schéma incomplet après migration'),
          contains('telecom_operators.name'),
        )),
        reason: 'la vérification d’ouverture doit confirmer l’écart',
      );
      expect(await DatabaseService.describeSchemaGaps(db),
          ['colonne manquante : telecom_operators.name']);

      // La colonne ajoutable de la même table est tout de même posée…
      expect(
          await _colonnes(db, 'telecom_operators'), contains('userPhoneNumber'));
      // …et le rattrapage des tables suivantes n'a pas été interrompu.
      expect(await _colonnes(db, 'ussd_operations'),
          containsAll(['customTemplate', 'requiredFields']));
    });

    test(
        'ALTER refusé par SQLite : l’échec remonte dans schemaIssues au lieu '
        'd’être avalé', () async {
      const fichier = 'mig_alter_refuse.db';
      final schema = Map<String, String>.from(_schemaHeriteV17());
      // `defaultTemplate TEXT NOT NULL` est jugé ajoutable par le service
      // (voir le rapport : la détection cherche la sous-chaîne « DEFAULT »,
      // que le *nom* de la colonne contient déjà). L'`ALTER` est donc tenté,
      // et SQLite le refuse dès que la table n'est pas vide.
      schema['ussd_operations'] = '''
        CREATE TABLE ussd_operations (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          provider TEXT NOT NULL,
          category TEXT NOT NULL,
          is_enabled INTEGER DEFAULT 1,
          is_synced INTEGER DEFAULT 0,
          sync_action TEXT DEFAULT 'created',
          updated_at TEXT
        )
      ''';
      await _creerBaseHeritee(fichier, 17, schema, amorcer: (db) async {
        await db.insert('ussd_operations', {
          'id': 'op-heritee',
          'name': 'Solde',
          'provider': 'MTN',
          'category': 'balance',
          'is_enabled': 1,
          'is_synced': 1,
          'sync_action': 'updated',
          'updated_at': '2025-05-01T08:00:00.000',
        });
      });

      final db = await _ouvrirParLeService(fichier);

      expect(
        DatabaseService.schemaIssues,
        contains(allOf(
          contains('palier 18 (rattrapage)'),
          contains('ussd_operations.defaultTemplate'),
          contains('non ajoutable'),
        )),
        reason: 'une colonne NOT NULL sans DEFAULT doit être écartée avant '
            "l'ALTER, avec un message explicite plutôt qu'une exception SQL",
      );
      expect(await DatabaseService.describeSchemaGaps(db),
          ['colonne manquante : ussd_operations.defaultTemplate']);

      // L'instruction suivante du même palier n'a pas été perdue avec celle
      // qui a échoué : c'est précisément ce que l'isolation par instruction
      // doit garantir.
      expect(await _colonnes(db, 'ussd_operations'),
          containsAll(['customTemplate', 'requiredFields']));
      expect(
          await _colonnes(db, 'telecom_operators'), contains('userPhoneNumber'));
      // La ligne héritée est intacte.
      expect(
          (await db.query('ussd_operations',
                  where: 'id = ?', whereArgs: ['op-heritee']))
              .single['name'],
          'Solde');
    });
  });
}
// -----------------------------------------------------------------------------
// Outils de test
// -----------------------------------------------------------------------------

/// Crée une base au schéma d'une version antérieure, l'amorce éventuellement
/// puis la referme, pour que le service la reprenne par `onUpgrade`.
Future<void> _creerBaseHeritee(
  String fichier,
  int version,
  Map<String, String> schema, {
  Future<void> Function(Database db)? amorcer,
}) async {
  final chemin = await _supprimerFichier(fichier);
  final db = await databaseFactory.openDatabase(
    chemin,
    options: OpenDatabaseOptions(
      version: version,
      onCreate: (db, _) async {
        for (final sql in schema.values) {
          await db.execute(sql);
        }
      },
    ),
  );
  if (amorcer != null) await amorcer(db);
  await db.close();
}

Future<String> _supprimerFichier(String fichier) async {
  final chemin = p.join(await getDatabasesPath(), fichier);
  final f = File(chemin);
  if (f.existsSync()) f.deleteSync();
  return chemin;
}

/// Ouvre [fichier] par le service, donc en passant par `onUpgrade` puis
/// `onOpen`.
Future<Database> _ouvrirParLeService(String fichier) async {
  await DatabaseService.instance.switchDatabase(name: fichier);
  return DatabaseService.instance.database;
}

Future<List<String>> _ordreColonnes(DatabaseExecutor db, String table) async =>
    (await db.rawQuery('PRAGMA table_info($table)'))
        .map((c) => c['name'] as String)
        .toList();

Future<Set<String>> _colonnes(DatabaseExecutor db, String table) async =>
    (await _ordreColonnes(db, table)).toSet();

Future<Set<String>> _tables(DatabaseExecutor db) async =>
    (await db.rawQuery("SELECT name FROM sqlite_master WHERE type = 'table'"))
        .map((r) => r['name'] as String)
        .toSet();

/// Le `CREATE TABLE` mémorisé par SQLite pour chaque table. Toute exécution
/// d'un `ALTER TABLE ADD COLUMN` le réécrit : comparer deux empreintes revient
/// à vérifier qu'aucune instruction de migration n'a tourné.
Future<Map<String, String?>> _empreinteSchema(DatabaseExecutor db) async {
  final rows = await db.rawQuery(
      "SELECT name, sql FROM sqlite_master WHERE type = 'table' ORDER BY name");
  return {
    for (final row in rows) row['name'] as String: row['sql'] as String?,
  };
}

Future<int> _versionUtilisateur(DatabaseExecutor db) async =>
    (await db.rawQuery('PRAGMA user_version')).first.values.first as int;

Map<String, dynamic> _depenseHeritee(String id) => {
      'id': id,
      'title': 'Dépense v14',
      'amount': 1500.0,
      'category': 'Autre',
      'date': '2025-02-02T00:00:00.000',
      'paymentMethod': '',
      'type': 'expense',
      'isLinkedToCashFlow': 1,
      'isPlanned': 0,
      'debtStatus': 'pending',
      'is_synced': 0,
      'sync_action': 'created',
    };

// --- Schémas hérités --------------------------------------------------------
//
// Reproduits colonne par colonne plutôt que dérivés du service : c'est la
// seule façon de vérifier qu'un palier ajoute bien ce qu'il annonce. Les trois
// colonnes sans palier dédié (`ussd_operations.customTemplate`,
// `ussd_operations.requiredFields`, `telecom_operators.userPhoneNumber`) sont
// volontairement absentes : sur une base réelle, elles n'existaient que grâce
// au filet `onOpen` supprimé.

const String _creationComptes = '''
  CREATE TABLE accounts (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    balance REAL NOT NULL DEFAULT 0.0,
    type TEXT,
    icon TEXT,
    color TEXT,
    isDefault INTEGER DEFAULT 0,
    is_shared INTEGER DEFAULT 0,
    owner_name TEXT,
    owner_id INTEGER,
    is_synced INTEGER DEFAULT 0,
    sync_action TEXT DEFAULT 'created',
    updated_at TEXT
  )
''';

const String _creationHistoriqueUssd = '''
  CREATE TABLE ussd_history (
    id TEXT PRIMARY KEY,
    operationName TEXT NOT NULL,
    providerName TEXT NOT NULL,
    ussdCode TEXT NOT NULL,
    date TEXT NOT NULL,
    status TEXT DEFAULT 'success',
    response TEXT,
    is_synced INTEGER DEFAULT 0,
    sync_action TEXT DEFAULT 'created',
    updated_at TEXT
  )
''';

/// Sans `customTemplate` ni `requiredFields`.
const String _creationOperationsUssdTronquee = '''
  CREATE TABLE ussd_operations (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    provider TEXT NOT NULL,
    category TEXT NOT NULL,
    defaultTemplate TEXT NOT NULL,
    is_enabled INTEGER DEFAULT 1,
    is_synced INTEGER DEFAULT 0,
    sync_action TEXT DEFAULT 'created',
    updated_at TEXT
  )
''';

/// Sans `userPhoneNumber`.
const String _creationOperateursTronquee = '''
  CREATE TABLE telecom_operators (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    country TEXT NOT NULL,
    is_synced INTEGER DEFAULT 0,
    sync_action TEXT DEFAULT 'created',
    updated_at TEXT
  )
''';

String _creationDepenses({required bool avecPaliers13Et14}) => '''
  CREATE TABLE expenses (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    amount REAL NOT NULL,
    category TEXT NOT NULL,
    date TEXT NOT NULL,
    paymentMethod TEXT NOT NULL DEFAULT '',
    type TEXT,
    accountId TEXT,
    debtTag TEXT,
    isLinkedToCashFlow INTEGER DEFAULT 1,
    isPlanned INTEGER DEFAULT 0,
    note TEXT,
    debtorName TEXT,
    debtorPhoneNumber TEXT,
    debtorUserId TEXT,
    creatorId TEXT,
    creatorName TEXT,
    debtStatus TEXT DEFAULT 'pending',
    interestRate REAL,
    repaymentDuration INTEGER,
    durationUnit TEXT,
    repaymentFrequency TEXT,
    installmentAmount REAL,
    dueDate TEXT,${avecPaliers13Et14 ? '''
    scheduleStatus TEXT,
    reminderAt TEXT,
    created_at TEXT,''' : ''}
    is_synced INTEGER DEFAULT 0,
    sync_action TEXT DEFAULT 'created',
    updated_at TEXT
  )
''';

Map<String, String> _schemaHeriteV12() => {
      'accounts': _creationComptes,
      'expenses': _creationDepenses(avecPaliers13Et14: false),
      'ussd_history': _creationHistoriqueUssd,
      'ussd_operations': _creationOperationsUssdTronquee,
      'telecom_operators': _creationOperateursTronquee,
    };

Map<String, String> _schemaHeriteV14() => {
      'accounts': _creationComptes,
      'expenses': _creationDepenses(avecPaliers13Et14: true),
      'ussd_history': _creationHistoriqueUssd,
      'ussd_operations': _creationOperationsUssdTronquee,
      'telecom_operators': _creationOperateursTronquee,
    };

Map<String, String> _schemaHeriteV17() => {
      ..._schemaHeriteV14(),
      'categories': '''
        CREATE TABLE categories (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          type TEXT NOT NULL,
          is_synced INTEGER DEFAULT 0,
          sync_action TEXT DEFAULT 'created',
          updated_at TEXT
        )
      ''',
      'products': '''
        CREATE TABLE products (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          price REAL NOT NULL,
          photo_path TEXT,
          description TEXT,
          created_at TEXT,
          updated_at TEXT,
          is_synced INTEGER DEFAULT 0,
          sync_action TEXT DEFAULT 'created'
        )
      ''',
      'staff_members': '''
        CREATE TABLE staff_members (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          role TEXT,
          phone_number TEXT,
          email TEXT,
          salary REAL,
          created_at TEXT,
          updated_at TEXT,
          is_synced INTEGER DEFAULT 0,
          sync_action TEXT DEFAULT 'created'
        )
      ''',
      'inbox_notifications': '''
        CREATE TABLE inbox_notifications (
          id TEXT PRIMARY KEY,
          type TEXT,
          data TEXT NOT NULL,
          read_at TEXT,
          created_at TEXT,
          updated_at TEXT
        )
      ''',
    };
