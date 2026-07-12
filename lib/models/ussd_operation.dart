import 'dart:convert';

class UssdOperation {
  final String id;
  String name;
  final String provider; // 'Orange' or 'MTN'
  String category;
  String defaultTemplate;
  String customTemplate;
  final List<String> requiredFields;

  UssdOperation({
    required this.id,
    required this.name,
    required this.provider,
    this.category = 'Autre',
    required this.defaultTemplate,
    String? customTemplate,
    required this.requiredFields,
  }) : customTemplate = customTemplate ?? defaultTemplate;

  String get activeTemplate => customTemplate.isNotEmpty ? customTemplate : defaultTemplate;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'provider': provider,
      'category': category,
      'defaultTemplate': defaultTemplate,
      'customTemplate': customTemplate,
      'requiredFields': requiredFields,
    };
  }

  factory UssdOperation.fromJson(Map<String, dynamic> json) {
    return UssdOperation(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      provider: json['provider'] ?? '',
      category: json['category'] ?? 'Autre',
      defaultTemplate: json['defaultTemplate'] ?? '',
      customTemplate: json['customTemplate'],
      requiredFields: List<String>.from(json['requiredFields'] ?? []),
    );
  }

  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'name': name,
      'provider': provider,
      'category': category,
      'defaultTemplate': defaultTemplate,
      'customTemplate': customTemplate,
      'requiredFields': jsonEncode(requiredFields),
    };
  }

  factory UssdOperation.fromDbMap(Map<String, dynamic> map) {
    return UssdOperation(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      provider: map['provider'] ?? '',
      category: map['category'] ?? 'Autre',
      defaultTemplate: map['defaultTemplate'] ?? '',
      customTemplate: map['customTemplate'],
      requiredFields: map['requiredFields'] != null ? List<String>.from(jsonDecode(map['requiredFields'])) : [],
    );
  }
}
