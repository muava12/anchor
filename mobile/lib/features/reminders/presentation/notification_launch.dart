import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../../app/router/app_routes.dart';
import '../data/reminder_actions.dart';

final FlutterLocalNotificationsPlugin notificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// Taps that arrive while the app is running.
final StreamController<String> notificationTaps =
    StreamController<String>.broadcast();

/// Action-button presses that arrive while the app is running.
final StreamController<ReminderAction> reminderActionPresses =
    StreamController<ReminderAction>.broadcast();

/// Presses that arrived before anyone listened; the handler drains them.
final List<ReminderAction> _pendingReminderActions = <ReminderAction>[];

String? notificationRouteForPayload(String? payload) {
  if (payload == null || payload.isEmpty) return null;
  return AppRoutes.widgetNote(payload);
}

/// Routes a notification response: an action button to [reminderActions], an
/// ordinary tap to [notificationTaps].
///
/// Returns the [ReminderAction] it routed, or null for a plain tap.
ReminderAction? routeNotificationResponse(NotificationResponse response) {
  final action = reminderActionFrom(response);
  if (action != null) {
    _deliverAction(action);
    return action;
  }
  final noteId = response.payload;
  if (noteId != null && noteId.isNotEmpty) notificationTaps.add(noteId);
  return null;
}

void _deliverAction(ReminderAction action) {
  if (reminderActionPresses.isClosed ||
        reminderActionPresses.hasListener) {
    reminderActionPresses.add(action);
  } else {
    _pendingReminderActions.add(action);
  }
}

/// The action presses nobody has handled yet, and empties the buffer.
List<ReminderAction> takePendingReminderActions() {
  final pending = List<ReminderAction>.of(_pendingReminderActions);
  _pendingReminderActions.clear();
  return pending;
}

/// Returns the route a cold-start tap asked for. Safe to call before the
/// first frame; does not touch the timezone database.
Future<String?> initializeNotifications() async {
  const settings = InitializationSettings(
    android: AndroidInitializationSettings('ic_stat_reminder'),
    iOS: DarwinInitializationSettings(
      // Permission is asked for at the first reminder.
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    ),
  );

  await notificationsPlugin.initialize(
    settings: settings,
    onDidReceiveNotificationResponse: routeNotificationResponse,
  );

  final launch = await notificationsPlugin.getNotificationAppLaunchDetails();
  final response = launch?.notificationResponse;
  // An action that started the app is handled, not routed to the note.
  if (response != null && reminderActionFrom(response) != null) return null;
  if (!(launch?.didNotificationLaunchApp ?? false)) return null;
  return notificationRouteForPayload(response?.payload);
}