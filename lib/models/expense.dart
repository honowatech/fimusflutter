class Expense {
  final String id;
  final String title;
  final double amount;
  final String category;
  final DateTime date;
  final String? note;
  final String type; // 'expense' or 'income'
  final String? accountId;
  final String? debtTag;
  final String? debtorUserId;
  final String debtStatus;
  final bool isLinkedToCashFlow;
  final bool isPlanned; // To mark future scheduled installments
  final double? interestRate;
  final int? repaymentDuration;
  final String? durationUnit; // 'Mois', 'Années'
  final String? repaymentFrequency; // 'Mensuelle', 'Hebdomadaire', etc.
  final double? installmentAmount;
  final String? creatorId;
  final String? creatorName;
  final String? originalType;
  final String? originalDebtTag;
  final String? originalDebtorUserId;
  final DateTime? updatedAt;

  Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
    this.note,
    this.type = 'expense',
    this.accountId,
    this.debtTag,
    this.debtorUserId,
    this.isLinkedToCashFlow = true,
    this.isPlanned = false,
    this.interestRate,
    this.repaymentDuration,
    this.durationUnit,
    this.repaymentFrequency,
    this.installmentAmount,
    this.creatorId,
    this.creatorName,
    this.originalType,
    this.originalDebtTag,
    this.originalDebtorUserId,
    this.debtStatus = 'pending',
    this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'category': category,
      'date': date.toIso8601String(),
      'note': note,
      'type': originalType ?? type,
      'accountId': accountId,
      'debtTag': originalDebtTag ?? debtTag,
      'debtorUserId': originalDebtorUserId ?? debtorUserId,
      'isLinkedToCashFlow': isLinkedToCashFlow,
      'isPlanned': isPlanned,
      'interestRate': interestRate,
      'repaymentDuration': repaymentDuration,
      'durationUnit': durationUnit,
      'repaymentFrequency': repaymentFrequency,
      'installmentAmount': installmentAmount,
      'creatorId': creatorId,
      'creatorName': creatorName,
      'debtStatus': debtStatus,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      category: json['category'] ?? 'Autre',
      date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
      note: json['note'],
      type: json['type'] ?? 'expense',
      accountId: json['accountId'],
      debtTag: json['debtTag'],
      debtorUserId: (json['debtorUserId'] ?? json['debtor_user_id'])?.toString(),
      isLinkedToCashFlow: json['isLinkedToCashFlow'] ?? true,
      isPlanned: json['isPlanned'] ?? false,
      interestRate: (json['interestRate'] as num?)?.toDouble(),
      repaymentDuration: json['repaymentDuration'] as int?,
      durationUnit: json['durationUnit'] as String?,
      repaymentFrequency: json['repaymentFrequency'] as String?,
      installmentAmount: (json['installmentAmount'] as num?)?.toDouble(),
      creatorId: (json['creatorId'] ?? json['creator_id'])?.toString(),
      creatorName: json['creatorName'] ?? json['creator_name'],
      debtStatus: json['debtStatus'] ?? json['debt_status'] ?? 'pending',
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at']) : (json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt']) : null),
    );
  }

  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'category': category,
      'date': date.toIso8601String(),
      'paymentMethod': '',
      'note': note,
      'type': originalType ?? type,
      'accountId': accountId,
      'debtTag': originalDebtTag ?? debtTag,
      'debtorName': '',
      'debtorPhoneNumber': '',
      'debtorUserId': originalDebtorUserId ?? debtorUserId,
      'debtStatus': debtStatus,
      'isLinkedToCashFlow': isLinkedToCashFlow ? 1 : 0,
      'isPlanned': isPlanned ? 1 : 0,
      'interestRate': interestRate,
      'repaymentDuration': repaymentDuration,
      'durationUnit': durationUnit,
      'repaymentFrequency': repaymentFrequency,
      'installmentAmount': installmentAmount,
      'creatorId': creatorId,
      'creatorName': creatorName,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory Expense.fromDbMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      category: map['category'] ?? 'Autre',
      date: map['date'] != null ? DateTime.parse(map['date']) : DateTime.now(),
      note: map['note'],
      type: map['type'] ?? 'expense',
      accountId: map['accountId'],
      debtTag: map['debtTag'],
      debtorUserId: map['debtorUserId']?.toString(),
      debtStatus: map['debtStatus'] ?? 'pending',
      isLinkedToCashFlow: map['isLinkedToCashFlow'] == 1,
      isPlanned: map['isPlanned'] == 1,
      interestRate: (map['interestRate'] as num?)?.toDouble(),
      repaymentDuration: map['repaymentDuration'] as int?,
      durationUnit: map['durationUnit'] as String?,
      repaymentFrequency: map['repaymentFrequency'] as String?,
      installmentAmount: (map['installmentAmount'] as num?)?.toDouble(),
      creatorId: map['creatorId']?.toString(),
      creatorName: map['creatorName'],
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at']) : null,
    );
  }

  Expense copyWith({
    String? id,
    String? title,
    double? amount,
    String? category,
    DateTime? date,
    String? note,
    String? type,
    String? accountId,
    String? debtTag,
    String? debtorUserId,
    bool? isLinkedToCashFlow,
    bool? isPlanned,
    double? interestRate,
    int? repaymentDuration,
    String? durationUnit,
    String? repaymentFrequency,
    double? installmentAmount,
    String? creatorId,
    String? creatorName,
    String? originalType,
    String? originalDebtTag,
    String? originalDebtorUserId,
    String? debtStatus,
    DateTime? updatedAt,
  }) {
    return Expense(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      date: date ?? this.date,
      note: note ?? this.note,
      type: type ?? this.type,
      accountId: accountId ?? this.accountId,
      debtTag: debtTag ?? this.debtTag,
      debtorUserId: debtorUserId ?? this.debtorUserId,
      isLinkedToCashFlow: isLinkedToCashFlow ?? this.isLinkedToCashFlow,
      isPlanned: isPlanned ?? this.isPlanned,
      interestRate: interestRate ?? this.interestRate,
      repaymentDuration: repaymentDuration ?? this.repaymentDuration,
      durationUnit: durationUnit ?? this.durationUnit,
      repaymentFrequency: repaymentFrequency ?? this.repaymentFrequency,
      installmentAmount: installmentAmount ?? this.installmentAmount,
      creatorId: creatorId ?? this.creatorId,
      creatorName: creatorName ?? this.creatorName,
      originalType: originalType ?? this.originalType,
      originalDebtTag: originalDebtTag ?? this.originalDebtTag,
      originalDebtorUserId: originalDebtorUserId ?? this.originalDebtorUserId,
      debtStatus: debtStatus ?? this.debtStatus,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
