import '../models/notification_model.dart';

class InboxDaySection {
  final String label;
  final List<NotificationModel> items;

  const InboxDaySection({required this.label, required this.items});
}

class InboxMerge {
  /// Retire les placeholders `push_*` dès qu'une notif serveur a la même clé.
  static List<NotificationModel> mergePushPlaceholders(
    List<NotificationModel> serverItems,
    List<NotificationModel> previous,
  ) {
    final serverKeys = serverItems.map((n) => n.dedupeKey).toSet();
    final serverIds = serverItems.map((n) => n.id).toSet();
    final leftoverPush = previous.where(
      (n) =>
          n.isPlaceholder &&
          !serverKeys.contains(n.dedupeKey) &&
          !serverIds.contains(n.id),
    );
    final merged = [...serverItems];
    for (final push in leftoverPush) {
      if (!merged.any((n) => n.dedupeKey == push.dedupeKey)) {
        merged.insert(0, push);
      }
    }
    return merged;
  }

  static DateTime? parseCreatedAt(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  static DateTime dayKey(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static List<InboxDaySection> groupByDay(
    List<NotificationModel> items, {
    required DateTime now,
    required String todayLabel,
    required String yesterdayLabel,
    required String Function(DateTime) formatOther,
  }) {
    final today = dayKey(now);
    final yesterday = today.subtract(const Duration(days: 1));
    final map = <DateTime, List<NotificationModel>>{};
    final undated = <NotificationModel>[];

    for (final item in items) {
      final created = parseCreatedAt(item.createdAt);
      if (created == null) {
        undated.add(item);
        continue;
      }
      map.putIfAbsent(dayKey(created), () => []).add(item);
    }

    final keys = map.keys.toList()..sort((a, b) => b.compareTo(a));
    final sections = <InboxDaySection>[];
    for (final key in keys) {
      final label = key == today
          ? todayLabel
          : key == yesterday
              ? yesterdayLabel
              : formatOther(key);
      sections.add(InboxDaySection(label: label, items: map[key]!));
    }
    if (undated.isNotEmpty) {
      sections.add(InboxDaySection(label: formatOther(now), items: undated));
    }
    return sections;
  }
}
