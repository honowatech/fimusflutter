class NotificationModel {
  final String id;
  final String? type;
  final String? notifiableType;
  final String? notifiableId;
  final Map<String, dynamic> data;
  String? readAt;
  final String? createdAt;
  final String? updatedAt;

  NotificationModel({
    required this.id,
    this.type,
    this.notifiableType,
    this.notifiableId,
    required this.data,
    this.readAt,
    this.createdAt,
    this.updatedAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString(),
      notifiableType: json['notifiable_type']?.toString(),
      notifiableId: json['notifiable_id']?.toString(),
      data: json['data'] != null ? Map<String, dynamic>.from(json['data']) : {},
      readAt: json['read_at']?.toString(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'notifiable_type': notifiableType,
      'notifiable_id': notifiableId,
      'data': data,
      'read_at': readAt,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  bool get isRead => readAt != null;

  String get message => data['message']?.toString() ?? 'Nouvelle notification';
  String? get dataType => data['type']?.toString();
}
