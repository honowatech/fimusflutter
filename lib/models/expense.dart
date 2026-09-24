import '../utils/currency_converter.dart';

class Expense {
  final String id;
  final String title;
  final double amount;

  /// Devise du montant, code ISO 4217 à trois lettres (`XOF`, `XAF`, `EUR`…).
  ///
  /// `null` = devise inconnue, opération antérieure au palier 19 : l'affichage
  /// retombe sur la devise du profil. Posée à la création (devise du compte
  /// lié, sinon du profil) puis **jamais réécrite** : un montant reste dans la
  /// devise où il a été saisi, c'est ce qui donne un historique juste après un
  /// changement de pays.
  final String? currency;
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
  final DateTime? dueDate;
  final String? scheduleStatus; // 'scheduled' pour une dépense programmée en attente
  final DateTime? reminderAt; // Date/heure de la notification d'échéance
  final DateTime? createdAt; // Date/heure d'enregistrement de l'opération
  final DateTime? updatedAt;

  Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
    String? currency,
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
    this.dueDate,
    this.scheduleStatus,
    this.reminderAt,
    this.createdAt,
    this.updatedAt,
  }) : currency = CurrencyConverter.normalizeCode(currency);

  /// Date d'enregistrement de l'opération dans l'application.
  /// Pour les anciennes lignes sans [createdAt], on retombe sur la dernière
  /// modification connue puis sur la date de l'opération.
  DateTime get recordedAt => createdAt ?? updatedAt ?? date;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'currency': currency,
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
      'dueDate': dueDate?.toIso8601String(),
      'due_date': dueDate?.toIso8601String(),
      'scheduleStatus': scheduleStatus,
      'schedule_status': scheduleStatus,
      'reminderAt': reminderAt?.toIso8601String(),
      'reminder_at': reminderAt?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'],
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
      dueDate: json['dueDate'] != null ? DateTime.tryParse(json['dueDate']) : (json['due_date'] != null ? DateTime.tryParse(json['due_date']) : null),
      scheduleStatus: json['scheduleStatus'] ?? json['schedule_status'],
      reminderAt: json['reminderAt'] != null ? DateTime.tryParse(json['reminderAt']) : (json['reminder_at'] != null ? DateTime.tryParse(json['reminder_at']) : null),
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) : (json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null),
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at']) : (json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt']) : null),
    );
  }

  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'currency': currency,
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
      'dueDate': dueDate?.toIso8601String(),
      'scheduleStatus': scheduleStatus,
      'reminderAt': reminderAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory Expense.fromDbMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      currency: map['currency'],
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
      dueDate: map['dueDate'] != null ? DateTime.tryParse(map['dueDate']) : (map['due_date'] != null ? DateTime.tryParse(map['due_date']) : null),
      scheduleStatus: map['scheduleStatus'],
      reminderAt: map['reminderAt'] != null ? DateTime.tryParse(map['reminderAt']) : (map['reminder_at'] != null ? DateTime.tryParse(map['reminder_at']) : null),
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at']) : (map['createdAt'] != null ? DateTime.tryParse(map['createdAt']) : null),
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at']) : null,
    );
  }

  Expense copyWith({
    String? id,
    String? title,
    double? amount,
    String? currency,
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
    DateTime? dueDate,
    String? scheduleStatus,
    DateTime? reminderAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Expense(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
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
      dueDate: dueDate ?? this.dueDate,
      scheduleStatus: scheduleStatus ?? this.scheduleStatus,
      reminderAt: reminderAt ?? this.reminderAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Bascule une dépense programmée en dépense réelle (confirmée).
  /// La ligne conserve son id ; les champs de programmation sont remis à null.
  Expense confirmAsRealExpense({DateTime? newDate}) {
    return Expense(
      id: id,
      title: title,
      amount: amount,
      // La devise de saisie suit la ligne : la confirmation ne la réécrit pas.
      currency: currency,
      category: category,
      date: newDate ?? date,
      note: note,
      type: type,
      accountId: accountId,
      debtTag: debtTag,
      debtorUserId: debtorUserId,
      isLinkedToCashFlow: true,
      isPlanned: false,
      interestRate: interestRate,
      repaymentDuration: repaymentDuration,
      durationUnit: durationUnit,
      repaymentFrequency: repaymentFrequency,
      installmentAmount: installmentAmount,
      creatorId: creatorId,
      creatorName: creatorName,
      debtStatus: debtStatus,
      dueDate: dueDate,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
