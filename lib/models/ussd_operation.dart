import 'dart:convert';
import '../utils/ussd_formatter.dart';

class UssdOperation {
  final String id;
  String name;
  final String provider; // 'Orange' or 'MTN'
  String category;
  String defaultTemplate;
  String customTemplate;
  List<String> requiredFields;
  bool isEnabled;
  final DateTime? updatedAt;

  UssdOperation({
    required this.id,
    required this.name,
    required this.provider,
    this.category = 'Autre',
    required String defaultTemplate,
    String? customTemplate,
    List<String>? requiredFields,
    this.isEnabled = true,
    this.updatedAt,
  })  : defaultTemplate = UssdFormatter.normalizeTemplate(defaultTemplate),
        customTemplate = UssdFormatter.normalizeTemplate(customTemplate ?? defaultTemplate),
        requiredFields = requiredFields ?? [] {
    _syncRequiredFields();
  }

  String get activeTemplate =>
      customTemplate.isNotEmpty ? UssdFormatter.normalizeTemplate(customTemplate) : UssdFormatter.normalizeTemplate(defaultTemplate);

  bool get isAgentOperation {
    final lowerCat = category.toLowerCase();
    if (lowerCat == 'agent' || lowerCat.contains('agent')) {
      return true;
    }
    final lowerName = name.toLowerCase();
    return lowerName.contains('agent') ||
        lowerName.contains('cash-in') ||
        lowerName.contains('cash in') ||
        lowerName.contains('cash-out') ||
        lowerName.contains('cash out') ||
        lowerName.contains('code client') ||
        lowerName.contains('flotte') ||
        lowerName.contains('uv') ||
        lowerName.contains('dépôt') ||
        lowerName.contains('depot');
  }

  void _syncRequiredFields() {
    final extracted = UssdFormatter.extractFields(activeTemplate);
    final combined = {...requiredFields, ...extracted}.toList();
    requiredFields = combined;
  }

  Map<String, dynamic> toJson() {
    _syncRequiredFields();
    return {
      'id': id,
      'name': name,
      'provider': provider,
      'category': category,
      'defaultTemplate': UssdFormatter.normalizeTemplate(defaultTemplate),
      'customTemplate': UssdFormatter.normalizeTemplate(customTemplate),
      'requiredFields': requiredFields,
      'is_enabled': isEnabled ? 1 : 0,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory UssdOperation.fromJson(Map<String, dynamic> json) {
    final defTpl = UssdFormatter.normalizeTemplate(json['defaultTemplate']?.toString() ?? json['default_template']?.toString() ?? '');
    final custTplRaw = json['customTemplate'] ?? json['custom_template'];
    final custTpl = custTplRaw != null ? UssdFormatter.normalizeTemplate(custTplRaw.toString()) : defTpl;
    final jsonFields = List<String>.from(json['requiredFields'] ?? json['required_fields'] ?? []);
    final extracted = UssdFormatter.extractFields(custTpl.isNotEmpty ? custTpl : defTpl);

    final rawEnabled = json['is_enabled'] ?? json['isEnabled'];
    final bool enabledVal = rawEnabled != null ? (rawEnabled == 1 || rawEnabled == true || rawEnabled == '1' || rawEnabled == 'true') : true;

    return UssdOperation(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      provider: json['provider']?.toString() ?? '',
      category: json['category']?.toString() ?? 'Autre',
      defaultTemplate: defTpl,
      customTemplate: custTpl,
      requiredFields: {...jsonFields, ...extracted}.toList(),
      isEnabled: enabledVal,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : (json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString()) : null),
    );
  }

  Map<String, dynamic> toDbMap() {
    _syncRequiredFields();
    return {
      'id': id,
      'name': name,
      'provider': provider,
      'category': category,
      'defaultTemplate': UssdFormatter.normalizeTemplate(defaultTemplate),
      'customTemplate': UssdFormatter.normalizeTemplate(customTemplate),
      'requiredFields': jsonEncode(requiredFields),
      'is_enabled': isEnabled ? 1 : 0,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory UssdOperation.fromDbMap(Map<String, dynamic> map) {
    final defTpl = UssdFormatter.normalizeTemplate(map['defaultTemplate']?.toString() ?? map['default_template']?.toString() ?? '');
    final custTplRaw = map['customTemplate'] ?? map['custom_template'];
    final custTpl = custTplRaw != null ? UssdFormatter.normalizeTemplate(custTplRaw.toString()) : defTpl;
    final dbFields = map['requiredFields'] != null ? List<String>.from(jsonDecode(map['requiredFields'])) : <String>[];
    final extracted = UssdFormatter.extractFields(custTpl.isNotEmpty ? custTpl : defTpl);

    final rawEnabled = map['is_enabled'] ?? map['isEnabled'];
    final bool enabledVal = rawEnabled != null ? (rawEnabled == 1 || rawEnabled == true || rawEnabled == '1' || rawEnabled == 'true') : true;

    return UssdOperation(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      provider: map['provider']?.toString() ?? '',
      category: map['category']?.toString() ?? 'Autre',
      defaultTemplate: defTpl,
      customTemplate: custTpl,
      requiredFields: {...dbFields, ...extracted}.toList(),
      isEnabled: enabledVal,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) : null,
    );
  }
}

