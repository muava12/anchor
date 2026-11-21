import 'package:anchor/app/router/app_routes.dart';
import 'package:anchor/features/reminders/data/reminder_actions.dart';
import 'package:anchor/features/reminders/presentation/notification_launch.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('handleLaunchNotification', () {
    test('a cold-start Done is delivered to the engine, not routed', () {
      final route = handleLaunchNotification(
        didNotificationLaunchApp: true,
        actionId: reminderActionWireId(ReminderActionType.done),
        payload: 'note-1',
        notificationId: 7,
      );

      expect(route, isNull);
      expect(takePendingReminderActions(), [
        const ReminderAction(
          id: 7,
          type: ReminderActionType.done,
          noteId: 'note-1',
        ),
      ]);
    });

    test('a cold-start Snooze is delivered', () {
      handleLaunchNotification(
        didNotificationLaunchApp: true,
        actionId: reminderActionWireId(ReminderActionType.snooze),
        payload: 'note-2',
      );

      expect(takePendingReminderActions(), [
        const ReminderAction(
          type: ReminderActionType.snooze,
          noteId: 'note-2',
        ),
      ]);
    });

    test('a swipe-away (dismiss) is delivered', () {
      handleLaunchNotification(
        didNotificationLaunchApp: true,
        payload: 'note-3',
        dismissed: true,
      );

      expect(takePendingReminderActions(), [
        const ReminderAction(
          type: ReminderActionType.dismiss,
          noteId: 'note-3',
        ),
      ]);
    });

    test('an ordinary body tap returns the note route and no action', () {
      final route = handleLaunchNotification(
        didNotificationLaunchApp: true,
        payload: 'note-1',
      );

      expect(route, AppRoutes.widgetNote('note-1'));
      expect(takePendingReminderActions(), isEmpty);
    });

    test('a launch the app made itself is left alone', () {
      final route = handleLaunchNotification(
        didNotificationLaunchApp: false,
        actionId: reminderActionWireId(ReminderActionType.done),
        payload: 'note-1',
      );

      expect(route, isNull);
      expect(takePendingReminderActions(), isEmpty);
    });

    test('an action with no payload is not delivered', () {
      final route = handleLaunchNotification(
        didNotificationLaunchApp: true,
        actionId: reminderActionWireId(ReminderActionType.done),
        payload: null,
      );

      expect(route, isNull);
      expect(takePendingReminderActions(), isEmpty);
    });
  });

  group('drainNativePendingAction', () {
    testWidgets('returns null on non-Android platforms', (tester) async {
      // Platform.isAndroid is false on the test host, so the function
      // returns null without touching the channel.
      final action = await drainNativePendingAction();
      expect(action, isNull);
    });
  });
}