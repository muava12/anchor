import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/logging/log_tags.dart';
import '../../../core/session/active_user_id_provider.dart';
import '../../../core/storage/preferences_repository.dart';
import '../../../l10n/l10n.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../notes/domain/note.dart';
import '../../notes/domain/note_blocks.dart';
import '../../notes/presentation/notes_controller.dart';
import '../domain/reminder_schedule.dart';
import '../domain/snoozed_occurrences.dart';
import 'notification_gateway.dart';

part 'reminder_scheduler.g.dart';

/// iOS keeps only the soonest 64 pending notifications.
const int maxScheduledReminders = 60;

const int _datedRings = 12;

/// Must stay above every note's slot.
const int _datedRingIdStep = 1000000;

const Duration _settleWindow = Duration(milliseconds: 500);

const List<Duration> _retryDelays = [
  Duration(seconds: 2),
  Duration(seconds: 10),
  Duration(seconds: 30),
  Duration(minutes: 2),
  Duration(minutes: 10),
];

/// The wait before the [attempt]th try, levelling off at the last delay.
Duration reminderRetryDelay(int attempt) =>
    _retryDelays[min(attempt, _retryDelays.length) - 1];

@Riverpod(keepAlive: true)
class ReminderScheduler extends _$ReminderScheduler {
  Timer? _settle;
  Timer? _retry;
  List<DesiredReminder>? _lastApplied;
  List<Note> _latest = const [];
  SnoozedOccurrences _snoozed = const SnoozedOccurrences.empty();
  Future<void>? _cleared;
  AppLifecycleListener? _lifecycle;

  /// Passes never overlap.
  Future<void>? _active;
  bool _rerunRequested = false;
  bool _forced = false;
  int _failures = 0;

  /// False until the notes stream has answered at least once. A pass before
  /// that would see no notes and cancel every card the OS still holds.
  bool _notesReady = false;

  @override
  void build() {
    // appDatabaseProvider throws while auth is still resolving the user.
    if (ref.watch(authControllerProvider).isLoading) return;

    final gateway = ref.watch(notificationGatewayProvider);
    final userId = ref.watch(activeUserIdProvider);
    final preferences = ref.watch(preferencesRepositoryProvider);

    _lastApplied = null;
    _latest = const [];
    _notesReady = false;
    _snoozed = const SnoozedOccurrences.empty();
    if (userId == null) {
      _cleared = _cancelAll(gateway);
      return;
    }

    // The app-start reconcile: the stream answers at once with what the
    // database holds, so a launch rebuilds every card the OS lost (a reboot, a
    // force stop) without waiting for a resume or a note edit.
    ref.listen(allActiveNotesProvider, (_, notes) {
      if (notes case AsyncData(:final value)) _onNotes(value);
    }, fireImmediately: true);

    _lifecycle = AppLifecycleListener(
      onResume: () => unawaited(_onResume(gateway, preferences)),
    );

    ref.onDispose(() {
      _settle?.cancel();
      _settle = null;
      _retry?.cancel();
      _retry = null;
      _lifecycle?.dispose();
      _lifecycle = null;
    });
  }

  /// Must never throw: every later pass awaits it.
  Future<void> _cancelAll(NotificationGateway gateway) async {
    try {
      await gateway.cancelAll();
    } catch (error, stack) {
      AppLogger.instance.error(
        LogTags.reminders,
        'Clearing the notifications failed',
        error: error,
        stackTrace: stack,
      );
    }
  }

  /// Rebuilds every card from the notes now, cancelling the leftovers.
  ///
  /// An occurrence that just settled changes nothing in the notes (a repeating
  /// reminder keeps its reminder), so only this puts the next period on the OS
  /// without waiting for a note edit or a resume.
  Future<void> resyncAll() => _reconcile(force: true);

  Future<void> _onResume(
    NotificationGateway gateway,
    PreferencesRepository preferences,
  ) async {
    await syncLocalTimeZone();
    _snoozed = await preferences.getSnoozedOccurrences();
    await _reconcile(force: true);
  }

  void _onNotes(List<Note> notes) {
    _latest = notes;
    _notesReady = true;
    _settle?.cancel();
    _settle = Timer(_settleWindow, () {
      _settle = null;
      unawaited(_reconcile());
    });
  }

