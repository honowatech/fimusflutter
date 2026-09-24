import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../models/ussd_operation.dart';
import '../models/operator.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';
import '../utils/api_config.dart';
import '../utils/ussd_formatter.dart';

// IDs stables pour les opérateurs de référence — doit correspondre au format
// utilisé par refreshCountryUssd() pour éviter les doublons.
const String _kRefPrefix = 'ref_';

String _refOpId(String country, String opName) =>
    '$_kRefPrefix${country.toLowerCase().replaceAll(' ', '_')}_'
    '${opName.toLowerCase().replaceAll(' ', '_')}';

String _refCodeId(String opId, String action) =>
    '${opId}_${action.toLowerCase().replaceAll(' ', '_')}';

List<Map<String, dynamic>> _parseJsonList(String jsonStr) {
  try {
    final decoded = jsonDecode(jsonStr);
    if (decoded is List) {
      return List<Map<String, dynamic>>.from(decoded);
    }
  } catch (_) {}
  return [];
}

class UssdProvider with ChangeNotifier {
  List<TelecomOperator> _operators = [];
  List<UssdOperation> _operations = [];
  List<String> _categories = [];

  // Cache du catalogue de référence backend : [{country, operators:[{name, ussd_codes:[]}]}]
  List<Map<String, dynamic>> _referenceUssd = [];

  // Ensemble des pays dont les USSD ont déjà été injectés (évite les doublons)
  final Set<String> _injectedCountries = {};

  Future<void>? _loadFuture;
  Future<void>? _fetchRefFuture;

  List<TelecomOperator> get operators => _operators;
  List<UssdOperation> get operations => _operations;
  List<String> get categories => _categories;

  UssdProvider() {
    loadData();
  }

  // ---------------------------------------------------------------------------
  // CHARGEMENT INITIAL
  // ---------------------------------------------------------------------------

  Future<void> loadData() {
    return _loadFuture ??= _performLoadData();
  }

  Future<void> _performLoadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final db = await DatabaseService.instance.database;

      // Force existing reference operators/operations to be marked as synced
      await db.update(
        'telecom_operators',
        {'is_synced': 1},
        where: "id LIKE 'ref_%' AND is_synced = 0",
      );
      await db.update(
        'ussd_operations',
        {'is_synced': 1},
        where: "id LIKE 'ref_%' AND is_synced = 0",
      );

      // --- Opérateurs ---
      // Migration : supprimer les anciens opérateurs hardcodés au profit du backend
      await _migrateHardcodedOperators(db);

      final List<Map<String, dynamic>> opMaps = await db.query(
        'telecom_operators',
        where: "sync_action != 'delete' OR sync_action IS NULL",
      );
      if (opMaps.isNotEmpty) {
        _operators = opMaps.map((e) => TelecomOperator.fromJson(e)).toList();
      }

      // --- Catégories ---
      final List<String>? cats = prefs.getStringList('ussd_categories');
      _categories = cats ?? _getDefaultCategories();
      if (cats == null) await _saveCategories();

      // --- Opérations (uniquement les non-supprimées) ---
      final List<Map<String, dynamic>> maps = await db.query(
        'ussd_operations',
        where: "sync_action != 'delete' OR sync_action IS NULL",
      );
      if (maps.isNotEmpty) {
        _operations = maps.map((e) => UssdOperation.fromDbMap(e)).toList();
        await _migrateTemplates(db);
        await _disableCameroonCreditOperations(db);
      }

      // Marquer les pays déjà injectés pour ne pas re-créer des doublons
      for (final op in _operators) {
        if (op.id.startsWith(_kRefPrefix)) {
          final parts = op.id.replaceFirst(_kRefPrefix, '').split('_');
          if (parts.isNotEmpty) {
            _injectedCountries.add(op.country.toLowerCase());
          }
        }
      }

      // Charger le catalogue de référence depuis le cache local (SharedPreferences)
      final cached = prefs.getString('cached_reference_ussd');
      if (cached != null && _referenceUssd.isEmpty) {
        try {
          _referenceUssd = await compute(_parseJsonList, cached);
          if (_referenceUssd.isNotEmpty) {
            debugPrint(
              'UssdProvider: ${_referenceUssd.length} pays pré-chargés depuis le cache local',
            );
          }
        } catch (e) {
          debugPrint('UssdProvider: erreur décodage cache local ussd: $e');
        }
      }

      notifyListeners();

