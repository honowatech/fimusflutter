class Product {
  final String id;
  final String name;
  final double price;
  final String? photoPath;
  final String? description;
  final String createdAt;
  final String? updatedAt;
  final bool isSynced;
  final String syncAction;

  Product({
    required this.id,
    required this.name,
    required this.price,
    this.photoPath,
    this.description,
    required this.createdAt,
    this.updatedAt,
    this.isSynced = false,
    this.syncAction = 'created',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'photo_path': photoPath,
      'description': description,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'is_synced': isSynced ? 1 : 0,
      'sync_action': syncAction,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'].toString(),
      name: map['name'] ?? '',
      price: (map['price'] is num)
          ? (map['price'] as num).toDouble()
          : double.tryParse(map['price']?.toString() ?? '0') ?? 0.0,
      photoPath: map['photo_path'] ?? map['photoUrl'] ?? map['photo_url'],
      description: map['description'],
      createdAt: map['created_at'] ?? DateTime.now().toIso8601String(),
      updatedAt: map['updated_at'],
      isSynced: map['is_synced'] == 1 || map['is_synced'] == true,
      syncAction: map['sync_action'] ?? 'created',
    );
  }

  Product copyWith({
    String? id,
    String? name,
    double? price,
    String? photoPath,
    String? description,
    String? createdAt,
    String? updatedAt,
    bool? isSynced,
    String? syncAction,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      photoPath: photoPath ?? this.photoPath,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
      syncAction: syncAction ?? this.syncAction,
    );
  }
}
