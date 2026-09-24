import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;
import 'package:monitrack/services/auth_service.dart';
import 'package:monitrack/services/database_service.dart';
import 'package:monitrack/utils/api_config.dart';

void main() {
  final dev = AppEnvironment.local();
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthService — sessions multicompte', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('ajout, activation et listage des sessions', () async {
      final auth = AuthService();
      await auth.addOrUpdateSession(
          {'uuid': 'u1', 'name': 'Alice', 'email': 'a@x.com'}, 'tok1');
      await auth.addOrUpdateSession(
          {'uuid': 'u2', 'name': 'Bob', 'email': 'b@x.com'}, 'tok2');

      final sessions = await auth.listSessions();
      expect(sessions.length, 2);
      expect(await auth.getActiveUserId(), 'u2');
      expect(await auth.getToken(), 'tok2');
      expect((await auth.getCachedUser())?['name'], 'Bob');
    });

    test('switchAccount réactive une session existante', () async {
      final auth = AuthService();
      await auth.addOrUpdateSession({'uuid': 'u1', 'name': 'Alice'}, 'tok1');
      await auth.addOrUpdateSession({'uuid': 'u2', 'name': 'Bob'}, 'tok2');

      expect(await auth.switchAccount('u1'), isTrue);
      expect(await auth.getActiveUserId(), 'u1');
      expect(await auth.getToken(), 'tok1');
      // La session réactivée passe en fin de liste (la plus récente).
      expect((await auth.listSessions()).last['name'], 'Alice');
      expect(await auth.switchAccount('unknown'), isFalse);
    });

    test('removeSession du compte actif active le compte restant', () async {
      final auth = AuthService();
      await auth.addOrUpdateSession({'uuid': 'u1', 'name': 'Alice'}, 'tok1');
      await auth.addOrUpdateSession({'uuid': 'u2', 'name': 'Bob'}, 'tok2');

      await auth.removeSession('u2');
      expect(await auth.listSessions(), hasLength(1));
      expect(await auth.getActiveUserId(), 'u1');
      expect(await auth.getToken(), 'tok1');
    });

    test('removeActiveSession (401) laisse les autres sessions sans en activer',
        () async {
      final auth = AuthService();
      await auth.addOrUpdateSession({'uuid': 'u1', 'name': 'Alice'}, 'tok1');
      await auth.addOrUpdateSession({'uuid': 'u2', 'name': 'Bob'}, 'tok2');

      await auth.removeActiveSession();
      expect(await auth.listSessions(), hasLength(1));
      expect(await auth.getActiveUserId(), isNull);
    });

    test("migration de l'ancienne session mono-compte", () async {
      SharedPreferences.setMockInitialValues({
        'auth_token': 'legacy-token',
        'cached_user': '{"uuid":"legacy","name":"Ancien","email":"old@x.com"}',
      });
      final auth = AuthService();
      expect(await auth.listSessions(), hasLength(1));
      expect(await auth.getActiveUserId(), 'legacy');
      expect(await auth.getToken(), 'legacy-token');
      expect((await auth.getCachedUser())?['name'], 'Ancien');
      // Seul ce compte peut hériter de l'ancienne base partagée.
      expect(await auth.getLegacyDbOwner(AppEnvironment.production), 'legacy');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('auth_token'), isNull);
      expect(prefs.getString('cached_user'), isNull);
    });
  });

  group('DatabaseService — bases par compte', () {
    setUpAll(() async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    test('nommage par utilisateur', () {
      expect(DatabaseService.perUserDbName('user-1', AppEnvironment.production),
          'monitrack_user-1.db');
      expect(DatabaseService.perUserDbName('user-1', dev),
          'monitrack_dev_user-1.db');
      expect(DatabaseService.perUserDbName('bad/id!', AppEnvironment.production),
          'monitrack_bad_id_.db');
    });

    test('isolation entre comptes et héritage réservé au propriétaire legacy',
        () async {
      SharedPreferences.setMockInitialValues({});
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final idA = 'isoA$stamp';
      final idB = 'isoB$stamp';
      final legacyRowId = 'legacy-$stamp';

      // Base legacy partagée, repartie de zéro à chaque exécution.
      final dir = await getDatabasesPath();
      await databaseFactory.deleteDatabase(p.join(dir, 'monitrack_dev.db'));
      await DatabaseService.instance
          .switchDatabase(name: 'monitrack_dev.db');
      var db = await DatabaseService.instance.database;
      await db.insert('accounts',
          {'id': legacyRowId, 'name': 'Compte legacy', 'balance': 100.0});

      // Premier compte : propriétaire de la base legacy → il en hérite.
      expect(
          await DatabaseService.instance.switchToUserDatabase(idA,
              env: dev, legacyDbOwner: idA),
          isTrue);
      db = await DatabaseService.instance.database;
      var rows = await db.query('accounts');
      expect(rows.map((r) => r['id']).toList(), [legacyRowId]);

      // Second compte : PAS propriétaire → base vierge, aucune fuite.
      await DatabaseService.instance
          .switchToUserDatabase(idB, env: dev, legacyDbOwner: idA);
      db = await DatabaseService.instance.database;
      expect(Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM accounts')), 0);
      await db.insert(
          'accounts', {'id': 'acc-b-$stamp', 'name': 'Compte B', 'balance': 5.0});

      // Retour au premier compte : ses données, pas celles de B.
      expect(
          await DatabaseService.instance.switchToUserDatabase(idA,
              env: dev, legacyDbOwner: idA),
          isTrue);
      db = await DatabaseService.instance.database;
      rows = await db.query('accounts');
      expect(rows.map((r) => r['id']).toList(), [legacyRowId]);

      // Bascule sans changement retourne false (pas de rechargement utile).
      expect(
          await DatabaseService.instance.switchToUserDatabase(idA,
              env: dev, legacyDbOwner: idA),
          isFalse);

      // Nettoyage des fichiers de test.
      await databaseFactory.deleteDatabase(
          p.join(dir, DatabaseService.perUserDbName(idA, dev)));
      await databaseFactory.deleteDatabase(
          p.join(dir, DatabaseService.perUserDbName(idB, dev)));
      await databaseFactory.deleteDatabase(p.join(dir, 'monitrack_dev.db'));
    });
  });
}
