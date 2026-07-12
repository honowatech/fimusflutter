class UssdHistory {
  final String id;
  final String operationName;
  final String providerName;
  final String ussdCode;
  final DateTime date;

  UssdHistory({
    required this.id,
    required this.operationName,
    required this.providerName,
    required this.ussdCode,
    required this.date,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'operationName': operationName,
      'providerName': providerName,
      'ussdCode': ussdCode,
      'date': date.toIso8601String(),
    };
  }

  factory UssdHistory.fromJson(Map<String, dynamic> json) {
    return UssdHistory(
      id: json['id'],
      operationName: json['operationName'],
      providerName: json['providerName'],
      ussdCode: json['ussdCode'],
      date: DateTime.parse(json['date']),
    );
  }

  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'operationName': operationName,
      'providerName': providerName,
      'ussdCode': ussdCode,
      'date': date.toIso8601String(),
    };
  }

  factory UssdHistory.fromDbMap(Map<String, dynamic> map) {
    return UssdHistory(
      id: map['id'] ?? '',
      operationName: map['operationName'] ?? '',
      providerName: map['providerName'] ?? '',
      ussdCode: map['ussdCode'] ?? '',
      date: map['date'] != null ? DateTime.parse(map['date']) : DateTime.now(),
    );
  }
}