      // Récupération asynchrone du catalogue backend + injection du pays courant
      unawaited(_fetchAndInjectForSavedCountry());
    } finally {
      _loadFuture = null;
    }
  }

  // ---------------------------------------------------------------------------
  // MIGRATIONS
  // ---------------------------------------------------------------------------

  /// Supprime les opérateurs hardcodés de l'ancienne version (op_orange, op_mtn…)
  /// s'ils existent encore en base, pour éviter les doublons avec les opérateurs
  /// de référence téléchargés depuis le backend.
  /// Protège les opérations personnalisées : si l'utilisateur a édité un template,
  /// on garde ses données dans un opérateur utilisateur.
  Future<void> _migrateHardcodedOperators(Database db) async {
    const hardcodedIds = ['op_orange', 'op_mtn'];
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('_hardcoded_ops_migrated') == true) return;

    for (final id in hardcodedIds) {
      // Supprimer l'opérateur hardcodé et ses opérations de la base locale
      await db.delete('ussd_operations', where: 'provider = ?', whereArgs: [id]);
      await db.delete('telecom_operators', where: 'id = ?', whereArgs: [id]);
    }

    await prefs.setBool('_hardcoded_ops_migrated', true);
    debugPrint('UssdProvider: migration des opérateurs hardcodés effectuée');
  }

  Future<void> _migrateTemplates(Database db) async {
    bool migrated = false;
    for (var op in _operations) {
      final normalizedDef = UssdFormatter.normalizeTemplate(op.defaultTemplate);
      final normalizedCust = UssdFormatter.normalizeTemplate(op.customTemplate);
      if (op.defaultTemplate != normalizedDef || op.customTemplate != normalizedCust) {
        op.defaultTemplate = normalizedDef;
        op.customTemplate = normalizedCust;
        migrated = true;
      }
      if (op.id == 'orange_credit' && op.defaultTemplate == '*150*2*1*{amount}#') {
        op.defaultTemplate = '#150*2*1*{amount}#';
        if (op.customTemplate == '*150*2*1*{amount}#') op.customTemplate = '#150*2*1*{amount}#';
        migrated = true;
      }

      if (op.provider.toLowerCase().contains('mtn') &&
          (op.name.toLowerCase().contains('transfert') || op.name.toLowerCase().contains('transfer'))) {
        final newTemplate = '*126*1*1*{phone}*{amount}#';
        if (op.defaultTemplate != newTemplate) {
          op.defaultTemplate = newTemplate;
          op.customTemplate = newTemplate;
          migrated = true;
        }
      }
      if (migrated) {
        await db.update('ussd_operations', op.toDbMap(), where: 'id = ?', whereArgs: [op.id]);
        migrated = false;
      }
    }
  }

  Future<void> _disableCameroonCreditOperations(Database db) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('_cameroon_credit_disabled_v1') == true) return;

    for (var op in _operations) {
      final opProvider = op.provider.toLowerCase();
      final opName = op.name.toLowerCase();
      final opCategory = op.category.toLowerCase();
      final isCredit = opName.contains('crédit') || opName.contains('credit') || opCategory == 'crédit' || opCategory == 'credit' || op.id.contains('credit');

      final operator = _operators.firstWhere(
        (o) => o.id == op.provider,
        orElse: () => TelecomOperator(id: '', name: '', country: ''),
      );
      final opCountry = operator.country.toLowerCase();
      final isOrangeOrMtn = operator.name.toLowerCase().contains('orange') ||
          operator.name.toLowerCase().contains('mtn') ||
          opProvider.contains('orange') ||
          opProvider.contains('mtn');

      if (isCredit && isOrangeOrMtn && (opCountry.contains('cameroun') || opCountry.isEmpty || opProvider.contains('cameroun') || opProvider.startsWith('op_'))) {
        op.isEnabled = false;
        await db.update('ussd_operations', op.toDbMap(), where: 'id = ?', whereArgs: [op.id]);
      }
    }

    await prefs.setBool('_cameroon_credit_disabled_v1', true);
  }

  // ---------------------------------------------------------------------------
  // RÉFÉRENCE BACKEND
  // ---------------------------------------------------------------------------

  /// Télécharge le catalogue USSD de référence depuis le backend.
  Future<void> _fetchReferenceUssd() {
    return _fetchRefFuture ??= _performFetchReferenceUssd();
  }

  Future<void> _performFetchReferenceUssd() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Si _referenceUssd est toujours vide, charger depuis le cache local
      if (_referenceUssd.isEmpty) {
        final cached = prefs.getString('cached_reference_ussd');
        if (cached != null) {
          try {
            _referenceUssd = await compute(_parseJsonList, cached);
            if (_referenceUssd.isNotEmpty) {
              debugPrint(
                'UssdProvider: ${_referenceUssd.length} pays chargés depuis le cache local dans _fetchReferenceUssd',
              );
            }
          } catch (e) {
            debugPrint('UssdProvider: erreur décodage cache local ussd: $e');
          }
        }
      }

      try {
        final dio = Dio()
          ..options.connectTimeout = const Duration(seconds: 8)
          ..options.receiveTimeout = const Duration(seconds: 8);
        final response = await dio.get(ApiConfig.ussdByCountry);
        if (response.statusCode == 200 && response.data is List) {
          _referenceUssd = List<Map<String, dynamic>>.from(response.data as List);
          final rawData = response.data as List;
          unawaited(compute(jsonEncode, rawData).then((jsonStr) {
            prefs.setString('cached_reference_ussd', jsonStr);
          }));
          debugPrint(
            'UssdProvider: ${_referenceUssd.length} pays chargés depuis le backend et mis en cache',
          );
        }
      } on DioException catch (e) {
        debugPrint(
          'UssdProvider: impossible de récupérer les USSD de référence (réseau): ${e.message}',
        );
      } catch (e) {
        debugPrint('UssdProvider: erreur inattendue: $e');
      }

      if (_referenceUssd.isEmpty) {
        _referenceUssd = _getOfflineFallbackReferenceUssd();
        debugPrint(
          'UssdProvider: utilisation du catalogue de référence hors-ligne (${_referenceUssd.length} pays)',
        );
      }
    } finally {
      _fetchRefFuture = null;
    }
  }

  /// Charge le catalogue puis injecte automatiquement les USSD du pays du profil.
  Future<void> _fetchAndInjectForSavedCountry() async {
    await _fetchReferenceUssd();

    final prefs = await SharedPreferences.getInstance();
    final profileJson = prefs.getString('user_profile');
    if (profileJson == null) return;

    try {
      final decoded = jsonDecode(profileJson) as Map<String, dynamic>;
      final country = decoded['country'] as String?;
      if (country != null && country.isNotEmpty && country != 'Tous') {
        await refreshCountryUssd(country);
      }
    } catch (e) {
      debugPrint('UssdProvider: erreur lecture profil: $e');
    }
  }

  /// Injecte les opérateurs et codes USSD de référence pour un pays donné.
  ///
  /// Appelé :
  ///   - Au démarrage via [_fetchAndInjectForSavedCountry]
  ///   - Quand l'utilisateur sélectionne un pays dans l'UI
  ///
  /// Les opérateurs/opérations existants (même ID) ne sont JAMAIS écrasés.
  Future<void> refreshCountryUssd(String country) async {
    if (_referenceUssd.isEmpty) {
      await _fetchReferenceUssd();
    }

    if (_referenceUssd.isEmpty) {
      debugPrint(
        'UssdProvider: catalogue vide, impossible d\'injecter pour $country',
      );
      return;
    }

    final countryKey = country.toLowerCase();

    // Trouver l'entrée de référence pour ce pays
    Map<String, dynamic> countryEntry = {};
    for (final entry in _referenceUssd) {
      final name = (entry['country'] as String?) ?? '';
      if (name.toLowerCase() == countryKey) {
        countryEntry = entry;
        break;
      }
    }

    if (countryEntry.isEmpty) {
      debugPrint(
        'UssdProvider: aucune donnée de référence pour "$country"',
      );
      return;
    }

    final db = await DatabaseService.instance.database;
    bool changed = false;

    final refOperators =
        List<Map<String, dynamic>>.from(countryEntry['operators'] as List? ?? []);

    for (final refOp in refOperators) {
      final opName = (refOp['name'] as String?) ?? '';
      if (opName.isEmpty) continue;

      final refCodes =
          List<Map<String, dynamic>>.from(refOp['ussd_codes'] as List? ?? []);

      // ID stable dérivé de pays + nom opérateur
      final opId = _refOpId(country, opName);

      // Insérer l'opérateur s'il n'existe pas encore
      if (!_operators.any((o) => o.id == opId)) {
        final op = TelecomOperator(id: opId, name: opName, country: country);
        _operators.add(op);

        await db.insert(
          'telecom_operators',
          {
            'id': opId,
            'name': opName,
            'userPhoneNumber': null,
            'country': country,
            'is_synced': 1, // donnée de référence, ne pas re-pousser
            'sync_action': 'created',
            'updated_at': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        changed = true;
        debugPrint('UssdProvider: opérateur inséré [$opId] $opName ($country)');
      }

      // Insérer chaque code USSD comme opération si absent
      for (final code in refCodes) {
        final action = (code['action'] as String?) ?? '';
        String template = (code['code'] as String?) ?? '';
        if (action.isEmpty || template.isEmpty) continue;

        if (opName.toLowerCase().contains('mtn') &&
            (action.toLowerCase().contains('transfert') || action.toLowerCase().contains('transfer'))) {
          template = '*126*1*1*{contact}*{amount}#';
        }

        final codeId = _refCodeId(opId, action);

        if (!_operations.any((o) => o.id == codeId)) {
          // Normalise les placeholders : ${phone} → {phone} pour compatibilité
          // avec le système de formulaires de l'app
          final normalizedTemplate = template.replaceAllMapped(
            RegExp(r'\$\{(\w+)\}'),
            (m) => '{${m.group(1)}}',
          );

          final requiredFields = RegExp(r'\{(\w+)\}')
              .allMatches(normalizedTemplate)
              .map((m) => m.group(1)!)
              .toSet()
              .toList();

          bool isOpEnabled = true;
          final actionLower = action.toLowerCase();
          final categoryInferred = _inferCategory(action);
          if (country.toLowerCase().contains('cameroun') &&
              (opName.toLowerCase().contains('orange') || opName.toLowerCase().contains('mtn')) &&
              (actionLower.contains('crédit') || actionLower.contains('credit') || categoryInferred.toLowerCase() == 'crédit' || categoryInferred.toLowerCase() == 'credit')) {
            isOpEnabled = false;
          }

          final ussdOp = UssdOperation(
            id: codeId,
            name: action,
            provider: opId,
            category: categoryInferred,
            defaultTemplate: normalizedTemplate,
            requiredFields: requiredFields,
            isEnabled: isOpEnabled,
            updatedAt: DateTime.now(),
          );

          _operations.add(ussdOp);
          await db.insert(
            'ussd_operations',
            {
              ...ussdOp.toDbMap(),
              'is_synced': 1,
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
          changed = true;
          debugPrint(
              'UssdProvider: opération insérée [$codeId] $action → $normalizedTemplate');
        }
      }
    }

    _injectedCountries.add(countryKey);

    if (changed) {
      notifyListeners();
    }
  }

  /// Heuristique simple pour assigner une catégorie à partir du nom d'action.
  String _inferCategory(String action) {
    final lower = action.toLowerCase();
    if (lower.contains('dépôt') || lower.contains('depot') || lower.contains('cash-in') || lower.contains('cash in')) {
      return 'Dépôt';
    } else if (lower.contains('retrait') || lower.contains('withdrawal') || lower.contains('cash-out') || lower.contains('cash out')) {
      return 'Retrait';
    } else if (lower.contains('transfer') || lower.contains('envoi') || lower.contains('envoyer')) {
      return 'Transfert';
    } else if (lower.contains('solde') || lower.contains('balance') || lower.contains('flotte') || lower.contains('uv')) {
      return 'Solde';
    } else if (lower.contains('crédit') || lower.contains('credit') || lower.contains('recharge')) {
      return 'Crédit';
    } else if (lower.contains('internet') || lower.contains('data') || lower.contains('forfait')) {
      return 'Internet';
    } else if (lower.contains('marchand') || lower.contains('merchant') || lower.contains('payer')) {
      return 'Paiement marchand';
    }
    return 'Autre';
  }

  // ---------------------------------------------------------------------------
  // CATÉGORIES
  // ---------------------------------------------------------------------------

  Future<void> _saveCategories() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('ussd_categories', _categories);
  }

  Future<void> addCategory(String category) async {
    if (!_categories.contains(category)) {
      _categories.add(category);
      await _saveCategories();
      notifyListeners();
    }
  }

  Future<void> deleteCategory(String category) async {
    _categories.remove(category);
    await _saveCategories();
    notifyListeners();
  }

  Future<void> updateCategory(String oldName, String newName) async {
    final index = _categories.indexOf(oldName);
    if (index != -1) {
      _categories[index] = newName;
      await _saveCategories();
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // OPÉRATEURS
  // ---------------------------------------------------------------------------

  Future<void> addOperator(TelecomOperator op) async {
    final db = await DatabaseService.instance.database;
    final opWithTime = TelecomOperator(
      id: op.id,
      name: op.name,
      userPhoneNumber: op.userPhoneNumber,
      country: op.country,
      updatedAt: DateTime.now(),
    );
    await db.insert('telecom_operators', {
      'id': opWithTime.id,
      'name': opWithTime.name,
      'userPhoneNumber': opWithTime.userPhoneNumber,
      'country': opWithTime.country,
      'is_synced': 0,
      'sync_action': 'created',
      'updated_at': opWithTime.updatedAt?.toIso8601String(),
    });
    _operators.add(opWithTime);
    notifyListeners();
    SyncService().push();
  }

  Future<void> deleteOperator(String operatorId) async {
    final db = await DatabaseService.instance.database;

    // Les opérateurs de référence sont simplement supprimés localement
    if (operatorId.startsWith(_kRefPrefix)) {
      await db.delete('telecom_operators', where: 'id = ?', whereArgs: [operatorId]);
      await db.delete('ussd_operations', where: 'provider = ?', whereArgs: [operatorId]);
    } else {
      await db.update(
        'telecom_operators',
        {'sync_action': 'delete', 'is_synced': 0, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [operatorId],
      );
      await db.update(
        'ussd_operations',
        {'sync_action': 'delete', 'is_synced': 0, 'updated_at': DateTime.now().toIso8601String()},
        where: 'provider = ?',
        whereArgs: [operatorId],
      );
    }

    _operators.removeWhere((op) => op.id == operatorId);
    _operations.removeWhere((op) => op.provider == operatorId);
    notifyListeners();
    if (!operatorId.startsWith(_kRefPrefix)) SyncService().push();
  }

  Future<void> updateOperator(TelecomOperator updatedOp) async {
    final index = _operators.indexWhere((op) => op.id == updatedOp.id);
    if (index != -1) {
      _operators[index] = updatedOp;
      final db = await DatabaseService.instance.database;
      await db.update(
        'telecom_operators',
        {
          'name': updatedOp.name,
          'userPhoneNumber': updatedOp.userPhoneNumber,
          'country': updatedOp.country,
          'is_synced': 0,
          'sync_action': 'updated',
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [updatedOp.id],
      );
      notifyListeners();
      SyncService().push();
    }
  }

  Future<void> updateOperatorPhone(String operatorId, String phoneNumber) async {
    final index = _operators.indexWhere((op) => op.id == operatorId);
    if (index != -1) {
      _operators[index].userPhoneNumber = phoneNumber;
      final db = await DatabaseService.instance.database;
      await db.update(
        'telecom_operators',
        {'userPhoneNumber': phoneNumber, 'is_synced': 0, 'sync_action': 'updated', 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [operatorId],
      );
      notifyListeners();
      SyncService().push();
    }
  }

  Future<void> updateOperatorName(String operatorId, String newName) async {
    final index = _operators.indexWhere((op) => op.id == operatorId);
    if (index != -1) {
      _operators[index].name = newName;
      final db = await DatabaseService.instance.database;
      await db.update(
        'telecom_operators',
        {'name': newName, 'is_synced': 0, 'sync_action': 'updated', 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [operatorId],
      );
      notifyListeners();
      SyncService().push();
    }
  }

  TelecomOperator? getOperatorById(String operatorId) {
    try {
      return _operators.firstWhere((op) => op.id == operatorId);
    } catch (_) {
      return null;
    }
  }

  /// Vide l'état en mémoire (déconnexion) : la base locale et les préférences
  /// par utilisateur sont purgées par ailleurs. Le catalogue de référence
  /// [_referenceUssd] est conservé : c'est un catalogue générique du backend,
  /// sans donnée personnelle, réutilisé à la connexion suivante.
  void clear() {
    _operators = [];
    _operations = [];
    _categories = _getDefaultCategories();
    _injectedCountries.clear();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // OPÉRATIONS
  // ---------------------------------------------------------------------------

  List<UssdOperation> getOperationsForProvider(String providerId) {
    return _operations.where((op) => op.provider == providerId).toList();
  }

  Future<void> reorderOperations(String operatorId, int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) newIndex -= 1;
    final providerOps = getOperationsForProvider(operatorId);
    if (oldIndex < 0 || oldIndex >= providerOps.length) return;
    if (newIndex < 0 || newIndex >= providerOps.length) return;
    final item = providerOps.removeAt(oldIndex);
    providerOps.insert(newIndex, item);
    int providerOpIndex = 0;
    for (int i = 0; i < _operations.length; i++) {
      if (_operations[i].provider == operatorId) {
        _operations[i] = providerOps[providerOpIndex++];
      }
    }
    notifyListeners();
  }

  Future<void> addOperation(UssdOperation operation) async {
    final db = await DatabaseService.instance.database;
    final opWithTime = UssdOperation(
      id: operation.id,
      name: operation.name,
      provider: operation.provider,
      category: operation.category,
      defaultTemplate: operation.defaultTemplate,
      customTemplate: operation.customTemplate,
      requiredFields: operation.requiredFields,
      updatedAt: DateTime.now(),
    );
    await db.insert('ussd_operations', opWithTime.toDbMap());
    _operations.add(opWithTime);
    notifyListeners();
    SyncService().push();
  }

  Future<void> deleteOperation(String operationId) async {
    final db = await DatabaseService.instance.database;

    // Les opérations de référence sont simplement supprimées localement
    if (operationId.startsWith(_kRefPrefix)) {
      await db.delete('ussd_operations', where: 'id = ?', whereArgs: [operationId]);
    } else {
      await db.update(
        'ussd_operations',
        {
          'sync_action': 'delete',
          'is_synced': 0,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [operationId],
      );
    }

    _operations.removeWhere((op) => op.id == operationId);
    notifyListeners();
    if (!operationId.startsWith(_kRefPrefix)) {
      SyncService().push();
    }
  }

  Future<void> updateOperationDetails(String id, String newName, String newTemplate) async {
    final index = _operations.indexWhere((op) => op.id == id);
    if (index != -1) {
      final normalized = UssdFormatter.normalizeTemplate(newTemplate);
      _operations[index].name = newName;
      _operations[index].defaultTemplate = normalized;
      _operations[index].customTemplate = normalized;
      final db = await DatabaseService.instance.database;
      await db.update(
        'ussd_operations',
        {..._operations[index].toDbMap(), 'is_synced': 0, 'sync_action': 'updated', 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );
      notifyListeners();
      SyncService().push();
    }
  }

  Future<void> updateCustomTemplate(String id, String newTemplate) async {
    final index = _operations.indexWhere((op) => op.id == id);
    if (index != -1) {
      final normalized = UssdFormatter.normalizeTemplate(newTemplate);
      _operations[index].customTemplate = normalized;
      final db = await DatabaseService.instance.database;
      await db.update(
        'ussd_operations',
        {..._operations[index].toDbMap(), 'is_synced': 0, 'sync_action': 'updated', 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );
      notifyListeners();
      SyncService().push();
    }
  }

  Future<void> resetToDefault(String id) async {
    final index = _operations.indexWhere((op) => op.id == id);
    if (index != -1) {
      _operations[index].customTemplate = _operations[index].defaultTemplate;
      final db = await DatabaseService.instance.database;
      await db.update(
        'ussd_operations',
        {..._operations[index].toDbMap(), 'is_synced': 0, 'sync_action': 'updated', 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );
      notifyListeners();
      SyncService().push();
    }
  }

  Future<void> toggleOperationEnabled(String id, bool isEnabled) async {
    final index = _operations.indexWhere((op) => op.id == id);
    if (index != -1) {
      _operations[index].isEnabled = isEnabled;
      final db = await DatabaseService.instance.database;
      await db.update(
        'ussd_operations',
        {..._operations[index].toDbMap(), 'is_synced': 0, 'sync_action': 'updated', 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );
      notifyListeners();
      SyncService().push();
    }
  }

  // ---------------------------------------------------------------------------
  // VALEURS PAR DÉFAUT
  // ---------------------------------------------------------------------------

  List<String> _getDefaultCategories() {
    return ['Dépôt', 'Retrait', 'Transfert', 'Paiement marchand', 'Crédit', 'Solde', 'Internet', 'Autre'];
  }

  List<Map<String, dynamic>> _getOfflineFallbackReferenceUssd() {
    return [
      {
        'country': 'Cameroun',
        'operators': [
          {
            'name': 'Orange',
            'ussd_codes': [
              {'action': 'Dépôt d\'argent (Cash-In)', 'code': '#150*1*1*\${phone}*\${amount}#'},
              {'action': 'Retrait client (Cash-Out Agent)', 'code': '#150*3*2*\${phone}*\${amount}#'},
              {'action': 'Retrait d\'argent (Code client)', 'code': '#150*3*2*\${agent}*\${amount}#'},
              {'action': 'Transfert d\'argent', 'code': '#150*1*1*\${phone}*\${amount}#'},
              {'action': 'Paiement marchand', 'code': '#150*3*\${merchant_code}*\${amount}#'},
              {'action': 'Solde compte Agent/UV', 'code': '#150*6*1#'},
              {'action': 'Achat crédit', 'code': '#150*2*1*\${amount}#'},
            ]
          },
          {
            'name': 'MTN',
            'ussd_codes': [
              {'action': 'Dépôt d\'argent (Cash-In Agent)', 'code': '*126*2*\${phone}*\${amount}#'},
              {'action': 'Retrait client (Cash-Out Agent)', 'code': '*126*3*\${phone}*\${amount}#'},
              {'action': 'Retrait d\'argent (Code client)', 'code': '*126*2*1*\${agent}*\${amount}#'},
              {'action': 'Transfert d\'argent', 'code': '*126*1*1*\${phone}*\${amount}#'},
              {'action': 'Paiement marchand', 'code': '*126*4*\${merchant_code}*\${amount}#'},
              {'action': 'Solde compte Flotte/Agent', 'code': '*126*1*7#'},
            ]
          }
        ]
      },
      {
        'country': "Côte d'Ivoire",
        'operators': [
          {
            'name': 'Orange',
            'ussd_codes': [
              {'action': 'Dépôt d\'argent (Cash-In)', 'code': '*144*1*1*\${phone}*\${amount}#'},
              {'action': 'Retrait client (Cash-Out Agent)', 'code': '*144*2*1*\${phone}*\${amount}#'},
              {'action': 'Transfert d\'argent', 'code': '*144*1*1*\${phone}*\${amount}#'},
              {'action': 'Paiement marchand', 'code': '*144*4*\${merchant_code}*\${amount}#'},
              {'action': 'Solde compte Agent', 'code': '*144*7*1#'},
            ]
          },
          {
            'name': 'MTN',
            'ussd_codes': [
              {'action': 'Dépôt d\'argent (Cash-In)', 'code': '*133*1*\${phone}*\${amount}#'},
              {'action': 'Retrait client (Cash-Out Agent)', 'code': '*133*2*\${phone}*\${amount}#'},
              {'action': 'Transfert d\'argent', 'code': '*133*1*\${phone}*\${amount}#'},
              {'action': 'Paiement marchand', 'code': '*133*4*\${merchant_code}*\${amount}#'},
              {'action': 'Solde compte Agent', 'code': '*133*12#'},
            ]
          },
          {
            'name': 'Moov',
            'ussd_codes': [
              {'action': 'Dépôt d\'argent (Cash-In)', 'code': '*155*1*1*\${phone}*\${amount}#'},
              {'action': 'Retrait client (Cash-Out Agent)', 'code': '*155*2*\${phone}*\${amount}#'},
              {'action': 'Transfert d\'argent', 'code': '*155*1*1*\${phone}*\${amount}#'},
              {'action': 'Paiement marchand', 'code': '*155*4*\${merchant_code}*\${amount}#'},
              {'action': 'Solde compte Agent', 'code': '*155*5*1#'},
            ]
          },
          {
            'name': 'Wave',
            'ussd_codes': [
              {'action': 'Menu Agent USSD', 'code': '*130#'},
            ]
          }
        ]
      },
      {
        'country': 'Sénégal',
        'operators': [
          {
            'name': 'Orange',
            'ussd_codes': [
              {'action': 'Dépôt d\'argent (Cash-In Agent)', 'code': '#144*11*\${phone}*\${amount}#'},
              {'action': 'Retrait client (Cash-Out Agent)', 'code': '#144*3*\${phone}*\${amount}#'},
              {'action': 'Transfert d\'argent', 'code': '#144*11*\${phone}*\${amount}#'},
              {'action': 'Paiement marchand', 'code': '#144*4*\${merchant_code}*\${amount}#'},
              {'action': 'Solde compte Agent', 'code': '#144*71#'},
            ]
          },
          {
            'name': 'Free',
            'ussd_codes': [
              {'action': 'Dépôt d\'argent (Cash-In Agent)', 'code': '#150*1*\${phone}*\${amount}#'},
              {'action': 'Retrait client (Cash-Out Agent)', 'code': '#150*2*\${phone}*\${amount}#'},
              {'action': 'Paiement marchand', 'code': '#150*3*\${merchant_code}*\${amount}#'},
              {'action': 'Solde compte Agent', 'code': '#150*6#'},
            ]
          },
          {
            'name': 'Wave',
            'ussd_codes': [
              {'action': 'Menu Agent USSD', 'code': '*130#'},
            ]
          }
        ]
      },
      {
        'country': 'Bénin',
        'operators': [
          {
            'name': 'MTN',
            'ussd_codes': [
              {'action': 'Dépôt d\'argent (Cash-In Agent)', 'code': '*840*1*\${phone}*\${amount}#'},
              {'action': 'Retrait client (Cash-Out Agent)', 'code': '*840*2*\${phone}*\${amount}#'},
              {'action': 'Transfert d\'argent', 'code': '*880*1*\${phone}*\${amount}#'},
              {'action': 'Paiement marchand', 'code': '*880*3*\${merchant_code}*\${amount}#'},
              {'action': 'Solde compte Agent', 'code': '*840#'},
            ]
          },
          {
            'name': 'Moov Africa',
            'ussd_codes': [
              {'action': 'Dépôt d\'argent (Cash-In)', 'code': '*155*1*\${phone}*\${amount}#'},
              {'action': 'Retrait client (Cash-Out Agent)', 'code': '*155*2*\${phone}*\${amount}#'},
              {'action': 'Solde compte Agent', 'code': '*155*5#'},
            ]
          }
        ]
      },
      {
        'country': 'Togo',
        'operators': [
          {
            'name': 'Togocom (T-Money)',
            'ussd_codes': [
              {'action': 'Dépôt d\'argent (Cash-In Agent)', 'code': '*145*1*\${phone}*\${amount}#'},
              {'action': 'Retrait client (Cash-Out Agent)', 'code': '*145*2*\${phone}*\${amount}#'},
              {'action': 'Solde compte Agent', 'code': '*145*7#'},
            ]
          },
          {
            'name': 'Moov Africa',
            'ussd_codes': [
              {'action': 'Dépôt d\'argent (Cash-In)', 'code': '*155*1*\${phone}*\${amount}#'},
              {'action': 'Retrait client (Cash-Out Agent)', 'code': '*155*2*\${phone}*\${amount}#'},
              {'action': 'Solde compte Agent', 'code': '*155*5#'},
            ]
          }
        ]
      },
      {
        'country': 'Mali',
        'operators': [
          {
            'name': 'Orange',
            'ussd_codes': [
              {'action': 'Dépôt d\'argent (Cash-In Agent)', 'code': '#144*1*1*\${phone}*\${amount}#'},
              {'action': 'Retrait client (Cash-Out Agent)', 'code': '#144*2*\${phone}*\${amount}#'},
              {'action': 'Solde compte Agent', 'code': '#144*7#'},
            ]
          },
          {
            'name': 'Moov Africa Malitel',
            'ussd_codes': [
              {'action': 'Dépôt d\'argent (Cash-In)', 'code': '*166*1*\${phone}*\${amount}#'},
              {'action': 'Retrait client (Cash-Out Agent)', 'code': '*166*2*\${phone}*\${amount}#'},
              {'action': 'Solde compte Agent', 'code': '*166#'},
            ]
          }
        ]
      },
      {
        'country': 'Burkina Faso',
        'operators': [
          {
            'name': 'Orange',
            'ussd_codes': [
              {'action': 'Dépôt d\'argent (Cash-In Agent)', 'code': '*144*1*1*\${phone}*\${amount}#'},
              {'action': 'Retrait client (Cash-Out Agent)', 'code': '*144*2*\${phone}*\${amount}#'},
              {'action': 'Solde compte Agent', 'code': '*144*7#'},
            ]
          },
          {
            'name': 'Moov Africa',
            'ussd_codes': [
              {'action': 'Dépôt d\'argent (Cash-In)', 'code': '*555*1*\${phone}*\${amount}#'},
              {'action': 'Retrait client (Cash-Out Agent)', 'code': '*555*2*\${phone}*\${amount}#'},
              {'action': 'Solde compte Agent', 'code': '*555*6#'},
            ]
          }
        ]
      },
      {
        'country': 'RDC',
        'operators': [
          {
            'name': 'Airtel',
            'ussd_codes': [
              {'action': 'Dépôt d\'argent (Cash-In Agent)', 'code': '*115*1*\${phone}*\${amount}#'},
              {'action': 'Retrait client (Cash-Out Agent)', 'code': '*115*2*\${phone}*\${amount}#'},
              {'action': 'Solde compte Agent', 'code': '*115*6#'},
            ]
          },
          {
            'name': 'Vodacom M-Pesa',
            'ussd_codes': [
              {'action': 'Dépôt d\'argent (Cash-In Agent)', 'code': '*1122*1*\${phone}*\${amount}#'},
              {'action': 'Retrait client (Cash-Out Agent)', 'code': '*1122*2*\${phone}*\${amount}#'},
              {'action': 'Solde compte Agent', 'code': '*1122#'},
            ]
          },
          {
            'name': 'Orange',
            'ussd_codes': [
              {'action': 'Dépôt d\'argent (Cash-In Agent)', 'code': '*144*1*\${phone}*\${amount}#'},
              {'action': 'Retrait client (Cash-Out Agent)', 'code': '*144*2*\${phone}*\${amount}#'},
            ]
          }
        ]
      },
      {
        'country': 'Guinée',
        'operators': [
          {
            'name': 'Orange',
            'ussd_codes': [
              {'action': 'Dépôt d\'argent (Cash-In Agent)', 'code': '*144*1*\${phone}*\${amount}#'},
              {'action': 'Retrait client (Cash-Out Agent)', 'code': '*144*2*\${phone}*\${amount}#'},
            ]
          },
          {
            'name': 'MTN',
            'ussd_codes': [
              {'action': 'Dépôt d\'argent (Cash-In Agent)', 'code': '*145*1*\${phone}*\${amount}#'},
              {'action': 'Retrait client (Cash-Out Agent)', 'code': '*145*2*\${phone}*\${amount}#'},
            ]
          }
        ]
      },
      {
        'country': 'Gabon',
        'operators': [
          {
            'name': 'Airtel',
            'ussd_codes': [
              {'action': 'Dépôt d\'argent (Cash-In Agent)', 'code': '*150*1*\${phone}*\${amount}#'},
              {'action': 'Retrait client (Cash-Out Agent)', 'code': '*150*2*\${phone}*\${amount}#'},
            ]
          },
          {
            'name': 'Moov Africa',
            'ussd_codes': [
              {'action': 'Dépôt d\'argent (Cash-In)', 'code': '*555*1*\${phone}*\${amount}#'},
              {'action': 'Retrait client (Cash-Out Agent)', 'code': '*555*2*\${phone}*\${amount}#'},
            ]
          }
        ]
      },
      {
        'country': 'Congo',
        'operators': [
          {
            'name': 'MTN',
            'ussd_codes': [
              {'action': 'Dépôt d\'argent (Cash-In Agent)', 'code': '*105*1*\${phone}*\${amount}#'},
              {'action': 'Retrait client (Cash-Out Agent)', 'code': '*105*2*\${phone}*\${amount}#'},
            ]
          },
          {
            'name': 'Airtel',
            'ussd_codes': [
              {'action': 'Dépôt d\'argent (Cash-In Agent)', 'code': '*128*1*\${phone}*\${amount}#'},
              {'action': 'Retrait client (Cash-Out Agent)', 'code': '*128*2*\${phone}*\${amount}#'},
            ]
          }
        ]
      },
      {
        'country': 'Niger',
        'operators': [
          {
            'name': 'Airtel',
            'ussd_codes': [
              {'action': 'Dépôt d\'argent (Cash-In Agent)', 'code': '*115*1*\${phone}*\${amount}#'},
              {'action': 'Retrait client (Cash-Out Agent)', 'code': '*115*2*\${phone}*\${amount}#'},
            ]
          },
          {
            'name': 'Moov Africa',
            'ussd_codes': [
              {'action': 'Dépôt d\'argent (Cash-In)', 'code': '*155*1*\${phone}*\${amount}#'},
              {'action': 'Retrait client (Cash-Out Agent)', 'code': '*155*2*\${phone}*\${amount}#'},
            ]
          }
        ]
      },
      {
        'country': 'Ghana',
        'operators': [
          {
            'name': 'MTN',
            'ussd_codes': [
              {'action': 'Dépôt d\'argent (Cash-In Agent)', 'code': '*171*1*\${phone}*\${amount}#'},
              {'action': 'Retrait client (Cash-Out Agent)', 'code': '*171*2*\${phone}*\${amount}#'},
              {'action': 'Transfert d\'argent', 'code': '*170*1*1*\${phone}*\${amount}#'},
              {'action': 'Solde compte Agent', 'code': '*171#'},
            ]
          },
          {
            'name': 'Telecel (Vodafone)',
            'ussd_codes': [
              {'action': 'Dépôt d\'argent (Cash-In Agent)', 'code': '*110*1*\${phone}*\${amount}#'},
              {'action': 'Retrait client (Cash-Out Agent)', 'code': '*110*2*\${phone}*\${amount}#'},
            ]
          }
        ]
      },
      {
        'country': 'Kenya',
        'operators': [
          {
            'name': 'Safaricom (M-Pesa)',
            'ussd_codes': [
              {'action': 'Dépôt d\'argent (Cash-In Agent)', 'code': '*234*1*\${phone}*\${amount}#'},
              {'action': 'Retrait client (Cash-Out Agent)', 'code': '*234*2*\${phone}*\${amount}#'},
              {'action': 'Transfert d\'argent', 'code': '*334*1*\${phone}*\${amount}#'},
              {'action': 'Solde compte Agent', 'code': '*234#'},
            ]
          },
          {
            'name': 'Airtel',
            'ussd_codes': [
              {'action': 'Dépôt d\'argent (Cash-In Agent)', 'code': '*222*1*\${phone}*\${amount}#'},
              {'action': 'Retrait client (Cash-Out Agent)', 'code': '*222*2*\${phone}*\${amount}#'},
            ]
          }
        ]
      },
      {
        'country': 'Madagascar',
        'operators': [
          {
            'name': 'Orange',
            'ussd_codes': [
              {'action': 'Dépôt d\'argent (Cash-In Agent)', 'code': '#144*1*\${phone}*\${amount}#'},
              {'action': 'Retrait client (Cash-Out Agent)', 'code': '#144*2*\${phone}*\${amount}#'},
            ]
          },
          {
            'name': 'Telma (MVola)',
            'ussd_codes': [
              {'action': 'Dépôt d\'argent (Cash-In Agent)', 'code': '#111*1*\${phone}*\${amount}#'},
              {'action': 'Retrait client (Cash-Out Agent)', 'code': '#111*2*\${phone}*\${amount}#'},
            ]
          }
        ]
      }
    ];
  }
}

