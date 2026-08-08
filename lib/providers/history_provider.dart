import 'package:flutter/foundation.dart';
import '../models/ussd_history.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';

class HistoryProvider with ChangeNotifier {
  List<UssdHistory> _history = [];
  
  List<UssdHistory> get history => _history;

  HistoryProvider() {
    loadHistory();
  }

  Future<void> loadHistory() async {
    final db = await DatabaseService.instance.database;
    final List<Map<String, dynamic>> maps = await db.query('ussd_history');

    _history = maps.map((e) => UssdHistory.fromDbMap(e)).toList();
    _history.sort((a, b) => b.date.compareTo(a.date));
    notifyListeners();
  }


  Future<void> addHistoryEntry(UssdHistory entry) async {
    final db = await DatabaseService.instance.database;
    await db.insert('ussd_history', entry.toDbMap());

    _history.insert(0, entry);
    notifyListeners();
    SyncService().push();
  }

  Future<void> removeHistoryEntry(String id) async {
    final db = await DatabaseService.instance.database;
    await db.update(
      'ussd_history',
      {
        'sync_action': 'delete',
        'is_synced': 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    _history.removeWhere((element) => element.id == id);
    notifyListeners();
    SyncService().push();
  }

  Future<void> clearHistory() async {
    final db = await DatabaseService.instance.database;
    await db.update(
      'ussd_history',
      {
        'sync_action': 'delete',
        'is_synced': 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
    );

    _history.clear();
    notifyListeners();
    SyncService().push();
  }
}
