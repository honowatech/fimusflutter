class TelecomOperator {
  final String id;
  String name;
  String? userPhoneNumber;
  String country;

  TelecomOperator({
    required this.id,
    required this.name,
    this.userPhoneNumber,
    this.country = 'Cameroun',
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'userPhoneNumber': userPhoneNumber,
      'country': country,
    };
  }

  factory TelecomOperator.fromJson(Map<String, dynamic> json) {
    return TelecomOperator(
      id: json['id'],
      name: json['name'],
      userPhoneNumber: json['userPhoneNumber'],
      country: json['country'] ?? 'Cameroun',
    );
  }
}
