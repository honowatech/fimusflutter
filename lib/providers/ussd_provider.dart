import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../models/ussd_operation.dart';
import '../models/operator.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';
import '../utils/api_config.dart';

// IDs stables pour les opérateurs de référence — doit correspondre au format
// utilisé par refreshCountryUssd() pour éviter les doublons.
const String _kRefPrefix = 'ref_';

String _refOpId(String country, String opName) =>
    '$_kRefPrefix${country.toLowerCase().replaceAll(' ', '_')}_'
    '${opName.toLowerCase().replaceAll(' ', '_')}';

String _refCodeId(String opId, String action) =>
    '${opId}_${action.toLowerCase().replaceAll(' ', '_')}';

class UssdProvider with ChangeNotifier {
  List<TelecomOperator> _operators = [];
  List<UssdOperation> _operations = [];
  List<String> _categories = [];

  // Cache du catalogue de référence backend : [{country, operators:[{name, ussd_codes:[]}]}]
  List<Map<String, dynamic>> _referenceUssd = [];

  // Ensemble des pays dont les USSD ont déjà été injectés (évite les doublons)
  final Set<String> _injectedCountries = {};

  List<TelecomOperator> get operators => _operators;
  List<UssdOperation> get operations => _operations;
  List<String> get categories => _categories;

  UssdProvider() {
    loadData();
  }

  // ---------------------------------------------------------------------------
  // CHARGEMENT INITIAL
  // ---------------------------------------------------------------------------

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final db = await DatabaseService.instance.database;

    // --- Opérateurs ---
    // Migration : supprimer les anciens opérateurs hardcodés au profit du backend
    await _migrateHardcodedOperators(db);

    final List<Map<String, dynamic>> opMaps = await db.query(
      'telecom_operators',
      where: "sync_action != 'delete' OR sync_action IS NULL",
    );
    if (opMaps.isNotEmpty) {
      _operators = opMaps.map((e) => TelecomOperator.fromJson(e)).toList();
    } else {
      // Premier lancement : on n'insère RIEN de hardcodé. On attend le backend.
      // On insère juste un placeholder vide pour que l'UI sache qu'on est prêts.
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
    }

    // Marquer les pays déjà injectés pour ne pas re-créer des doublons
    for (final op in _operators) {
      if (op.id.startsWith(_kRefPrefix)) {
        // Extraire le nom du pays depuis l'ID de référence
        final parts = op.id.replaceFirst(_kRefPrefix, '').split('_');
        if (parts.isNotEmpty) {
          _injectedCountries.add(op.country.toLowerCase());
        }
      }
    }

    // Charger le catalogue de référence depuis le cache local (SharedPreferences)
    final cached = prefs.getString('cached_reference_ussd');
    if (cached != null) {
      try {
        final decoded = jsonDecode(cached);
        if (decoded is List) {
          _referenceUssd = List<Map<String, dynamic>>.from(decoded);
          developer.log(
            'UssdProvider: ${_referenceUssd.length} pays pré-chargés depuis le cache local',
            name: 'UssdProvider',
          );
        }
      } catch (e) {
        developer.log('UssdProvider: erreur décodage cache local ussd: $e', name: 'UssdProvider');
      }
    }

    notifyListeners();

