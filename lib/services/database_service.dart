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
          version: 12,
          onCreate: _createDB,
          onUpgrade: _upgradeDB,
          onOpen: _onOpenDB,
        ),
      );
    } else {
      final path = filePath == inMemoryDatabasePath
          ? inMemoryDatabasePath
          : join(await getDatabasesPath(), filePath);

      return await openDatabase(
        path,
        version: 12,
        onCreate: _createDB,
        onUpgrade: _upgradeDB,
        onOpen: _onOpenDB,
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

    // Expense Table
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
        sync_action TEXT DEFAULT 'created',
        updated_at TEXT
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
        is_enabled INTEGER DEFAULT 1,
        is_synced INTEGER DEFAULT 0,
        sync_action TEXT DEFAULT 'created',
        updated_at TEXT
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
        sync_action TEXT DEFAULT 'created',
        updated_at TEXT
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
    if (oldVersion < 4) {
      try {
        await db.execute("ALTER TABLE expenses ADD COLUMN debtStatus TEXT DEFAULT 'pending'");
      } catch (_) {}
    }
    if (oldVersion < 5) {
      try {
        await db.execute("ALTER TABLE accounts ADD COLUMN updated_at TEXT");
        await db.execute("ALTER TABLE expenses ADD COLUMN updated_at TEXT");
        await db.execute("ALTER TABLE ussd_history ADD COLUMN updated_at TEXT");
        await db.execute("ALTER TABLE ussd_operations ADD COLUMN updated_at TEXT");
        await db.execute("ALTER TABLE telecom_operators ADD COLUMN updated_at TEXT");
      } catch (_) {}
    }
    if (oldVersion < 6) {
      try {
        await db.execute("ALTER TABLE accounts ADD COLUMN type TEXT");
      } catch (_) {}
    }
    if (oldVersion < 7) {
      try {
        await db.execute("ALTER TABLE ussd_operations ADD COLUMN is_enabled INTEGER DEFAULT 1");
      } catch (_) {}
    }
    if (oldVersion < 8) {
      try {
        await db.execute("ALTER TABLE expenses ADD COLUMN type TEXT");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE expenses ADD COLUMN accountId TEXT");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE expenses ADD COLUMN debtTag TEXT");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE expenses ADD COLUMN isLinkedToCashFlow INTEGER DEFAULT 1");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE expenses ADD COLUMN isPlanned INTEGER DEFAULT 0");
      } catch (_) {}
    }
    if (oldVersion < 9) {
      try {
        await db.execute("ALTER TABLE accounts ADD COLUMN is_synced INTEGER DEFAULT 0");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE accounts ADD COLUMN sync_action TEXT DEFAULT 'created'");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE ussd_history ADD COLUMN is_synced INTEGER DEFAULT 0");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE ussd_history ADD COLUMN sync_action TEXT DEFAULT 'created'");
      } catch (_) {}
    }
    if (oldVersion < 10) {
      try {
        await db.execute("ALTER TABLE ussd_history ADD COLUMN status TEXT DEFAULT 'success'");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE ussd_history ADD COLUMN response TEXT");
      } catch (_) {}
    }
    if (oldVersion < 11) {
      try {
        await db.execute("ALTER TABLE accounts ADD COLUMN isDefault INTEGER DEFAULT 0");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE accounts ADD COLUMN icon TEXT");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE accounts ADD COLUMN color TEXT");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE expenses ADD COLUMN is_synced INTEGER DEFAULT 0");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE expenses ADD COLUMN sync_action TEXT DEFAULT 'created'");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE ussd_operations ADD COLUMN is_synced INTEGER DEFAULT 0");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE ussd_operations ADD COLUMN sync_action TEXT DEFAULT 'created'");
      } catch (_) {}
    }
    if (oldVersion < 12) {
      try {
        await db.execute("ALTER TABLE expenses ADD COLUMN paymentMethod TEXT NOT NULL DEFAULT ''");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE expenses ADD COLUMN note TEXT");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE expenses ADD COLUMN debtorName TEXT");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE expenses ADD COLUMN debtorPhoneNumber TEXT");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE expenses ADD COLUMN interestRate REAL");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE expenses ADD COLUMN repaymentDuration INTEGER");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE expenses ADD COLUMN durationUnit TEXT");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE expenses ADD COLUMN repaymentFrequency TEXT");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE expenses ADD COLUMN installmentAmount REAL");
      } catch (_) {}
    }
  }

  Future _onOpenDB(Database db) async {
    final columnsToAdd = [
      // Accounts
      "ALTER TABLE accounts ADD COLUMN isDefault INTEGER DEFAULT 0",
      "ALTER TABLE accounts ADD COLUMN icon TEXT",
      "ALTER TABLE accounts ADD COLUMN color TEXT",
      "ALTER TABLE accounts ADD COLUMN type TEXT",
      "ALTER TABLE accounts ADD COLUMN is_shared INTEGER DEFAULT 0",
      "ALTER TABLE accounts ADD COLUMN owner_name TEXT",
      "ALTER TABLE accounts ADD COLUMN owner_id INTEGER",
      "ALTER TABLE accounts ADD COLUMN is_synced INTEGER DEFAULT 0",
      "ALTER TABLE accounts ADD COLUMN sync_action TEXT DEFAULT 'created'",
      "ALTER TABLE accounts ADD COLUMN updated_at TEXT",
      // Expenses
      "ALTER TABLE expenses ADD COLUMN paymentMethod TEXT NOT NULL DEFAULT ''",
      "ALTER TABLE expenses ADD COLUMN type TEXT",
      "ALTER TABLE expenses ADD COLUMN accountId TEXT",
      "ALTER TABLE expenses ADD COLUMN debtTag TEXT",
      "ALTER TABLE expenses ADD COLUMN isLinkedToCashFlow INTEGER DEFAULT 1",
      "ALTER TABLE expenses ADD COLUMN isPlanned INTEGER DEFAULT 0",
      "ALTER TABLE expenses ADD COLUMN note TEXT",
      "ALTER TABLE expenses ADD COLUMN debtorName TEXT",
      "ALTER TABLE expenses ADD COLUMN debtorPhoneNumber TEXT",
      "ALTER TABLE expenses ADD COLUMN debtorUserId TEXT",
      "ALTER TABLE expenses ADD COLUMN creatorId TEXT",
      "ALTER TABLE expenses ADD COLUMN creatorName TEXT",
      "ALTER TABLE expenses ADD COLUMN debtStatus TEXT DEFAULT 'pending'",
      "ALTER TABLE expenses ADD COLUMN interestRate REAL",
      "ALTER TABLE expenses ADD COLUMN repaymentDuration INTEGER",
      "ALTER TABLE expenses ADD COLUMN durationUnit TEXT",
      "ALTER TABLE expenses ADD COLUMN repaymentFrequency TEXT",
      "ALTER TABLE expenses ADD COLUMN installmentAmount REAL",
      "ALTER TABLE expenses ADD COLUMN is_synced INTEGER DEFAULT 0",
      "ALTER TABLE expenses ADD COLUMN sync_action TEXT DEFAULT 'created'",
      "ALTER TABLE expenses ADD COLUMN updated_at TEXT",
      // USSD History
      "ALTER TABLE ussd_history ADD COLUMN status TEXT DEFAULT 'success'",
      "ALTER TABLE ussd_history ADD COLUMN response TEXT",
      "ALTER TABLE ussd_history ADD COLUMN is_synced INTEGER DEFAULT 0",
      "ALTER TABLE ussd_history ADD COLUMN sync_action TEXT DEFAULT 'created'",
      "ALTER TABLE ussd_history ADD COLUMN updated_at TEXT",
      // USSD Operations
      "ALTER TABLE ussd_operations ADD COLUMN customTemplate TEXT",
      "ALTER TABLE ussd_operations ADD COLUMN requiredFields TEXT",
      "ALTER TABLE ussd_operations ADD COLUMN is_enabled INTEGER DEFAULT 1",
      "ALTER TABLE ussd_operations ADD COLUMN is_synced INTEGER DEFAULT 0",
      "ALTER TABLE ussd_operations ADD COLUMN sync_action TEXT DEFAULT 'created'",
      "ALTER TABLE ussd_operations ADD COLUMN updated_at TEXT",
      // Telecom Operators
      "ALTER TABLE telecom_operators ADD COLUMN userPhoneNumber TEXT",
      "ALTER TABLE telecom_operators ADD COLUMN is_synced INTEGER DEFAULT 0",
      "ALTER TABLE telecom_operators ADD COLUMN sync_action TEXT DEFAULT 'created'",
      "ALTER TABLE telecom_operators ADD COLUMN updated_at TEXT",
    ];
    for (final sql in columnsToAdd) {
      try {
        await db.execute(sql);
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
