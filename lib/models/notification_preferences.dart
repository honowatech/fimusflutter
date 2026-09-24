import 'package:flutter/material.dart' show TimeOfDay;

/// Préférences de notification de l'utilisateur.
///
/// Contrat d'API (`/users/notification-preferences`) :
/// `notify_debts`, `notify_contacts`, `notify_joint_accounts`,
/// `notify_scheduled_expenses`, `notify_announcements`,
/// `notify_weekly_digest` (booléens, défaut
/// `true`), `reminder_hour` (`"HH:mm"`, défaut `"08:30"`),
/// `quiet_hours_enabled` (booléen, défaut `false`), `quiet_hours_start` et
/// `quiet_hours_end` (`"HH:mm"`, défauts `"22:00"` et `"07:00"`).
///
/// La désérialisation est tolérante aux champs absents : un serveur plus
/// ancien qui ne renvoie que les quatre booléens historiques reste accepté,
/// les nouveaux champs reprenant alors leur valeur par défaut.
class NotificationPreferences {
  static const String defaultReminderHour = '08:30';
  static const String defaultQuietHoursStart = '22:00';
  static const String defaultQuietHoursEnd = '07:00';

  final bool notifyDebts;
  final bool notifyContacts;
  final bool notifyJointAccounts;
  final bool notifyScheduledExpenses;
  final bool notifyAnnouncements;

  /// Bilan hebdomadaire (`weekly_digest`, sprint 5) : dixième clé du contrat
  /// serveur. Ne coupe que ce résumé, aucune autre notification.
  final bool notifyWeeklyDigest;

  /// Heure d'envoi des rappels d'échéance, au format `"HH:mm"`.
  final String reminderHour;

  final bool quietHoursEnabled;

  /// Début / fin des heures calmes, au format `"HH:mm"`.
  final String quietHoursStart;
  final String quietHoursEnd;

