import 'package:dio/dio.dart';
import 'package:sqflite/sqflite.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../utils/api_config.dart';

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

    if (accounts.isEmpty &&
        expenses.isEmpty &&
        ussdHistories.isEmpty &&
        ussdOperations.isEmpty &&
        telecomOperators.isEmpty) {
      return SyncResult(success: true, pushed: 0, pulled: 0);
    }

    try {
      final response = await _dio.post(
        ApiConfig.syncPush,
        data: {
          'accounts': accounts,
          'expenses': expenses,
          'ussdHistories': ussdHistories,
          'ussdOperations': ussdOperations,
          'telecomOperators': telecomOperators,
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

        final total = accounts.length +
            expenses.length +
            ussdHistories.length +
            ussdOperations.length +
            telecomOperators.length;
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

        final serverAccounts =
            List<Map<String, dynamic>>.from(data['accounts'] ?? []);
        for (final row in serverAccounts) {
          await _upsert(db, 'accounts', _remapAccount(row));
          pulled++;
        }

        final serverExpenses =
            List<Map<String, dynamic>>.from(data['expenses'] ?? []);
        for (final row in serverExpenses) {
          await _upsert(db, 'expenses', _remapExpense(row));
          pulled++;
        }

        final serverHistories =
            List<Map<String, dynamic>>.from(data['ussdHistories'] ?? []);
        for (final row in serverHistories) {
          await _upsert(db, 'ussd_history', _remapHistory(row));
          pulled++;
        }

        final serverOperations =
            List<Map<String, dynamic>>.from(data['ussdOperations'] ?? []);
        for (final row in serverOperations) {
          await _upsert(db, 'ussd_operations', _remapOperation(row));
          pulled++;
        }

        final serverOperators =
            List<Map<String, dynamic>>.from(data['telecomOperators'] ?? []);
        for (final row in serverOperators) {
          await _upsert(db, 'telecom_operators', _remapTelecomOperator(row));
          pulled++;
        }

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
    final pullResult = await pull();
    final pushResult = await push();
    return SyncResult(
      success: pushResult.success && pullResult.success,
      pushed: pushResult.pushed,
      pulled: pullResult.pulled,
      error: pullResult.error ?? pushResult.error,
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  Future<void> _markAsSynced(
      Database db, String table, List<Map<String, dynamic>> rows) async {
    for (final row in rows) {
      await db.update(
        table,
        {'is_synced': 1},
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }
  }

  Future<void> _cleanDeleted(Database db, String table) async {
    await db.delete(table,
        where: '(sync_action = ? OR sync_action = ?) AND is_synced = ?',
        whereArgs: ['deleted', 'delete', 1]);
  }

  Future<void> _upsert(
      Database db, String table, Map<String, dynamic> row) async {
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
      ..['sync_action'] = 'updated';
    await db.insert(table, localRow,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Map<String, dynamic> _remapAccount(Map<String, dynamic> r) => {
        'id': r['uuid'] ?? r['id'],
        'name': r['name'],
        'balance': r['balance'] != null ? double.parse(r['balance'].toString()) : 0.0,
        'type': r['type'],
        'icon': r['icon'],
        'color': r['color'],
        'is_shared': (r['isShared'] == true || r['isShared'] == 1) ? 1 : 0,
        'owner_name': r['ownerName'],
        'owner_id': r['ownerId'],
      };

  /// Remap snake_case server keys to camelCase SQLite columns for expenses.
  Map<String, dynamic> _remapExpense(Map<String, dynamic> r) => {
        'id': r['uuid'] ?? r['id'],
        'title': r['title'],
        'amount': r['amount'] != null ? double.parse(r['amount'].toString()) : 0.0,
        'category': r['category'],
        'date': r['date'],
        'note': r['note'],
        'type': r['type'],
        'accountId': r['account_uuid'] ?? r['accountId'],
        'debtTag': r['debt_tag'] ?? r['debtTag'],
        'debtorUserId': r['debtor_user_id'] ?? r['debtorUserId']?.toString(),
        'isLinkedToCashFlow': r['is_linked_to_cash_flow'] ?? r['isLinkedToCashFlow'] ?? 1,
        'isPlanned': r['is_planned'] ?? r['isPlanned'] ?? 0,
        'interestRate': r['interest_rate'] ?? r['interestRate'],
        'repaymentDuration': r['repayment_duration'] ?? r['repaymentDuration'],
        'durationUnit': r['duration_unit'] ?? r['durationUnit'],
        'repayment_frequency': r['repayment_frequency'] ?? r['repaymentFrequency'],
        'installmentAmount': r['installment_amount'] ?? r['installmentAmount'],
        'creatorId': r['creator_id'] ?? r['creatorId']?.toString(),
        'creatorName': r['creator_name'] ?? r['creatorName'],
      };

  Map<String, dynamic> _remapHistory(Map<String, dynamic> r) => {
        'id': r['uuid'] ?? r['id'],
        'operationName': r['operation_name'] ?? r['operationName'],
        'providerName': r['provider_name'] ?? r['providerName'],
        'ussdCode': r['ussd_code'] ?? r['ussdCode'],
        'date': r['date'],
        'status': r['status'] ?? 'success',
        'response': r['response'],
      };

  Map<String, dynamic> _remapOperation(Map<String, dynamic> r) => {
        'id': r['uuid'] ?? r['id'],
        'name': r['name'],
        'provider': r['provider'],
        'category': r['category'],
        'defaultTemplate': r['default_template'] ?? r['defaultTemplate'],
        'customTemplate': r['custom_template'] ?? r['customTemplate'],
        'requiredFields': r['required_fields'] ?? r['requiredFields'],
      };

  Map<String, dynamic> _remapTelecomOperator(Map<String, dynamic> r) => {
        'id': r['uuid'] ?? r['id'],
        'name': r['name'],
        'userPhoneNumber': r['user_phone_number'] ?? r['userPhoneNumber'],
        'country': (r['country'] != null && r['country'] is Map) ? r['country']['name'] : (r['country'] ?? 'Cameroun'),
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
