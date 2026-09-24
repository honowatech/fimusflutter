import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/exchange_rate_service.dart';
import '../utils/api_client.dart';
import '../utils/api_config.dart';
import '../utils/currency_converter.dart';
import '../utils/ussd_formatter.dart';

/// Handles bidirectional synchronisation between local SQLite and remote API.
class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;

  // Conservé pour injection dans les tests (token via ApiClient).
  // ignore: unused_field
  final AuthService _authService;
  Dio get _dio => ApiClient.instance;

  /// Catégories supprimées localement (clés « type|nom ») : le pull ne doit
  /// pas les réinsérer, elles restent dans le pool partagé pour les autres.
  Set<String> _categoryTombstones = {};

  SyncService._internal({AuthService? authService})
      : _authService = authService ?? AuthService();

  /// Table SQLite locale → clé du contrat de synchronisation (aller et
  /// retour). Sert aussi à reconnaître les tables citées par le serveur dans
  /// un accusé de push ou une liste de suppressions.
  static const Map<String, String> _payloadKeys = {
    'accounts': 'accounts',
    'expenses': 'expenses',
    'ussd_history': 'ussdHistories',
    'ussd_operations': 'ussdOperations',
    'telecom_operators': 'telecomOperators',
    'categories': 'categories',
    'products': 'products',
    'staff_members': 'staff_members',
  };

  /// Tables pour lesquelles le backend pratique la suppression douce
  /// (`deleted_at`, trait `SoftDeletes` sur `Account`, `Expense`, `Product`
  /// et `StaffMember`) : ce sont les seules dont une suppression distante peut
  /// aujourd'hui redescendre. Voir [_collectTombstones] pour les formes de
  /// réponse acceptées, et le rapport d'audit pour ce qui manque encore.
  static const List<String> _softDeleteTables = [
    'accounts',
    'expenses',
    'products',
    'staff_members',
  ];

  // ---------------------------------------------------------------------------
  // Journal des conflits (constat M4)
  // ---------------------------------------------------------------------------
  static const int _maxConflicts = 200;
  final List<SyncConflict> _conflicts = [];

  /// Conflits relevés depuis le dernier [clearConflicts], du plus ancien au
  /// plus récent. Il n'y a pas de résolution automatique (hors périmètre) :
  /// l'arbitrage actuel reste « le local non synchronisé gagne », mais la
  /// version serveur écartée est désormais tracée et affichable.
  List<SyncConflict> get conflicts => List.unmodifiable(_conflicts);

  void clearConflicts() => _conflicts.clear();

  /// Compteur monotone : la taille du journal est plafonnée à
  /// [_maxConflicts], elle ne peut donc pas servir à compter les conflits
  /// d'une synchronisation — journal saturé, la différence valait 0.
  int _conflictSeq = 0;

  void _recordConflict(SyncConflict conflict) {
    _conflictSeq++;
    _conflicts.add(conflict);
    if (_conflicts.length > _maxConflicts) {
      _conflicts.removeRange(0, _conflicts.length - _maxConflicts);
    }
    debugPrint('[Sync] $conflict');
  }

  // ---------------------------------------------------------------------------
  // PUSH — Send unsynced local rows to the server
  // ---------------------------------------------------------------------------

  /// Push actuellement en cours, `null` sinon.
  Future<SyncResult>? _pushInFlight;

  /// Rattrapage programmé — au plus un (constat M4).
  Future<SyncResult>? _pushPending;

  bool get isPushInFlight => _pushInFlight != null;

  /// Vrai si un push est déjà programmé derrière celui en cours.
  bool get isPushPending => _pushPending != null;

  /// push() est appelé sans `await` depuis une trentaine d'endroits (après
  /// chaque écriture locale) : deux envois simultanés transportaient donc les
  /// mêmes lignes.
  ///
  /// Verrou : un seul push à la fois. Si un push est demandé pendant qu'un
  /// autre tourne, **un seul** rattrapage est mis en attente ; toutes les
  /// demandes concurrentes partagent ce même futur au lieu de s'empiler. Le
  /// rattrapage part dès que le push courant se termine, succès ou échec —
  /// les lignes écrites entre-temps ne sont donc jamais oubliées.
  ///
  /// Aucune exception ne s'échappe, sinon elle exploserait dans la zone
  /// appelante : les lectures locales peuvent échouer (base verrouillée par
  /// une transaction concurrente) et les lignes repartiront au push suivant.
  Future<SyncResult> push() {
    final pending = _pushPending;
    if (pending != null) {
      // Un rattrapage est déjà programmé : on s'y rattache.
      return pending;
    }
    final inFlight = _pushInFlight;
    if (inFlight != null) {
      return _pushPending = _pushAfter(inFlight);
    }
    return _startPush();
  }

  /// Relance un push dès que [previous] est terminé. L'échec du push
  /// précédent n'annule pas le rattrapage.
  Future<SyncResult> _pushAfter(Future<SyncResult> previous) async {
    try {
      await previous;
    } catch (_) {
      // Le résultat du push précédent ne nous intéresse pas ici.
    }
    // Le rattrapage devient le push courant. Les deux affectations sont
    // consécutives, sans point d'attente entre elles : aucune demande
    // concurrente ne peut s'insérer et lancer un second push.
    _pushPending = null;
    return _startPush();
  }

  Future<SyncResult> _startPush() {
    final completer = Completer<SyncResult>();
    _pushInFlight = completer.future;
    unawaited(_runPush(completer));
    return completer.future;
  }

  Future<void> _runPush(Completer<SyncResult> completer) async {
    SyncResult result;
    try {
      result = await _performPush();
    } catch (e) {
      result =
          SyncResult(success: false, pushed: 0, pulled: 0, error: e.toString());
    }
    // Ne libère le verrou que s'il n'a pas déjà été repris par un rattrapage.
    if (identical(_pushInFlight, completer.future)) {
      _pushInFlight = null;
    }
    completer.complete(result);
  }

  /// Remet le verrou à zéro. Réservé aux tests : le service est un singleton,
  /// un push resté en attente d'un cas de test fausserait le suivant.
  @visibleForTesting
  void resetPushLock() {
    _pushInFlight = null;
    _pushPending = null;
  }

  Future<SyncResult> _performPush() async {
    final db = await DatabaseService.instance.database;

    // Collecte des lignes non synchronisées, table par table. `collected` sert
    // au marquage, `toPush` à l'envoi : certaines lignes sont écartées avant
    // l'envoi sur décision purement locale (voir ci-dessous).
    final batches = <_TablePush>[
      _TablePush(
        table: 'accounts',
        rows: await db.query('accounts', where: 'is_synced = ?', whereArgs: [0]),
      ),
      _TablePush(
        table: 'expenses',
        rows: await db.query('expenses', where: 'is_synced = ?', whereArgs: [0]),
      ),
      _TablePush(
        table: 'ussd_history',
        rows: await db.query('ussd_history', where: 'is_synced = ?', whereArgs: [0]),
      ),
      _TablePush(
        table: 'ussd_operations',
        rows: await db.query('ussd_operations', where: 'is_synced = ?', whereArgs: [0]),
        // Les opérations de référence (préfixe `ref_`) ne sont jamais poussées.
        keep: (row) => !(row['id'] as String).startsWith('ref_'),
        transform: _prepareUssdOperation,
      ),
      _TablePush(
        table: 'telecom_operators',
        rows: await db.query('telecom_operators', where: 'is_synced = ?', whereArgs: [0]),
        // Idem pour les opérateurs de référence.
        keep: (row) => !(row['id'] as String).startsWith('ref_'),
      ),
      _TablePush(
        table: 'categories',
        rows: await db.query('categories', where: 'is_synced = ?', whereArgs: [0]),
        // Le pool de catégories est partagé : une suppression reste locale,
        // on ne pousse que les créations et modifications.
        keep: (row) =>
            row['sync_action'] != 'delete' && row['sync_action'] != 'deleted',
      ),
      // Catalogue produits (petit commerce) : l'id local est un UUID v4 généré
      // par l'appareil et sert de clé de rapprochement côté serveur, ce qui
      // rend l'envoi idempotent si deux push transportent la même ligne.
      _TablePush(
        table: 'products',
        rows: await db.query('products', where: 'is_synced = ?', whereArgs: [0]),
      ),
      // Personnel (entreprise) : même schéma que les produits.
      _TablePush(
        table: 'staff_members',
        rows: await db.query('staff_members', where: 'is_synced = ?', whereArgs: [0]),
      ),
    ];

    if (batches.every((b) => b.toPush.isEmpty)) {
      return SyncResult(success: true, pushed: 0, pulled: 0);
    }

    try {
      final response = await _dio.post(
        ApiConfig.syncPush,
        data: {
          for (final batch in batches) batch.payloadKey: batch.toPush,
        },
      );

      if (response.statusCode == 200) {
        // Le corps de la réponse est lu (constat M4) : un 200 ne vaut plus
        // acquittement inconditionnel de toutes les lignes.
        final ack = PushAck.parse(response.data);
        final conflictsBefore = _conflictSeq;
        var pushed = 0;

        for (final batch in batches) {
          final toMark = <Map<String, dynamic>>[];
          for (final row in batch.collected) {
            final id = row['id']?.toString();
            if (id == null) continue;
            final wasSent = batch.sentIds.contains(id);
            if (ack.isAccepted(batch.table, id, wasSent: wasSent)) {
              toMark.add(row);
              if (wasSent) pushed++;
            } else {
              // Ligne refusée : elle reste is_synced = 0 et repartira au
              // prochain push, et le motif est tracé.
              _recordConflict(SyncConflict(
                table: batch.table,
                rowId: id,
                kind: SyncConflictKind.pushRejected,
                detail: ack.reasonFor(batch.table, id),
              ));
            }
          }
          await _markAsSynced(db, batch.table, toMark);
          await _cleanDeleted(db, batch.table);
        }

        return SyncResult(
          success: true,
          pushed: pushed,
          pulled: 0,
          conflicts: _conflictSeq - conflictsBefore,
        );
      }

      return SyncResult(success: false, pushed: 0, pulled: 0,
          error: 'Server returned ${response.statusCode}');
    } on DioException catch (e) {
      return SyncResult(
          success: false, pushed: 0, pulled: 0, error: _errorMsg(e));
    } catch (e) {
      return SyncResult(
          success: false, pushed: 0, pulled: 0, error: e.toString());
    }
  }

  /// Colonnes qu'un pull ne doit pas effacer lorsqu'il les rend nulles.
  /// Voir [_upsert] ; l'appartenance au remap d'une table vaut appartenance
  /// à son schéma.
  static const List<String> _preservableColumns = ['created_at', 'currency'];

  /// `requiredFields` est stocké en JSON ; le backend attend une liste.
  static Map<String, dynamic> _prepareUssdOperation(Map<String, dynamic> row) {
    if (row['requiredFields'] is String) {
      try {
        row['requiredFields'] = jsonDecode(row['requiredFields'] as String);
      } catch (_) {
        row['requiredFields'] = [];
      }
    }
    return row;
  }

  // ---------------------------------------------------------------------------
  // PULL — Fetch server data and upsert into local SQLite
  // ---------------------------------------------------------------------------
  Future<SyncResult> pull() async {
    try {
      final response = await _dio.get(ApiConfig.syncPull);

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final db = await DatabaseService.instance.database;
        final prefs = await SharedPreferences.getInstance();
        _categoryTombstones =
            (prefs.getStringList('deleted_category_keys') ?? const []).toSet();

        final conflictsBefore = _conflictSeq;
        int pulled = 0;
        int deleted = 0;

        // Suppressions distantes à appliquer, tables et identifiants
        // confondus. Calculé avant la transaction pour que les lignes
        // marquées supprimées ne soient pas réinsérées au passage.
        final tombstones = _collectTombstones(data);

        await db.transaction((txn) async {
          Future<void> upsertAll(
            String payloadKey,
            String table,
            Map<String, dynamic> Function(Map<String, dynamic>) remap, {
            String? altPayloadKey,
          }) async {
            final rows = List<Map<String, dynamic>>.from(
                data[payloadKey] ?? (altPayloadKey != null ? data[altPayloadKey] : null) ?? []);
            for (final row in rows) {
              // Une ligne porteuse d'un `deleted_at` est une pierre tombale,
              // pas une mise à jour.
              if (_isTombstoneRow(row)) continue;
              await _upsert(txn, table, remap(row));
              pulled++;
            }
          }

          await upsertAll('accounts', 'accounts', _remapAccount);
          await upsertAll('expenses', 'expenses', _remapExpense);
          await upsertAll('ussdHistories', 'ussd_history', _remapHistory);
          await upsertAll('ussdOperations', 'ussd_operations', _remapOperation);
          await upsertAll(
              'telecomOperators', 'telecom_operators', _remapTelecomOperator);

          final serverCategories =
              List<Map<String, dynamic>>.from(data['categories'] ?? []);
          for (final row in serverCategories) {
            if (_isTombstoneRow(row)) continue;
            await _upsertCategory(txn, _remapCategory(row));
            pulled++;
          }

          await upsertAll('products', 'products', _remapProduct);
          // Le backend expose la clé en snake_case ; la variante camelCase est
          // acceptée par tolérance si le contrat évolue.
          await upsertAll('staff_members', 'staff_members', _remapStaffMember,
              altPayloadKey: 'staffMembers');

          // Suppressions faites sur le serveur ou un autre appareil.
          for (final entry in tombstones.entries) {
            for (final id in entry.value) {
              if (await _applyTombstone(txn, entry.key, id)) deleted++;
            }
          }
        });

        return SyncResult(
          success: true,
          pushed: 0,
          pulled: pulled,
          deleted: deleted,
          conflicts: _conflictSeq - conflictsBefore,
        );
      }

      return SyncResult(success: false, pushed: 0, pulled: 0,
          error: 'Server returned ${response.statusCode}');
    } on DioException catch (e) {
      return SyncResult(
          success: false, pushed: 0, pulled: 0, error: _errorMsg(e));
    } catch (e) {
      return SyncResult(
          success: false, pushed: 0, pulled: 0, error: e.toString());
    }
  }

  // ---------------------------------------------------------------------------
  // Tombstones — suppressions descendantes (constat M4)
  // ---------------------------------------------------------------------------

  static bool _isTombstoneRow(Map<String, dynamic> row) =>
      row['deleted_at'] != null || row['deletedAt'] != null;

  /// Identifiants supprimés côté serveur, par table locale.
  ///
  /// Trois formes sont acceptées, pour n'imposer aucun aller-retour avec le
  /// backend quand celui-ci exposera ses suppressions douces :
  ///  1. une ligne de la liste habituelle portant un `deleted_at` non nul ;
  ///  2. une clé de premier niveau `deleted_<table>` (ou `deletedProducts`…)
  ///     contenant des identifiants ou des objets `{uuid, deleted_at}` ;
  ///  3. une enveloppe `deletions` / `tombstones` : `{ table: [uuid, …] }`.
  ///
  /// Aucune n'est produite par le backend actuel : le pull filtre les lignes
  /// supprimées via la portée par défaut de `SoftDeletes` et ne les mentionne
  /// nulle part. Tant que c'est le cas, cette fonction rend une table vide et
  /// le comportement est inchangé.
  static Map<String, Set<String>> _collectTombstones(Map<String, dynamic> data) {
    final result = <String, Set<String>>{};

    void add(String table, dynamic item) {
      final id = _idOf(item);
      if (id == null || id.isEmpty) return;
      (result[table] ??= <String>{}).add(id);
    }

    // 1. `deleted_at` sur les lignes des listes habituelles.
    for (final entry in _payloadKeys.entries) {
      final rows = data[entry.value];
      if (rows is! List) continue;
      for (final row in rows) {
        if (row is Map && _isTombstoneRow(Map<String, dynamic>.from(row))) {
          add(entry.key, row);
        }
      }
    }

    // 2. clés dédiées `deleted_*` / `deleted*`.
    for (final key in data.keys) {
      final normalized = _normalizeKey(key);
      if (!normalized.startsWith('deleted')) continue;
      final table = _localTableFor(normalized.substring('deleted'.length));
      if (table == null) continue;
      final value = data[key];
      if (value is! List) continue;
      for (final item in value) {
        add(table, item);
      }
    }

    // 3. enveloppe `deletions` / `tombstones`.
    for (final key in const ['deletions', 'tombstones', 'deleted']) {
      final section = data[key];
      if (section is! Map) continue;
      section.forEach((rawTable, value) {
        final table = _localTableFor(rawTable.toString());
        if (table == null || value is! List) return;
        for (final item in value) {
          add(table, item);
        }
      });
    }

    return result;
  }

  /// Applique une suppression distante. Retourne vrai si la ligne a bien été
  /// retirée. Une modification locale non encore synchronisée l'emporte —
  /// comme partout ailleurs — mais le conflit est désormais journalisé.
  Future<bool> _applyTombstone(
      DatabaseExecutor db, String table, String id) async {
    final existing = await db.query(
      table,
      columns: ['is_synced', 'sync_action'],
      where: 'id = ?',
      whereArgs: [id],
    );
    if (existing.isEmpty) return false;
    final isSynced = existing.first['is_synced'];
    final syncAction = existing.first['sync_action'];
    final localDeletePending =
        syncAction == 'delete' || syncAction == 'deleted';
    if (isSynced == 0 && !localDeletePending) {
      _recordConflict(SyncConflict(
        table: table,
        rowId: id,
        kind: SyncConflictKind.remoteDeleteVsLocalEdit,
        detail: 'supprimée sur le serveur, modifiée localement sans envoi',
      ));
      return false;
    }
    await db.delete(table, where: 'id = ?', whereArgs: [id]);
    return true;
  }

  // ---------------------------------------------------------------------------
  // Full sync: push first (to send local deletes/updates), then pull
  // ---------------------------------------------------------------------------
  Future<SyncResult> fullSync() async {
    // Refresh exchange rates in the background (silent failure).
    try {
      await ExchangeRateService().syncRates();
    } catch (_) {}

    // Passe par le même verrou que les push d'arrière-plan : si l'un tourne
    // déjà, on attend son rattrapage plutôt que d'envoyer les mêmes lignes.
    final pushResult = await push();
    if (!pushResult.success) {
      return pushResult;
    }

    final pullResult = await pull();
    return SyncResult(
      success: pullResult.success,
      pushed: pushResult.pushed,
      pulled: pullResult.pulled,
      deleted: pullResult.deleted,
      conflicts: pushResult.conflicts + pullResult.conflicts,
      error: pullResult.error,
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  Future<void> _markAsSynced(
      Database db, String table, List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    final batch = db.batch();
    for (final row in rows) {
      if (row['updated_at'] != null) {
        batch.update(
          table,
          {'is_synced': 1},
          where: 'id = ? AND updated_at = ?',
          whereArgs: [row['id'], row['updated_at']],
        );
      } else {
        batch.update(
          table,
          {'is_synced': 1},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      }
    }
    await batch.commit(noResult: true);
  }

  Future<void> _cleanDeleted(Database db, String table) async {
    await db.delete(table,
        where: '(sync_action = ? OR sync_action = ?) AND is_synced = ?',
        whereArgs: ['deleted', 'delete', 1]);
  }

  Future<void> _upsert(
      DatabaseExecutor db, String table, Map<String, dynamic> row) async {
    final id = row['id'];
    // Colonnes dont la valeur locale doit survivre à une version serveur qui
    // ne les porte pas. Elles ne sont lues que si le remap de *cette* table
    // les expose : toutes les tables n'ont ni `created_at` ni `currency`, et
    // un `SELECT` d'une colonne absente échouerait.
    final preservable = _preservableColumns.where(row.containsKey).toList();
    Map<String, dynamic>? local;
    if (id != null) {
      final List<Map<String, dynamic>> existing = await db.query(
        table,
        columns: ['is_synced', 'sync_action', 'updated_at', ...preservable],
        where: 'id = ?',
        whereArgs: [id],
      );
      if (existing.isNotEmpty) {
        local = existing.first;
        final isSynced = local['is_synced'];
        final syncAction = local['sync_action'];
        if (isSynced == 0 || syncAction == 'delete' || syncAction == 'deleted') {
          // En local, l'enregistrement a été modifié et n'est pas encore
          // synchronisé ou est en cours de suppression : on ne l'écrase pas
          // avec la version du serveur. Si la version serveur est plus
          // récente, elle est perdue — le conflit est journalisé (constat M4),
          // faute de résolution automatique (hors périmètre).
          if (_serverIsNewer(row['updated_at'], local['updated_at'])) {
            _recordConflict(SyncConflict(
              table: table,
              rowId: id.toString(),
              kind: SyncConflictKind.localWinsOverServer,
              detail: 'serveur ${row['updated_at']} > local '
                  '${local['updated_at']} ; version serveur écartée',
              serverVersion: Map<String, dynamic>.from(row),
            ));
          }
          return;
        }
      }
    }
    final localRow = Map<String, dynamic>.from(row)
      ..['is_synced'] = 1
      ..['sync_action'] = 'updated'
      ..['updated_at'] = row['updated_at'] ?? DateTime.now().toIso8601String();
    // Préserver la valeur locale quand la version serveur (plus ancienne, ou
    // d'un backend pas encore à jour) ne porte pas la colonne : le
    // remplacement l'écraserait sinon par NULL.
    //
    // - `created_at` : date d'enregistrement locale (expenses, products,
    //   staff_members) ;
    // - `currency` : devise de saisie (expenses, accounts). Une devise déjà
    //   posée n'est jamais effacée — c'est la règle « jamais réécrite » qui
    //   garantit un historique juste après un changement de pays.
    for (final column in preservable) {
      if (row[column] == null && local != null && local[column] != null) {
        localRow[column] = local[column];
      }
    }
    await db.insert(table, localRow,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Compare deux horodatages ISO 8601 ; faux si l'un des deux manque ou est
  /// illisible (on ne journalise pas un conflit qu'on ne sait pas qualifier).
  static bool _serverIsNewer(dynamic serverUpdatedAt, dynamic localUpdatedAt) {
    final server = DateTime.tryParse(serverUpdatedAt?.toString() ?? '');
    final local = DateTime.tryParse(localUpdatedAt?.toString() ?? '');
    if (server == null || local == null) return false;
    return server.isAfter(local);
  }

  Map<String, dynamic> _remapAccount(Map<String, dynamic> r) => {
        'id': r['uuid'] ?? r['id'] ?? '',
        'name': r['name'] ?? '',
        'balance': r['balance'] != null ? double.parse(r['balance'].toString()) : 0.0,
        // Clé `currency` du contrat de synchronisation, pour les deux tables.
        // Normalisée à la descente : ce qui n'est pas un code ISO 4217 vaut
        // « devise inconnue » (NULL), jamais une valeur inventée.
        'currency': CurrencyConverter.normalizeCode(r['currency']),
        'type': r['type'],
        'icon': r['icon'],
        'color': r['color'],
        'isDefault': (r['isDefault'] == true || r['isDefault'] == 1 || r['is_default'] == true || r['is_default'] == 1) ? 1 : 0,
        'is_shared': (r['isShared'] == true || r['isShared'] == 1 || r['is_shared'] == true || r['is_shared'] == 1) ? 1 : 0,
        'owner_name': r['ownerName'] ?? r['owner_name'],
        'owner_id': r['ownerId'] ?? r['owner_id'],
        'updated_at': r['updated_at'],
      };

  /// Remap snake_case server keys to camelCase SQLite columns for expenses.
  Map<String, dynamic> _remapExpense(Map<String, dynamic> r) {
    final rawLinked = r['is_linked_to_cash_flow'] ?? r['isLinkedToCashFlow'];
    final int linkedVal = (rawLinked == null || rawLinked == true || rawLinked == 1 || rawLinked == '1' || rawLinked == 'true') ? 1 : 0;

    final rawPlanned = r['is_planned'] ?? r['isPlanned'];
    final int plannedVal = (rawPlanned == true || rawPlanned == 1 || rawPlanned == '1' || rawPlanned == 'true') ? 1 : 0;

    return {
      'id': r['uuid'] ?? r['id'] ?? '',
      'title': r['title'] ?? '',
      'amount': r['amount'] != null ? double.parse(r['amount'].toString()) : 0.0,
      'currency': CurrencyConverter.normalizeCode(r['currency']),
      'category': r['category'] ?? 'Autre',
      'date': r['date'] ?? DateTime.now().toIso8601String(),
      'paymentMethod': r['payment_method'] ?? r['paymentMethod'] ?? '',
      'note': r['note'],
      'type': r['type'] ?? 'expense',
      'accountId': r['account_uuid'] ?? r['accountId'],
      'debtTag': r['debt_tag'] ?? r['debtTag'],
      'debtorName': r['debtor_name'] ?? r['debtorName'] ?? '',
      'debtorPhoneNumber': r['debtor_phone_number'] ?? r['debtorPhoneNumber'] ?? '',
      'debtorUserId': (r['debtor_user_id'] ?? r['debtorUserId'])?.toString(),
      'isLinkedToCashFlow': linkedVal,
      'isPlanned': plannedVal,
      'interestRate': r['interest_rate'] != null ? double.tryParse(r['interest_rate'].toString()) : (r['interestRate'] != null ? double.tryParse(r['interestRate'].toString()) : null),
      'repaymentDuration': r['repayment_duration'] as int? ?? r['repaymentDuration'] as int?,
      'durationUnit': r['duration_unit'] ?? r['durationUnit'],
      'repaymentFrequency': r['repayment_frequency'] ?? r['repaymentFrequency'],
      'installmentAmount': r['installment_amount'] != null ? double.tryParse(r['installment_amount'].toString()) : (r['installmentAmount'] != null ? double.tryParse(r['installmentAmount'].toString()) : null),
      'creatorId': (r['creator_id'] ?? r['creatorId'])?.toString(),
      'creatorName': r['creator_name'] ?? r['creatorName'],
      'debtStatus': r['debt_status'] ?? r['debtStatus'] ?? 'pending',
      'dueDate': r['due_date'] ?? r['dueDate'],
      'scheduleStatus': r['schedule_status'] ?? r['scheduleStatus'],
      'reminderAt': r['reminder_at'] ?? r['reminderAt'],
      'created_at': r['created_at'] ?? r['createdAt'],
      'updated_at': r['updated_at'],
    };
  }

  Map<String, dynamic> _remapHistory(Map<String, dynamic> r) => {
        'id': r['uuid'] ?? r['id'] ?? '',
        'operationName': r['operation_name'] ?? r['operationName'] ?? '',
        'providerName': r['provider_name'] ?? r['providerName'] ?? '',
        'ussdCode': r['ussd_code'] != null ? UssdFormatter.normalizeTemplate(r['ussd_code'].toString()) : (r['ussdCode'] != null ? UssdFormatter.normalizeTemplate(r['ussdCode'].toString()) : ''),
        'date': r['date'] ?? DateTime.now().toIso8601String(),
        'status': r['status'] ?? 'success',
        'response': r['response'],
        'updated_at': r['updated_at'],
      };

  Map<String, dynamic> _remapOperation(Map<String, dynamic> r) {
    final def = UssdFormatter.normalizeTemplate((r['default_template'] ?? r['defaultTemplate'])?.toString() ?? '');
    final custRaw = r['custom_template'] ?? r['customTemplate'];
    final cust = custRaw != null ? UssdFormatter.normalizeTemplate(custRaw.toString()) : def;

    final rawEnabled = r['is_enabled'] ?? r['isEnabled'];
    final int enabledVal = rawEnabled != null ? (rawEnabled == 1 || rawEnabled == true || rawEnabled == '1' || rawEnabled == 'true' ? 1 : 0) : 1;

    dynamic reqFields = r['required_fields'] ?? r['requiredFields'];
    if (reqFields != null && reqFields is! String) {
      try {
        reqFields = jsonEncode(reqFields);
      } catch (_) {
        reqFields = null;
      }
    }

    return {
      'id': r['uuid'] ?? r['id'] ?? '',
      'name': r['name'] ?? '',
      'provider': r['provider'] ?? '',
      'category': r['category'] ?? '',
      'defaultTemplate': def,
      'customTemplate': cust,
      'requiredFields': reqFields,
      'is_enabled': enabledVal,
      'updated_at': r['updated_at'],
    };
  }

  Map<String, dynamic> _remapTelecomOperator(Map<String, dynamic> r) => {
        'id': r['uuid'] ?? r['id'] ?? '',
        'name': r['name'] ?? '',
        'userPhoneNumber': r['user_phone_number'] ?? r['userPhoneNumber'],
        'country': (r['country'] != null && r['country'] is Map) ? r['country']['name'] : (r['country'] ?? 'Cameroun'),
        'updated_at': r['updated_at'],
      };

  /// Remap des produits : les clés serveur reprennent les colonnes SQLite en
  /// snake_case, l'identifiant étant renvoyé sous `uuid` (celui généré par
  /// l'appareil à la création).
  Map<String, dynamic> _remapProduct(Map<String, dynamic> r) => {
        'id': (r['uuid'] ?? r['id'] ?? '').toString(),
        'name': r['name'] ?? '',
        // price est NOT NULL en local : jamais de valeur nulle.
        'price': r['price'] != null
            ? (double.tryParse(r['price'].toString()) ?? 0.0)
            : 0.0,
        // photo_path est un chemin de fichier local : si le serveur renvoie
        // plutôt une URL (photo_url), on la stocke dans la même colonne, que
        // Product.fromMap sait déjà interpréter.
        'photo_path': r['photo_path'] ??
            r['photoPath'] ??
            r['photo_url'] ??
            r['photoUrl'],
        'description': r['description'],
        'created_at': r['created_at'] ?? r['createdAt'],
        'updated_at': r['updated_at'],
      };

  /// Remap du personnel : mêmes conventions que les produits.
  Map<String, dynamic> _remapStaffMember(Map<String, dynamic> r) => {
        'id': (r['uuid'] ?? r['id'] ?? '').toString(),
        'name': r['name'] ?? '',
        'role': r['role'],
        'phone_number': r['phone_number'] ?? r['phoneNumber'],
        'email': r['email'],
        'salary': r['salary'] != null
            ? double.tryParse(r['salary'].toString())
            : null,
        'created_at': r['created_at'] ?? r['createdAt'],
        'updated_at': r['updated_at'],
      };

  Map<String, dynamic> _remapCategory(Map<String, dynamic> r) => {
        'id': r['uuid'] ?? r['id'] ?? '',
        'name': r['name'] ?? '',
        'type': r['type'] ?? 'expense',
        'updated_at': r['updated_at'],
      };

  /// Upsert d'une catégorie par (nom, type) : le pool étant partagé, c'est le
  /// nom normalisé qui identifie une catégorie, pas son id. Les lignes locales
  /// non synchronisées (création hors ligne en attente) ne sont pas écrasées,
  /// et les catégories supprimées localement (tombstones) ne sont pas
  /// réinsérées.
  Future<void> _upsertCategory(
      DatabaseExecutor db, Map<String, dynamic> row) async {
    final name = row['name'] as String?;
    final type = row['type'] as String?;
    if (name == null || name.isEmpty || type == null) return;
    if (_categoryTombstones.contains('$type|$name')) return;

    final existing = await db.query(
      'categories',
      where: 'name = ? AND type = ?',
      whereArgs: [name, type],
    );
    final localRow = {
      'id': row['id'],
      'name': name,
      'type': type,
      'is_synced': 1,
      'sync_action': 'updated',
      'updated_at': row['updated_at'] ?? DateTime.now().toIso8601String(),
    };
    if (existing.isNotEmpty) {
      final isSynced = existing.first['is_synced'];
      final syncAction = existing.first['sync_action'];
      if (isSynced == 0 || syncAction == 'delete' || syncAction == 'deleted') {
        // En local, la catégorie a été modifiée et n'est pas encore
        // synchronisée ou est en cours de suppression : on ne l'écrase pas.
        if (_serverIsNewer(row['updated_at'], existing.first['updated_at'])) {
          _recordConflict(SyncConflict(
            table: 'categories',
            rowId: '$type|$name',
            kind: SyncConflictKind.localWinsOverServer,
            detail: 'version serveur écartée au profit du local non envoyé',
            serverVersion: Map<String, dynamic>.from(row),
          ));
        }
        return;
      }
      await db.update(
        'categories',
        localRow,
        where: 'name = ? AND type = ?',
        whereArgs: [name, type],
      );
    } else {
      await db.insert('categories', localRow,
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  String _errorMsg(DioException e) {
    if (e.response != null) {
      final data = e.response?.data;
      if (data is Map) {
        final message = data['message'];
        if (message != null && message.toString().trim().isNotEmpty) {
          return message.toString();
        }
      } else if (data != null && data.toString().trim().isNotEmpty) {
        // Corps non-JSON (page HTML, texte brut, etc.) : on le renvoie tel quel.
        return data.toString();
      }
      return 'Erreur serveur';
    }
    return 'Erreur réseau. Vérifiez votre connexion.';
  }

  // ---------------------------------------------------------------------------
  // Correspondance des clés du contrat
  // ---------------------------------------------------------------------------

  static String _normalizeKey(String key) =>
      key.toLowerCase().replaceAll(RegExp(r'[_\-\s]'), '');

  /// Table SQLite locale désignée par [key], que le serveur l'écrive en
  /// snake_case, en camelCase ou sous le nom de la table locale.
  static String? _localTableFor(String key) {
    final normalized = _normalizeKey(key);
    if (normalized.isEmpty) return null;
    for (final entry in _payloadKeys.entries) {
      if (_normalizeKey(entry.key) == normalized) return entry.key;
      if (_normalizeKey(entry.value) == normalized) return entry.key;
    }
    return null;
  }

  /// Identifiant porté par [item] : une chaîne nue, ou un objet `{id}` /
  /// `{uuid}`.
  static String? _idOf(dynamic item) {
    if (item is String) return item;
    if (item is num) return item.toString();
    if (item is Map) {
      final id = item['id'] ?? item['uuid'];
      return id?.toString();
    }
    return null;
  }

  /// Tables couvertes par la suppression douce côté backend — exposé pour la
  /// documentation du contrat et les tests.
  static List<String> get softDeleteTables =>
      List.unmodifiable(_softDeleteTables);
}

/// Un lot de lignes d'une table, de la lecture locale à l'envoi.
class _TablePush {
  _TablePush({
    required this.table,
    required List<Map<String, dynamic>> rows,
    bool Function(Map<String, dynamic>)? keep,
    Map<String, dynamic> Function(Map<String, dynamic>)? transform,
  })  : collected = rows,
        toPush = rows.where(keep ?? _always).map((row) {
          final copy = Map<String, dynamic>.from(row);
          // Le serveur attend « deleted » là où le local note « delete ».
          if (copy['sync_action'] == 'delete') {
            copy['sync_action'] = 'deleted';
          }
          return transform == null ? copy : transform(copy);
        }).toList();

  static bool _always(Map<String, dynamic> _) => true;

  /// Table SQLite locale.
  final String table;

  /// Lignes non synchronisées lues localement.
  final List<Map<String, dynamic>> collected;

  /// Lignes réellement envoyées au serveur.
  final List<Map<String, dynamic>> toPush;

  String get payloadKey => SyncService._payloadKeys[table] ?? table;

  late final Set<String> sentIds =
      toPush.map((row) => row['id']?.toString()).whereType<String>().toSet();
}

/// Accusé de réception d'un push.
///
/// **Contrat manquant côté backend** : `POST /api/sync/push` répond
/// aujourd'hui `{"message": "Sync successful"}` (ou 500 pour tout le lot, la
/// transaction étant globale). Aucun détail par ligne n'est disponible, donc
/// [opaque] vaut vrai et l'on retombe sur le comportement historique — toutes
/// les lignes envoyées sont marquées synchronisées. Dès que le serveur
/// renverra un détail dans l'une des formes reconnues par [parse], il sera
/// exploité sans modification de l'application.
class PushAck {
  const PushAck._(this.accepted, this.rejected, this.reasons)
      : opaque = false;

  /// Réponse sans détail exploitable : tout est réputé accepté.
  const PushAck.opaque()
      : accepted = const {},
        rejected = const {},
        reasons = const {},
        opaque = true;

  /// Identifiants explicitement acceptés, par table locale. Quand une table y
  /// figure, l'accusé vaut liste blanche pour cette table.
  final Map<String, Set<String>> accepted;

  /// Identifiants explicitement refusés, par table locale.
  final Map<String, Set<String>> rejected;

  /// Motif du refus, indexé par « table|id ».
  final Map<String, String> reasons;

  final bool opaque;

  /// Formes reconnues, toutes optionnelles et cumulables :
  ///  - `rejected` / `failed` / `errors` / `conflicts` :
  ///    `{ "<table>": ["<uuid>", {"id": "<uuid>", "error": "<motif>"}] }`
  ///  - `accepted` / `synced` / `applied` / `results` : même forme ; un objet
  ///    peut porter `status` (`ok`, `created`, `updated`, `deleted`… contre
  ///    tout autre valeur = refus).
  ///
  /// Les noms de table sont reconnus en snake_case, en camelCase ou sous le
  /// nom de la table locale.
  static PushAck parse(dynamic body) {
    if (body is! Map) return const PushAck.opaque();

    final accepted = <String, Set<String>>{};
    final rejected = <String, Set<String>>{};
    final reasons = <String, String>{};

    const okStatuses = {
      'ok',
      'success',
      'accepted',
      'synced',
      'created',
      'updated',
      'deleted',
      'unchanged',
    };

    void readSection(dynamic section, {required bool defaultOk}) {
      if (section is! Map) return;
      section.forEach((rawTable, value) {
        final table = SyncService._localTableFor(rawTable.toString());
        if (table == null || value is! List) return;
        for (final item in value) {
          final id = SyncService._idOf(item);
          if (id == null || id.isEmpty) continue;
          var isOk = defaultOk;
          if (item is Map) {
            final status =
                (item['status'] ?? item['result'])?.toString().toLowerCase();
            if (status != null) {
              isOk = okStatuses.contains(status);
            }
            final reason = item['error'] ?? item['message'] ?? item['reason'];
            if (reason != null) {
              reasons['$table|$id'] = reason.toString();
            }
          }
          (isOk ? accepted : rejected).putIfAbsent(table, () => <String>{}).add(id);
        }
      });
    }

    for (final key in const ['rejected', 'failed', 'errors', 'conflicts']) {
      readSection(body[key], defaultOk: false);
    }
    for (final key in const ['accepted', 'synced', 'applied', 'results']) {
      readSection(body[key], defaultOk: true);
    }

    if (accepted.isEmpty && rejected.isEmpty) return const PushAck.opaque();
    return PushAck._(accepted, rejected, reasons);
  }

  /// Vrai si la ligne peut être marquée synchronisée.
  ///
  /// [wasSent] distingue les lignes réellement envoyées de celles écartées
  /// avant l'envoi sur décision locale (opérations et opérateurs de référence,
  /// suppressions de catégories) : ces dernières n'ont pas de verdict serveur
  /// et restent marquées.
  bool isAccepted(String table, String id, {required bool wasSent}) {
    if (opaque || !wasSent) return true;
    if (rejected[table]?.contains(id) ?? false) return false;
    final whitelist = accepted[table];
    if (whitelist == null) return true;
    return whitelist.contains(id);
  }

  String? reasonFor(String table, String id) => reasons['$table|$id'];
}

/// Nature d'un conflit de synchronisation.
enum SyncConflictKind {
  /// Version locale non synchronisée conservée, version serveur plus récente
  /// écartée.
  localWinsOverServer,

  /// Ligne supprimée sur le serveur mais modifiée localement sans envoi : la
  /// suppression n'est pas appliquée.
  remoteDeleteVsLocalEdit,

  /// Ligne refusée par le serveur lors d'un push.
  pushRejected,
}

/// Trace d'un conflit. Aucune résolution automatique n'est tentée : l'objet
/// existe pour qu'un écran puisse plus tard présenter l'arbitrage à
/// l'utilisateur, et pour qu'un conflit cesse d'être invisible.
class SyncConflict {
  SyncConflict({
    required this.table,
    required this.rowId,
    required this.kind,
    this.detail,
    this.serverVersion,
    DateTime? detectedAt,
  }) : detectedAt = detectedAt ?? DateTime.now();

  final String table;
  final String rowId;
  final SyncConflictKind kind;
  final String? detail;

  /// Version serveur écartée, conservée telle quelle pour un affichage ou une
  /// reprise manuelle ultérieure.
  final Map<String, dynamic>? serverVersion;

  final DateTime detectedAt;

  @override
  String toString() =>
      'conflit ${kind.name} sur $table#$rowId${detail != null ? ' — $detail' : ''}';
}

class SyncResult {
  final bool success;
  final int pushed;
  final int pulled;

  /// Lignes supprimées localement en réponse à une suppression distante.
  final int deleted;

  /// Nombre de conflits journalisés (voir [SyncService.conflicts]).
  final int conflicts;

  final String? error;

  SyncResult({
    required this.success,
    required this.pushed,
    required this.pulled,
    this.deleted = 0,
    this.conflicts = 0,
    this.error,
  });

  @override
  String toString() =>
      'SyncResult(success: $success, pushed: $pushed, pulled: $pulled, '
      'deleted: $deleted, conflicts: $conflicts, error: $error)';
}
