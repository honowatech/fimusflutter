import 'package:flutter_test/flutter_test.dart';
import 'package:monitrack/models/notification_preferences.dart';

void main() {
  group('NotificationPreferences', () {
    test('default constructor initializes with true', () {
      final prefs = NotificationPreferences();

      expect(prefs.notifyDebts, true);
      expect(prefs.notifyContacts, true);
      expect(prefs.notifyJointAccounts, true);
      expect(prefs.notifyAnnouncements, true);
    });

    test('fromJson correctly parses map', () {
      final json = {
        'notify_debts': false,
        'notify_contacts': true,
        'notify_joint_accounts': false,
        'notify_campaigns': false,
      };

      final prefs = NotificationPreferences.fromJson(json);

      expect(prefs.notifyDebts, false);
      expect(prefs.notifyContacts, true);
      expect(prefs.notifyJointAccounts, false);
      expect(prefs.notifyAnnouncements, false);
    });

    test('toJson correctly serializes to map', () {
      final prefs = NotificationPreferences(
        notifyDebts: true,
        notifyContacts: false,
        notifyJointAccounts: true,
      );

      final json = prefs.toJson();

      expect(json['notify_debts'], true);
      expect(json['notify_contacts'], false);
      expect(json['notify_joint_accounts'], true);
      expect(json['notify_announcements'], true);
    });

    test('copyWith ne change que les champs fournis', () {
      final prefs = NotificationPreferences(
        notifyDebts: true,
        notifyContacts: true,
        notifyJointAccounts: false,
      );

      final updated = prefs.copyWith(notifyDebts: false);

      expect(updated.notifyDebts, false);
      expect(updated.notifyContacts, true);
      expect(updated.notifyJointAccounts, false);
    });
  });
}
