import 'package:anchor/features/reminders/data/notification_gateway.dart';
import 'package:anchor/features/reminders/data/reminder_actions.dart';
import 'package:anchor/features/reminders/presentation/notification_launch.dart';
import 'package:anchor/l10n/l10n.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

class RecordingGateway implements NotificationGateway {
  final cancelled = <int>[];

  @override
  Future<void> cancel(int id) async => cancelled.add(id);

  @override
  Future<void> cancelAll() async {}

  @override
  Future<void> schedule(ScheduledNotification notification) async {}

  @override
  Future<List<int>> pendingIds() async => const [];

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  bool get requiresExactAlarmPermission => false;

  @override
  Future<bool> canScheduleExact() async => true;

  @override
  Future<void> requestExactPermission() async {}
}

void main() {
  final english = lookupAppLocalizations(const Locale('en'));

  group('the action wire id', () {
    test('names the type the Android action id carries', () {
      expect(
        reminderActionWireId(ReminderActionType.done),
        'reminder_done',
      );
      expect(
        reminderActionWireId(ReminderActionType.snooze),
        'reminder_snooze',
      );
      expect(
        reminderActionWireId(ReminderActionType.dismiss),
        'reminder_dismiss',
      );
    });

    test('reads back the type an action id names', () {
      for (final type in ReminderActionType.values) {
        expect(reminderActionTypeForWireId(reminderActionWireId(type)), type);
      }
    });

    test('ignores ids that are not ours', () {
      expect(reminderActionTypeForWireId(null), isNull);
      expect(reminderActionTypeForWireId(''), isNull);
      expect(reminderActionTypeForWireId('reminder_'), isNull);
      expect(reminderActionTypeForWireId('reminder_snooze_again'), isNull);
      expect(reminderActionTypeForWireId('other_done'), isNull);
      expect(reminderActionTypeForWireId('done'), isNull);
    });
  });

  group('reading a response', () {
    test('maps an action id and the payload to an action', () {
      final action = reminderActionFrom(
        const NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotificationAction,
          id: 7,
          actionId: 'reminder_snooze',
          payload: 'note-1',
        ),
      );

      expect(action, const ReminderAction(id: 7, type: ReminderActionType.snooze, noteId: 'note-1'));
    });

    test('counts a swipe away as dismiss', () {
      final action = reminderActionFrom(
        const NotificationResponse(
          notificationResponseType:
              NotificationResponseType.notificationDismissed,
          id: 9,
          payload: 'note-2',
        ),
      );

      expect(action, const ReminderAction(id: 9, type: ReminderActionType.dismiss, noteId: 'note-2'));
    });

    test('leaves an ordinary tap alone', () {
      final action = reminderActionFrom(
        const NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotification,
          id: 3,
          payload: 'note-3',
        ),
      );

      expect(action, isNull);
    });

    test('needs a note to act on', () {
      final action = reminderActionFrom(
        const NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotificationAction,
          id: 3,
          actionId: 'reminder_done',
        ),
      );

      expect(action, isNull);
    });
  });

  group('the buttons on the card', () {
    test('offers done, snooze and dismiss in that order', () {
      final actions = reminderActions(english);

      expect(actions.map((action) => action.id).toList(), [
        'reminder_done',
        'reminder_snooze',
        'reminder_dismiss',
      ]);
      expect(actions.map((action) => action.title).toList(), [
        'Done',
        'Snooze',
        'Dismiss',
      ]);
    });

    test('only snooze brings the app to the front', () {
      final actions = reminderActions(english);

      expect(actions.first.showsUserInterface, isFalse);
      expect(actions[1].showsUserInterface, isTrue);
      expect(actions[2].showsUserInterface, isFalse);
    });

    test('done and dismiss clear the card, snooze keeps it', () {
      final actions = reminderActions(english);

      expect(actions.first.cancelNotification, isTrue);
      expect(actions[1].cancelNotification, isFalse);
      expect(actions[2].cancelNotification, isTrue);
    });

    test('the labels come from l10n', () {
      expect(english.reminderActionDone, 'Done');
      expect(english.reminderActionSnooze, 'Snooze');
      expect(english.reminderActionDismiss, 'Dismiss');
    });
  });

  group('routing a response', () {
    test('sends an action button to the action stream', () async {
      final seen = <ReminderAction>[];
      final subscription = reminderActionPresses.stream.listen(seen.add);

      final routed = routeNotificationResponse(
        const NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotificationAction,
          id: 4,
          actionId: 'reminder_dismiss',
          payload: 'note-4',
        ),
      );

      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();

      expect(routed, const ReminderAction(id: 4, type: ReminderActionType.dismiss, noteId: 'note-4'));
      expect(seen, [routed]);
    });

    test('keeps a plain tap on the tap stream', () async {
      final taps = <String>[];
      final actions = <ReminderAction>[];
      final tapSubscription = notificationTaps.stream.listen(taps.add);
      final actionSubscription = reminderActionPresses.stream.listen(actions.add);

      final routed = routeNotificationResponse(
        const NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotification,
          id: 4,
          payload: 'note-4',
        ),
      );

      await Future<void>.delayed(Duration.zero);
      await tapSubscription.cancel();
      await actionSubscription.cancel();

      expect(routed, isNull);
      expect(taps, ['note-4']);
      expect(actions, isEmpty);
    });

    test('holds an action that arrives before anyone listens', () {
      routeNotificationResponse(
        const NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotificationAction,
          id: 6,
          actionId: 'reminder_done',
          payload: 'note-6',
        ),
      );

      final pending = takePendingReminderActions();

      expect(pending, [
        const ReminderAction(id: 6, type: ReminderActionType.done, noteId: 'note-6'),
      ]);
      expect(takePendingReminderActions(), isEmpty);
    });
  });

  group('carrying the press out', () {
    test('dismiss cancels the notification', () async {
      final gateway = RecordingGateway();

      await handleReminderAction(
        const ReminderAction(id: 5, type: ReminderActionType.dismiss, noteId: 'n1'),
        gateway: gateway,
      );

      expect(gateway.cancelled, [5]);
    });

    test('dismiss without an id cancels nothing', () async {
      final gateway = RecordingGateway();

      await handleReminderAction(
        const ReminderAction(type: ReminderActionType.dismiss, noteId: 'n1'),
        gateway: gateway,
      );

      expect(gateway.cancelled, isEmpty);
    });

    test('done hands the note to the settle step', () async {
      final gateway = RecordingGateway();
      final settled = <String>[];

      await handleReminderAction(
        const ReminderAction(id: 5, type: ReminderActionType.done, noteId: 'n1'),
        gateway: gateway,
        onDone: (noteId) async => settled.add(noteId),
      );

      expect(settled, ['n1']);
      expect(gateway.cancelled, isEmpty);
    });

    test('done without the settle step changes nothing', () async {
      final gateway = RecordingGateway();

      await handleReminderAction(
        const ReminderAction(id: 5, type: ReminderActionType.done, noteId: 'n1'),
        gateway: gateway,
      );

      expect(gateway.cancelled, isEmpty);
    });

    test('snooze hands the note to the snooze step', () async {
      final gateway = RecordingGateway();
      final snoozed = <String>[];

      await handleReminderAction(
        const ReminderAction(id: 5, type: ReminderActionType.snooze, noteId: 'n1'),
        gateway: gateway,
        onSnooze: (noteId) async => snoozed.add(noteId),
      );

      expect(snoozed, ['n1']);
      expect(gateway.cancelled, isEmpty);
    });

    test('snooze without the snooze step changes nothing', () async {
      final gateway = RecordingGateway();

      await handleReminderAction(
        const ReminderAction(id: 5, type: ReminderActionType.snooze, noteId: 'n1'),
        gateway: gateway,
      );

      expect(gateway.cancelled, isEmpty);
    });

    test('a refused cancel does not throw', () async {
      await expectLater(
        handleReminderAction(
          const ReminderAction(id: 5, type: ReminderActionType.dismiss, noteId: 'n1'),
          gateway: RefusingGateway(),
        ),
        completes,
      );
    });
  });
}

class RefusingGateway extends RecordingGateway {
  @override
  Future<void> cancel(int id) async => throw Exception('the OS refused');
}