import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:monitrack/services/notifications/pending_notification_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PendingNotificationStore.pendingAction = null;
    PendingNotificationStore.pendingData = null;
  });

  test('persist + restore action cold start', () async {
    await PendingNotificationStore.persistAction({
      'action': 'scheduled_confirm',
      'expense_uuid': 'exp-1',
    });
    PendingNotificationStore.pendingAction = null;

    await PendingNotificationStore.restore();
    expect(PendingNotificationStore.pendingAction?['action'], 'scheduled_confirm');
    expect(PendingNotificationStore.pendingAction?['expense_uuid'], 'exp-1');
  });

  test('persist + restore data tap', () async {
    await PendingNotificationStore.persistData({
      'type': 'new_joint_debt',
      'expense_uuid': 'abc',
    });
    PendingNotificationStore.pendingData = null;

    await PendingNotificationStore.restore();
    expect(PendingNotificationStore.pendingData?['type'], 'new_joint_debt');
  });

  test('clear action ne touche pas data', () async {
    await PendingNotificationStore.persistAction({'action': 'x'});
    await PendingNotificationStore.persistData({'type': 'y'});
    await PendingNotificationStore.clear(action: true);

    expect(PendingNotificationStore.pendingAction, isNull);
    expect(PendingNotificationStore.pendingData?['type'], 'y');
  });
}
