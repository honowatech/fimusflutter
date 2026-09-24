import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/staff_member.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';

class StaffProvider with ChangeNotifier {
  List<StaffMember> _staffMembers = [];
  bool _isLoading = false;
  String _searchQuery = '';

  List<StaffMember> get staffMembers {
    if (_searchQuery.isEmpty) {
      return List.unmodifiable(_staffMembers);
    }
    final q = _searchQuery.toLowerCase().trim();
    return _staffMembers.where((s) =>
        s.name.toLowerCase().contains(q) ||
        (s.role != null && s.role!.toLowerCase().contains(q)) ||
        (s.phoneNumber != null && s.phoneNumber!.contains(q))).toList();
  }

  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;

  StaffProvider() {
    loadStaffMembers();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<void> loadStaffMembers() async {
    _isLoading = true;
    notifyListeners();

    try {
      final db = await DatabaseService.instance.database;
      // 'delete' est le marqueur local de suppression (converti en 'deleted'
      // à l'envoi) ; 'deleted' reste accepté pour les lignes écrites par les
      // versions précédentes de l'application.
      final List<Map<String, dynamic>> maps = await db.query(
        'staff_members',
        where:
            "(sync_action != 'delete' AND sync_action != 'deleted') OR sync_action IS NULL",
        orderBy: 'created_at DESC',
      );

      _staffMembers = maps.map((m) => StaffMember.fromMap(m)).toList();
    } catch (e) {
      debugPrint('[StaffProvider] Error loading staff members: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addStaffMember({
    required String name,
    String? role,
    String? phoneNumber,
    String? email,
    double? salary,
  }) async {
    final nowStr = DateTime.now().toIso8601String();
    final newMember = StaffMember(
      id: const Uuid().v4(),
      name: name.trim(),
      role: role?.trim(),
      phoneNumber: phoneNumber?.trim(),
      email: email?.trim(),
      salary: salary,
      createdAt: nowStr,
      updatedAt: nowStr,
      isSynced: false,
      syncAction: 'created',
    );

    try {
      final db = await DatabaseService.instance.database;
      await db.insert('staff_members', newMember.toMap());
      _staffMembers.insert(0, newMember);
      notifyListeners();

      // Background push
      SyncService().push().catchError((e) {
        debugPrint('[StaffProvider] Background push error: $e');
        return SyncResult(
          success: false,
          pushed: 0,
          pulled: 0,
          error: e.toString(),
        );
      });
    } catch (e) {
      debugPrint('[StaffProvider] Error adding staff member: $e');
      rethrow;
    }
  }

  Future<void> updateStaffMember(StaffMember updated) async {
    final nowStr = DateTime.now().toIso8601String();
    final memberToSave = updated.copyWith(
      updatedAt: nowStr,
      isSynced: false,
      syncAction: updated.syncAction == 'created' ? 'created' : 'updated',
    );

    try {
      final db = await DatabaseService.instance.database;
      await db.update(
        'staff_members',
        memberToSave.toMap(),
        where: 'id = ?',
        whereArgs: [memberToSave.id],
      );

      final index = _staffMembers.indexWhere((s) => s.id == memberToSave.id);
      if (index != -1) {
        _staffMembers[index] = memberToSave;
        notifyListeners();
      }

      SyncService().push().catchError((e) {
        debugPrint('[StaffProvider] Background push error: $e');
        return SyncResult(
          success: false,
          pushed: 0,
          pulled: 0,
          error: e.toString(),
        );
      });
    } catch (e) {
      debugPrint('[StaffProvider] Error updating staff member: $e');
      rethrow;
    }
  }

  Future<void> deleteStaffMember(String id) async {
    try {
      final db = await DatabaseService.instance.database;
      // L'état de synchronisation est relu en base : la copie en mémoire
      // devient obsolète dès qu'un push en arrière-plan a marqué la ligne
      // is_synced = 1, et une suppression physique laisserait alors la ligne
      // sur le serveur, qui la réinsérerait au pull suivant.
      final rows = await db.query(
        'staff_members',
        columns: ['is_synced'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      final bool isSynced =
          rows.isNotEmpty && (rows.first['is_synced'] == 1);

      if (isSynced) {
        // Soft delete
        await db.update(
          'staff_members',
          {
            'sync_action': 'delete',
            'is_synced': 0,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [id],
        );
      } else {
        // Hard delete
        await db.delete(
          'staff_members',
          where: 'id = ?',
          whereArgs: [id],
        );
      }

      _staffMembers.removeWhere((s) => s.id == id);
      notifyListeners();

      SyncService().push().catchError((e) {
        debugPrint('[StaffProvider] Background push error: $e');
        return SyncResult(
          success: false,
          pushed: 0,
          pulled: 0,
          error: e.toString(),
        );
      });
    } catch (e) {
      debugPrint('[StaffProvider] Error deleting staff member: $e');
      rethrow;
    }
  }
}
