import 'package:anchor/features/reminders/data/notification_gateway.dart';
import 'package:anchor/l10n/l10n.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final english = lookupAppLocalizations(const Locale('en'));

  group('reminder channel tiers', () {
    test('the important tier maps to the reminders channel at MAX', () {
      final details = LocalNotificationGateway.detailsForTier(
        NotificationTier.important,
        english,
      );

      expect(details.channelId, 'reminders');
      expect(details.importance, Importance.max);
      expect(details.priority, Priority.max);
      expect(details.channelName, 'Reminders');
    });

    test('the silent tier maps to the pinned_notes channel at MIN', () {
      final details = LocalNotificationGateway.detailsForTier(
        NotificationTier.silent,
        english,
      );

      expect(details.channelId, 'pinned_notes');
      expect(details.importance, Importance.min);
      expect(details.priority, Priority.min);
      expect(details.channelName, 'Pinned notes');
    });

    test('channel names and descriptions come from l10n', () {
      expect(english.reminderChannelName, 'Reminders');
      expect(english.reminderChannelDescription, isNotEmpty);
      expect(english.pinnedChannelName, 'Pinned notes');
      expect(english.pinnedChannelDescription, isNotEmpty);
    });

    test('new notifications default to the important tier', () {
      final notification = ScheduledNotification(
        id: 1,
        title: 'Pick up milk',
        body: 'On your way home',
        at: DateTime(2026, 11, 19, 8),
        repeat: null,
        payload: 'note-1',
      );

      expect(notification.tier, NotificationTier.important);
    });

    test('a silent notification keeps its tier', () {
      final notification = ScheduledNotification(
        id: 2,
        title: 'Pinned',
        body: 'Quiet nudge',
        at: DateTime(2026, 11, 19, 9),
        repeat: null,
        payload: 'note-2',
        tier: NotificationTier.silent,
      );

      expect(notification.tier, NotificationTier.silent);
    });
  });
}
