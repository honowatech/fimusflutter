class Contact {
  final int id;
  final String name;
  final String email;
  final String userCode;
  final String pseudo;
  final String? alias;

  Contact({
    required this.id,
    required this.name,
    required this.email,
    required this.userCode,
    this.pseudo = '',
    this.alias,
  });

  String get displayName => (alias != null && alias!.isNotEmpty) ? alias! : name;

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      userCode: json['user_code'] ?? '',
      pseudo: json['pseudo'] ?? '',
      alias: json['pivot'] != null ? json['pivot']['alias'] : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'user_code': userCode,
      'pseudo': pseudo,
      'alias': alias,
    };
  }
}
