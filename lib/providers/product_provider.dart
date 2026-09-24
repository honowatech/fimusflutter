import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/product.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';

class ProductProvider with ChangeNotifier {
  List<Product> _products = [];
  bool _isLoading = false;
  String _searchQuery = '';

  List<Product> get products {
    if (_searchQuery.isEmpty) {
      return List.unmodifiable(_products);
    }
    final q = _searchQuery.toLowerCase().trim();
    return _products.where((p) => p.name.toLowerCase().contains(q)).toList();
  }

  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;

  ProductProvider() {
    loadProducts();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<void> loadProducts() async {
    _isLoading = true;
    notifyListeners();

    try {
      final db = await DatabaseService.instance.database;
      // 'delete' est le marqueur local de suppression (converti en 'deleted'
      // à l'envoi) ; 'deleted' reste accepté pour les lignes écrites par les
      // versions précédentes de l'application.
      final List<Map<String, dynamic>> maps = await db.query(
        'products',
        where:
            "(sync_action != 'delete' AND sync_action != 'deleted') OR sync_action IS NULL",
        orderBy: 'created_at DESC',
      );

      _products = maps.map((m) => Product.fromMap(m)).toList();
    } catch (e) {
      debugPrint('[ProductProvider] Error loading products: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addProduct({
    required String name,
    required double price,
    String? photoPath,
    String? description,
  }) async {
    final nowStr = DateTime.now().toIso8601String();
    final newProduct = Product(
      id: const Uuid().v4(),
      name: name.trim(),
      price: price,
      photoPath: photoPath,
      description: description?.trim(),
      createdAt: nowStr,
      updatedAt: nowStr,
      isSynced: false,
      syncAction: 'created',
    );

    try {
      final db = await DatabaseService.instance.database;
      await db.insert('products', newProduct.toMap());
      _products.insert(0, newProduct);
      notifyListeners();

      // Background push
      SyncService().push().catchError((e) {
        debugPrint('[ProductProvider] Background push error: $e');
        return SyncResult(
          success: false,
          pushed: 0,
          pulled: 0,
          error: e.toString(),
        );
      });
    } catch (e) {
      debugPrint('[ProductProvider] Error adding product: $e');
      rethrow;
    }
  }

  Future<void> updateProduct(Product updated) async {
    final nowStr = DateTime.now().toIso8601String();
    final productToSave = updated.copyWith(
      updatedAt: nowStr,
      isSynced: false,
      syncAction: updated.syncAction == 'created' ? 'created' : 'updated',
    );

    try {
      final db = await DatabaseService.instance.database;
      await db.update(
        'products',
        productToSave.toMap(),
        where: 'id = ?',
        whereArgs: [productToSave.id],
      );

      final index = _products.indexWhere((p) => p.id == productToSave.id);
      if (index != -1) {
        _products[index] = productToSave;
        notifyListeners();
      }

      SyncService().push().catchError((e) {
        debugPrint('[ProductProvider] Background push error: $e');
        return SyncResult(
          success: false,
          pushed: 0,
          pulled: 0,
          error: e.toString(),
        );
      });
    } catch (e) {
      debugPrint('[ProductProvider] Error updating product: $e');
      rethrow;
    }
  }

  Future<void> deleteProduct(String id) async {
    try {
      final db = await DatabaseService.instance.database;
      // L'état de synchronisation est relu en base : la copie en mémoire
      // devient obsolète dès qu'un push en arrière-plan a marqué la ligne
      // is_synced = 1, et une suppression physique laisserait alors la ligne
      // sur le serveur, qui la réinsérerait au pull suivant.
      final rows = await db.query(
        'products',
        columns: ['is_synced'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      final bool isSynced =
          rows.isNotEmpty && (rows.first['is_synced'] == 1);

      if (isSynced) {
        // Soft delete to sync deletion
        await db.update(
          'products',
          {
            'sync_action': 'delete',
            'is_synced': 0,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [id],
        );
      } else {
        // Hard delete if never synced
        await db.delete(
          'products',
          where: 'id = ?',
          whereArgs: [id],
        );
      }

      _products.removeWhere((p) => p.id == id);
      notifyListeners();

      SyncService().push().catchError((e) {
        debugPrint('[ProductProvider] Background push error: $e');
        return SyncResult(
          success: false,
          pushed: 0,
          pulled: 0,
          error: e.toString(),
        );
      });
    } catch (e) {
      debugPrint('[ProductProvider] Error deleting product: $e');
      rethrow;
    }
  }
}
