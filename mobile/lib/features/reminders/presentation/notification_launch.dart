import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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

/// Drains the native BroadcastReceiver's pending action (SharedPreferences).
///
/// On Android the [ReminderActionReceiver] writes a Done or Dismiss press
/// that landed while the app was in the background. This call retrieves
/// and clears it, returning a [ReminderAction] or null when nothing is pending.
Future<ReminderAction?> drainNativePendingAction() async {
  if (!Platform.isAndroid) return null;
  try {
    const channel = MethodChannel('moek.anchor.notex/reminder_actions');
    final result = await channel.invokeMethod<Map<Object?, Object?>>('drainPending');
    if (result == null) return null;
    final noteId = result['noteId'] as String? ?? '';
    final type = result['type'] as String? ?? '';
    if (noteId.isEmpty) return null;
    final actionType = type == 'done'
        ? ReminderActionType.done
        : ReminderActionType.dismiss;
    return ReminderAction(type: actionType, noteId: noteId);
  } on PlatformException {
    debugPrint('drainNativePendingAction: channel not ready');
    return null;
  }
}

/// A note id the native Snooze / content intent asked to open.
class NativeLaunchExtras {
  const NativeLaunchExtras({this.snoozeNoteId, this.openNoteId});

  /// Open the snooze picker for this note.
  final String? snoozeNoteId;

  /// Open this note directly.
  final String? openNoteId;
}

/// Drains the launch extra the native Snooze / content intent stashed.
///
/// [LaunchExtrasChannel] (via MainActivity) records it before the engine is up;
/// this returns it once and clears it. Null on a plain launch or non-Android.
Future<NativeLaunchExtras?> drainNativeLaunchExtras() async {
  if (!Platform.isAndroid) return null;
  try {
    const channel = MethodChannel('moek.anchor.notex/launch_extras');
    final result =
        await channel.invokeMethod<Map<Object?, Object?>>('drainLaunchExtras');
    if (result == null) return null;
    final snooze = result['snoozeNoteId'] as String?;
    final open = result['openNoteId'] as String?;
    if (snooze == null && open == null) return null;
    return NativeLaunchExtras(snoozeNoteId: snooze, openNoteId: open);
  } on PlatformException {
    return null;
  }
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
  return handleLaunchNotification(
    didNotificationLaunchApp: launch?.didNotificationLaunchApp ?? false,
    actionId: response?.actionId,
    payload: response?.payload,
    notificationId: response?.id,
    dismissed:
        response?.notificationResponseType ==
        NotificationResponseType.notificationDismissed,
  );
}

/// Handles a launch a notification caused.
///
/// A reminder action (Done / Snooze / Dismiss, including a cold start) is
/// delivered to the engine instead of routed to the note. A body tap returns
/// the note's route. Takes the response's raw fields so a unit test does not
/// need the plugin's types.
String? handleLaunchNotification({
  required bool didNotificationLaunchApp,
  String? actionId,
  String? payload,
  int? notificationId,
  bool dismissed = false,
}) {
  if (!didNotificationLaunchApp) return null;
  final type = dismissed
      ? ReminderActionType.dismiss
      : reminderActionTypeForWireId(actionId);
  if (type != null && payload != null && payload.isNotEmpty) {
    _deliverAction(
      ReminderAction(id: notificationId, type: type, noteId: payload),
    );
    return null;
  }
  return notificationRouteForPayload(payload);
}