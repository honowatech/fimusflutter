class UssdHistory {
  final String id;
  final String operationName;
  final String providerName;
  final String ussdCode;
  final DateTime date;
  final String status;
  final String? response;
  final DateTime? updatedAt;

  UssdHistory({
    required this.id,
    required this.operationName,
    required this.providerName,
    required this.ussdCode,
    required this.date,
    this.status = 'success',
    this.response,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'operationName': operationName,
      'providerName': providerName,
      'ussdCode': ussdCode,
      'date': date.toIso8601String(),
      'status': status,
      'response': response,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory UssdHistory.fromJson(Map<String, dynamic> json) {
    return UssdHistory(
      id: json['id']?.toString() ?? '',
      operationName: json['operationName']?.toString() ?? json['operation_name']?.toString() ?? '',
      providerName: json['providerName']?.toString() ?? json['provider_name']?.toString() ?? '',
      ussdCode: json['ussdCode']?.toString() ?? json['ussd_code']?.toString() ?? '',
      date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
      status: json['status']?.toString() ?? 'success',
      response: json['response']?.toString(),
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
      'operationName': operationName,
      'providerName': providerName,
      'ussdCode': ussdCode,
      'date': date.toIso8601String(),
      'status': status,
      'response': response,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory UssdHistory.fromDbMap(Map<String, dynamic> map) {
    return UssdHistory(
      id: map['id']?.toString() ?? '',
      operationName: map['operationName']?.toString() ?? '',
      providerName: map['providerName']?.toString() ?? '',
      ussdCode: map['ussdCode']?.toString() ?? '',
      date: map['date'] != null ? DateTime.parse(map['date']) : DateTime.now(),
      status: map['status']?.toString() ?? 'success',
      response: map['response']?.toString(),
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at']) : null,
    );
  }
}
