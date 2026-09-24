import 'package:flutter_test/flutter_test.dart';
import 'package:monitrack/services/notifications/reminder_ids.dart';
import 'package:monitrack/utils/notification_channels.dart';

void main() {
  group('ReminderIds', () {
    test('debtWallClock est à 8h30 le jour J', () {
      final due = DateTime(2026, 9, 20, 23, 59);
      final wall = ReminderIds.debtWallClock(due);
      expect(wall.year, 2026);
      expect(wall.month, 9);
      expect(wall.day, 20);
      expect(wall.hour, 8);
      expect(wall.minute, 30);
    });

    test('isInThePast distingue futur et passé', () {
      final now = DateTime(2026, 9, 15, 10);
      expect(ReminderIds.isInThePast(DateTime(2026, 9, 15, 9), now), isTrue);
      expect(ReminderIds.isInThePast(DateTime(2026, 9, 15, 11), now), isFalse);
    });

    test('un instant égal à `now` est considéré comme passé', () {
      final now = DateTime(2026, 9, 15, 10);
      expect(ReminderIds.isInThePast(now, now), isTrue);
    });

    test('ids dette et dépense programmée ne collisionnent pas', () {
      const id = 'exp-42';
      expect(
        ReminderIds.debtNotificationId(id),
        isNot(ReminderIds.scheduledExpenseNotificationId(id)),
      );
      expect(
        ReminderIds.scheduledExpenseNotificationId(id),
        NotificationChannels.stableId('scheduled_$id'),
      );
      expect(ReminderIds.debtNotificationId(id), greaterThanOrEqualTo(0));
    });
  });

  group('Non-régression : collision rappel local / push métier', () {
    test(
        'l\'id du rappel de dette diffère de l\'id dérivé de l\'uuid nu '
        '(sinon un push écraserait le rappel encore programmé)', () {
      for (final uuid in [
        'exp-42',
        '3f2a9c10-0000-4000-8000-000000000001',
        'a',
        '',
      ]) {
        expect(
          ReminderIds.debtNotificationId(uuid),
          isNot(NotificationChannels.stableId(uuid)),
          reason: 'uuid = "$uuid"',
        );
      }
    });

    test('la graine de dette reste préfixée', () {
      expect(ReminderIds.debtIdSeed('exp-42'), 'debt_exp-42');
      expect(ReminderIds.scheduledIdSeed('exp-42'), 'scheduled_exp-42');
      expect(
        ReminderIds.debtNotificationId('exp-42'),
        NotificationChannels.stableId('debt_exp-42'),
      );
    });

    test('les ids restent dans la plage 31-bit acceptée par le plugin', () {
      for (final uuid in ['exp-42', 'très-long-uuid-àéî', '0']) {
        for (final id in [
          ReminderIds.debtNotificationId(uuid),
          ReminderIds.scheduledExpenseNotificationId(uuid),
        ]) {
          expect(id, greaterThanOrEqualTo(0), reason: uuid);
          expect(id, lessThanOrEqualTo(0x7fffffff), reason: uuid);
        }
      }
    });

    test('deux uuid différents produisent deux ids différents', () {
      final ids = <int>{};
      for (var i = 0; i < 200; i++) {
        ids.add(ReminderIds.debtNotificationId('exp-$i'));
        ids.add(ReminderIds.scheduledExpenseNotificationId('exp-$i'));
      }
      expect(ids, hasLength(400));
    });
  });
}
