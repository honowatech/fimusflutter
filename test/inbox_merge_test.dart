import 'package:flutter_test/flutter_test.dart';
import 'package:monitrack/models/notification_model.dart';
import 'package:monitrack/utils/inbox_merge.dart';
import 'package:monitrack/utils/pin_hasher.dart';

void main() {
  group('InboxMerge.mergePushPlaceholders', () {
    test('remplace le placeholder push par la ligne serveur', () {
      final push = NotificationModel(
        id: 'push_new_joint_debt|abc',
        data: {'type': 'new_joint_debt', 'expense_uuid': 'abc'},
        createdAt: DateTime.now().toIso8601String(),
      );
      final server = NotificationModel(
        id: 'uuid-server',
        data: {
          'type': 'new_joint_debt',
          'expense_uuid': 'abc',
          'message': 'ok',
        },
        createdAt: DateTime.now().toIso8601String(),
      );

      final merged = InboxMerge.mergePushPlaceholders([server], [push]);
      expect(merged, hasLength(1));
      expect(merged.single.id, 'uuid-server');
    });

    test('conserve un push sans équivalent serveur', () {
      final push = NotificationModel(
        id: 'push_contact_added|9',
        data: {'type': 'contact_added', 'added_by_user_id': '9'},
      );
      final merged = InboxMerge.mergePushPlaceholders(const [], [push]);
      expect(merged.single.id, push.id);
    });
  });

  group('InboxMerge.groupByDay', () {
    test('sépare aujourd\'hui et hier', () {
      final now = DateTime(2026, 9, 15, 18);
      final today = NotificationModel(
        id: '1',
        data: const {},
        createdAt: DateTime(2026, 9, 15, 10).toIso8601String(),
      );
      final yesterday = NotificationModel(
        id: '2',
        data: const {},
        createdAt: DateTime(2026, 9, 14, 9).toIso8601String(),
      );

      final sections = InboxMerge.groupByDay(
        [today, yesterday],
        now: now,
        todayLabel: 'Aujourd\'hui',
        yesterdayLabel: 'Hier',
        formatOther: (_) => 'autre',
      );

      expect(sections, hasLength(2));
      expect(sections.first.label, 'Aujourd\'hui');
      expect(sections.first.items.single.id, '1');
      expect(sections.last.label, 'Hier');
    });
  });

  group('PinHasher', () {
    test('v2 est déterministe et distinct du legacy', () {
      const pin = '1234';
      const salt = 'device-salt';
      expect(PinHasher.hashV2(pin, salt), PinHasher.hashV2(pin, salt));
      expect(PinHasher.hashV2(pin, salt), isNot(PinHasher.hashLegacy(pin)));
      expect(PinHasher.isV2(PinHasher.hashV2(pin, salt)), isTrue);
    });

    test('matches accepte legacy et v2', () {
      const pin = '1234';
      const salt = 'abc';
      expect(PinHasher.matches(pin, PinHasher.hashLegacy(pin), salt), isTrue);
      expect(PinHasher.matches(pin, PinHasher.hashV2(pin, salt), salt), isTrue);
      expect(PinHasher.matches(pin, pin, salt), isTrue);
      expect(PinHasher.matches('0000', PinHasher.hashV2(pin, salt), salt), isFalse);
    });
  });
}
