import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:monitrack/services/database_service.dart';
import 'package:monitrack/services/sync_service.dart';
import 'package:monitrack/utils/api_client.dart';

import 'sync_fake_dio.dart';

/// Verrou de push (constat M4) : `push()` est appelé sans `await` depuis une
/// trentaine d'endroits, après chaque écriture locale. Sans verrou, deux
/// envois simultanés transportaient les mêmes lignes.
///
/// Le réseau est simulé par un intercepteur Dio : le premier envoi est retenu
/// derrière un « portail » aussi longtemps que le test le souhaite, ce qui
/// rend la concurrence reproductible.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const fichier = 'sync_push_lock.db';
  late Database db;
  late SyncService sync;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DatabaseService.instance.close();
    final f = File(p.join(await getDatabasesPath(), fichier));
    if (f.existsSync()) f.deleteSync();
    await DatabaseService.instance.switchDatabase(name: fichier);
    db = await DatabaseService.instance.database;

    // Le service est un singleton : un verrou hérité d'un cas précédent
    // fausserait le suivant.
    sync = SyncService();
    sync.resetPushLock();
    sync.clearConflicts();
  });

  tearDown(() async {
    ApiClient.debugReset();
    sync.resetPushLock();
    sync.clearConflicts();
    await DatabaseService.instance.close();
  });

  Future<List<String>> identifiantsEnvoyes(
          Map<String, dynamic> corps, String cle) async =>
      List<Map<String, dynamic>>.from(corps[cle] as List)
          .map((row) => row['id'] as String)
          .toList();

  Future<int?> etatSynchro(String id) async => (await db.query('expenses',
          columns: ['is_synced'], where: 'id = ?', whereArgs: [id]))
      .single['is_synced'] as int?;

  test('plusieurs appels pendant un push en cours ne déclenchent qu’un seul '
      'rattrapage', () async {
    await db.insert('expenses', depenseLocale('dep-1'));

    final portail = Completer<void>();
    final corpsEnvoyes = <Map<String, dynamic>>[];
    ApiClient.debugOverride(dioFeint((options) async {
      corpsEnvoyes.add(Map<String, dynamic>.from(options.data as Map));
      if (corpsEnvoyes.length == 1) {
        // Écriture locale survenue pendant le premier envoi : c'est le cas
        // que le rattrapage existe pour rattraper.
        await db.insert('expenses', depenseLocale('dep-2'));
        await portail.future;
      }
      return reponseJson(options, {'message': 'Sync successful'});
    }));

    final premier = sync.push();
    expect(sync.isPushInFlight, isTrue,
        reason: 'le verrou doit être pris avant même le premier await');
    expect(sync.isPushPending, isFalse);

    // Huit demandes concurrentes pendant l'envoi.
    final concurrentes = List.generate(8, (_) => sync.push());
    expect(sync.isPushPending, isTrue);
    for (final demande in concurrentes) {
      expect(identical(demande, concurrentes.first), isTrue,
          reason: 'toutes les demandes concurrentes partagent le même futur');
    }

    portail.complete();
    final resultats = await Future.wait([premier, ...concurrentes]);

    expect(corpsEnvoyes, hasLength(2),
        reason: '1 push en cours + 1 seul rattrapage, quel que soit le nombre '
            'de demandes');
    expect(resultats.every((r) => r.success), isTrue);
    expect(sync.isPushInFlight, isFalse);
    expect(sync.isPushPending, isFalse);
  });

  test('les lignes écrites pendant le premier envoi partent dans le second',
      () async {
    await db.insert('expenses', depenseLocale('dep-avant'));

    final portail = Completer<void>();
    final corpsEnvoyes = <Map<String, dynamic>>[];
    ApiClient.debugOverride(dioFeint((options) async {
      corpsEnvoyes.add(Map<String, dynamic>.from(options.data as Map));
      if (corpsEnvoyes.length == 1) {
        await db.insert('expenses', depenseLocale('dep-pendant'));
        await portail.future;
      }
      return reponseJson(options, {'message': 'Sync successful'});
    }));

    final premier = sync.push();
    final rattrapage = sync.push();
    portail.complete();
    await Future.wait([premier, rattrapage]);

    expect(await identifiantsEnvoyes(corpsEnvoyes[0], 'expenses'), ['dep-avant'],
        reason: 'le premier envoi ne connaît pas encore la ligne suivante');
    expect(
        await identifiantsEnvoyes(corpsEnvoyes[1], 'expenses'), ['dep-pendant'],
        reason: 'la ligne écrite pendant l’envoi doit partir au rattrapage, '
            'et la ligne déjà acquittée ne doit pas repartir');

    expect(await etatSynchro('dep-avant'), 1);
    expect(await etatSynchro('dep-pendant'), 1);
  });

  test('le rattrapage part même si le premier push échoue', () async {
    await db.insert('expenses', depenseLocale('dep-1'));

    final portail = Completer<void>();
    var appels = 0;
    ApiClient.debugOverride(dioFeint((options) async {
      appels++;
      if (appels == 1) {
        await portail.future;
        throw panneReseau(options);
      }
      return reponseJson(options, {'message': 'Sync successful'});
    }));

    final premier = sync.push();
    final rattrapage = sync.push();
    portail.complete();

    final echec = await premier;
    final reprise = await rattrapage;

    expect(echec.success, isFalse);
    expect(echec.error, isNotNull);
    expect(appels, 2, reason: 'l’échec ne doit pas annuler le rattrapage');
    expect(reprise.success, isTrue);
    expect(reprise.pushed, 1);
    expect(await etatSynchro('dep-1'), 1,
        reason: 'la ligne non envoyée au premier coup part au second');
    expect(sync.isPushInFlight, isFalse);
    expect(sync.isPushPending, isFalse);
  });

  test('une exception inattendue est absorbée : aucune erreur ne remonte à la '
      'zone appelante', () async {
    await db.insert('expenses', depenseLocale('dep-1'));

    ApiClient.debugOverride(dioFeint((options) {
      throw StateError('panne imprévue');
    }));

    // `push()` est appelé sans `await` en production : une exception qui
    // s'échapperait ferait exploser la zone appelante.
    final resultat = await sync.push();

    expect(resultat.success, isFalse);
    expect(resultat.error, isNotNull);
    expect(await etatSynchro('dep-1'), 0,
        reason: 'rien n’est acquitté quand l’envoi n’aboutit pas');
    expect(sync.isPushInFlight, isFalse,
        reason: 'le verrou doit être rendu même en cas d’échec');
  });

  test('un refus serveur détaillé remonte son message', () async {
    await db.insert('expenses', depenseLocale('dep-1'));

    ApiClient.debugOverride(dioFeint((options) {
      throw DioException(
        requestOptions: options,
        response: Response<dynamic>(
          requestOptions: options,
          statusCode: 422,
          data: const {'message': 'Quota de synchronisation dépassé'},
        ),
        type: DioExceptionType.badResponse,
      );
    }));

    final resultat = await sync.push();

    expect(resultat.success, isFalse);
    expect(resultat.error, 'Quota de synchronisation dépassé');
    expect(await etatSynchro('dep-1'), 0);
  });

  test('une demande arrivée après la fin du push en cours lance un envoi neuf',
      () async {
    var appels = 0;
    ApiClient.debugOverride(dioFeint((options) {
      appels++;
      return reponseJson(options, {'message': 'Sync successful'});
    }));

    await db.insert('expenses', depenseLocale('dep-1'));
    await sync.push();
    expect(sync.isPushInFlight, isFalse);

    await db.insert('expenses', depenseLocale('dep-2'));
    await sync.push();

    expect(appels, 2,
        reason: 'le verrou ne doit pas rester pris après un push terminé');
    expect(await etatSynchro('dep-2'), 1);
  });

  test('le rattrapage n’envoie rien quand tout a déjà été acquitté', () async {
    await db.insert('expenses', depenseLocale('dep-1'));

    final portail = Completer<void>();
    var appels = 0;
    ApiClient.debugOverride(dioFeint((options) async {
      appels++;
      if (appels == 1) await portail.future;
      return reponseJson(options, {'message': 'Sync successful'});
    }));

    final premier = sync.push();
    final rattrapage = sync.push();
    portail.complete();
    final resultats = await Future.wait([premier, rattrapage]);

    expect(appels, 1,
        reason: 'c’est le double envoi des mêmes lignes que le verrou doit '
            'empêcher : sans ligne nouvelle, le rattrapage n’appelle pas le '
            'serveur');
    expect(resultats[0].pushed, 1);
    expect(resultats[1].pushed, 0);
    expect(await etatSynchro('dep-1'), 1);
  });

  test('resetPushLock libère le verrou sans interrompre le push en cours',
      () async {
    await db.insert('expenses', depenseLocale('dep-1'));

    final portail = Completer<void>();
    ApiClient.debugOverride(dioFeint((options) async {
      await portail.future;
      return reponseJson(options, {'message': 'Sync successful'});
    }));

    final premier = sync.push();
    final enAttente = sync.push(); // rattrapage programmé
    expect(sync.isPushInFlight, isTrue);
    expect(sync.isPushPending, isTrue);

    sync.resetPushLock();

    expect(sync.isPushInFlight, isFalse);
    expect(sync.isPushPending, isFalse);

    portail.complete();
    final resultat = await premier;
    expect(resultat.success, isTrue,
        reason: 'le push déjà lancé va jusqu’au bout');
    await enAttente;
  });
}
