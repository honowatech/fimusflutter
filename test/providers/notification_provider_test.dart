import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:monitrack/providers/notification_provider.dart';
import 'package:monitrack/services/auth_service.dart';
import 'package:monitrack/services/database_service.dart';
import 'package:monitrack/services/notification_service.dart';
import 'package:monitrack/utils/api_client.dart';

/// `NotificationService` est un **singleton non injectable**
/// (`factory NotificationService() => _instance`) et `NotificationProvider`
/// l'appelle directement : il n'existe aucun point de substitution.
///
/// La coupure se fait donc un cran plus bas, là où le dépôt expose de vrais
/// crochets de test :
///  * `ApiClient.debugOverride` (documenté « pour les tests ») remplace le Dio
///    du dépôt inbox par un adaptateur scripté ;
///  * `DatabaseService.switchDatabase(name: inMemoryDatabasePath)` (documenté
///    lui aussi pour les tests) isole le cache sur une base en mémoire — aucun
///    fichier `monitrack*.db` n'est touché ;
///  * `AuthService().addOrUpdateSession` ouvre une vraie session (repli mémoire
///    du stockage sécurisé), sans quoi le dépôt court-circuite tout appel.
///
/// Le provider testé est donc le vrai, avec sa vraie chaîne de services : seul
/// le transport HTTP est simulé.
typedef _Reponse = ResponseBody Function(RequestOptions options);

class _AdaptateurScripte implements HttpClientAdapter {
  /// Réponse servie pour la prochaine requête ; `null` ⇒ panne réseau.
  _Reponse? reponse;