    // Récupération asynchrone du catalogue backend + injection du pays courant
    unawaited(_fetchAndInjectForSavedCountry());
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
    developer.log('UssdProvider: migration des opérateurs hardcodés effectuée', name: 'UssdProvider');
  }

  Future<void> _migrateTemplates(Database db) async {
    bool migrated = false;
    for (var op in _operations) {
      if (op.id == 'orange_credit' && op.defaultTemplate == '*150*2*1*{amount}#') {
        op.defaultTemplate = '#150*2*1*{amount}#';
        if (op.customTemplate == '*150*2*1*{amount}#') op.customTemplate = '#150*2*1*{amount}#';
        migrated = true;
      }
      if (op.id == 'mtn_credit' && op.defaultTemplate == '*126*2*1*{amount}#') {
        op.defaultTemplate = '*126*3*1*{amount}#';
        if (op.customTemplate == '*126*2*1*{amount}#') op.customTemplate = '*126*3*1*{amount}#';
        migrated = true;
      }
      if (migrated) {
        await db.update('ussd_operations', op.toDbMap(), where: 'id = ?', whereArgs: [op.id]);
        migrated = false;
      }
    }
  }

  // ---------------------------------------------------------------------------
  // RÉFÉRENCE BACKEND
  // ---------------------------------------------------------------------------

  /// Télécharge le catalogue USSD de référence depuis le backend.
  Future<void> _fetchReferenceUssd() async {
    final prefs = await SharedPreferences.getInstance();

    // Si _referenceUssd est toujours vide, charger depuis le cache local
    if (_referenceUssd.isEmpty) {
      final cached = prefs.getString('cached_reference_ussd');
      if (cached != null) {
        try {
          final decoded = jsonDecode(cached);
          if (decoded is List) {
            _referenceUssd = List<Map<String, dynamic>>.from(decoded);
            developer.log(
              'UssdProvider: ${_referenceUssd.length} pays chargés depuis le cache local dans _fetchReferenceUssd',
              name: 'UssdProvider',
            );
          }
        } catch (e) {
          developer.log('UssdProvider: erreur décodage cache local ussd: $e', name: 'UssdProvider');
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
        await prefs.setString('cached_reference_ussd', jsonEncode(_referenceUssd));
        developer.log(
          'UssdProvider: ${_referenceUssd.length} pays chargés depuis le backend et mis en cache',
          name: 'UssdProvider',
        );
      }
    } on DioException catch (e) {
      developer.log(
        'UssdProvider: impossible de récupérer les USSD de référence (réseau): ${e.message}',
        name: 'UssdProvider',
      );
    } catch (e) {
      developer.log('UssdProvider: erreur inattendue: $e', name: 'UssdProvider');
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
      developer.log('UssdProvider: erreur lecture profil: $e', name: 'UssdProvider');
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
      developer.log(
        'UssdProvider: catalogue vide, impossible d\'injecter pour $country',
        name: 'UssdProvider',
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
      developer.log(
        'UssdProvider: aucune donnée de référence pour "$country"',
        name: 'UssdProvider',
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
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        changed = true;
        developer.log('UssdProvider: opérateur inséré [$opId] $opName ($country)',
            name: 'UssdProvider');
      }

      // Insérer chaque code USSD comme opération si absent
      for (final code in refCodes) {
        final action = (code['action'] as String?) ?? '';
        final template = (code['code'] as String?) ?? '';
        if (action.isEmpty || template.isEmpty) continue;

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

          final ussdOp = UssdOperation(
            id: codeId,
            name: action,
            provider: opId,
            category: _inferCategory(action),
            defaultTemplate: normalizedTemplate,
            requiredFields: requiredFields,
          );

          _operations.add(ussdOp);
          await db.insert(
            'ussd_operations',
            ussdOp.toDbMap(),
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
          changed = true;
          developer.log(
              'UssdProvider: opération insérée [$codeId] $action → $normalizedTemplate',
              name: 'UssdProvider');
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
    if (lower.contains('transfer') || lower.contains('envoi') || lower.contains('envoyer')) {
      return 'Transfert';
    } else if (lower.contains('retrait') || lower.contains('withdrawal')) {
      return 'Transfert';
    } else if (lower.contains('solde') || lower.contains('balance')) {
      return 'Solde';
    } else if (lower.contains('crédit') || lower.contains('credit') || lower.contains('recharge')) {
      return 'Crédit';
    } else if (lower.contains('internet') || lower.contains('data') || lower.contains('forfait')) {
      return 'Internet';
    } else if (lower.contains('marchand') || lower.contains('merchant') || lower.contains('payer')) {
      return 'Transfert';
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
    await db.insert('telecom_operators', {
      'id': op.id,
      'name': op.name,
      'userPhoneNumber': op.userPhoneNumber,
      'country': op.country,
      'is_synced': 0,
      'sync_action': 'created',
    });
    _operators.add(op);
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
        {'sync_action': 'delete', 'is_synced': 0},
        where: 'id = ?',
        whereArgs: [operatorId],
      );
      await db.update(
        'ussd_operations',
        {'sync_action': 'delete', 'is_synced': 0},
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
        {'userPhoneNumber': phoneNumber, 'is_synced': 0, 'sync_action': 'updated'},
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
        {'name': newName, 'is_synced': 0, 'sync_action': 'updated'},
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
    await db.insert('ussd_operations', operation.toDbMap());
    _operations.add(operation);
    notifyListeners();
    SyncService().push();
  }

  Future<void> updateOperationDetails(String id, String newName, String newTemplate) async {
    final index = _operations.indexWhere((op) => op.id == id);
    if (index != -1) {
      _operations[index].name = newName;
      _operations[index].defaultTemplate = newTemplate;
      _operations[index].customTemplate = newTemplate;
      final db = await DatabaseService.instance.database;
      await db.update(
        'ussd_operations',
        {..._operations[index].toDbMap(), 'is_synced': 0, 'sync_action': 'updated'},
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
      _operations[index].customTemplate = newTemplate;
      final db = await DatabaseService.instance.database;
      await db.update(
        'ussd_operations',
        {..._operations[index].toDbMap(), 'is_synced': 0, 'sync_action': 'updated'},
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
        {..._operations[index].toDbMap(), 'is_synced': 0, 'sync_action': 'updated'},
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
    return ['Transfert', 'Crédit', 'Solde', 'Internet', 'Autre'];
  }
}
