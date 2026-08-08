import 'package:flutter_test/flutter_test.dart';
import 'package:monitrack/models/notification_preferences.dart';

void main() {
  group('NotificationPreferences', () {
    test('default constructor initializes with true', () {
      final prefs = NotificationPreferences();

      expect(prefs.notifyDebts, true);
      expect(prefs.notifyContacts, true);
      expect(prefs.notifyJointAccounts, true);
    });

    test('fromJson correctly parses map', () {
      final json = {
        'notify_debts': false,
        'notify_contacts': true,
        'notify_joint_accounts': false,
      };

      final prefs = NotificationPreferences.fromJson(json);

      expect(prefs.notifyDebts, false);
      expect(prefs.notifyContacts, true);
      expect(prefs.notifyJointAccounts, false);
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
    });
  });
}
