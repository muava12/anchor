/// Snoozing a reminder occurrence: the durations offered, the reschedule, and
/// the length the person last picked.
library;

import '../../../core/logging/app_logger.dart';
import '../../../core/logging/log_tags.dart';
import '../../../core/storage/preferences_repository.dart';
import '../../../l10n/l10n.dart';
import '../../notes/data/repository/notes_repository.dart';
import '../../notes/domain/note.dart';
import '../domain/reminder_schedule.dart';
import 'notification_gateway.dart';
import 'reminder_scheduler.dart';

/// Ten minutes.
const int snoozeTenMinutes = 10;

/// Half an hour.
const int snoozeThirtyMinutes = 30;

/// An hour.
const int snoozeHour = 60;

/// Four hours.
const int snoozeFourHours = 240;

/// A whole day; offered only to a repeating reminder.
const int snoozeDay = 1440;

/// The snooze lengths the sheet offers, in minutes.
///
/// A one-off reminder gets the short list; a repeating reminder also gets a
/// whole day, because its next period is only a day away at most for a daily.
/// The list is fresh each call so the sheet cannot mutate a shared constant.
List<int> snoozeDurations({required bool recurring}) => [
  snoozeTenMinutes,
  snoozeThirtyMinutes,
  snoozeHour,
  snoozeFourHours,
  if (recurring) snoozeDay,
];

/// Puts the occurrence a snooze press names off by [minutes].
///
/// The note's current card is cancelled and a fresh one is scheduled for
/// `now + minutes`. A one-off reminder also moves its stored time so the next
/// reconcile keeps it; a repeating reminder keeps its period (the scheduler
/// reschedules the next period, Task 6). When [preferences] is given the
/// length is remembered so the picker opens on it next time.
Future<void> snoozeOccurrence(
  String noteId,
  int minutes, {
  required NotificationGateway gateway,
  required NotesRepository repo,
  PreferencesRepository? preferences,
  DateTime Function()? clock,
}) async {
  final now = (clock ?? DateTime.now)();
  final at = now.add(Duration(minutes: minutes));
  final note = await repo.getNote(noteId);
  final reminder = note?.reminder;
  final slot = note?.reminderSlot;

  // Remember the length whether or not there is anything to reschedule.
  await preferences?.setLatestSnoozeMinutes(minutes);

  if (note == null || reminder == null) return;
  if (slot == null) {
    AppLogger.instance.warn(
      LogTags.reminders,
      'Snoozed note $noteId with no reminder slot to reschedule',
    );
    return;
  }

  await gateway.cancel(slot);
  final heading = reminderHeading(note);
  final l10n = deviceL10n();
  await gateway.schedule(
    ScheduledNotification(
      id: slot,
      title: heading ?? l10n.reminderTitle,
      body: heading == null ? '' : reminderBody(note),
      at: at,
      repeat: null,
      payload: noteId,
    ),
  );

  // A one-off moves its anchor so the reconcile after this keeps the new time;
  // a repeating reminder keeps its period but records the snooze so reconcile
  // holds the snoozed card instead of resetting it to the original period.
  if (!reminder.recurrence.repeats) {
    await repo.setReminder(
      noteId,
      NoteReminder(
        remindAt: toWallClock(at),
        recurrence: ReminderRecurrence.none,
        version: reminder.version,
      ),
    );
  } else if (preferences != null) {
    final snoozed = await preferences.getSnoozedOccurrences();
    await preferences.setSnoozedOccurrences(
      snoozed.set(noteId, toWallClock(at)),
    );
  }

  AppLogger.instance.info(
    LogTags.reminders,
    'Snoozed note $noteId by $minutes min, next at ${toWallClock(at)}',
  );
}

/// The label for a snooze length, in minutes: "10 min", "1 hour", "1 day".
String snoozeDurationLabel(int minutes, AppLocalizations l10n) {
  if (minutes < snoozeHour) return l10n.snoozeMinutes(minutes);
  if (minutes < snoozeDay) return l10n.snoozeHours(minutes ~/ snoozeHour);
  return l10n.snoozeDay;
}
