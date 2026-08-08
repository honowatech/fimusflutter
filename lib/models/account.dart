class Account {
  final String id;
  final String name;
  final double balance;
  final String? type;
  final String? icon;
  final String? color;
  final bool isShared;
  final String? ownerName;
  final int? ownerId;
  final DateTime? updatedAt;

  Account({
    required this.id,
    required this.name,
    this.balance = 0.0,
    this.type,
    this.icon,
    this.color,
    this.isShared = false,
    this.ownerName,
    this.ownerId,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'balance': balance,
      'type': type,
      'icon': icon,
      'color': color,
      'isShared': isShared,
      'ownerName': ownerName,
      'ownerId': ownerId,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id'] ?? json['uuid'] ?? '',
      name: json['name'] ?? '',
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      type: json['type'],
      icon: json['icon'],
      color: json['color'],
      isShared: json['isShared'] ?? (json['user_id'] != null && json['user_id'] is Map) ?? false, // placeholder logic
      ownerName: json['ownerName'] ?? (json['user'] != null ? json['user']['name'] : null),
      ownerId: json['ownerId'] ?? json['user_id'],
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at']) : (json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt']) : null),
    );
  }

  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'name': name,
      'balance': balance,
      'type': type,
      'icon': icon,
      'color': color,
      'is_shared': isShared ? 1 : 0,
      'owner_name': ownerName,
      'owner_id': ownerId,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory Account.fromDbMap(Map<String, dynamic> map) {
    return Account(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      balance: (map['balance'] as num?)?.toDouble() ?? 0.0,
      type: map['type'],
      icon: map['icon'],
      color: map['color'],
      isShared: map['is_shared'] == 1,
      ownerName: map['owner_name'],
      ownerId: map['owner_id'],
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at']) : null,
    );
  }

  Account copyWith({
    String? name,
    double? balance,
    String? type,
    String? icon,
    String? color,
    bool? isShared,
    String? ownerName,
    int? ownerId,
    DateTime? updatedAt,
  }) {
    return Account(
      id: id,
      name: name ?? this.name,
      balance: balance ?? this.balance,
      type: type ?? this.type,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      isShared: isShared ?? this.isShared,
      ownerName: ownerName ?? this.ownerName,
      ownerId: ownerId ?? this.ownerId,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
