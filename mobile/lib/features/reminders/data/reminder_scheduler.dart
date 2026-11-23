import 'dart:async';
import 'dart:io';
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
import '../../notes/data/repository/notes_repository.dart';
import '../../notes/domain/note.dart';
import '../../notes/domain/note_blocks.dart';
import '../../notes/presentation/notes_controller.dart';
import '../../tags/data/repository/tags_repository.dart';
import '../../tags/domain/tag.dart';
import '../domain/reminder_schedule.dart';
import '../domain/snoozed_occurrences.dart';
import 'notification_gateway.dart';
import 'pending_snooze_channel.dart';

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
  Future<void>? _drained;
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

    // Settle the snoozes the native stack stashed while the app was closed
    // before any pass runs: their alarms are already armed, so an early pass
    // would cancel them as orphans and re-arm the stale database time.
    _drained = _drainNativeSnoozes();

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

  /// Applies the native snooze stash to the database. Never throws: every
  /// later pass awaits it.
  Future<void> _drainNativeSnoozes() async {
    try {
      final applied = await drainPendingSnoozes(
        repo: ref.read(notesRepositoryProvider),
      );
      if (applied > 0) {
        AppLogger.instance.info(
          LogTags.reminders,
          'applied $applied native snooze(s) to the database',
        );
      }
    } catch (error, stack) {
      AppLogger.instance.error(
        LogTags.reminders,
        'Draining the native snoozes failed',
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
    // A snooze pressed natively while the app was closed lands here.
    await _drainNativeSnoozes();
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
    // The app-start drain must finish first: a pass that saw the stash
    // unapplied would cancel the snoozed alarms as orphans.
    await _drained;
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

      final allTags = await ref.read(tagsRepositoryProvider).getTags();
      final desired = desiredReminders(
        _latest,
        now: now,
        l10n: deviceL10n(),
        snoozed: _snoozed,
        tagsById: {for (final tag in allTags) tag.id: tag},
      );

      if (_sameAs(desired)) return;

      final pending = await gateway.pendingTimes();
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

/// The device's local wall-clock time now, for the grace-period check.
DateTime _nowLocal() => DateTime.now();

/// A card the OS has not cleaned up after it fired: its scheduled time is
/// still on the OS's pending list, but the heads-up is already showing.
/// Cancelling it would drop the heads-up the user is reading.
const _cancelGrace = Duration(minutes: 5);

Future<ReminderSyncReport> applyReminders(
  NotificationGateway gateway,
  List<DesiredReminder> desired, {
  required Map<int, DateTime?> pending,
}) async {
  final wanted = {for (final item in desired) item.id};
  var cancelled = 0;
  final orphans = pending.keys.where(
    (id) {
      if (wanted.contains(id)) return false;
      final at = pending[id];
      // Unknown time (null): the OS holds it and a previous app instance
      // scheduled it. Leave it alone.
      if (at == null) return false;
      // Inside the grace period: freshly fired, the heads-up is showing.
      if (at.isAfter(_nowLocal().subtract(_cancelGrace))) return false;
      // Older than the grace period: a leftover the reconcile should cancel.
      cancelled++;
      return true;
    },
  ).toList();
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

  return ReminderSyncReport(cancelled: cancelled, failed: failed);
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

/// The note's first tag name (its display order), or '' when it has none;
/// drawn as "#name" on the native reminder sheet's meta line.
String _firstTagName(Note note, Map<String, Tag> tagsById) {
  for (final id in note.tagIds) {
    final name = tagsById[id]?.name;
    if (name != null && name.isNotEmpty) return name;
  }
  return '';
}

List<DesiredReminder> desiredReminders(
  List<Note> notes, {
  required DateTime now,
  required AppLocalizations l10n,
  SnoozedOccurrences snoozed = const SnoozedOccurrences.empty(),
  Map<String, Tag> tagsById = const <String, Tag>{},
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
          recurrence: reminder.recurrence.name,
          tag: _firstTagName(note, tagsById),
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

    // On Android a reminder rings natively and an alarm has no OS-level
    // repeat, so every ring is a dated one-shot. Elsewhere the plugin can use
    // an OS repeat, so one card covers the whole period.
    if (!Platform.isAndroid) {
      final repeat = matchComponentsFor(reminder.recurrence);
      if (repeat == null || canUseOsRepeat(reminder, now: now)) {
        desired.add(ring(slot, at, repeat));
        continue;
      }
    }
    final dates = nextOccurrences(reminder, from: now, count: _datedRings);
    for (final (index, date) in dates.indexed) {
      desired.add(ring(slot + index * _datedRingIdStep, date, null));
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
    this.recurrence = 'none',
    this.tag = '',
  });

  final int id;
  final DateTime at;
  final String title;
  final String body;
  final DateTimeComponents? repeat;
  final String noteId;

  /// The note's recurrence (its ReminderRecurrence name, "none" when it
  /// does not repeat), carried to the native stack for the snooze chain.
  final String recurrence;

  /// The note's first tag name (no leading "#"), drawn on the native sheet's
  /// meta line; empty when the note has no tag.
  final String tag;

  ScheduledNotification toNotification() => ScheduledNotification(
    id: id,
    title: title,
    body: body,
    at: at,
    repeat: repeat,
    payload: noteId,
    recurrence: recurrence,
    tag: tag,
  );

  @override
  bool operator ==(Object other) =>
      other is DesiredReminder &&
      other.id == id &&
      other.at == at &&
      other.title == title &&
      other.body == body &&
      other.repeat == repeat &&
      other.noteId == noteId &&
      other.recurrence == recurrence;

  @override
  int get hashCode =>
      Object.hash(id, at, title, body, repeat, noteId, recurrence);
}
