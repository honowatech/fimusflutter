import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:monitrack/services/database_service.dart';
import 'package:monitrack/services/sync_service.dart';
import 'package:monitrack/utils/api_client.dart';

import 'sync_fake_dio.dart';

/// Lecture de l'accusé de push (constat M4) : un `200` ne vaut plus
/// acquittement inconditionnel de toutes les lignes envoyées.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PushAck.parse', () {
    test('corps opaque (texte brut) : tout est réputé accepté', () {
      final ack = PushAck.parse('Sync successful');

      expect(ack.opaque, isTrue);
      expect(ack.accepted, isEmpty);
      expect(ack.rejected, isEmpty);
      expect(ack.isAccepted('expenses', 'uuid-1', wasSent: true), isTrue);
      expect(ack.isAccepted('accounts', 'uuid-2', wasSent: true), isTrue);
      expect(ack.reasonFor('expenses', 'uuid-1'), isNull);
    });

    test('corps JSON sans détail par ligne : opaque, comportement historique',
        () {
      // C'est exactement ce que répond le backend aujourd'hui.
      final ack = PushAck.parse({'message': 'Sync successful'});

      expect(ack.opaque, isTrue);
      expect(ack.isAccepted('expenses', 'uuid-1', wasSent: true), isTrue);
    });

    test('corps nul ou liste : opaque', () {
      expect(PushAck.parse(null).opaque, isTrue);
      expect(PushAck.parse(const ['uuid-1']).opaque, isTrue);
      expect(PushAck.parse(42).opaque, isTrue);
    });

    test('forme {table: [uuid]} : seules les lignes citées sont refusées', () {
      final ack = PushAck.parse({
        'rejected': {
          'expenses': ['uuid-refusee'],
        },
      });

      expect(ack.opaque, isFalse);
      expect(ack.rejected['expenses'], {'uuid-refusee'});
      expect(ack.isAccepted('expenses', 'uuid-refusee', wasSent: true), isFalse);
      expect(ack.isAccepted('expenses', 'uuid-autre', wasSent: true), isTrue,
          reason: 'sans liste blanche, tout ce qui n’est pas refusé passe');
      expect(ack.isAccepted('accounts', 'uuid-refusee', wasSent: true), isTrue,
          reason: 'le refus est indexé par table');
    });

    test('forme {table: [{id, status, error}]} : le motif du refus est conservé',
        () {
      final ack = PushAck.parse({
        'results': {
          'expenses': [
            {'id': 'uuid-ok', 'status': 'created'},
            {
              'id': 'uuid-ko',
              'status': 'rejected',
              'error': 'compte introuvable',
            },
          ],
        },
      });

      expect(ack.isAccepted('expenses', 'uuid-ok', wasSent: true), isTrue);
      expect(ack.isAccepted('expenses', 'uuid-ko', wasSent: true), isFalse);
      expect(ack.reasonFor('expenses', 'uuid-ko'), 'compte introuvable');
      expect(ack.reasonFor('expenses', 'uuid-ok'), isNull);
    });

    test('la clé `uuid` est acceptée au même titre que `id`', () {
      final ack = PushAck.parse({
        'rejected': {
          'accounts': [
            {'uuid': 'uuid-ko', 'message': 'solde négatif'},
          ],
        },
      });

      expect(ack.isAccepted('accounts', 'uuid-ko', wasSent: true), isFalse);
      expect(ack.reasonFor('accounts', 'uuid-ko'), 'solde négatif');
    });

    test('un statut inconnu vaut refus, même dans une section d’acceptation',
        () {
      final ack = PushAck.parse({
        'accepted': {
          'products': [
            {'id': 'uuid-ok', 'status': 'updated'},
            {'id': 'uuid-bizarre', 'status': 'skipped'},
          ],
        },
      });

      expect(ack.isAccepted('products', 'uuid-ok', wasSent: true), isTrue);
      expect(ack.isAccepted('products', 'uuid-bizarre', wasSent: true), isFalse);
    });

    test('un statut favorable dans une section de refus vaut acceptation', () {
      // Cas limite : le serveur range une ligne dans « failed » mais la marque
      // `unchanged`. Le statut explicite l'emporte sur la section.
      final ack = PushAck.parse({
        'failed': {
          'expenses': [
            {'id': 'uuid-1', 'status': 'unchanged'},
          ],
        },
      });

      expect(ack.isAccepted('expenses', 'uuid-1', wasSent: true), isTrue);
      expect(ack.accepted['expenses'], {'uuid-1'});
    });

    test('une table citée dans `accepted` devient une liste blanche', () {
      final ack = PushAck.parse({
        'accepted': {
          'expenses': ['uuid-1'],
        },
      });

      expect(ack.isAccepted('expenses', 'uuid-1', wasSent: true), isTrue);
      expect(ack.isAccepted('expenses', 'uuid-2', wasSent: true), isFalse,
          reason: 'une ligne absente de la liste blanche de sa table n’a pas '
              'été acquittée');
      expect(ack.isAccepted('accounts', 'uuid-2', wasSent: true), isTrue,
          reason: 'la liste blanche ne vaut que pour la table qui la porte');
    });

    test('le refus l’emporte quand la ligne figure dans les deux sections', () {
      final ack = PushAck.parse({
        'rejected': {
          'expenses': ['uuid-1'],
        },
        'accepted': {
          'expenses': ['uuid-1', 'uuid-2'],
        },
      });

      expect(ack.isAccepted('expenses', 'uuid-1', wasSent: true), isFalse);
      expect(ack.isAccepted('expenses', 'uuid-2', wasSent: true), isTrue);
    });

    test('noms de tables en snake_case, camelCase ou nom local', () {
      final enSnake = PushAck.parse({
        'rejected': {
          'ussd_history': ['h-1'],
          'staff_members': ['s-1'],
        },
      });
      expect(enSnake.isAccepted('ussd_history', 'h-1', wasSent: true), isFalse);
      expect(enSnake.isAccepted('staff_members', 's-1', wasSent: true), isFalse);

      // Clés du contrat de synchronisation (camelCase).
      final enCamel = PushAck.parse({
        'rejected': {
          'ussdHistories': ['h-1'],
          'ussdOperations': ['o-1'],
          'telecomOperators': ['t-1'],
          'staffMembers': ['s-1'],
        },
      });
      expect(enCamel.isAccepted('ussd_history', 'h-1', wasSent: true), isFalse);
      expect(
          enCamel.isAccepted('ussd_operations', 'o-1', wasSent: true), isFalse);
      expect(enCamel.isAccepted('telecom_operators', 't-1', wasSent: true),
          isFalse);
      expect(enCamel.isAccepted('staff_members', 's-1', wasSent: true), isFalse);
    });

    test('une table inconnue du contrat est ignorée', () {
      final ack = PushAck.parse({
        'rejected': {
          'invoices': ['uuid-1'],
        },
      });

      expect(ack.opaque, isTrue,
          reason: 'aucun verdict exploitable : on retombe sur le mode opaque');
      expect(ack.isAccepted('expenses', 'uuid-1', wasSent: true), isTrue);
    });

    test('sections vides ou mal formées : retour au mode opaque', () {
      expect(
          PushAck.parse({
            'rejected': {'expenses': <String>[]},
          }).opaque,
          isTrue);
      expect(
          PushAck.parse({
            'rejected': {'expenses': 'uuid-1'},
          }).opaque,
          isTrue,
          reason: 'une valeur qui n’est pas une liste n’est pas exploitable');
      expect(PushAck.parse({'rejected': <String, dynamic>{}}).opaque, isTrue);
      expect(
          PushAck.parse({
            'rejected': {
              'expenses': [
                {'id': ''},
                {'sans_identifiant': 'x'},
              ],
            },
          }).opaque,
          isTrue,
          reason: 'un identifiant vide ou absent ne produit aucun verdict');
    });

    test('identifiants numériques : ramenés à leur écriture textuelle', () {
      final ack = PushAck.parse({
        'rejected': {
          'accounts': [42],
        },
      });

      expect(ack.isAccepted('accounts', '42', wasSent: true), isFalse);
    });

    test('tous les alias de sections sont reconnus', () {
      for (final refus in const ['rejected', 'failed', 'errors', 'conflicts']) {
        final ack = PushAck.parse({
          refus: {
            'expenses': ['uuid-1'],
          },
        });
        expect(ack.isAccepted('expenses', 'uuid-1', wasSent: true), isFalse,
            reason: 'section de refus « $refus » non reconnue');
      }
      for (final succes in const ['accepted', 'synced', 'applied', 'results']) {
        final ack = PushAck.parse({
          succes: {
            'expenses': ['uuid-1'],
          },
        });
        expect(ack.isAccepted('expenses', 'uuid-1', wasSent: true), isTrue);
        expect(ack.isAccepted('expenses', 'uuid-2', wasSent: true), isFalse,
            reason: 'section d’acceptation « $succes » non reconnue');
      }
    });

    test('une ligne non envoyée n’est jamais refusée : elle n’a pas de verdict '
        'serveur', () {
      final ack = PushAck.parse({
        'rejected': {
          'ussd_operations': ['ref_mtn_solde'],
        },
      });

      // Les opérations de référence sont écartées avant l'envoi : le serveur
      // ne peut pas avoir d'avis sur elles.
      expect(
          ack.isAccepted('ussd_operations', 'ref_mtn_solde', wasSent: false),
          isTrue);
      expect(ack.isAccepted('ussd_operations', 'ref_mtn_solde', wasSent: true),
          isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // Effet réel de l'accusé sur la base locale
  // ---------------------------------------------------------------------------

  group('effet de l’accusé sur les lignes locales', () {
    const fichier = 'sync_push_ack.db';
    late Database db;

    setUp(() async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      SharedPreferences.setMockInitialValues({});

      final chemin = p.join(await getDatabasesPath(), fichier);
      await DatabaseService.instance.close();
      final f = File(chemin);
      if (f.existsSync()) f.deleteSync();
      await DatabaseService.instance.switchDatabase(name: fichier);
      db = await DatabaseService.instance.database;

      SyncService().resetPushLock();
      SyncService().clearConflicts();
    });

    tearDown(() async {
      ApiClient.debugReset();
      SyncService().resetPushLock();
      SyncService().clearConflicts();
      await DatabaseService.instance.close();
    });

    Future<int?> etatSynchro(String id) async => (await db.query('expenses',
            columns: ['is_synced'], where: 'id = ?', whereArgs: [id]))
        .single['is_synced'] as int?;

    test('une ligne refusée reste non synchronisée et le conflit est journalisé',
        () async {
      await db.insert('expenses', depenseLocale('dep-ok'));
      await db.insert('expenses', depenseLocale('dep-ko'));

      ApiClient.debugOverride(dioFeint((options) => reponseJson(options, {
            'rejected': {
              'expenses': [
                {'id': 'dep-ko', 'error': 'montant invalide'},
              ],
            },
          })));

      final resultat = await SyncService().push();

      expect(resultat.success, isTrue);
      expect(resultat.pushed, 1, reason: 'une seule ligne a été acquittée');
      expect(resultat.conflicts, 1);
      expect(await etatSynchro('dep-ok'), 1);
      expect(await etatSynchro('dep-ko'), 0,
          reason: 'la ligne refusée doit repartir au prochain push');

      final conflits = SyncService().conflicts;
      expect(conflits, hasLength(1));
      expect(conflits.single.kind, SyncConflictKind.pushRejected);
      expect(conflits.single.table, 'expenses');
      expect(conflits.single.rowId, 'dep-ko');
      expect(conflits.single.detail, 'montant invalide');
    });

    test('un corps opaque acquitte toutes les lignes envoyées', () async {
      await db.insert('expenses', depenseLocale('dep-1'));
      await db.insert('expenses', depenseLocale('dep-2'));
      await db.insert('accounts', compteLocal('cpt-1'));

      ApiClient.debugOverride(dioFeint(
          (options) => reponseJson(options, {'message': 'Sync successful'})));

      final resultat = await SyncService().push();

      expect(resultat.success, isTrue);
      expect(resultat.pushed, 3);
      expect(resultat.conflicts, 0);
      expect(await etatSynchro('dep-1'), 1);
      expect(await etatSynchro('dep-2'), 1);
      expect(SyncService().conflicts, isEmpty);
    });

    test('une liste blanche partielle laisse les lignes non citées à renvoyer',
        () async {
      await db.insert('expenses', depenseLocale('dep-1'));
      await db.insert('expenses', depenseLocale('dep-2'));

      ApiClient.debugOverride(dioFeint((options) => reponseJson(options, {
            'accepted': {
              'expenses': ['dep-1'],
            },
          })));

      final resultat = await SyncService().push();

      expect(resultat.pushed, 1);
      expect(await etatSynchro('dep-1'), 1);
      expect(await etatSynchro('dep-2'), 0);
      expect(SyncService().conflicts.single.rowId, 'dep-2');
    });

    test('les opérations de référence ne sont pas envoyées mais sont marquées '
        'synchronisées', () async {
      await db.insert('ussd_operations', {
        'id': 'ref_mtn_solde',
        'name': 'Solde MTN',
        'provider': 'MTN',
        'category': 'balance',
        'defaultTemplate': '*126#',
        'is_enabled': 1,
        'is_synced': 0,
        'sync_action': 'created',
        'updated_at': '2026-03-01T09:00:00.000',
      });
      await db.insert('expenses', depenseLocale('dep-1'));

      Map<String, dynamic>? corpsEnvoye;
      ApiClient.debugOverride(dioFeint((options) {
        corpsEnvoye = Map<String, dynamic>.from(options.data as Map);
        return reponseJson(options, {'message': 'ok'});
      }));

      final resultat = await SyncService().push();

      expect(corpsEnvoye!['ussdOperations'], isEmpty,
          reason: 'les opérations `ref_` ne quittent jamais l’appareil');
      expect(resultat.pushed, 1, reason: 'seule la dépense a été comptée');
      expect(
          (await db.query('ussd_operations',
                  columns: ['is_synced'],
                  where: 'id = ?',
                  whereArgs: ['ref_mtn_solde']))
              .single['is_synced'],
          1,
          reason: 'sans verdict serveur possible, la ligne locale est marquée');
    });

    test('un statut HTTP non 200 n’acquitte rien', () async {
      await db.insert('expenses', depenseLocale('dep-1'));

      ApiClient.debugOverride(dioFeint((options) =>
          reponseJson(options, {'message': 'oops'}, statusCode: 202)));

      final resultat = await SyncService().push();

      expect(resultat.success, isFalse);
      expect(resultat.error, contains('202'));
      expect(await etatSynchro('dep-1'), 0);
    });

    test('rien à envoyer : aucun appel réseau, succès immédiat', () async {
      var appels = 0;
      ApiClient.debugOverride(dioFeint((options) {
        appels++;
        return reponseJson(options, {'message': 'ok'});
      }));

      final resultat = await SyncService().push();

      expect(appels, 0);
      expect(resultat.success, isTrue);
      expect(resultat.pushed, 0);
    });
  });
}