  final List<RequestOptions> appels = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    appels.add(options);
    final servir = reponse;
    if (servir == null) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'réseau simulé indisponible',
      );
    }
    return servir(options);
  }

  @override
  void close({bool force = false}) {}

  void panne() => reponse = null;

  void json(Map<String, dynamic> corps, {int statut = 200}) {
    reponse = (options) => ResponseBody.fromString(
          jsonEncode(corps),
          statut,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
  }

  void vide({int statut = 200}) {
    reponse = (options) => ResponseBody.fromString(
          '',
          statut,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
  }
}

/// Ligne de notification telle que la renvoie Laravel.
Map<String, dynamic> _ligne(
  String id, {
  String type = 'new_debt',
  String? uuid,
  bool lue = false,
  String createdAt = '2026-10-01T08:00:00Z',
}) =>
    {
      'id': id,
      'type': 'App\\Notifications\\Generic',
      'data': {
        'type': type,
        'expense_uuid': uuid ?? 'exp-$id',
        'title': 'Titre $id',
        'message': 'Message $id',
      },
      'read_at': lue ? '2026-10-01T09:00:00Z' : null,
      'created_at': createdAt,
    };

Map<String, dynamic> _page(
  List<Map<String, dynamic>> lignes, {
  int currentPage = 1,
  int lastPage = 1,
  required int unreadCount,
}) =>
    {
      'notifications': lignes,
      'current_page': currentPage,
      'last_page': lastPage,
      'unread_count': unreadCount,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _AdaptateurScripte reseau;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // Base en mémoire : isolée de `monitrack.db` et remise à zéro à chaque test.
    await DatabaseService.instance.switchDatabase(name: inMemoryDatabasePath);
    await DatabaseService.instance.clearAllData();

    reseau = _AdaptateurScripte();
    final dio = Dio(BaseOptions(headers: {'Accept': 'application/json'}))
      ..httpClientAdapter = reseau;
    ApiClient.debugOverride(dio);

    // Sans session active, le dépôt inbox ne sort même pas sur le réseau.
    await AuthService()
        .addOrUpdateSession({'uuid': 'u-test', 'pseudo': 'test'}, 'jeton-test');
  });

  tearDown(() {
    ApiClient.debugReset();
  });

  test('prérequis : la session simulée est bien vue comme authentifiée',
      () async {
    expect(await AuthService().hasToken(), isTrue);
  });

  group('fetch — compteur de non-lus et source de vérité serveur', () {
    test('le compteur vient de `unread_count`, pas du comptage des éléments',
        () async {
      // 3 éléments chargés dont 1 non lu, mais le serveur en annonce 12
      // (les autres sont sur les pages suivantes).
      reseau.json(_page(
        [
          _ligne('a'),
          _ligne('b', lue: true),
          _ligne('c', lue: true),
        ],
        unreadCount: 12,
        lastPage: 3,
      ));

      final provider = NotificationProvider();
      await provider.fetch();

      expect(provider.notifications, hasLength(3));
      expect(provider.unreadCount, 12,
          reason: 'le compteur ne doit pas être recalculé localement');
      expect(provider.hasMore, isTrue);
      expect(provider.fetchFailed, isFalse);
      expect(provider.isStale, isFalse);
      expect(provider.lastSyncAt, isNotNull);
    });

    test('un `unread_count` négatif est ramené à zéro', () async {
      reseau.json(_page([_ligne('a')], unreadCount: -5));
      final provider = NotificationProvider();
      await provider.fetch();
      expect(provider.unreadCount, 0);
    });

    test('une réponse sans `unread_count` retombe à zéro sans planter',
        () async {
      reseau.json({
        'notifications': [_ligne('a')],
      });
      final provider = NotificationProvider();
      await provider.fetch();
      expect(provider.notifications, hasLength(1));
      expect(provider.unreadCount, 0);
    });
  });

  group('fetch — un échec réseau ne vide jamais la liste', () {
    test('la liste et le compteur survivent à une panne réseau', () async {
      reseau.json(_page([_ligne('a'), _ligne('b')], unreadCount: 7));
      final provider = NotificationProvider();
      await provider.fetch();
      expect(provider.notifications, hasLength(2));

      reseau.panne();
      await provider.fetch();

      expect(provider.notifications, hasLength(2),
          reason: 'une panne réseau ne doit jamais écraser la liste affichée');
      expect(provider.notifications.map((n) => n.id), ['a', 'b']);
      expect(provider.unreadCount, 7);
      expect(provider.fetchFailed, isTrue);
      expect(provider.isStale, isTrue,
          reason: 'l\'écran doit pouvoir afficher le bandeau hors ligne');
    });

    test('une réponse illisible est traitée comme un échec, pas comme un vide',
        () async {
      reseau.json(_page([_ligne('a')], unreadCount: 1));
      final provider = NotificationProvider();
      await provider.fetch();

      // Le serveur renvoie 200 mais un corps qui n'est pas un objet.
      reseau.reponse = (options) => ResponseBody.fromString(
            '"pas un objet"',
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
      await provider.fetch();

      expect(provider.notifications, hasLength(1));
      expect(provider.fetchFailed, isTrue);
    });

    test('une erreur 500 laisse la liste intacte', () async {
      reseau.json(_page([_ligne('a')], unreadCount: 1));
      final provider = NotificationProvider();
      await provider.fetch();

      reseau.vide(statut: 500);
      await provider.fetch();

      expect(provider.notifications, hasLength(1));
      expect(provider.fetchFailed, isTrue);
    });

    test('hors ligne au tout premier chargement : le cache prend le relais',
        () async {
      // Un premier passage réussi remplit le cache local.
      reseau.json(_page([_ligne('a'), _ligne('b', lue: true)], unreadCount: 1));
      await NotificationProvider().fetch();

      // Nouveau provider (relancement de l'application), serveur injoignable.
      reseau.panne();
      final provider = NotificationProvider();
      await provider.fetch();

      expect(provider.notifications.map((n) => n.id), containsAll(['a', 'b']));
      expect(provider.unreadCount, 1,
          reason: 'faute de réponse serveur, le cache fait foi');
      expect(provider.isStale, isTrue);
      expect(provider.fetchFailed, isTrue);
    });

    test('un succès efface l\'état « périmé » laissé par la panne', () async {
      reseau.json(_page([_ligne('a')], unreadCount: 3));
      final provider = NotificationProvider();
      await provider.fetch();

      reseau.panne();
      await provider.fetch();
      expect(provider.isStale, isTrue);

      reseau.json(_page([_ligne('a')], unreadCount: 0));
      await provider.fetch();
      expect(provider.fetchFailed, isFalse);
      expect(provider.isStale, isFalse);
      expect(provider.unreadCount, 0);
    });
  });

  group('Suppression annulable (removeForUndo / restoreRemoved)', () {
    Future<NotificationProvider> avecTroisElements() async {
      reseau.json(_page(
        [_ligne('a'), _ligne('b'), _ligne('c')],
        unreadCount: 3,
      ));
      final provider = NotificationProvider();
      await provider.fetch();
      return provider;
    }

    test('removeForUndo retire l\'élément et décrémente les non-lus', () async {
      final provider = await avecTroisElements();
      final jeton = provider.removeForUndo(['b']);

      expect(provider.notifications.map((n) => n.id), ['a', 'c']);
      expect(provider.unreadCount, 2);
      expect(jeton.ids, ['b']);
      expect(jeton.removedUnread, 1);
      expect(jeton.isResolved, isFalse);
      // Rien n'a encore été envoyé au serveur.
      expect(
        reseau.appels.where((a) => a.path.endsWith('/notifications/delete')),
        isEmpty,
      );
    });

    test('restoreRemoved replace l\'élément à sa position d\'origine',
        () async {
      final provider = await avecTroisElements();
      final jeton = provider.removeForUndo(['b']);
      provider.restoreRemoved(jeton);

      expect(provider.notifications.map((n) => n.id), ['a', 'b', 'c'],
          reason: 'l\'élément doit revenir au milieu, pas en tête de liste');
      expect(provider.unreadCount, 3);
      expect(jeton.isResolved, isTrue);
    });

    test('une suppression multiple est restaurée dans l\'ordre d\'origine',
        () async {
      final provider = await avecTroisElements();
      final jeton = provider.removeForUndo(['a', 'c']);
      expect(provider.notifications.map((n) => n.id), ['b']);
      expect(jeton.removedUnread, 2);

      provider.restoreRemoved(jeton);
      expect(provider.notifications.map((n) => n.id), ['a', 'b', 'c']);
      expect(provider.unreadCount, 3);
    });

    test('un élément déjà lu ne fait pas bouger le compteur de non-lus',
        () async {
      reseau.json(_page(
        [_ligne('a'), _ligne('b', lue: true)],
        unreadCount: 1,
      ));
      final provider = NotificationProvider();
      await provider.fetch();

      final jeton = provider.removeForUndo(['b']);
      expect(jeton.removedUnread, 0);
      expect(provider.unreadCount, 1);
      provider.restoreRemoved(jeton);
      expect(provider.unreadCount, 1);
    });

    test('un jeton ne se résout qu\'une fois : double restauration sans effet',
        () async {
      final provider = await avecTroisElements();
      final jeton = provider.removeForUndo(['b']);

      provider.restoreRemoved(jeton);
      provider.restoreRemoved(jeton);

      expect(provider.notifications.map((n) => n.id), ['a', 'b', 'c']);
      expect(provider.unreadCount, 3,
          reason: 'une double restauration gonflerait le compteur');
    });

    test('restaurer après confirmation ne réinsère rien', () async {
      final provider = await avecTroisElements();
      final jeton = provider.removeForUndo(['b']);

      reseau.vide(); // DELETE accepté par le serveur.
      expect(await provider.confirmRemoval(jeton), isTrue);
      expect(provider.notifications.map((n) => n.id), ['a', 'c']);

      provider.restoreRemoved(jeton);
      expect(provider.notifications.map((n) => n.id), ['a', 'c']);
      expect(provider.unreadCount, 2);
    });

    test('confirmer deux fois n\'émet qu\'un seul DELETE', () async {
      final provider = await avecTroisElements();
      final jeton = provider.removeForUndo(['b']);

      reseau.vide();
      expect(await provider.confirmRemoval(jeton), isTrue);
      expect(await provider.confirmRemoval(jeton), isTrue);

      final deletes = reseau.appels
          .where((a) => a.path.endsWith('/notifications/delete'))
          .toList();
      expect(deletes, hasLength(1));
      expect(
        (deletes.single.data as Map)['notification_ids'],
        ['b'],
      );
    });

    test('demander la suppression d\'un id absent renvoie un jeton vide',
        () async {
      final provider = await avecTroisElements();
      final jeton = provider.removeForUndo(['inconnu']);
      expect(jeton.isEmpty, isTrue);
      expect(provider.notifications, hasLength(3));
      expect(provider.unreadCount, 3);

      // Un jeton vide ne perturbe ni la restauration ni la confirmation.
      provider.restoreRemoved(jeton);
      expect(provider.notifications, hasLength(3));
      expect(await provider.confirmRemoval(jeton), isTrue);
    });

    test('une liste d\'ids vide est un non-événement', () async {
      final provider = await avecTroisElements();
      final jeton = provider.removeForUndo(const []);
      expect(jeton.isEmpty, isTrue);
      expect(provider.notifications, hasLength(3));
    });

    test('confirmation refusée par le serveur : les éléments reviennent',
        () async {
      final provider = await avecTroisElements();
      final jeton = provider.removeForUndo(['b']);

      reseau.panne();
      expect(await provider.confirmRemoval(jeton), isFalse);

      expect(provider.notifications.map((n) => n.id), ['a', 'b', 'c'],
          reason: 'un DELETE refusé ne doit pas perdre la notification');
      expect(provider.unreadCount, 3);
      expect(jeton.isResolved, isTrue,
          reason: 'le jeton est refermé après la restauration de secours');
    });

    test('un placeholder local est supprimé sans aucun appel serveur',
        () async {
      final provider = NotificationProvider();
      provider.addFromPush({'type': 'new_debt', 'expense_uuid': 'exp-push'});
      expect(provider.notifications.single.isPlaceholder, isTrue);

      final jeton = provider.removeForUndo([provider.notifications.first.id]);
      reseau.panne(); // même hors ligne, la confirmation doit réussir.
      expect(await provider.confirmRemoval(jeton), isTrue);
      expect(provider.notifications, isEmpty);
      expect(
        reseau.appels.where((a) => a.path.endsWith('/notifications/delete')),
        isEmpty,
      );
    });
  });

  group('Filtrage des suppressions en attente lors d\'un rafraîchissement', () {
    test('un rafraîchissement ne fait pas réapparaître l\'élément en attente',
        () async {
      reseau.json(_page([_ligne('a'), _ligne('b')], unreadCount: 2));
      final provider = NotificationProvider();
      await provider.fetch();

      final jeton = provider.removeForUndo(['b']);
      expect(provider.notifications.map((n) => n.id), ['a']);

      // Le serveur renvoie toujours « b » : la suppression n'est pas confirmée.
      reseau.json(_page([_ligne('a'), _ligne('b')], unreadCount: 2));
      await provider.fetch();

      expect(provider.notifications.map((n) => n.id), ['a'],
          reason: 'b est en attente d\'annulation, il ne doit pas revenir');

      // Après annulation, un nouveau rafraîchissement le ramène normalement.
      provider.restoreRemoved(jeton);
      await provider.fetch();
      expect(provider.notifications.map((n) => n.id), ['a', 'b']);
    });

    test('le filtre s\'applique aussi à la page suivante (loadMore)', () async {
      reseau.json(_page(
        [_ligne('a'), _ligne('b')],
        unreadCount: 4,
        lastPage: 2,
      ));
      final provider = NotificationProvider();
      await provider.fetch();
      expect(provider.hasMore, isTrue);

      final jeton = provider.removeForUndo(['a']);
      reseau.json(_page(
        [_ligne('c'), _ligne('a')],
        currentPage: 2,
        lastPage: 2,
        unreadCount: 4,
      ));
      await provider.loadMore();

      expect(provider.notifications.map((n) => n.id), ['b', 'c']);
      expect(jeton.ids, ['a']);
    });

    test('l\'élément en attente n\'est pas réécrit dans le cache local',
        () async {
      reseau.json(_page([_ligne('a'), _ligne('b')], unreadCount: 2));
      final provider = NotificationProvider();
      await provider.fetch();
      provider.removeForUndo(['b']);

      // Le rafraîchissement réécrit le cache à partir de la liste filtrée.
      reseau.json(_page([_ligne('a'), _ligne('b')], unreadCount: 2));
      await provider.fetch();

      final cache = await NotificationService().loadCachedNotifications();
      expect(cache.map((n) => n.id), ['a'],
          reason: 'le cache ne doit pas conserver une ligne en cours de '
              'suppression, sinon elle revient au prochain démarrage');
    });

    test('`clear` purge aussi les suppressions en attente', () async {
      reseau.json(_page([_ligne('a'), _ligne('b')], unreadCount: 2));
      final provider = NotificationProvider();
      await provider.fetch();
      provider.removeForUndo(['b']);
      provider.clear();

      // Après une déconnexion, plus rien n'est filtré.
      reseau.json(_page([_ligne('a'), _ligne('b')], unreadCount: 2));
      await provider.fetch();
      expect(provider.notifications.map((n) => n.id), ['a', 'b']);
    });
  });

  group('addFromPush', () {
    test('injecte la notification en tête et incrémente les non-lus', () {
      final provider = NotificationProvider();
      provider.addFromPush({
        'type': 'new_debt',
        'expense_uuid': 'exp-1',
        'notification_id': 'srv-1',
        'title': 'Nouvelle dette',
      });
      expect(provider.notifications.single.id, 'srv-1');
      expect(provider.unreadCount, 1);
    });

    test('un doublon (push reçu deux fois) n\'est pas ajouté deux fois', () {
      final provider = NotificationProvider();
      final push = {
        'type': 'new_debt',
        'expense_uuid': 'exp-1',
        'notification_id': 'srv-1',
      };
      provider.addFromPush(push);
      provider.addFromPush(push);
      expect(provider.notifications, hasLength(1));
      expect(provider.unreadCount, 1);
    });

    test('un placeholder est remplacé par la ligne serveur, sans double compte',
        () {
      final provider = NotificationProvider();
      provider.addFromPush({'type': 'new_debt', 'expense_uuid': 'exp-1'});
      expect(provider.notifications.single.isPlaceholder, isTrue);
      expect(provider.unreadCount, 1);

      provider.addFromPush({
        'type': 'new_debt',
        'expense_uuid': 'exp-1',
        'notification_id': 'srv-1',
      });
      expect(provider.notifications, hasLength(1));
      expect(provider.notifications.single.id, 'srv-1');
      expect(provider.unreadCount, 1,
          reason: 'le non-lu du placeholder doit être décompté');
    });

    test('le placeholder disparaît au profit de la ligne serveur au fetch',
        () async {
      final provider = NotificationProvider();
      provider.addFromPush({'type': 'new_debt', 'expense_uuid': 'exp-a'});
      expect(provider.notifications.single.isPlaceholder, isTrue);

      reseau.json(_page(
        [_ligne('a', uuid: 'exp-a')],
        unreadCount: 1,
      ));
      await provider.fetch();

      expect(provider.notifications, hasLength(1));
      expect(provider.notifications.single.id, 'a');
      expect(provider.notifications.single.isPlaceholder, isFalse);
    });

    test('un push d\'une autre entité reste affiché après le fetch', () async {
      final provider = NotificationProvider();
      provider.addFromPush({'type': 'new_debt', 'expense_uuid': 'exp-zzz'});

      reseau.json(_page([_ligne('a', uuid: 'exp-a')], unreadCount: 1));
      await provider.fetch();

      expect(provider.notifications, hasLength(2));
      expect(provider.notifications.first.isPlaceholder, isTrue);
    });
  });

  group('markAsRead / markAllAsRead', () {
    test('marquer comme lu décrémente le compteur serveur d\'une unité',
        () async {
      reseau.json(_page([_ligne('a'), _ligne('b')], unreadCount: 9));
      final provider = NotificationProvider();
      await provider.fetch();

      reseau.vide();
      expect(await provider.markAsRead('a'), isTrue);
      expect(provider.unreadCount, 8);
      expect(provider.notifications.first.isRead, isTrue);
    });

    test('un échec serveur annule le marquage et restaure le compteur',
        () async {
      reseau.json(_page([_ligne('a')], unreadCount: 1));
      final provider = NotificationProvider();
      await provider.fetch();

      reseau.panne();
      expect(await provider.markAsRead('a'), isFalse);
      expect(provider.notifications.single.isRead, isFalse);
      expect(provider.unreadCount, 1);
    });

    test('marquer une notification déjà lue est un succès sans appel serveur',
        () async {
      reseau.json(_page([_ligne('a', lue: true)], unreadCount: 0));
      final provider = NotificationProvider();
      await provider.fetch();

      final avant = reseau.appels.length;
      expect(await provider.markAsRead('a'), isTrue);
      expect(reseau.appels.length, avant);
      expect(provider.unreadCount, 0);
    });

    test('un id inconnu renvoie false sans toucher au compteur', () async {
      reseau.json(_page([_ligne('a')], unreadCount: 1));
      final provider = NotificationProvider();
      await provider.fetch();

      expect(await provider.markAsRead('fantome'), isFalse);
      expect(provider.unreadCount, 1);
    });

    test('un placeholder est marqué lu localement, sans appel serveur',
        () async {
      final provider = NotificationProvider();
      provider.addFromPush({'type': 'new_debt', 'expense_uuid': 'exp-1'});
      final id = provider.notifications.single.id;

      final avant = reseau.appels.length;
      expect(await provider.markAsRead(id), isTrue);
      expect(reseau.appels.length, avant,
          reason: 'aucune requête ne doit partir avec un id `push_*`');
      expect(provider.notifications.single.isRead, isTrue);
      expect(provider.unreadCount, 0);
    });

    test('markAllAsRead remet le compteur à zéro, et le restaure en cas d\'échec',
        () async {
      reseau.json(_page([_ligne('a'), _ligne('b')], unreadCount: 5));
      final provider = NotificationProvider();
      await provider.fetch();

      reseau.panne();
      expect(await provider.markAllAsRead(), isFalse);
      expect(provider.unreadCount, 5);
      expect(provider.notifications.every((n) => !n.isRead), isTrue);

      reseau.vide();
      expect(await provider.markAllAsRead(), isTrue);
      expect(provider.unreadCount, 0);
      expect(provider.notifications.every((n) => n.isRead), isTrue);
    });
  });

  group('deleteNotifications (suppression directe)', () {
    test('un échec serveur restaure la liste à l\'identique, ordre compris',
        () async {
      reseau.json(_page(
        [_ligne('a'), _ligne('b'), _ligne('c')],
        unreadCount: 3,
      ));
      final provider = NotificationProvider();
      await provider.fetch();

      reseau.panne();
      expect(await provider.deleteNotifications(['b']), isFalse);
      expect(provider.notifications.map((n) => n.id), ['a', 'b', 'c']);
      expect(provider.unreadCount, 3);
    });

    test('une liste vide est un succès immédiat', () async {
      final provider = NotificationProvider();
      expect(await provider.deleteNotifications(const []), isTrue);
    });
  });

  group('clear', () {
    test('remet la liste, le compteur et l\'horodatage à zéro', () async {
      reseau.json(_page([_ligne('a')], unreadCount: 4));
      final provider = NotificationProvider();
      await provider.fetch();
      expect(provider.lastSyncAt, isNotNull);

      provider.clear();

      expect(provider.notifications, isEmpty);
      expect(provider.unreadCount, 0);
      expect(provider.lastSyncAt, isNull);
      expect(provider.fetchFailed, isFalse);
      expect(provider.isStale, isFalse);
      expect(provider.hasMore, isFalse);
    });
  });

  group('Indicateurs de chargement', () {
    test('premier chargement vs rafraîchissement', () async {
      reseau.json(_page([_ligne('a')], unreadCount: 1));
      final provider = NotificationProvider();

      final etats = <String>[];
      provider.addListener(() {
        if (provider.isInitialLoading) etats.add('initial');
        if (provider.isRefreshing) etats.add('rafraichissement');
      });

      await provider.fetch();
      expect(etats, contains('initial'));
      expect(etats, isNot(contains('rafraichissement')));

      etats.clear();
      await provider.fetch();
      expect(etats, contains('rafraichissement'));
      expect(etats, isNot(contains('initial')),
          reason: 'la liste affichée ne doit jamais être remplacée par un '
              'indicateur plein écran',
      );
    });

    test('la liste exposée est non modifiable', () async {
      reseau.json(_page([_ligne('a')], unreadCount: 1));
      final provider = NotificationProvider();
      await provider.fetch();
      final liste = provider.notifications;
      expect(() => liste.clear(), throwsUnsupportedError);
      expect(() => liste.add(liste.first), throwsUnsupportedError);
    });
  });
}
