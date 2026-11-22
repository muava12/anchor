import 'package:flutter/services.dart';

import '../../notes/data/repository/notes_repository.dart';
import '../domain/reminder_schedule.dart';

/// The native reminder MethodChannel; the gateway and the drain share it.
const MethodChannel reminderActionChannel = MethodChannel(
  'moek.anchor.notex/reminder_actions',
);

/// Applies the snoozes the native stack stashed in its `PendingSnoozeStore`
/// while the app was closed, then returns how many it applied.
///
/// For each record it moves the note's reminder to the snoozed time. The
/// native alarm is already armed at that time and is left in place; the
/// reconcile that follows sees the database matching it and keeps the card.
/// [setReminder] marks the row unsynced so the sync engine pushes the time.
///
/// A record whose note is gone, or lost its reminder, is skipped. A missing
/// native side (the other platforms) drains nothing and returns 0.
Future<int> drainPendingSnoozes({
  required NotesRepository repo,
  MethodChannel channel = reminderActionChannel,
}) async {
  List<Map<Object?, Object?>> records;
  try {
    final raw = await channel.invokeMethod('drainPendingSnoozes');
    records =
        (raw as List?)?.whereType<Map<Object?, Object?>>().toList() ?? const [];
  } on PlatformException {
    return 0;
  } on MissingPluginException {
    return 0;
  }
  if (records.isEmpty) return 0;

  var applied = 0;
  for (final record in records) {
    final noteId = record['noteId'] as String?;
    final newAtMillis = record['newAtMillis'] as int?;
    if (noteId == null || newAtMillis == null) continue;

    final note = await repo.getNote(noteId);
    final reminder = note?.reminder;
    if (reminder == null) continue;

    // The native stack kept local wall-clock times; read them back the same
    // way the scheduler resolves them.
    final at = DateTime.fromMillisecondsSinceEpoch(newAtMillis);
    await repo.setReminder(
      noteId,
      reminder.copyWith(remindAt: toWallClock(at)),
    );
    applied++;
  }
  return applied;
}
