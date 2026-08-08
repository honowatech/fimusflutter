class TelecomOperator {
  final String id;
  String name;
  String? userPhoneNumber;
  String country;
  final DateTime? updatedAt;

  TelecomOperator({
    required this.id,
    required this.name,
    this.userPhoneNumber,
    this.country = 'Cameroun',
    this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'userPhoneNumber': userPhoneNumber,
      'country': country,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory TelecomOperator.fromJson(Map<String, dynamic> json) {
    return TelecomOperator(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      userPhoneNumber: json['userPhoneNumber']?.toString(),
      country: json['country']?.toString() ?? 'Cameroun',
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : (json['updatedAt'] != null
              ? DateTime.tryParse(json['updatedAt'].toString())
              : null),
    );
  }

  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'name': name,
      'userPhoneNumber': userPhoneNumber,
      'country': country,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory TelecomOperator.fromDbMap(Map<String, dynamic> map) {
    return TelecomOperator(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      userPhoneNumber: map['userPhoneNumber']?.toString(),
      country: map['country']?.toString() ?? 'Cameroun',
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) : null,
    );
  }
}
