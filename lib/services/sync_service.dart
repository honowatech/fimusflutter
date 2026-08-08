import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:sqflite/sqflite.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/exchange_rate_service.dart';
import '../utils/api_config.dart';
import '../utils/ussd_formatter.dart';

/// Handles bidirectional synchronisation between local SQLite and remote API.
class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;

  final AuthService _authService;
  late final Dio _dio;

  SyncService._internal({AuthService? authService})
      : _authService = authService ?? AuthService() {
    _dio = Dio();
    _dio.options.headers['Accept'] = 'application/json';

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _authService.getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
    ));
  }

  // ---------------------------------------------------------------------------
  // PUSH — Send unsynced local rows to the server
  // ---------------------------------------------------------------------------
  Future<SyncResult> push() async {
    final db = await DatabaseService.instance.database;

    // Collect all unsynced rows from every table
    final accounts = await db.query('accounts',
        where: 'is_synced = ?', whereArgs: [0]);
    final expenses = await db.query('expenses',
        where: 'is_synced = ?', whereArgs: [0]);
    final ussdHistories = await db.query('ussd_history',
        where: 'is_synced = ?', whereArgs: [0]);
    final ussdOperations = await db.query('ussd_operations',
        where: 'is_synced = ?', whereArgs: [0]);
    final telecomOperators = await db.query('telecom_operators',
        where: 'is_synced = ?', whereArgs: [0]);

    // Map 'delete' action to 'deleted' and filter out reference operators/operations
    final accountsToPush = accounts.map((row) {
      final copy = Map<String, dynamic>.from(row);
      if (copy['sync_action'] == 'delete') {
        copy['sync_action'] = 'deleted';
      }
      return copy;
    }).toList();

    final expensesToPush = expenses.map((row) {
      final copy = Map<String, dynamic>.from(row);
      if (copy['sync_action'] == 'delete') {
        copy['sync_action'] = 'deleted';
      }
      return copy;
    }).toList();

    final ussdHistoriesToPush = ussdHistories.map((row) {
      final copy = Map<String, dynamic>.from(row);
      if (copy['sync_action'] == 'delete') {
        copy['sync_action'] = 'deleted';
      }
      return copy;
    }).toList();

    // Do not push reference USSD operations (prefix 'ref_')
    final ussdOperationsToPush = ussdOperations
        .where((row) => !(row['id'] as String).startsWith('ref_'))
        .map((row) {
      final copy = Map<String, dynamic>.from(row);
      if (copy['sync_action'] == 'delete') {
        copy['sync_action'] = 'deleted';
      }
      // Decode requiredFields JSON string to List for backend validation/processing
      if (copy['requiredFields'] != null && copy['requiredFields'] is String) {
        try {
          copy['requiredFields'] = jsonDecode(copy['requiredFields'] as String);
        } catch (_) {
          copy['requiredFields'] = [];
        }
      }
      return copy;
    }).toList();

    // Do not push reference operators (prefix 'ref_')
    final telecomOperatorsToPush = telecomOperators
        .where((row) => !(row['id'] as String).startsWith('ref_'))
        .map((row) {
      final copy = Map<String, dynamic>.from(row);
      if (copy['sync_action'] == 'delete') {
        copy['sync_action'] = 'deleted';
      }
      return copy;
    }).toList();

    if (accountsToPush.isEmpty &&
        expensesToPush.isEmpty &&
        ussdHistoriesToPush.isEmpty &&
        ussdOperationsToPush.isEmpty &&
        telecomOperatorsToPush.isEmpty) {
      return SyncResult(success: true, pushed: 0, pulled: 0);
    }

    try {
      final response = await _dio.post(
        ApiConfig.syncPush,
        data: {
          'accounts': accountsToPush,
          'expenses': expensesToPush,
          'ussdHistories': ussdHistoriesToPush,
          'ussdOperations': ussdOperationsToPush,
          'telecomOperators': telecomOperatorsToPush,
        },
      );

      if (response.statusCode == 200) {
        // Mark all pushed rows as synced
        await _markAsSynced(db, 'accounts', accounts);
        await _markAsSynced(db, 'expenses', expenses);
        await _markAsSynced(db, 'ussd_history', ussdHistories);
        await _markAsSynced(db, 'ussd_operations', ussdOperations);
        await _markAsSynced(db, 'telecom_operators', telecomOperators);

        // Clean up locally-deleted rows
        await _cleanDeleted(db, 'accounts');
        await _cleanDeleted(db, 'expenses');
        await _cleanDeleted(db, 'ussd_history');
        await _cleanDeleted(db, 'ussd_operations');
        await _cleanDeleted(db, 'telecom_operators');

        final total = accountsToPush.length +
            expensesToPush.length +
            ussdHistoriesToPush.length +
            ussdOperationsToPush.length +
            telecomOperatorsToPush.length;
        return SyncResult(success: true, pushed: total, pulled: 0);
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
  // PULL — Fetch server data and upsert into local SQLite
  // ---------------------------------------------------------------------------
  Future<SyncResult> pull() async {
    try {
      final response = await _dio.get(ApiConfig.syncPull);

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final db = await DatabaseService.instance.database;

        int pulled = 0;

        await db.transaction((txn) async {
          final serverAccounts =
              List<Map<String, dynamic>>.from(data['accounts'] ?? []);
          for (final row in serverAccounts) {
            await _upsert(txn, 'accounts', _remapAccount(row));
            pulled++;
          }

          final serverExpenses =
              List<Map<String, dynamic>>.from(data['expenses'] ?? []);
          for (final row in serverExpenses) {
            await _upsert(txn, 'expenses', _remapExpense(row));
            pulled++;
          }

          final serverHistories =
              List<Map<String, dynamic>>.from(data['ussdHistories'] ?? []);
          for (final row in serverHistories) {
            await _upsert(txn, 'ussd_history', _remapHistory(row));
            pulled++;
          }

          final serverOperations =
              List<Map<String, dynamic>>.from(data['ussdOperations'] ?? []);
          for (final row in serverOperations) {
            await _upsert(txn, 'ussd_operations', _remapOperation(row));
            pulled++;
          }

          final serverOperators =
              List<Map<String, dynamic>>.from(data['telecomOperators'] ?? []);
          for (final row in serverOperators) {
            await _upsert(txn, 'telecom_operators', _remapTelecomOperator(row));
            pulled++;
          }
        });

        return SyncResult(success: true, pushed: 0, pulled: pulled);
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
  // Full sync: pull first, then push
  // ---------------------------------------------------------------------------
  Future<SyncResult> fullSync() async {
    // Refresh exchange rates in the background (silent failure).
    try {
      await ExchangeRateService().syncRates();
    } catch (_) {}

    final pullResult = await pull();
    if (!pullResult.success) {
      return pullResult;
    }

    final pushResult = await push();
    return SyncResult(
      success: pushResult.success,
      pushed: pushResult.pushed,
      pulled: pullResult.pulled,
      error: pushResult.error,
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  Future<void> _markAsSynced(
      Database db, String table, List<Map<String, dynamic>> rows) async {
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
    if (id != null) {
      final List<Map<String, dynamic>> existing = await db.query(
        table,
        columns: ['is_synced'],
        where: 'id = ?',
        whereArgs: [id],
      );
      if (existing.isNotEmpty && existing.first['is_synced'] == 0) {
        // En local, l'enregistrement a été modifié et n'est pas encore synchronisé.
        // On ne l'écrase pas avec la version du serveur.
        return;
      }
    }
    final localRow = Map<String, dynamic>.from(row)
      ..['is_synced'] = 1
      ..['sync_action'] = 'updated'
      ..['updated_at'] = row['updated_at'] ?? DateTime.now().toIso8601String();
    await db.insert(table, localRow,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Map<String, dynamic> _remapAccount(Map<String, dynamic> r) => {
        'id': r['uuid'] ?? r['id'] ?? '',
        'name': r['name'] ?? '',
        'balance': r['balance'] != null ? double.parse(r['balance'].toString()) : 0.0,
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

  String _errorMsg(DioException e) {
    if (e.response != null) {
      return e.response?.data['message'] ?? 'Erreur serveur';
    }
    return 'Erreur réseau. Vérifiez votre connexion.';
  }
}

class SyncResult {
  final bool success;
  final int pushed;
  final int pulled;
  final String? error;

  SyncResult({
    required this.success,
    required this.pushed,
    required this.pulled,
    this.error,
  });

  @override
  String toString() =>
      'SyncResult(success: $success, pushed: $pushed, pulled: $pulled, error: $error)';
}