  Future<void> _reconcile({bool force = false}) {
    _forced = _forced || force;

    final active = _active;
    if (active != null) {
      _rerunRequested = true;
      return active;
    }

    final pass = _runPasses();
    _active = pass;
    return pass;
  }

  Future<void> _runPasses() async {
    try {
      do {
        _rerunRequested = false;
        await _runPass();
      } while (_rerunRequested);
    } finally {
      _active = null;
    }
  }

  Future<void> _runPass() async {
    // No notes yet: cancelling now would drop every live card.
    if (!_notesReady) return;

    final gateway = ref.read(notificationGatewayProvider);
    final preferences = ref.read(preferencesRepositoryProvider);
    if (_forced) {
      _forced = false;
      _lastApplied = null;
    }
    try {
      await _cleared;
      // Pull the latest snoozes; a stale pass would reset a snoozed card to
      // its original period.
      _snoozed = await preferences.getSnoozedOccurrences();
      await gateway.initialize();
      final now = DateTime.now();

      // A snooze whose time has passed hands the note back to its period.
      final expired = <String>[];
      for (final noteId in _snoozed.noteIds) {
        final at = parseWallClock(_snoozed.atFor(noteId));
        if (at == null || !at.isAfter(now)) expired.add(noteId);
      }
      if (expired.isNotEmpty) {
        var pruned = _snoozed;
        for (final noteId in expired) {
          pruned = pruned.remove(noteId);
        }
        _snoozed = pruned;
        await preferences.setSnoozedOccurrences(pruned);
      }

      final desired = desiredReminders(
        _latest,
        now: now,
        l10n: deviceL10n(),
        snoozed: _snoozed,
      );

      if (_sameAs(desired)) return;

      final pending = (await gateway.pendingIds()).toSet();
      final report = await applyReminders(gateway, desired, pending: pending);

      // Only a pass with no failures is remembered.
      _lastApplied = report.failed == 0 ? desired : null;
      AppLogger.instance.info(
        LogTags.reminders,
        'reconciled scheduled=${desired.length} '
        'cancelled=${report.cancelled} failed=${report.failed}',
      );
      _armRetry(report.failed > 0);
    } catch (error, stack) {
      _lastApplied = null;
      _snoozed = const SnoozedOccurrences.empty();
      AppLogger.instance.error(
        LogTags.reminders,
        'Reconcile failed',
        error: error,
        stackTrace: stack,
      );
      _armRetry(true);
    }
  }

  void _armRetry(bool failed) {
    _retry?.cancel();
    _retry = null;

    if (!failed) {
      _failures = 0;
      return;
    }

    _failures++;
    final delay = reminderRetryDelay(_failures);
    AppLogger.instance.warn(
      LogTags.reminders,
      'retrying in ${delay.inSeconds}s',
    );
    _retry = Timer(delay, () {
      _retry = null;
      unawaited(_reconcile());
    });
  }

  bool _sameAs(List<DesiredReminder> next) {
    final last = _lastApplied;
    if (last == null || last.length != next.length) return false;
    for (var i = 0; i < next.length; i++) {
      if (last[i] != next[i]) return false;
    }
    return true;
  }
}

Future<ReminderSyncReport> applyReminders(
  NotificationGateway gateway,
  List<DesiredReminder> desired, {
  required Set<int> pending,
}) async {
  final wanted = {for (final item in desired) item.id};
  final orphans = pending.difference(wanted);
  var failed = 0;

  for (final id in orphans) {
    try {
      await gateway.cancel(id);
    } catch (error, stack) {
      failed++;
      AppLogger.instance.error(
        LogTags.reminders,
        'Cancelling notification $id failed',
        error: error,
        stackTrace: stack,
      );
    }
  }

  for (final item in desired) {
    try {
      await gateway.schedule(item.toNotification());
    } catch (error, stack) {
      failed++;
      AppLogger.instance.error(
        LogTags.reminders,
        'Scheduling the reminder on note ${item.noteId} failed',
        error: error,
        stackTrace: stack,
      );
    }
  }

  return ReminderSyncReport(cancelled: orphans.length, failed: failed);
}

