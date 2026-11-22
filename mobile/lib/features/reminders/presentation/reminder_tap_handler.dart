import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/router/app_router.dart';
import '../../../app/router/pending_launch_route.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/logging/log_tags.dart';
import '../../../core/session/active_user_id_provider.dart';
import '../../../core/storage/preferences_repository.dart';
import '../../../l10n/l10n.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../notes/data/repository/notes_repository.dart';
import '../data/notification_gateway.dart';
import '../data/reminder_actions.dart';
import '../data/reminder_scheduler.dart';
import '../data/reminder_snooze.dart';
import 'notification_launch.dart';
import 'reminder_labels.dart';
import 'snooze_sheet.dart';

part 'reminder_tap_handler.g.dart';

/// Shows the snooze picker for [noteId] and reschedules on a choice.
///
/// Reads the note's recurrence and the last length, opens [showSnoozeSheet]
/// on the router's navigator, and hands the chosen minutes to
/// [snoozeOccurrence]. On a cold start the navigator may not be attached on the
/// first frame; [maxFrames] post-frame retries wait for it, and a give-up is
/// logged so a dropped press is never silent.
Future<void> promptReminderSnooze(
  String noteId, {
  required NotificationGateway gateway,
  required NotesRepository repo,
  required PreferencesRepository preferences,
  GlobalKey<NavigatorState>? navigatorKey,
  int maxFrames = 5,
}) async {
  final note = await repo.getNote(noteId);
  final recurring = note?.reminder?.recurrence.repeats ?? false;
  final latest = await preferences.getLatestSnoozeMinutes();

  BuildContext? context;
  for (var frame = 0; frame <= maxFrames; frame++) {
    context = navigatorKey?.currentContext;
    if (context != null && context.mounted) break;
    if (frame == maxFrames) {
      AppLogger.instance.warn(
        LogTags.reminders,
        'Snooze picker for note $noteId dropped: the navigator was not ready '
        'after $maxFrames frames',
      );
      return;
    }
    await _nextFrame();
  }

  if (context != null && context.mounted) {
    final l10n = context.l10n;
    final rawTitle = note?.title.trim() ?? '';
    final title = rawTitle.isNotEmpty ? rawTitle : '';
    final repeat = note?.reminder?.recurrence;
    final repeatText = repeat != null && repeat.repeats
        ? repeatLabel(repeat, l10n)
        : null;
    final label = [title, if (repeatText != null) repeatText]
        .where((s) => s.isNotEmpty)
        .join(' · ');
    await showSnoozeSheet(
      context,
      recurring: recurring,
      latestMinutes: latest,
      reminderLabel: label.isEmpty ? null : label,
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

/// Completes after the next frame is drawn.
Future<void> _nextFrame() {
  final completer = Completer<void>();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!completer.isCompleted) completer.complete();
  });
  return completer.future;
}

/// Cold-start taps go through `initializeApp`.
@Riverpod(keepAlive: true)
class ReminderTapHandler extends _$ReminderTapHandler {
  @override
  void build() {
    // appDatabaseProvider throws while auth is still resolving the user.
    if (ref.watch(authControllerProvider).isLoading) return;
    // No user yet (fresh install, before login): the database is unavailable.
    if (ref.watch(activeUserIdProvider) == null) return;

    final pending = PendingLaunchRoute(ref);
    final gateway = ref.watch(notificationGatewayProvider);
    final repo = ref.watch(notesRepositoryProvider);
    final preferences = ref.watch(preferencesRepositoryProvider);
    final navigatorKey = ref.watch(routerNavigatorKeyProvider);
    Future<void> carryOut(ReminderAction action) => handleReminderAction(
      action,
      gateway: gateway,
      repo: repo,
      preferences: preferences,
      onSnooze: (noteId) => promptReminderSnooze(
        noteId,
        gateway: gateway,
        repo: repo,
        preferences: preferences,
        navigatorKey: navigatorKey,
      ),
      // Settling an occurrence changes no note, so ask for the cards to be
      // rebuilt: the repeating reminder's next period goes back on the OS now
      // instead of at the next resume.
      onResync: () => ref.read(reminderSchedulerProvider.notifier).resyncAll(),
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
    // Background presses (Done / Dismiss) landed in the native
    // BroadcastReceiver while the app was closed; drain them now.
    unawaited(
      drainNativePendingAction().then((action) {
        if (action != null) carryOut(action);
      }),
    );
    // A native Snooze / content-intent tap stashed a note id before the engine
    // was up; open the snooze picker or the note.
    unawaited(
      _drainNativeLaunchExtras(
        pending: pending,
        gateway: gateway,
        repo: repo,
        preferences: preferences,
        navigatorKey: navigatorKey,
      ),
    );
    final resumeObserver = _LaunchExtrasResumeObserver(
      () => _drainNativeLaunchExtras(
        pending: pending,
        gateway: gateway,
        repo: repo,
        preferences: preferences,
        navigatorKey: navigatorKey,
      ),
    );
    WidgetsBinding.instance.addObserver(resumeObserver);
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(resumeObserver);
      taps.cancel();
      actions.cancel();
    });
  }
}

/// Opens what a native Snooze / content intent asked for, if it stashed one.
Future<void> _drainNativeLaunchExtras({
  required PendingLaunchRoute pending,
  required NotificationGateway gateway,
  required NotesRepository repo,
  required PreferencesRepository preferences,
  required GlobalKey<NavigatorState> navigatorKey,
}) async {
  final extras = await drainNativeLaunchExtras();
  if (extras == null) return;
  if (extras.snoozeNoteId != null) {
    await promptReminderSnooze(
      extras.snoozeNoteId!,
      gateway: gateway,
      repo: repo,
      preferences: preferences,
      navigatorKey: navigatorKey,
    );
  }
  if (extras.openNoteId != null) {
    final route = notificationRouteForPayload(extras.openNoteId);
    if (route != null) pending.open(route);
  }
}

/// Re-drains the stashed launch extra on every resume (a warm Snooze tap).
class _LaunchExtrasResumeObserver with WidgetsBindingObserver {
  _LaunchExtrasResumeObserver(this._onResumed);

  final Future<void> Function() _onResumed;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_onResumed());
  }
}
