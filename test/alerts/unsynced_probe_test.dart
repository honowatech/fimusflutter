import 'package:flutter_test/flutter_test.dart';
import 'package:monitrack/services/alerts/alert_models.dart';
import 'package:monitrack/services/alerts/unsynced_probe.dart';
import 'package:monitrack/services/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Sonde SQLite des données en attente d'envoi.
///
/// Les fonctions pures ([UnsyncedProbe.timestampExpression],
/// [UnsyncedProbe.snapshotFromRow]) sont couvertes sans base ; la requête
/// réelle est vérifiée sur une base **en mémoire** (`inMemoryDatabasePath`),
/// jamais sur `monitrack.db`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('timestampExpression', () {
    test('rend la colonne telle quelle quand il n y en a qu une', () {
      expect(UnsyncedProbe.timestampExpression(['updated_at']), 'updated_at');
    });

    test('compose un COALESCE quand plusieurs colonnes sont disponibles', () {
      expect(
        UnsyncedProbe.timestampExpression(['updated_at', 'created_at']),
        'COALESCE(updated_at, created_at)',
      );
    });

    test('respecte l ordre de repli déclaré', () {
      expect(
        UnsyncedProbe.timestampExpression(['created_at', 'updated_at']),
        'COALESCE(created_at, updated_at)',
      );
    });

    test('chaque table surveillée produit une expression exploitable', () {
      for (final entry in UnsyncedProbe.trackedTables.entries) {
        final expression = UnsyncedProbe.timestampExpression(entry.value);
        expect(entry.value, isNotEmpty, reason: entry.key);
        expect(expression, isNotEmpty, reason: entry.key);
        expect(expression, isNot(contains(';')), reason: entry.key);
      }
    });
  });

  group('trackedTables', () {
    test('exclut les tables dont les lignes restent locales pour toujours',
        () {
      expect(UnsyncedProbe.trackedTables.keys, isNot(contains('categories')));
      expect(
        UnsyncedProbe.trackedTables.keys,
        isNot(contains('ussd_operations')),
      );
      expect(
        UnsyncedProbe.trackedTables.keys,
        isNot(contains('telecom_operators')),
      );
    });

    test('couvre les tables de saisie utilisateur', () {
      expect(
        UnsyncedProbe.trackedTables.keys,
        containsAll(['expenses', 'accounts', 'ussd_history']),
      );
    });
  });

  group('snapshotFromRow', () {
    test('rend une photo vide quand le compteur est nul', () {
      final photo = UnsyncedProbe.snapshotFromRow(
        const {'pending': 0, 'oldest': '2026-09-01T08:00:00.000'},
      );
      expect(photo, const UnsyncedSnapshot.empty());
    });

    test('rend une photo vide quand le compteur est absent ou illisible', () {
      expect(
        UnsyncedProbe.snapshotFromRow(const {}),
        const UnsyncedSnapshot.empty(),
      );
      expect(
        UnsyncedProbe.snapshotFromRow(const {'pending': '5'}),
        const UnsyncedSnapshot.empty(),
      );
    });

    test('lit le compteur et l horodatage', () {
      final photo = UnsyncedProbe.snapshotFromRow(
        const {'pending': 4, 'oldest': '2026-09-01T08:00:00.000'},
      );
      expect(photo.pendingCount, 4);
      expect(photo.oldestPendingAt, DateTime(2026, 9, 1, 8));
    });

    test('garde le compteur quand l horodatage est nul ou illisible', () {
      final sansDate =
          UnsyncedProbe.snapshotFromRow(const {'pending': 4, 'oldest': null});
      expect(sansDate.pendingCount, 4);
      expect(sansDate.oldestPendingAt, isNull);

      final illisible = UnsyncedProbe.snapshotFromRow(
        const {'pending': 4, 'oldest': 'pas une date'},
      );
      expect(illisible.pendingCount, 4);
      expect(illisible.oldestPendingAt, isNull);
    });

    test('ramène un horodatage UTC en heure locale', () {
      final photo = UnsyncedProbe.snapshotFromRow(
        const {'pending': 1, 'oldest': '2026-09-01T08:00:00.000Z'},
      );
      expect(photo.oldestPendingAt!.isUtc, isFalse);
      expect(
        photo.oldestPendingAt,
        DateTime.utc(2026, 9, 1, 8).toLocal(),
      );
    });
  });

  group('requête réelle sur une base en mémoire', () {
    late Database db;

    setUp(() async {
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      await db.execute(
        'CREATE TABLE expenses (id TEXT PRIMARY KEY, is_synced INTEGER, '
        'created_at TEXT, updated_at TEXT)',
      );
    });

    tearDown(() async => db.close());

    Future<UnsyncedSnapshot> sonder() async {
      final stamp = UnsyncedProbe.timestampExpression(
        UnsyncedProbe.trackedTables['expenses']!,
      );
      final rows = await db.rawQuery(
        'SELECT COUNT(*) AS pending, MIN($stamp) AS oldest '
        'FROM expenses WHERE is_synced = 0',
      );
      return UnsyncedProbe.snapshotFromRow(rows.first);
    }

    test('une table vide rend une photo vide', () async {
      expect(await sonder(), const UnsyncedSnapshot.empty());
    });

    test('les lignes déjà synchronisées sont ignorées', () async {
      await db.insert('expenses', {
        'id': 'a',
        'is_synced': 1,
        'updated_at': '2026-01-01T00:00:00.000',
      });
      expect(await sonder(), const UnsyncedSnapshot.empty());
    });

    test('le COALESCE retombe sur created_at quand updated_at est nul',
        () async {
      await db.insert('expenses', {
        'id': 'a',
        'is_synced': 0,
        'created_at': '2026-09-01T08:00:00.000',
        'updated_at': null,
      });
      await db.insert('expenses', {
        'id': 'b',
        'is_synced': 0,
        'created_at': '2026-08-01T08:00:00.000',
        'updated_at': '2026-09-10T08:00:00.000',
      });
      final photo = await sonder();
      expect(photo.pendingCount, 2);
      expect(
        photo.oldestPendingAt,
        DateTime(2026, 9, 1, 8),
        reason: 'la ligne b est datée par son updated_at, pas son created_at',
      );
    });

    test('une ligne sans aucun horodatage est comptée sans dater la photo',
        () async {
      await db.insert('expenses', {'id': 'a', 'is_synced': 0});
      final photo = await sonder();
      expect(photo.pendingCount, 1);
      expect(
        photo.oldestPendingAt,
        isNull,
        reason: 'ancienneté indémontrable : aucune alerte ne doit suivre',
      );
    });

    test('MIN ignore les lignes sans horodatage mais COUNT les garde',
        () async {
      await db.insert('expenses', {'id': 'a', 'is_synced': 0});
      await db.insert('expenses', {
        'id': 'b',
        'is_synced': 0,
        'updated_at': '2026-09-05T08:00:00.000',
      });
      final photo = await sonder();
      expect(photo.pendingCount, 2);
      expect(photo.oldestPendingAt, DateTime(2026, 9, 5, 8));
    });
  });

  group('UnsyncedProbe.read sur la base applicative en mémoire', () {
    setUp(() async {
      await DatabaseService.instance.close();
      await DatabaseService.instance.switchDatabase(name: inMemoryDatabasePath);
    });

    tearDownAll(() async {
      await DatabaseService.instance.close();
    });

    test('rend une photo vide sur une base neuve', () async {
      final photo = await const UnsyncedProbe().read();
      expect(photo, const UnsyncedSnapshot.empty());
    });

    test('agrège plusieurs tables et retient la plus ancienne ligne', () async {
      final db = await DatabaseService.instance.database;
      await db.insert('expenses', {
        'id': 'exp-1',
        'title': 'Taxi',
        'amount': 1500.0,
        'category': 'Transport',
        'date': '2026-09-10T08:00:00.000',
        'is_synced': 0,
        'created_at': '2026-09-10T08:00:00.000',
      });
      await db.insert('accounts', {
        'id': 'acc-1',
        'name': 'Courant',
        'balance': 100.0,
        'is_synced': 0,
        'updated_at': '2026-09-02T08:00:00.000',
      });
      await db.insert('accounts', {
        'id': 'acc-2',
        'name': 'Épargne',
        'balance': 100.0,
        'is_synced': 1,
        'updated_at': '2026-01-01T08:00:00.000',
      });

      final photo = await const UnsyncedProbe().read();
      expect(photo.pendingCount, 2, reason: 'acc-2 est déjà synchronisé');
      expect(photo.oldestPendingAt, DateTime(2026, 9, 2, 8));
    });

    test('les catégories non synchronisées ne sont pas comptées', () async {
      final db = await DatabaseService.instance.database;
      await db.insert('categories', {
        'id': 'cat-1',
        'name': 'Transport',
        'type': 'expense',
        'is_synced': 0,
      });
      final photo = await const UnsyncedProbe().read();
      expect(
        photo.pendingCount,
        0,
        reason: 'une suppression locale de catégorie alerterait pour toujours',
      );
    });
  });
}
