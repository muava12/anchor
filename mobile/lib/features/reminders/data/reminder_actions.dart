import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/logging/log_tags.dart';
import '../../../core/storage/preferences_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../notes/data/repository/notes_repository.dart';
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
/// (Task 5). When [repo] is given and no [onDone] callback is, a done press
/// settles the occurrence against the note itself. Until the callbacks or repo
/// are wired, a press is logged and nothing else happens.
Future<void> handleReminderAction(
  ReminderAction action, {
  required NotificationGateway gateway,
  NotesRepository? repo,
  PreferencesRepository? preferences,
  Future<void> Function(String noteId)? onDone,
  Future<void> Function(String noteId)? onSnooze,
}) async {
  try {
    switch (action.type) {
      case ReminderActionType.dismiss:
        await dismissOccurrence(
          action,
          gateway: gateway,
          preferences: preferences,
        );
      case ReminderActionType.done:
        final settle = onDone;
        if (settle != null) {
          await settle(action.noteId);
        } else if (repo != null) {
          await doneOccurrence(action.noteId, repo, preferences: preferences);
        } else {
          AppLogger.instance.info(
            LogTags.reminders,
            'Done on note ${action.noteId}: settling the occurrence lands in '
            'Task 4',
          );
        }
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

/// Settles the occurrence a done press names.
///
/// A one-off reminder ends here: its reminder is unset, so the note no longer
/// rings. A repeating reminder keeps its reminder; the next period is
/// rescheduled by the scheduler (Task 6). Any snooze on this note is cleared so
/// a settled occurrence does not resurface. A note with no reminder, or one
/// that is gone, is left untouched.
Future<void> doneOccurrence(
  String noteId,
  NotesRepository repo, {
  PreferencesRepository? preferences,
}) async {
  await _clearSnooze(noteId, preferences);
  final note = await repo.getNote(noteId);
  if (note == null) return;
  final reminder = note.reminder;
  if (reminder == null) return;
  if (reminder.recurrence.repeats) return;
  await repo.setReminder(noteId, null);
}

/// Quietly clears the notification a dismiss press names.
///
/// The note keeps its reminder; only this occurrence's card is cancelled, and
/// any snooze on this note is cleared so the dismissed occurrence stays quiet.
Future<void> dismissOccurrence(
  ReminderAction action, {
  required NotificationGateway gateway,
  PreferencesRepository? preferences,
}) async {
  await _clearSnooze(action.noteId, preferences);
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

/// Removes any snoozed occurrence for [noteId] so a reconcile or the scheduler
/// stops holding the card at its snoozed time.
Future<void> _clearSnooze(
  String noteId,
  PreferencesRepository? preferences,
) async {
  if (preferences == null) return;
  final snoozed = await preferences.getSnoozedOccurrences();
  if (!snoozed.contains(noteId)) return;
  await preferences.setSnoozedOccurrences(snoozed.remove(noteId));
}