  const NotificationPreferences({
    this.notifyDebts = true,
    this.notifyContacts = true,
    this.notifyJointAccounts = true,
    this.notifyScheduledExpenses = true,
    this.notifyAnnouncements = true,
    this.notifyWeeklyDigest = true,
    this.reminderHour = defaultReminderHour,
    this.quietHoursEnabled = false,
    this.quietHoursStart = defaultQuietHoursStart,
    this.quietHoursEnd = defaultQuietHoursEnd,
  });

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      notifyDebts: _asBool(json['notify_debts'], true),
      notifyContacts: _asBool(json['notify_contacts'], true),
      notifyJointAccounts: _asBool(json['notify_joint_accounts'], true),
      notifyScheduledExpenses:
          _asBool(json['notify_scheduled_expenses'], true),
      // `notify_campaigns` : ancien nom du champ, encore renvoyé par les
      // serveurs non migrés.
      notifyAnnouncements: _asBool(
        json['notify_announcements'] ?? json['notify_campaigns'],
        true,
      ),
      // Tolérance : un serveur non migré ne renvoie pas la dixième clé, le
      // bilan reste alors activé (valeur par défaut du backend).
      notifyWeeklyDigest: _asBool(json['notify_weekly_digest'], true),
      reminderHour: _asTimeString(json['reminder_hour'], defaultReminderHour),
      quietHoursEnabled: _asBool(json['quiet_hours_enabled'], false),
      quietHoursStart:
          _asTimeString(json['quiet_hours_start'], defaultQuietHoursStart),
      quietHoursEnd:
          _asTimeString(json['quiet_hours_end'], defaultQuietHoursEnd),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'notify_debts': notifyDebts,
      'notify_contacts': notifyContacts,
      'notify_joint_accounts': notifyJointAccounts,
      'notify_scheduled_expenses': notifyScheduledExpenses,
      'notify_announcements': notifyAnnouncements,
      'notify_weekly_digest': notifyWeeklyDigest,
      'reminder_hour': reminderHour,
      'quiet_hours_enabled': quietHoursEnabled,
      'quiet_hours_start': quietHoursStart,
      'quiet_hours_end': quietHoursEnd,
    };
  }

  NotificationPreferences copyWith({
    bool? notifyDebts,
    bool? notifyContacts,
    bool? notifyJointAccounts,
    bool? notifyScheduledExpenses,
    bool? notifyAnnouncements,
    bool? notifyWeeklyDigest,
    String? reminderHour,
    bool? quietHoursEnabled,
    String? quietHoursStart,
    String? quietHoursEnd,
  }) {
    return NotificationPreferences(
      notifyDebts: notifyDebts ?? this.notifyDebts,
      notifyContacts: notifyContacts ?? this.notifyContacts,
      notifyJointAccounts: notifyJointAccounts ?? this.notifyJointAccounts,
      notifyScheduledExpenses:
          notifyScheduledExpenses ?? this.notifyScheduledExpenses,
      notifyAnnouncements: notifyAnnouncements ?? this.notifyAnnouncements,
      notifyWeeklyDigest: notifyWeeklyDigest ?? this.notifyWeeklyDigest,
      reminderHour: reminderHour ?? this.reminderHour,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
    );
  }

  // --- Accès horaires ------------------------------------------------------

  TimeOfDay get reminderTime => parseTime(reminderHour, defaultReminderHour);
  TimeOfDay get quietStartTime =>
      parseTime(quietHoursStart, defaultQuietHoursStart);
  TimeOfDay get quietEndTime => parseTime(quietHoursEnd, defaultQuietHoursEnd);

  /// Convertit `"HH:mm"` en [TimeOfDay], en retombant sur [fallback] si la
  /// chaîne est invalide.
  static TimeOfDay parseTime(String value, String fallback) {
    final parsed = _tryParseTime(value) ?? _tryParseTime(fallback);
    return parsed ?? const TimeOfDay(hour: 0, minute: 0);
  }

  /// Formate un [TimeOfDay] en `"HH:mm"` (indépendant de la locale, contrat
  /// d'API).
  static String formatTime(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// `true` si [moment] tombe dans la plage d'heures calmes (la plage peut
  /// traverser minuit, par ex. 22:00 → 07:00). Utilisé par les modules de
  /// rappels locaux pour filtrer les notifications.
  bool isWithinQuietHours(DateTime moment) {
    if (!quietHoursEnabled) return false;
    final start = quietStartTime;
    final end = quietEndTime;
    final current = moment.hour * 60 + moment.minute;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;
    if (startMinutes == endMinutes) return false;
    if (startMinutes < endMinutes) {
      return current >= startMinutes && current < endMinutes;
    }
    // Plage à cheval sur minuit.
    return current >= startMinutes || current < endMinutes;
  }

  // --- Helpers de désérialisation -----------------------------------------

  static bool _asBool(dynamic value, bool fallback) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') return true;
      if (normalized == 'false' || normalized == '0') return false;
    }
    return fallback;
  }

  static String _asTimeString(dynamic value, String fallback) {
    if (value is String) {
      final parsed = _tryParseTime(value);
      if (parsed != null) return formatTime(parsed);
    }
    return fallback;
  }

  static TimeOfDay? _tryParseTime(String value) {
    final match = RegExp(r'^(\d{1,2}):(\d{1,2})').firstMatch(value.trim());
    if (match == null) return null;
    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationPreferences &&
          other.notifyDebts == notifyDebts &&
          other.notifyContacts == notifyContacts &&
          other.notifyJointAccounts == notifyJointAccounts &&
          other.notifyScheduledExpenses == notifyScheduledExpenses &&
          other.notifyAnnouncements == notifyAnnouncements &&
          other.notifyWeeklyDigest == notifyWeeklyDigest &&
          other.reminderHour == reminderHour &&
          other.quietHoursEnabled == quietHoursEnabled &&
          other.quietHoursStart == quietHoursStart &&
          other.quietHoursEnd == quietHoursEnd;

  @override
  int get hashCode => Object.hash(
        notifyDebts,
        notifyContacts,
        notifyJointAccounts,
        notifyScheduledExpenses,
        notifyAnnouncements,
        notifyWeeklyDigest,
        reminderHour,
        quietHoursEnabled,
        quietHoursStart,
        quietHoursEnd,
      );
}
