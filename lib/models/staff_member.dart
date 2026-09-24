class StaffMember {
  final String id;
  final String name;
  final String? role;
  final String? phoneNumber;
  final String? email;
  final double? salary;
  final String createdAt;
  final String? updatedAt;
  final bool isSynced;
  final String syncAction;

  StaffMember({
    required this.id,
    required this.name,
    this.role,
    this.phoneNumber,
    this.email,
    this.salary,
    required this.createdAt,
    this.updatedAt,
    this.isSynced = false,
    this.syncAction = 'created',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'role': role,
      'phone_number': phoneNumber,
      'email': email,
      'salary': salary,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'is_synced': isSynced ? 1 : 0,
      'sync_action': syncAction,
    };
  }

  factory StaffMember.fromMap(Map<String, dynamic> map) {
    return StaffMember(
      id: map['id'].toString(),
      name: map['name'] ?? '',
      role: map['role'],
      phoneNumber: map['phone_number'] ?? map['phoneNumber'],
      email: map['email'],
      salary: map['salary'] != null
          ? ((map['salary'] is num)
              ? (map['salary'] as num).toDouble()
              : double.tryParse(map['salary']?.toString() ?? ''))
          : null,
      createdAt: map['created_at'] ?? DateTime.now().toIso8601String(),
      updatedAt: map['updated_at'],
      isSynced: map['is_synced'] == 1 || map['is_synced'] == true,
      syncAction: map['sync_action'] ?? 'created',
    );
  }

  StaffMember copyWith({
    String? id,
    String? name,
    String? role,
    String? phoneNumber,
    String? email,
    double? salary,
    String? createdAt,
    String? updatedAt,
    bool? isSynced,
    String? syncAction,
  }) {
    return StaffMember(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      salary: salary ?? this.salary,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
      syncAction: syncAction ?? this.syncAction,
    );
  }
}
