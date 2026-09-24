import 'dart:io';
import 'package:sqflite/sqflite.dart';
// Même API que `sqflite` (les types viennent tous deux de `sqflite_common`),
// avec un mot de passe à l'ouverture, servi par SQLCipher 4.
import 'package:sqflite_sqlcipher/sqflite.dart' as sqlcipher;
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import '../utils/api_config.dart';
import 'database_encryption.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;
  static String _currentDbName = 'monitrack.db';

  DatabaseService._init();

  static String get currentDbName => _currentDbName;

  // ---------------------------------------------------------------------------
  // Schéma (constat M5)
  // ---------------------------------------------------------------------------

  /// Version courante du schéma local — **constante unique**, partagée par le
  /// web et le mobile. Deux constantes divergentes laissaient auparavant le
  /// web sur un palier plus ancien que le mobile.
  ///
  /// v18 = palier de réconciliation : il remplace, en une seule passe, le
  /// filet de sécurité qui rejouait une cinquantaine d'`ALTER TABLE` à chaque
  /// ouverture (voir [_reconcileSchema]).
  ///
  /// v19 = devise portée par la donnée : `expenses.currency` et
  /// `accounts.currency`. Nullable à dessein — `NULL` signifie « devise
  /// inconnue, antérieure à cette version » et l'affichage retombe sur celle
  /// du profil. Aucun remplissage rétroactif n'est tenté : deviner la devise
  /// d'un montant déjà enregistré reviendrait à inventer de la donnée
  /// financière.
  static const int schemaVersion = 19;

  /// Palier qui rattrape les écarts hérités du filet `onOpen`.
  static const int _reconciliationVersion = 18;

  /// Définition de référence de chaque table. Source unique de vérité : la
  /// création, les paliers de migration, le rattrapage et la vérification
  /// d'intégrité en dérivent tous, ce qui évite qu'une colonne existe dans un
  /// `CREATE TABLE` mais dans aucun `ALTER`.
  ///
  /// Contrainte de forme : aucune contrainte au niveau table (pas de
  /// `PRIMARY KEY (...)` ni de `FOREIGN KEY` en fin de bloc), chaque virgule
  /// sépare donc une définition de colonne — c'est ce qu'exploite
  /// [_columnDefinitions].
  static const Map<String, String> _schema = {
    'accounts': '''
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
        updated_at TEXT,
        currency TEXT
      )
    ''',
    'expenses': '''
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
        dueDate TEXT,
        scheduleStatus TEXT,
        reminderAt TEXT,
        created_at TEXT,
        is_synced INTEGER DEFAULT 0,
        sync_action TEXT DEFAULT 'created',
        updated_at TEXT,
        currency TEXT
      )
    ''',
    'ussd_history': '''
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
    ''',
    'ussd_operations': '''
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
    ''',
    'telecom_operators': '''
      CREATE TABLE telecom_operators (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        userPhoneNumber TEXT,
        country TEXT NOT NULL,
        is_synced INTEGER DEFAULT 0,
        sync_action TEXT DEFAULT 'created',
        updated_at TEXT
      )
    ''',
    // Pool partagé : dépenses / entrées.
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
    // Petit commerce.
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
    // Entreprise.
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

  /// Tables créées à chaque palier de migration.
  static const Map<int, List<String>> _tablesByVersion = {
    2: ['telecom_operators'],
    15: ['categories'],
    16: ['products', 'staff_members'],
    17: ['inbox_notifications'],
  };

  /// Colonnes ajoutées à chaque palier, notées « table.colonne ». La
  /// définition SQL est reprise de [_schema] : un palier ne fait que désigner
  /// la colonne, il ne la redécrit pas.
  static const Map<int, List<String>> _columnsByVersion = {
    3: [
      'accounts.is_shared',
      'accounts.owner_name',
      'accounts.owner_id',
      'expenses.debtorUserId',
      'expenses.creatorId',
      'expenses.creatorName',
    ],
    4: ['expenses.debtStatus'],
    5: [
      'accounts.updated_at',
      'expenses.updated_at',
      'ussd_history.updated_at',
      'ussd_operations.updated_at',
      'telecom_operators.updated_at',
    ],
    6: ['accounts.type'],
    7: ['ussd_operations.is_enabled'],
    8: [
      'expenses.type',
      'expenses.accountId',
      'expenses.debtTag',
      'expenses.isLinkedToCashFlow',
      'expenses.isPlanned',
    ],
    9: [
      'accounts.is_synced',
      'accounts.sync_action',
      'ussd_history.is_synced',
      'ussd_history.sync_action',
    ],
    10: ['ussd_history.status', 'ussd_history.response'],
    11: [
      'accounts.isDefault',
      'accounts.icon',
      'accounts.color',
      'expenses.is_synced',
      'expenses.sync_action',
      'ussd_operations.is_synced',
      'ussd_operations.sync_action',
    ],
    12: [
      'expenses.paymentMethod',
      'expenses.note',
      'expenses.debtorName',
      'expenses.debtorPhoneNumber',
      'expenses.interestRate',
      'expenses.repaymentDuration',
      'expenses.durationUnit',
      'expenses.repaymentFrequency',
      'expenses.installmentAmount',
      'expenses.dueDate',
    ],
    13: ['expenses.scheduleStatus', 'expenses.reminderAt'],
    14: ['expenses.created_at'],
    // Palier 19 — devise de la donnée. Déclarée en fin de `CREATE TABLE` pour
    // que l'ordre physique d'une base migrée (`ALTER TABLE ADD COLUMN` ajoute
    // toujours à la fin) soit identique à celui d'une base neuve.
    19: ['expenses.currency', 'accounts.currency'],
  };

  /// Anomalies de schéma relevées depuis la dernière ouverture : échec d'une
  /// instruction de migration, table ou colonne manquante après migration.
  /// Remplace les `catch (_) {}` muets — les écarts sont désormais visibles
  /// (journal de debug, tests, écran de diagnostic éventuel).
  static final List<String> _schemaIssues = [];

  static List<String> get schemaIssues => List.unmodifiable(_schemaIssues);

  static void _reportIssue(String message) {
    _schemaIssues.add(message);
    debugPrint('[DB] $message');
  }

  /// Définit le nom de base initial avant le premier accès
  static void setDefaultDbName(AppEnvironment env) {
    if (_database == null) {
      _currentDbName = env.sharedDbName;
    }
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB(_currentDbName);
    return _database!;
  }

  /// Bascule vers la base partagée de [env] (environnement actif par défaut).
  /// [name] impose un fichier précis — utilisé par les tests pour isoler
  /// chaque suite sur sa propre base (ex: en mémoire), les suites tournant
  /// en parallèle sur un fichier partagé provoquant des « database is locked ».
  Future<void> switchDatabase({AppEnvironment? env, String? name}) async {
    final targetDb = name ?? (env ?? ApiConfig.env).sharedDbName;
    if (_currentDbName == targetDb && _database != null) {
      return;
    }
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    _currentDbName = targetDb;
    _database = await _initDB(_currentDbName);
  }

  /// Nom de la base SQLite propre à un compte (isolation multicompte) :
  /// `monitrack_<userId>.db` en production, `monitrack_dev_<userId>.db` en dev.
  static String perUserDbName(String userId, AppEnvironment env) {
    final safeId = userId.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    return '${env.dbPrefix}$safeId.db';
  }

  /// Bascule vers la base du compte donné. Si [legacyDbOwner] correspond au
  /// propriétaire de l'ancienne base partagée (pré-multicompte, identifié
  /// lors de la migration de session), celle-ci est copiée vers la base du
  /// compte pour préserver ses données — et uniquement pour lui : les autres
  /// comptes démarrent sur une base vierge. Retourne vrai si la base active
  /// a réellement changé (les données doivent être rechargées).
  Future<bool> switchToUserDatabase(String userId,
      {AppEnvironment? env, String? legacyDbOwner}) async {
    env ??= ApiConfig.env;
    final targetDb = perUserDbName(userId, env);
    if (_currentDbName == targetDb && _database != null) {
      return false;
    }
    final legacyCandidates = {env.sharedDbName, 'monitrack.db'}.toList();

    if (_database != null) {
      await _database!.close();
      _database = null;
    }

    if (!kIsWeb && legacyDbOwner == userId) {
      await _copyLegacyDbFileIfNeeded(legacyCandidates, targetDb);
    }

    _currentDbName = targetDb;
    _database = await _initDB(_currentDbName);
    return true;
  }

  /// Copie la première base partagée existante vers [targetName] si celle-ci
  /// n'existe pas encore (migration one-shot des données pré-multicompte).
  /// Le fichier source est conservé intact.
  ///
  /// Chiffrement (constat E3) : la copie est indifférente à l'état du fichier.
  /// Une base héritée en clair sera migrée à l'ouverture de la base du compte ;
  /// une base déjà chiffrée reste lisible, la clé étant celle de l'appareil et
  /// non celle d'un compte.
  Future<void> _copyLegacyDbFileIfNeeded(
      List<String> legacyNames, String targetName) async {
    try {
      final dir = await getDatabasesPath();
      final target = File(join(dir, targetName));
      if (await target.exists()) return;
      for (final name in legacyNames) {
        if (name == targetName) continue;
        final legacy = File(join(dir, name));
        if (await legacy.exists()) {
          await legacy.copy(target.path);
          return;
        }
      }
    } catch (_) {
      // Migration best-effort : en cas d'échec, la base du compte démarre
      // vide et se repeuple depuis le serveur à la première synchronisation.
    }
  }

  /// Purge toutes les données utilisateur de la base active (déconnexion,
  /// suppression de compte) afin qu'elles ne soient pas visibles depuis un
  /// autre compte sur le même appareil.
  Future<void> clearAllData() async {
    final db = await database;
    await db.transaction(_deleteAllRows);
  }

  /// Purge les tables de test de la base locale de développement
  Future<void> clearDevDatabase() async {
    // Jamais une base de production (partagée ou par compte) ; toute autre
    // base (dev, mémoire, nom imposé par une suite de tests) est purgeable.
    final isProductionDb = _currentDbName == AppEnvironment.production.sharedDbName ||
        (_currentDbName.startsWith(AppEnvironment.production.dbPrefix) &&
            !_currentDbName.startsWith(AppEnvironment.local().dbPrefix));
    if (isProductionDb) return;
    final db = await database;
    await db.transaction(_deleteAllRows);
  }

  /// Vide toutes les tables du schéma. Une table absente (base héritée dont
  /// la création a échoué) est journalisée et ignorée, sans annuler la purge
  /// des autres : c'est une vérification d'existence, pas un `catch` muet.
  Future<void> _deleteAllRows(Transaction txn) async {
    final existing = await _existingTables(txn);
    for (final table in _schema.keys) {
      if (!existing.contains(table)) {
        _reportIssue('purge : table $table absente, ignorée');
        continue;
      }
      await txn.delete(table);
    }
  }

  // ---------------------------------------------------------------------------
  // Chiffrement (constat E3)
  // ---------------------------------------------------------------------------

  /// Couche de chiffrement. Le moteur est injecté ici et nulle part ailleurs :
  /// `database_encryption.dart` ne dépend d'aucun plugin, ce qui le rend
  /// testable avec un double.
  static final ChiffrementBase _chiffrement = ChiffrementBase(
    ouvrirMoteur: (
      String chemin, {
      String? motDePasse,
      int? version,
      OnDatabaseCreateFn? onCreate,
      OnDatabaseVersionChangeFn? onUpgrade,
      OnDatabaseOpenFn? onOpen,
      bool instanceUnique = true,
    }) =>
        sqlcipher.openDatabase(
          chemin,
          password: motDePasse,
          version: version,
          onCreate: onCreate,
          onUpgrade: onUpgrade,
          onOpen: onOpen,
          singleInstance: instanceUnique,
        ),
  );

  /// Vrai lorsque la dernière ouverture a dû repartir d'une base vide (clé de
  /// chiffrement perdue : restauration d'appareil, Keystore réinitialisé).
  /// Les données déjà synchronisées doivent être rechargées par un
  /// `SyncService.pull()` complet ; celles qui n'avaient jamais été poussées
  /// sont définitivement perdues.
  static bool resyncRequiseApresPerteCle = false;

  /// Journal de la couche de chiffrement (migration, perte de clé, repli).
  /// Volontairement distinct de [schemaIssues], réservé aux écarts de schéma.
  static List<String> get encryptionIssues => ChiffrementBase.incidents;

  Future<Database> _initDB(String filePath) async {
    _schemaIssues.clear();
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
      return await databaseFactory.openDatabase(
        filePath,
        options: OpenDatabaseOptions(
          version: schemaVersion,
          onCreate: _createDB,
          onUpgrade: _upgradeDB,
          onOpen: _onOpenDB,
        ),
      );
    } else {
      final path = filePath == inMemoryDatabasePath
          ? inMemoryDatabasePath
          : join(await getDatabasesPath(), filePath);

      // Base chiffrée (constat E3). Une base en mémoire n'a pas de fichier à
      // protéger et sert surtout aux tests : elle reste en clair.
      if (ChiffrementBase.actif && path != inMemoryDatabasePath) {
        final resultat = await _chiffrement.ouvrir(
          path,
          version: schemaVersion,
          onCreate: _createDB,
          onUpgrade: _upgradeDB,
          onOpen: _onOpenDB,
        );
        resyncRequiseApresPerteCle = resultat.resynchronisationRequise;
        return resultat.base;
      }

      return await openDatabase(
        path,
        version: schemaVersion,
        onCreate: _createDB,
        onUpgrade: _upgradeDB,
        onOpen: _onOpenDB,
      );
    }
  }

  /// Base neuve : toutes les tables sont créées au schéma courant, aucun
  /// palier de migration n'est rejoué.
  Future<void> _createDB(Database db, int version) async {
    for (final createSql in _schema.values) {
      await db.execute(createSql);
    }
  }

  /// Migration palier par palier, de [oldVersion] + 1 jusqu'à [newVersion].
  ///
  /// Chaque palier n'applique que ce qui lui appartient, et chaque
  /// instruction est isolée : l'échec de l'une ne fait plus sauter les
  /// suivantes (constat M5 — plusieurs `ALTER` partageaient un même
  /// `try/catch`). Avant chaque `ALTER`, l'existence réelle de la colonne est
  /// vérifiée par `PRAGMA table_info`, au lieu de tenter l'instruction et
  /// d'avaler l'erreur.
  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    for (var version = oldVersion + 1; version <= newVersion; version++) {
      for (final table in _tablesByVersion[version] ?? const <String>[]) {
        await _createTableIfAbsent(db, table);
      }
      for (final ref in _columnsByVersion[version] ?? const <String>[]) {
        final dot = ref.indexOf('.');
        await _addColumn(db, ref.substring(0, dot), ref.substring(dot + 1));
      }
      if (version == 14) {
        await _backfillExpenseCreatedAt(db);
      }
      if (version == _reconciliationVersion) {
        await _reconcileSchema(db);
      }
    }
  }

  /// Palier 14 — la date d'enregistrement des anciennes lignes n'étant pas
  /// connue, on reprend la dernière modification connue.
  Future<void> _backfillExpenseCreatedAt(DatabaseExecutor db) async {
    final columns = await _columnsOf(db, 'expenses');
    if (!columns.contains('created_at') || !columns.contains('updated_at')) {
      _reportIssue('palier 14 : colonnes expenses.created_at/updated_at '
          'absentes, reprise des dates ignorée');
      return;
    }
    await _run(
      db,
      'palier 14 : reprise de expenses.created_at',
      'UPDATE expenses SET created_at = updated_at '
          'WHERE created_at IS NULL AND updated_at IS NOT NULL',
    );
  }

  /// Palier 18 — rattrapage unique de ce que faisait l'ancien filet `onOpen`.
  ///
  /// Trois colonnes n'ont jamais eu de palier dédié
  /// (`ussd_operations.customTemplate`, `ussd_operations.requiredFields`,
  /// `telecom_operators.userPhoneNumber`) : sur les bases anciennes, elles
  /// n'existaient que grâce aux `ALTER` rejoués à chaque ouverture. On les
  /// ajoute ici une bonne fois, en comparant le schéma réel à [_schema], ce
  /// qui permet de retirer le filet sans casser ces bases — y compris celles
  /// déjà en v17, qui passent par ce palier.
  Future<void> _reconcileSchema(DatabaseExecutor db) async {
    for (final entry in _schema.entries) {
      final table = entry.key;
      await _createTableIfAbsent(db, table);
      final actual = await _columnsOf(db, table);
      if (actual.isEmpty) continue;
      for (final definition in _columnDefinitions(entry.value)) {
        final column = _columnName(definition);
        if (actual.contains(column)) continue;
        await _executeAddColumn(db, table, column, definition,
            label: 'palier 18 (rattrapage)');
      }
    }
  }

  /// Crée [table] depuis [_schema] si elle n'existe pas déjà.
  Future<void> _createTableIfAbsent(DatabaseExecutor db, String table) async {
    final createSql = _schema[table];
    if (createSql == null) {
      _reportIssue('table inconnue au schéma : $table');
      return;
    }
    if (await _tableExists(db, table)) return;
    await _run(db, 'création de la table $table', createSql);
  }

  /// Ajoute [column] à [table] si — et seulement si — elle manque réellement.
  /// La définition est reprise de [_schema] ; une seule instruction est
  /// exécutée, et un échec est journalisé au lieu d'être avalé.
  Future<void> _addColumn(
      DatabaseExecutor db, String table, String column) async {
    final createSql = _schema[table];
    if (createSql == null) {
      _reportIssue('table inconnue au schéma : $table (colonne $column)');
      return;
    }
    if (!await _tableExists(db, table)) {
      // La table sera créée au schéma courant par un palier ultérieur ou par
      // le rattrapage : la colonne y figurera déjà.
      _reportIssue('table $table absente : ajout de $column reporté');
      return;
    }
    if ((await _columnsOf(db, table)).contains(column)) return;
    final definition = _columnDefinitions(createSql)
        .where((d) => _columnName(d) == column)
        .firstOrNull;
    if (definition == null) {
      _reportIssue('colonne $table.$column absente du schéma de référence');
      return;
    }
    await _executeAddColumn(db, table, column, definition, label: 'migration');
  }

  Future<void> _executeAddColumn(DatabaseExecutor db, String table,
      String column, String definition,
      {required String label}) async {
    if (!_isAddable(definition)) {
      // SQLite refuse `ADD COLUMN` pour une clé primaire ou un `NOT NULL`
      // sans valeur par défaut. Ces colonnes datent de la création de la
      // table et ne peuvent pas manquer ; si c'est le cas, la table est
      // corrompue et seul un signalement a du sens.
      _reportIssue(
          '$label : $table.$column manquante et non ajoutable ($definition)');
      return;
    }
    await _run(db, '$label : $table.$column',
        'ALTER TABLE $table ADD COLUMN $definition');
  }

  /// Exécute **une** instruction de migration. Un échec est journalisé et
  /// n'interrompt pas les paliers suivants : la base reste exploitable et
  /// l'écart remonte dans [schemaIssues] au lieu de disparaître.
  Future<void> _run(DatabaseExecutor db, String label, String sql) async {
    try {
      await db.execute(sql);
    } catch (e) {
      _reportIssue('échec — $label : $e');
    }
  }

  /// Ouverture : simple vérification d'intégrité. Le filet historique
  /// (une cinquantaine d'`ALTER` rejoués et ignorés à chaque démarrage)
  /// masquait les vrais échecs de migration et coûtait autant d'allers-retours
  /// SQLite ; il est remplacé par 2 requêtes de lecture qui **journalisent**
  /// l'écart sans le corriger.
  Future<void> _onOpenDB(Database db) async {
    final gaps = await describeSchemaGaps(db);
    for (final gap in gaps) {
      _reportIssue('schéma incomplet après migration — $gap');
    }
  }

  /// Écarts entre le schéma réel de [db] et [_schema]. Ne modifie rien :
  /// exposé pour les tests et pour un diagnostic éventuel.
  static Future<List<String>> describeSchemaGaps(DatabaseExecutor db) async {
    final gaps = <String>[];
    final existing = await _existingTables(db);
    for (final entry in _schema.entries) {
      final table = entry.key;
      if (!existing.contains(table)) {
        gaps.add('table manquante : $table');
        continue;
      }
      final actual = await _columnsOf(db, table);
      for (final definition in _columnDefinitions(entry.value)) {
        final column = _columnName(definition);
        if (!actual.contains(column)) {
          gaps.add('colonne manquante : $table.$column');
        }
      }
    }
    return gaps;
  }

  // ---------------------------------------------------------------------------
  // Introspection du schéma
  // ---------------------------------------------------------------------------

  static Future<Set<String>> _existingTables(DatabaseExecutor db) async {
    final rows = await db
        .rawQuery("SELECT name FROM sqlite_master WHERE type = 'table'");
    return rows.map((row) => row['name'].toString()).toSet();
  }

  static Future<bool> _tableExists(DatabaseExecutor db, String table) async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      [table],
    );
    return rows.isNotEmpty;
  }

  /// Colonnes réellement présentes. `PRAGMA table_info` rend une liste vide
  /// pour une table inexistante, sans lever d'erreur.
  static Future<Set<String>> _columnsOf(
      DatabaseExecutor db, String table) async {
    final rows = await db.rawQuery('PRAGMA table_info($table)');
    return rows.map((row) => row['name'].toString()).toSet();
  }

  /// Définitions de colonnes extraites d'un `CREATE TABLE` de [_schema].
  static List<String> _columnDefinitions(String createSql) {
    final start = createSql.indexOf('(');
    final end = createSql.lastIndexOf(')');
    if (start < 0 || end <= start) return const [];
    return createSql
        .substring(start + 1, end)
        .split(',')
        .map((line) => line.trim().replaceAll(RegExp(r'\s+'), ' '))
        .where((line) => line.isNotEmpty)
        .toList();
  }

  static String _columnName(String definition) => definition.split(' ').first;

  /// `ALTER TABLE ... ADD COLUMN` est refusé par SQLite pour une clé primaire
  /// et pour un `NOT NULL` dépourvu de `DEFAULT`.
  static bool _isAddable(String definition) {
    // La clause DEFAULT est cherchée dans le type et les contraintes, jamais
    // dans le nom : `defaultTemplate TEXT NOT NULL` contient « default » dans
    // son nom et passait donc pour une colonne pourvue d'un DEFAULT, donc
    // ajoutable — d'où une exception SQLite brute au lieu de l'écart annoncé.
    final upper = definition.toUpperCase();
    if (upper.contains('PRIMARY KEY')) return false;
    final constraints = upper.substring(_columnName(definition).length);
    if (upper.contains('NOT NULL') &&
        !RegExp(r'DEFAULT').hasMatch(constraints)) {
      return false;
    }
    return true;
  }

  /// Ferme la base active et remet [_database] à `null` (constat M5) : sans
  /// cela, le prochain accès rendait une instance déjà fermée. La base n'est
  /// pas rouverte au passage — l'ancienne implémentation le faisait via le
  /// getter `database`.
  Future<void> close() async {
    final db = _database;
    _database = null;
    if (db != null) {
      await db.close();
    }
  }

  Future<T> runTransaction<T>(Future<T> Function(Transaction txn) action) async {
    final db = await database;
    return await db.transaction(action);
  }
}
