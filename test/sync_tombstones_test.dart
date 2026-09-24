import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:monitrack/services/database_service.dart';
import 'package:monitrack/services/sync_service.dart';
import 'package:monitrack/utils/api_client.dart';

import 'sync_fake_dio.dart';

/// Consommation des suppressions distantes (constat M4) et journal de
/// conflits. Le backend ne produit encore aucune de ces formes : les tests
/// vérifient que le client saura les lire le jour où il le fera, et qu'en
/// attendant rien ne change.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const fichier = 'sync_tombstones.db';
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

  /// Fait répondre le faux serveur avec [corps] sur `GET /sync/pull`.
  void serveurRepond(Map<String, dynamic> corps) {
    ApiClient.debugOverride(dioFeint((options) => reponseJson(options, corps)));
  }

  Future<int> nombreDeDepenses() =>
      db.query('expenses').then((rows) => rows.length);

  test('suppression distante appliquée sur une ligne locale synchronisée',
      () async {
    await db.insert('expenses',
        depenseLocale('dep-supprimee', isSynced: 1, syncAction: 'updated'));
    await db.insert('expenses',
        depenseLocale('dep-gardee', isSynced: 1, syncAction: 'updated'));

    serveurRepond({
      'expenses': [
        {
          'uuid': 'dep-supprimee',
          'title': 'Dépense',
          'deleted_at': '2026-03-05T10:00:00.000Z',
        },
      ],
    });

    final resultat = await sync.pull();

    expect(resultat.success, isTrue);
    expect(resultat.deleted, 1);
    expect(resultat.pulled, 0,
        reason: 'une ligne porteuse de deleted_at est une pierre tombale, '
            'pas une mise à jour');
    expect(resultat.conflicts, 0);
    expect(await nombreDeDepenses(), 1);
    expect((await db.query('expenses')).single['id'], 'dep-gardee');
  });

  test('suppression ignorée et conflit journalisé quand la ligne locale a des '
      'modifications non envoyées', () async {
    await db.insert('expenses',
        depenseLocale('dep-modifiee', isSynced: 0, syncAction: 'updated'));

    serveurRepond({
      'deleted_expenses': ['dep-modifiee'],
    });

    final resultat = await sync.pull();

    expect(resultat.deleted, 0);
    expect(resultat.conflicts, 1);
    expect(await nombreDeDepenses(), 1,
        reason: 'le travail local non envoyé ne doit pas être effacé');

    final conflit = sync.conflicts.single;
    expect(conflit.kind, SyncConflictKind.remoteDeleteVsLocalEdit);
    expect(conflit.table, 'expenses');
    expect(conflit.rowId, 'dep-modifiee');
    expect(conflit.detail, contains('supprimée sur le serveur'));
  });

  test('suppression locale déjà en attente : la suppression distante est '
      'appliquée sans conflit', () async {
    // La ligne est marquée supprimée localement mais pas encore poussée : les
    // deux côtés veulent la même chose, il n'y a rien à arbitrer.
    await db.insert('expenses',
        depenseLocale('dep-a-supprimer', isSynced: 0, syncAction: 'delete'));

    serveurRepond({
      'deleted_expenses': ['dep-a-supprimer'],
    });

    final resultat = await sync.pull();

    expect(resultat.deleted, 1);
    expect(resultat.conflicts, 0);
    expect(await nombreDeDepenses(), 0);
    expect(sync.conflicts, isEmpty);
  });

  test('une suppression portant sur une ligne absente en local ne compte pas',
      () async {
    serveurRepond({
      'deleted_expenses': ['dep-inconnue'],
    });

    final resultat = await sync.pull();

    expect(resultat.deleted, 0);
    expect(resultat.conflicts, 0);
  });

  test('forme « enveloppe » : deletions / tombstones, identifiants nus ou '
      'objets', () async {
    await db.insert('expenses',
        depenseLocale('dep-1', isSynced: 1, syncAction: 'updated'));
    await db.insert('accounts',
        compteLocal('cpt-1', isSynced: 1, syncAction: 'updated'));
    await db.insert('products', {
      'id': 'prod-1',
      'name': 'Savon',
      'price': 500.0,
      'is_synced': 1,
      'sync_action': 'updated',
      'updated_at': '2026-03-01T09:00:00.000',
    });

    serveurRepond({
      'deletions': {
        // Nom de la table locale…
        'expenses': ['dep-1'],
        // …clé du contrat en camelCase…
        'accounts': [
          {'uuid': 'cpt-1', 'deleted_at': '2026-03-05T10:00:00.000Z'},
        ],
      },
      'tombstones': {
        'products': ['prod-1'],
      },
    });

    final resultat = await sync.pull();

    expect(resultat.deleted, 3);
    expect(await db.query('expenses'), isEmpty);
    expect(await db.query('accounts'), isEmpty);
    expect(await db.query('products'), isEmpty);
  });

  test('forme « clé dédiée » : deleted_<table> et son écriture camelCase',
      () async {
    await db.insert('products', {
      'id': 'prod-1',
      'name': 'Savon',
      'price': 500.0,
      'is_synced': 1,
      'sync_action': 'updated',
      'updated_at': '2026-03-01T09:00:00.000',
    });
    await db.insert('staff_members', {
      'id': 'emp-1',
      'name': 'Awa',
      'is_synced': 1,
      'sync_action': 'updated',
      'updated_at': '2026-03-01T09:00:00.000',
    });

    serveurRepond({
      'deletedProducts': ['prod-1'],
      'deleted_staff_members': [
        {'id': 'emp-1'},
      ],
    });

    final resultat = await sync.pull();

    expect(resultat.deleted, 2);
    expect(await db.query('products'), isEmpty);
    expect(await db.query('staff_members'), isEmpty);
  });

  test('une table inconnue ou une valeur mal formée est ignorée sans erreur',
      () async {
    await db.insert('expenses',
        depenseLocale('dep-1', isSynced: 1, syncAction: 'updated'));

    serveurRepond({
      'deletions': {
        'invoices': ['fact-1'],
        'expenses': 'dep-1',
      },
      'deleted_unknown_table': ['x-1'],
    });

    final resultat = await sync.pull();

    expect(resultat.success, isTrue);
    expect(resultat.deleted, 0);
    expect(await nombreDeDepenses(), 1,
        reason: 'une valeur qui n’est pas une liste n’emporte aucune '
            'suppression');
  });

  test('une pierre tombale n’est jamais réinsérée par le pull', () async {
    // Aucune ligne locale : la version « supprimée » ne doit pas créer la
    // ligne au passage.
    serveurRepond({
      'expenses': [
        {
          'uuid': 'dep-fantome',
          'title': 'Supprimée côté serveur',
          'amount': 900,
          'category': 'Autre',
          'date': '2026-03-01T09:00:00.000',
          'deleted_at': '2026-03-05T10:00:00.000Z',
        },
      ],
    });

    final resultat = await sync.pull();

    expect(resultat.pulled, 0);
    expect(await nombreDeDepenses(), 0);
  });

  test('suppressions et mises à jour dans la même réponse', () async {
    await db.insert('expenses',
        depenseLocale('dep-a-supprimer', isSynced: 1, syncAction: 'updated'));

    serveurRepond({
      'expenses': [
        {
          'uuid': 'dep-a-supprimer',
          'deleted_at': '2026-03-05T10:00:00.000Z',
        },
        {
          'uuid': 'dep-nouvelle',
          'title': 'Achat de riz',
          'amount': 3500,
          'category': 'Alimentation',
          'date': '2026-03-04T08:00:00.000',
          'updated_at': '2026-03-04T08:00:00.000',
        },
      ],
    });

    final resultat = await sync.pull();

    expect(resultat.pulled, 1);
    expect(resultat.deleted, 1);
    final restantes = await db.query('expenses');
    expect(restantes.single['id'], 'dep-nouvelle');
    expect(restantes.single['title'], 'Achat de riz');
    expect(restantes.single['is_synced'], 1);
  });

  test('version serveur plus récente écartée au profit du local non envoyé : '
      'le conflit est tracé', () async {
    await db.insert(
        'expenses',
        depenseLocale('dep-1',
            isSynced: 0,
            titre: 'Titre local',
            updatedAt: '2026-03-01T09:00:00.000'));

    serveurRepond({
      'expenses': [
        {
          'uuid': 'dep-1',
          'title': 'Titre serveur',
          'amount': 9999,
          'category': 'Autre',
          'date': '2026-03-01T09:00:00.000',
          'updated_at': '2026-03-10T09:00:00.000',
        },
      ],
    });

    final resultat = await sync.pull();

    expect(resultat.conflicts, 1);
    expect((await db.query('expenses')).single['title'], 'Titre local',
        reason: 'l’arbitrage reste « le local non synchronisé gagne »');

    final conflit = sync.conflicts.single;
    expect(conflit.kind, SyncConflictKind.localWinsOverServer);
    expect(conflit.rowId, 'dep-1');
    expect(conflit.serverVersion?['title'], 'Titre serveur',
        reason: 'la version écartée est conservée pour un arbitrage ultérieur');
  });

  test('le journal de conflits est borné à 200 entrées, les plus récentes',
      () async {
    const total = 205;
    final identifiants =
        List.generate(total, (i) => 'dep-${i.toString().padLeft(3, '0')}');
    final lot = db.batch();
    for (final id in identifiants) {
      lot.insert('expenses', depenseLocale(id, isSynced: 0));
    }
    await lot.commit(noResult: true);

    serveurRepond({'deleted_expenses': identifiants});

    final resultat = await sync.pull();

    expect(resultat.deleted, 0);

    final journal = sync.conflicts;
    expect(journal, hasLength(200), reason: 'le journal est plafonné');
    expect(journal.first.rowId, identifiants[total - 200],
        reason: 'ce sont les plus anciens qui sont écartés');
    expect(journal.last.rowId, identifiants.last);

    // `SyncResult.conflicts` vient d'un compteur monotone, pas de la taille
    // du journal : les 205 conflits détectés sont annoncés, même si le
    // journal n'en conserve que les 200 derniers.
    expect(resultat.conflicts, 205,
        reason: 'le plafond du journal ne doit pas masquer des conflits');

    sync.clearConflicts();
    expect(sync.conflicts, isEmpty);
  });

  test('journal saturé : les conflits d’une synchronisation suivante restent '
      'comptés dans SyncResult', () async {
    Future<void> saturer(List<String> identifiants) async {
      final lot = db.batch();
      for (final id in identifiants) {
        lot.insert('expenses', depenseLocale(id, isSynced: 0));
      }
      await lot.commit(noResult: true);
      serveurRepond({'deleted_expenses': identifiants});
      await sync.pull();
    }

    await saturer(
        List.generate(200, (i) => 'a-${i.toString().padLeft(3, '0')}'));
    expect(sync.conflicts, hasLength(200));

    final nouveaux = List.generate(5, (i) => 'b-$i');
    final lot = db.batch();
    for (final id in nouveaux) {
      lot.insert('expenses', depenseLocale(id, isSynced: 0));
    }
    await lot.commit(noResult: true);
    serveurRepond({'deleted_expenses': nouveaux});

    final resultat = await sync.pull();

    // Les cinq conflits ont bien eu lieu : ils sont en fin de journal…
    expect(sync.conflicts.map((c) => c.rowId).toList().sublist(195), nouveaux);
    // …et le résultat les annonce, alors même que la taille du journal n'a
    // pas bougé (plafond atteint).
    expect(resultat.conflicts, 5,
        reason: 'le compteur est monotone, pas une différence de longueur');
    expect(await nombreDeDepenses(), 205,
        reason: 'aucune des lignes modifiées localement n’a été supprimée');
  });

  test('les tables sans suppression douce côté serveur sont documentées', () {
    expect(SyncService.softDeleteTables,
        ['accounts', 'expenses', 'products', 'staff_members']);
  });
}
