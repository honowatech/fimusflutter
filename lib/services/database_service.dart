import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('monitrack.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
      return await databaseFactory.openDatabase(
        filePath,
        options: OpenDatabaseOptions(
          version: 3,
          onCreate: _createDB,
          onUpgrade: _upgradeDB,
        ),
      );
    } else {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, filePath);

      return await openDatabase(
        path,
        version: 3,
        onCreate: _createDB,
        onUpgrade: _upgradeDB,
      );
    }
  }

  Future _createDB(Database db, int version) async {
    // Accounts Table
    await db.execute('''
      CREATE TABLE accounts (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        balance REAL NOT NULL DEFAULT 0.0,
        icon TEXT,
        color TEXT,
        is_shared INTEGER DEFAULT 0,
        owner_name TEXT,
        owner_id INTEGER,
        is_synced INTEGER DEFAULT 0,
        sync_action TEXT DEFAULT 'created'
      )
    ''');

    // Expenses Table
    await db.execute('''
      CREATE TABLE expenses (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        category TEXT NOT NULL,
        date TEXT NOT NULL,
        note TEXT,
        type TEXT NOT NULL,
        accountId TEXT,
        debtTag TEXT,
        debtorUserId TEXT,
        isLinkedToCashFlow INTEGER DEFAULT 1,
        isPlanned INTEGER DEFAULT 0,
        interestRate REAL,
        repaymentDuration INTEGER,
        durationUnit TEXT,
        repaymentFrequency TEXT,
        installmentAmount REAL,
        creatorId TEXT,
        creatorName TEXT,
        is_synced INTEGER DEFAULT 0,
        sync_action TEXT DEFAULT 'created'
      )
    ''');

    // USSD History Table
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
        sync_action TEXT DEFAULT 'created'
      )
    ''');

    // USSD Operations Table
    await db.execute('''
      CREATE TABLE ussd_operations (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        provider TEXT NOT NULL,
        category TEXT NOT NULL,
        defaultTemplate TEXT NOT NULL,
        customTemplate TEXT,
        requiredFields TEXT,
        is_synced INTEGER DEFAULT 0,
        sync_action TEXT DEFAULT 'created'
      )
    ''');

    // Telecom Operators Table
    await db.execute('''
      CREATE TABLE telecom_operators (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        userPhoneNumber TEXT,
        country TEXT NOT NULL,
        is_synced INTEGER DEFAULT 0,
        sync_action TEXT DEFAULT 'created'
      )
    ''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE telecom_operators (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          userPhoneNumber TEXT,
          country TEXT NOT NULL,
          is_synced INTEGER DEFAULT 0,
          sync_action TEXT DEFAULT 'created'
        )
      ''');
    }
    if (oldVersion < 3) {
      try {
        await db.execute("ALTER TABLE accounts ADD COLUMN is_shared INTEGER DEFAULT 0");
        await db.execute("ALTER TABLE accounts ADD COLUMN owner_name TEXT");
        await db.execute("ALTER TABLE accounts ADD COLUMN owner_id INTEGER");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE expenses ADD COLUMN debtorUserId TEXT");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE expenses ADD COLUMN creatorId TEXT");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE expenses ADD COLUMN creatorName TEXT");
      } catch (_) {}
    }
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }

  Future<T> runTransaction<T>(Future<T> Function(Transaction txn) action) async {
    final db = await database;
    return await db.transaction(action);
  }
}
