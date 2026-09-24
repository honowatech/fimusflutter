import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../database_service.dart';
import 'alert_models.dart';

/// Photographie des données locales encore en attente d'envoi.
///
/// **Lecture seule** : aucune écriture, aucun changement de schéma. La sonde
/// interroge les tables qui portent déjà `is_synced` et un horodatage, puis
/// rend un [UnsyncedSnapshot] que l'évaluateur (pur) consomme.
class UnsyncedProbe {
  const UnsyncedProbe();

  /// Tables surveillées et colonnes d'horodatage disponibles (dans l'ordre de
  /// repli, via `COALESCE`).
  ///
  /// Volontairement **partiel** :
  ///  * `categories` est exclue — une suppression de catégorie reste locale
  ///    pour toujours (`SyncService` ne pousse pas `sync_action = 'delete'`) :
  ///    ces lignes resteraient éternellement `is_synced = 0` et
  ///    déclencheraient une alerte permanente et fausse ;
  ///  * `ussd_operations` et `telecom_operators` sont exclues — leurs lignes de
  ///    référence (préfixe `ref_`) ne sont jamais poussées, même motif.
  ///
  /// Restent les tables dont chaque ligne non synchronisée représente bien une
  /// donnée saisie par l'utilisateur et perdue en cas de changement de
  /// téléphone.
  static const Map<String, List<String>> trackedTables = <String, List<String>>{
    'expenses': <String>['updated_at', 'created_at'],
    'accounts': <String>['updated_at'],
    'ussd_history': <String>['updated_at'],
    'products': <String>['updated_at', 'created_at'],
    'staff_members': <String>['updated_at', 'created_at'],
  };

  /// Expression SQL de l'horodatage retenu pour une table. Fonction pure.
  static String timestampExpression(List<String> columns) =>
      columns.length == 1 ? columns.first : 'COALESCE(${columns.join(', ')})';

  /// Interroge toutes les tables surveillées et agrège le résultat.
  ///
  /// Toute erreur (table absente sur une base ancienne, base verrouillée) est
  /// absorbée table par table : une sonde partielle vaut mieux qu'une
  /// exception qui ferait sauter toute l'évaluation.
  Future<UnsyncedSnapshot> read() async {
    try {
      final db = await DatabaseService.instance.database;
      final parts = <UnsyncedSnapshot>[];
      for (final entry in trackedTables.entries) {
        parts.add(await _readTable(db, entry.key, entry.value));
      }
      return UnsyncedSnapshot.combine(parts);
    } catch (e) {
      debugPrint('Error probing unsynced data: $e');
      return const UnsyncedSnapshot.empty();
    }
  }

  Future<UnsyncedSnapshot> _readTable(
    Database db,
    String table,
    List<String> stampColumns,
  ) async {
    try {
      final stamp = timestampExpression(stampColumns);
      final rows = await db.rawQuery(
        'SELECT COUNT(*) AS pending, MIN($stamp) AS oldest '
        'FROM $table WHERE is_synced = 0',
      );
      if (rows.isEmpty) return const UnsyncedSnapshot.empty();
      return snapshotFromRow(rows.first);
    } catch (e) {
      debugPrint('Error probing unsynced rows in $table: $e');
      return const UnsyncedSnapshot.empty();
    }
  }

  /// Convertit une ligne `{pending, oldest}` en [UnsyncedSnapshot].
  ///
  /// `oldest` peut être `null` alors que `pending > 0` : ce sont d'anciennes
  /// lignes sans horodatage. L'ancienneté étant alors indémontrable,
  /// l'évaluateur n'alertera pas. Fonction pure, testable sans base.
  static UnsyncedSnapshot snapshotFromRow(Map<String, Object?> row) {
    final rawCount = row['pending'];
    final count = rawCount is num ? rawCount.toInt() : 0;
    if (count <= 0) return const UnsyncedSnapshot.empty();

    final rawOldest = row['oldest'];
    final oldest =
        rawOldest is String ? DateTime.tryParse(rawOldest)?.toLocal() : null;
    return UnsyncedSnapshot(pendingCount: count, oldestPendingAt: oldest);
  }
}