class ReminderSyncReport {
  const ReminderSyncReport({required this.cancelled, required this.failed});

  final int cancelled;
  final int failed;
}

String? reminderHeading(Note note) {
  if (note.hasTitle) return note.title;
  final firstLine = snippetTextOf(note.content).split('\n').first;
  return firstLine.isEmpty ? null : firstLine;
}

String reminderBody(Note note) {
  final lines = snippetTextOf(
    note.content,
  ).split('\n').where((l) => l.trim().isNotEmpty).toList();
  final rest = note.hasTitle ? lines : lines.skip(1).toList();
  return rest.isEmpty ? '' : rest.first;
}

List<DesiredReminder> desiredReminders(
  List<Note> notes, {
  required DateTime now,
  required AppLocalizations l10n,
  SnoozedOccurrences snoozed = const SnoozedOccurrences.empty(),
}) {
  final desired = <DesiredReminder>[];
  for (final note in notes) {
    final reminder = note.reminder;
    // Trashed and archived notes keep their reminder but stop ringing.
    if (reminder == null || !note.isActive || note.isArchived) continue;

    final slot = note.reminderSlot;
    if (slot == null) {
      AppLogger.instance.warn(
        LogTags.reminders,
        'No notification id for note ${note.id}',
      );
      continue;
    }

    final heading = reminderHeading(note);
    DesiredReminder ring(int id, DateTime ringAt, DateTimeComponents? repeat) =>
        DesiredReminder(
          id: id,
          at: ringAt,
          title: heading ?? l10n.reminderTitle,
          body: heading == null ? '' : reminderBody(note),
          repeat: repeat,
          noteId: note.id,
        );

    // A repeating reminder with a live snooze rings the snoozed time once, not
    // its original period: the snooze has not yet passed, so hold the card at
    // now + minutes and leave the period for the scheduler to reschedule after.
    // A one-off moves its own `remindAt` when snoozed, so it ignores this map.
    if (reminder.recurrence.repeats) {
      final snoozeAt = snoozed.atFor(note.id);
      if (snoozeAt != null) {
        final snoozedAt = parseWallClock(snoozeAt);
        if (snoozedAt != null && !snoozedAt.isBefore(now)) {
          desired.add(ring(slot, snoozedAt, null));
          continue;
        }
      }
    }

    final at = nextOccurrence(reminder, from: now);
    if (at == null) continue;

    final repeat = matchComponentsFor(reminder.recurrence);
    if (repeat == null || canUseOsRepeat(reminder, now: now)) {
      desired.add(ring(slot, at, repeat));
    } else {
      final dates = nextOccurrences(reminder, from: now, count: _datedRings);
      for (final (index, date) in dates.indexed) {
        desired.add(ring(slot + index * _datedRingIdStep, date, null));
      }
    }
  }

  desired.sort((a, b) => a.at.compareTo(b.at));
  return desired.take(maxScheduledReminders).toList();
}

DateTimeComponents? matchComponentsFor(ReminderRecurrence recurrence) =>
    switch (recurrence) {
      ReminderRecurrence.none => null,
      ReminderRecurrence.daily => DateTimeComponents.time,
      ReminderRecurrence.weekly => DateTimeComponents.dayOfWeekAndTime,
      ReminderRecurrence.monthly => DateTimeComponents.dayOfMonthAndTime,
      ReminderRecurrence.yearly => DateTimeComponents.dateAndTime,
    };

@immutable
class DesiredReminder {
  const DesiredReminder({
    required this.id,
    required this.at,
    required this.title,
    this.body = '',
    required this.repeat,
    required this.noteId,
  });

  final int id;
  final DateTime at;
  final String title;
  final String body;
  final DateTimeComponents? repeat;
  final String noteId;

  ScheduledNotification toNotification() => ScheduledNotification(
    id: id,
    title: title,
    body: body,
    at: at,
    repeat: repeat,
    payload: noteId,
  );

  @override
  bool operator ==(Object other) =>
      other is DesiredReminder &&
      other.id == id &&
      other.at == at &&
      other.title == title &&
      other.body == body &&
      other.repeat == repeat &&
      other.noteId == noteId;

  @override
  int get hashCode => Object.hash(id, at, title, body, repeat, noteId);
}
