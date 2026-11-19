import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/router/app_router.dart';
import '../../../app/router/pending_launch_route.dart';
import '../../../core/storage/preferences_repository.dart';
import '../../notes/data/repository/notes_repository.dart';
import '../data/notification_gateway.dart';
import '../data/reminder_actions.dart';
import '../data/reminder_snooze.dart';
import 'notification_launch.dart';
import 'snooze_sheet.dart';

part 'reminder_tap_handler.g.dart';

/// Shows the snooze picker for [noteId] and reschedules on a choice.
///
/// Reads the note's recurrence and the last length, opens [showSnoozeSheet]
/// on the router's navigator, and hands the chosen minutes to
/// [snoozeOccurrence]. Safe to call with no navigator (nothing is shown).
Future<void> promptReminderSnooze(
  String noteId, {
  required NotificationGateway gateway,
  required NotesRepository repo,
  required PreferencesRepository preferences,
  GlobalKey<NavigatorState>? navigatorKey,
}) async {
  final context = navigatorKey?.currentContext;
  if (context == null || !context.mounted) return;
  final note = await repo.getNote(noteId);
  final recurring = note?.reminder?.recurrence.repeats ?? false;
  final latest = await preferences.getLatestSnoozeMinutes();
  if (context.mounted) {
    await showSnoozeSheet(
      context,
      recurring: recurring,
      latestMinutes: latest,
      onSnooze: (minutes) => snoozeOccurrence(
        noteId,
        minutes,
        gateway: gateway,
        repo: repo,
        preferences: preferences,
      ),
    );
  }
}

/// Cold-start taps go through `initializeApp`.
@Riverpod(keepAlive: true)
class ReminderTapHandler extends _$ReminderTapHandler {
  @override
  void build() {
    final pending = PendingLaunchRoute(ref);
    final gateway = ref.watch(notificationGatewayProvider);
    final repo = ref.watch(notesRepositoryProvider);
    final preferences = ref.watch(preferencesRepositoryProvider);
    final navigatorKey = ref.watch(routerNavigatorKeyProvider);
    Future<void> carryOut(ReminderAction action) => handleReminderAction(
      action,
      gateway: gateway,
      repo: repo,
      onSnooze: (noteId) => promptReminderSnooze(
        noteId,
        gateway: gateway,
        repo: repo,
        preferences: preferences,
        navigatorKey: navigatorKey,
      ),
    );
    final taps = notificationTaps.stream.listen((noteId) {
      final route = notificationRouteForPayload(noteId);
      if (route != null) pending.open(route);
    });
    final actions = reminderActionPresses.stream.listen(
      (action) => unawaited(carryOut(action)),
    );
    // A press that landed before this provider existed is not lost.
    for (final action in takePendingReminderActions()) {
      unawaited(carryOut(action));
    }
    ref.onDispose(() {
      taps.cancel();
      actions.cancel();
    });
  }
}