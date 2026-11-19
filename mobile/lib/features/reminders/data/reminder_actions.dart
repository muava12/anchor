import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/logging/log_tags.dart';
import '../../../l10n/app_localizations.dart';
import 'notification_gateway.dart';

/// What an action button on a reminder notification asked for.
enum ReminderActionType {
  /// The occurrence is finished; a repeating reminder keeps its next period.
  done,

  /// Put the occurrence off; the snooze length is Task 5's.
  snooze,

  /// Quiet this occurrence only; the note keeps its reminder.
  dismiss,
}

/// The Android action id of a [type]. The OS hands it back on the response.
String reminderActionWireId(ReminderActionType type) => 'reminder_${type.name}';

/// The [ReminderActionType] a wire id names, or null when it is not one of ours.
ReminderActionType? reminderActionTypeForWireId(String? wireId) {
  if (wireId == null) return null;
  const prefix = 'reminder_';
  if (!wireId.startsWith(prefix)) return null;
  final name = wireId.substring(prefix.length);
  for (final type in ReminderActionType.values) {
    if (type.name == name) return type;
  }
  return null;
}

/// One press of a reminder's action button.
@immutable
class ReminderAction {
  const ReminderAction({required this.type, required this.noteId, this.id});

  /// What was pressed.
  final ReminderActionType type;

  /// The note whose reminder rang.
  final String noteId;

  /// The OS notification id, i.e. the note's reminder slot. Null when the
  /// platform did not report one.
  final int? id;

  @override
  bool operator ==(Object other) =>
      other is ReminderAction &&
      other.type == type &&
      other.noteId == noteId &&
      other.id == id;

  @override
  int get hashCode => Object.hash(type, noteId, id);

  @override
  String toString() => 'ReminderAction(${type.name}, $noteId, id: $id)';
}

/// The action of a notification response, or null for an ordinary tap.
///
/// Swiping a reminder away counts as dismiss.
ReminderAction? reminderActionFrom(NotificationResponse response) {
  final type =
      response.notificationResponseType ==
          NotificationResponseType.notificationDismissed
      ? ReminderActionType.dismiss
      : reminderActionTypeForWireId(response.actionId);
  if (type == null) return null;
  final noteId = response.payload;
  if (noteId == null || noteId.isEmpty) return null;
  return ReminderAction(id: response.id, type: type, noteId: noteId);
}

/// The three buttons on a reminder card, in the order Android shows them.
///
/// Done and dismiss clear the card themselves, so the OS drops it even when
/// the app cannot run. Snooze brings the app to the front: its picker (Task 5)
/// is a sheet in the app.
List<AndroidNotificationAction> reminderActions(AppLocalizations l10n) => [
  AndroidNotificationAction(
    reminderActionWireId(ReminderActionType.done),
    l10n.reminderActionDone,
    cancelNotification: true,
  ),
  AndroidNotificationAction(
    reminderActionWireId(ReminderActionType.snooze),
    l10n.reminderActionSnooze,
    cancelNotification: false,
    showsUserInterface: true,
  ),
  AndroidNotificationAction(
    reminderActionWireId(ReminderActionType.dismiss),
    l10n.reminderActionDismiss,
    cancelNotification: true,
  ),
];

/// Carries out what a reminder's action button asked for.
///
/// [onDone] settles the occurrence (Task 4) and [onSnooze] puts it off
/// (Task 5). Until they are wired, a press is logged and nothing else happens.
Future<void> handleReminderAction(
  ReminderAction action, {
  required NotificationGateway gateway,
  Future<void> Function(String noteId)? onDone,
  Future<void> Function(String noteId)? onSnooze,
}) async {
  try {
    switch (action.type) {
      case ReminderActionType.dismiss:
        await _dismiss(action, gateway);
      case ReminderActionType.done:
        final settle = onDone;
        if (settle == null) {
          AppLogger.instance.info(
            LogTags.reminders,
            'Done on note ${action.noteId}: settling the occurrence lands in '
            'Task 4',
          );
          return;
        }
        await settle(action.noteId);
      case ReminderActionType.snooze:
        final putOff = onSnooze;
        if (putOff == null) {
          AppLogger.instance.info(
            LogTags.reminders,
            'Snooze on note ${action.noteId}: the picker lands in Task 5',
          );
          return;
        }
        await putOff(action.noteId);
    }
  } catch (error, stack) {
    AppLogger.instance.error(
      LogTags.reminders,
      'Handling ${action.type.name} on note ${action.noteId} failed',
      error: error,
      stackTrace: stack,
    );
  }
}

Future<void> _dismiss(ReminderAction action, NotificationGateway gateway) async {
  final id = action.id;
  if (id == null) {
    AppLogger.instance.warn(
      LogTags.reminders,
      'Dismissed the reminder on note ${action.noteId} with no id to cancel',
    );
    return;
  }
  await gateway.cancel(id);
}