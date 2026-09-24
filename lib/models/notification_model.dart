import 'dart:convert';

import '../utils/notification_route.dart';

class NotificationPageResult {
  final List<NotificationModel> items;
  final int currentPage;
  final int lastPage;
  final int unreadCount;

  final bool success;

  const NotificationPageResult({
    required this.items,
    this.currentPage = 1,
    this.lastPage = 1,
    this.unreadCount = 0,
    this.success = true,
  });
}

/// Catégorie métier d'une notification, dérivée de `data['type']`.
///
/// Elle pilote à la fois l'habillage de la tuile (icône + couleur) et les
/// filtres du centre de notifications.
///
/// La table des types doit rester alignée avec `NotificationRoute.fromData`
/// et `NotificationChannels.androidChannelIdForType`.
enum NotificationCategory {
  debts,
  contacts,
  jointAccounts,
  scheduledExpenses,
  announcements,
  other;

  static const Set<String> _debtTypes = {
    'new_debt',
    'new_joint_debt',
    'debt_created',
    'debt_updated',
    'debt_rejected',
    'debt_due_date_reminder',
  };

  static NotificationCategory fromType(String? type) {
    if (type == null || type.isEmpty) return NotificationCategory.other;
    if (_debtTypes.contains(type)) return NotificationCategory.debts;
    switch (type) {
      case 'contact_added':
        return NotificationCategory.contacts;
      case 'joint_account_added':
        return NotificationCategory.jointAccounts;
      case 'scheduled_expense_due':
        return NotificationCategory.scheduledExpenses;
      case 'mass_broadcast':
      case 'announcements':
        return NotificationCategory.announcements;
      default:
        return NotificationCategory.other;
    }
  }
}

/// Tranche temporelle utilisée pour les en-têtes de section de l'inbox.
enum NotificationDateBucket {
  today,
  yesterday,
  thisWeek,
  earlier;

  /// Une notification sans date lisible est reléguée en fin de liste
  /// ([NotificationDateBucket.earlier]), jamais perdue.
  static NotificationDateBucket of(DateTime? date, {required DateTime now}) {
    if (date == null) return NotificationDateBucket.earlier;
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final days = today.difference(day).inDays;
    // Une date future (horloge décalée) est traitée comme « aujourd'hui ».
    if (days <= 0) return NotificationDateBucket.today;
    if (days == 1) return NotificationDateBucket.yesterday;
    if (days <= 7) return NotificationDateBucket.thisWeek;
    return NotificationDateBucket.earlier;
  }
}

class NotificationModel {
  /// Préfixe des identifiants purement locaux (placeholders créés depuis un push
  /// quand le serveur n'a pas fourni `notification_id`).
  static const String placeholderPrefix = 'push_';

  final String id;
  final String? type;
  final String? notifiableType;
  final String? notifiableId;
  final Map<String, dynamic> data;
  final String? readAt;
  final String? createdAt;
  final String? updatedAt;

  const NotificationModel({
    required this.id,
    this.type,
    this.notifiableType,
    this.notifiableId,
    required this.data,
    this.readAt,
    this.createdAt,
    this.updatedAt,
  });

  /// Modèle immuable : toute mutation passe par une copie.
  /// `readAt` est remis à `null` via `clearReadAt` (un `null` passé en
  /// paramètre signifie « ne change pas »).
  NotificationModel copyWith({
    String? id,
    String? type,
    String? notifiableType,
    String? notifiableId,
    Map<String, dynamic>? data,
    String? readAt,
    bool clearReadAt = false,
    String? createdAt,
    String? updatedAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      type: type ?? this.type,
      notifiableType: notifiableType ?? this.notifiableType,
      notifiableId: notifiableId ?? this.notifiableId,
      data: data ?? this.data,
      readAt: clearReadAt ? null : (readAt ?? this.readAt),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Construit une entrée d'inbox à partir du `data` d'un push FCM.
  ///
  /// Contrat backend : si `data['notification_id']` est présent, c'est l'id de
  /// la notification Laravel — les actions serveur (lu / suppression) sont donc
  /// permises immédiatement. Sinon on fabrique un placeholder local inerte
  /// `push_<clé de dédoublonnage>`, remplacé au prochain `fetch`.
  factory NotificationModel.fromPush(
    Map<String, dynamic> pushData, {
    required String dedupeKey,
  }) {
    final serverId = pushData['notification_id']?.toString().trim();
    final hasServerId = serverId != null && serverId.isNotEmpty;
    return NotificationModel(
      id: hasServerId ? serverId : '$placeholderPrefix$dedupeKey',
      type: pushData['type']?.toString(),
      data: Map<String, dynamic>.from(pushData),
      createdAt: DateTime.now().toUtc().toIso8601String(),
    );
  }

  /// `true` tant que la notification n'existe que côté application : aucune
  /// requête API ne doit être émise avec cet id.
  bool get isPlaceholder => id.startsWith(placeholderPrefix);

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

  String get title => data['title']?.toString() ?? '';
  String get message {
    final value = data['message']?.toString() ?? data['body']?.toString() ?? '';
    if (value.isNotEmpty) return value;
    if (title.isNotEmpty) return title;
    return '';
  }
  String? get dataType => data['type']?.toString();

  /// Date de création ramenée au fuseau local (`null` si absente ou illisible).
  DateTime? get createdAtLocal {
    final raw = createdAt;
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  /// Catégorie métier. `data['type']` fait foi ; `type` (nom de classe Laravel)
  /// ne sert que de repli.
  NotificationCategory get category =>
      NotificationCategory.fromType(dataType ?? type);

  /// Doit rester aligné sur [NotificationRoute.dedupeKey] : c'est ce qui permet
  /// à une ligne serveur de remplacer le placeholder issu du push.
  String get dedupeKey {
    final kind = dataType ?? type ?? '';
    // Source unique de la règle, partagée avec le routage : les alertes sans
    // entité (nouvelle connexion, bilan hebdomadaire) y sont traitées.
    final entity = NotificationRoute.entityFor(data);
    if (entity != null && entity.toString().isNotEmpty) {
      return '$kind|$entity';
    }
    // Placeholder : l'id encapsule déjà la clé calculée au moment du push.
    if (isPlaceholder) return id.substring(placeholderPrefix.length);
    return '$kind|$id';
  }

  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'type': type,
      'data': jsonEncode(data),
      'read_at': readAt,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory NotificationModel.fromDbMap(Map<String, dynamic> row) {
    Map<String, dynamic> data = {};
    final raw = row['data'];
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) data = Map<String, dynamic>.from(decoded);
      } catch (_) {}
    } else if (raw is Map) {
      data = Map<String, dynamic>.from(raw);
    }
    return NotificationModel(
      id: row['id']?.toString() ?? '',
      type: row['type']?.toString(),
      data: data,
      readAt: row['read_at']?.toString(),
      createdAt: row['created_at']?.toString(),
      updatedAt: row['updated_at']?.toString(),
    );
  }
}
