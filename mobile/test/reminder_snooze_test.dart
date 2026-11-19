import 'dart:async';

import 'package:anchor/core/storage/preferences_repository.dart';
import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/features/notes/data/repository/notes_repository.dart';
import 'package:anchor/features/notes/domain/note.dart';
import 'package:anchor/features/reminders/data/notification_gateway.dart';
import 'package:anchor/features/reminders/data/reminder_snooze.dart';
import 'package:anchor/features/reminders/domain/snoozed_occurrences.dart';
import 'package:anchor/features/reminders/presentation/reminder_tap_handler.dart';
import 'package:anchor/features/reminders/presentation/snooze_sheet.dart';
import 'package:anchor/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records the notifications it was asked to schedule and cancel.
class RecordingGateway implements NotificationGateway {
  final scheduled = <ScheduledNotification>[];
  final cancelled = <int>[];

  @override
  Future<void> cancel(int id) async => cancelled.add(id);

  @override
  Future<void> cancelAll() async {}

  @override
  Future<void> schedule(ScheduledNotification notification) async =>
      scheduled.add(notification);

  @override
  Future<List<int>> pendingIds() async => const [];

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  bool get requiresExactAlarmPermission => false;

  @override
  Future<bool> canScheduleExact() async => true;

  @override
  Future<void> requestExactPermission() async {}
}

/// Holds one note and records reminder writes.
class FakeNotesRepository implements NotesRepository {
  FakeNotesRepository(this._note);

  Note? _note;
  final remindersSet = <NoteReminder?>[];

  @override
  Future<Note?> getNote(String id) async => _note?.id == id ? _note : null;

  @override
  Future<void> setReminder(String noteId, NoteReminder? reminder) async {
    remindersSet.add(reminder);
    final current = _note;
    if (current == null || current.id != noteId) return;
    _note = current.copyWith(reminder: reminder);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class FakePreferences extends PreferencesRepository {
  FakePreferences() : super(const FlutterSecureStorage());

  int? _latest;
  int? setCalls;
  SnoozedOccurrences snoozed = const SnoozedOccurrences.empty();

  @override
  Future<int?> getLatestSnoozeMinutes() async => _latest;

  @override
  Future<void> setLatestSnoozeMinutes(int minutes) async {
    _latest = minutes;
    setCalls = minutes;
  }

  @override
  Future<SnoozedOccurrences> getSnoozedOccurrences() async => snoozed;

  @override
  Future<void> setSnoozedOccurrences(SnoozedOccurrences value) async {
    snoozed = value;
  }
}

Note _noteWithReminder({
  String id = 'n1',
  int? reminderSlot = 7,
  ReminderRecurrence recurrence = ReminderRecurrence.none,
}) => Note(
  id: id,
  title: 'Groceries',
  reminderSlot: reminderSlot,
  reminder: NoteReminder(remindAt: '2026-09-04T18:00', recurrence: recurrence),
);

void main() {
  final english = lookupAppLocalizations(const Locale('en'));

  group('snooze durations', () {
    test('a one-off offers ten, thirty, sixty and two hundred forty', () {
      expect(snoozeDurations(recurring: false), [10, 30, 60, 240]);
    });

    test('a repeating reminder adds a whole day', () {
      expect(snoozeDurations(recurring: true), [10, 30, 60, 240, 1440]);
    });

    test('the list is fresh each call, so callers cannot mutate it', () {
      final first = snoozeDurations(recurring: false);
      first.add(999);
      expect(snoozeDurations(recurring: false), [10, 30, 60, 240]);
    });
  });

  group('snoozing an occurrence', () {
    test('reschedules the note at now plus the minutes', () async {
      final gateway = RecordingGateway();
      final repo = FakeNotesRepository(_noteWithReminder());
      final now = DateTime(2026, 9, 4, 18, 0);

      await snoozeOccurrence(
        'n1',
        30,
        gateway: gateway,
        repo: repo,
        clock: () => now,
      );

      expect(gateway.cancelled, [7]);
      expect(gateway.scheduled, hasLength(1));
      final ring = gateway.scheduled.single;
      expect(ring.at, DateTime(2026, 9, 4, 18, 30));
      expect(ring.id, 7);
      expect(ring.payload, 'n1');
    });

    test('a repeating snooze keeps the note in place', () async {
      final gateway = RecordingGateway();
      final repo = FakeNotesRepository(
        _noteWithReminder(recurrence: ReminderRecurrence.daily),
      );
      final preferences = FakePreferences();

      await snoozeOccurrence(
        'n1',
        60,
        gateway: gateway,
        repo: repo,
        preferences: preferences,
        clock: () => DateTime(2026, 9, 4, 18, 0),
      );

      expect(repo.remindersSet, isEmpty);
      expect(gateway.scheduled.single.at, DateTime(2026, 9, 4, 19, 0));
      // The snooze is recorded so a reconcile holds the card at now+minutes.
      expect(preferences.snoozed.atFor('n1'), '2026-09-04T19:00');
    });

    test('a one-off snooze does not write the snooze store', () async {
      final gateway = RecordingGateway();
      final repo = FakeNotesRepository(_noteWithReminder());
      final preferences = FakePreferences();

      await snoozeOccurrence(
        'n1',
        30,
        gateway: gateway,
        repo: repo,
        preferences: preferences,
        clock: () => DateTime(2026, 9, 4, 18, 0),
      );

      expect(preferences.snoozed.contains('n1'), isFalse);
    });

    test('a one-off moves its reminder to the new time', () async {
      final gateway = RecordingGateway();
      final repo = FakeNotesRepository(_noteWithReminder());
      final now = DateTime(2026, 9, 4, 18, 0);

      await snoozeOccurrence(
        'n1',
        240,
        gateway: gateway,
        repo: repo,
        clock: () => now,
      );

      expect(repo.remindersSet, hasLength(1));
      final moved = repo.remindersSet.single;
      expect(moved, isNotNull);
      expect(moved!.remindAt, '2026-09-04T22:00');
      expect(moved.recurrence, ReminderRecurrence.none);
    });

    test('a note with no reminder is left alone', () async {
      final gateway = RecordingGateway();
      final repo = FakeNotesRepository(Note(id: 'n1', title: 'Groceries'));

      await snoozeOccurrence(
        'n1',
        30,
        gateway: gateway,
        repo: repo,
        clock: () => DateTime(2026, 9, 4, 18, 0),
      );

      expect(gateway.scheduled, isEmpty);
      expect(repo.remindersSet, isEmpty);
    });

    test('a note that is gone does not throw', () async {
      final gateway = RecordingGateway();
      final repo = FakeNotesRepository(null);

      await expectLater(
        snoozeOccurrence(
          'n1',
          30,
          gateway: gateway,
          repo: repo,
          clock: () => DateTime(2026, 9, 4, 18, 0),
        ),
        completes,
      );
      expect(gateway.scheduled, isEmpty);
    });

    test('a note with no slot logs and skips the schedule', () async {
      final gateway = RecordingGateway();
      final repo = FakeNotesRepository(_noteWithReminder(reminderSlot: null));

      await snoozeOccurrence(
        'n1',
        30,
        gateway: gateway,
        repo: repo,
        clock: () => DateTime(2026, 9, 4, 18, 0),
      );

      expect(gateway.scheduled, isEmpty);
      expect(gateway.cancelled, isEmpty);
    });
  });

  group('the last snooze length', () {
    test('snoozing remembers the minutes', () async {
      final gateway = RecordingGateway();
      final repo = FakeNotesRepository(_noteWithReminder());
      final preferences = FakePreferences();

      await snoozeOccurrence(
        'n1',
        30,
        gateway: gateway,
        repo: repo,
        preferences: preferences,
        clock: () => DateTime(2026, 9, 4, 18, 0),
      );

      expect(preferences.setCalls, 30);
    });

    test('a length that was stored reads back', () async {
      final preferences = FakePreferences();
      await preferences.setLatestSnoozeMinutes(60);

      expect(await preferences.getLatestSnoozeMinutes(), 60);
    });
  });

  group('the snooze sheet', () {
    Future<void> openSheet(
      WidgetTester tester, {
      bool recurring = false,
      int? latest,
    }) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showSnoozeSheet(
                    context,
                    recurring: recurring,
                    latestMinutes: latest,
                    onSnooze: (_) async {},
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('a one-off shows four duration chips', (tester) async {
      await openSheet(tester);

      for (final minutes in [10, 30, 60, 240]) {
        expect(find.byKey(ValueKey('snooze_minutes_$minutes')), findsOneWidget);
      }
      expect(find.byKey(const ValueKey('snooze_minutes_1440')), findsNothing);
    });

    testWidgets('a repeating reminder shows five duration chips', (
      tester,
    ) async {
      await openSheet(tester, recurring: true);

      for (final minutes in [10, 30, 60, 240, 1440]) {
        expect(find.byKey(ValueKey('snooze_minutes_$minutes')), findsOneWidget);
      }
    });

    testWidgets('a chip carries its label', (tester) async {
      await openSheet(tester);

      expect(find.text(english.snoozeMinutes(10)), findsOneWidget);
      expect(find.text(english.snoozeMinutes(30)), findsOneWidget);
    });

    testWidgets('picking a chip snoozes with those minutes', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      int? chosen;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showSnoozeSheet(
                    context,
                    recurring: false,
                    onSnooze: (minutes) async => chosen = minutes,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('snooze_minutes_30')));
      await tester.pumpAndSettle();

      expect(chosen, 30);
    });
  });

  group('prompting a snooze on a cold start', () {
    testWidgets('shows the picker once the navigator is ready', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final navigatorKey = GlobalKey<NavigatorState>();
      final gateway = RecordingGateway();
      final repo = FakeNotesRepository(
        _noteWithReminder(recurrence: ReminderRecurrence.daily),
      );
      final preferences = FakePreferences();

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            navigatorKey: navigatorKey,
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Do not await the prompt: it stays pending until the sheet is dismissed.
      unawaited(
        promptReminderSnooze(
          'n1',
          gateway: gateway,
          repo: repo,
          preferences: preferences,
          navigatorKey: navigatorKey,
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text(english.snoozeSheetTitle), findsOneWidget);
    });

    testWidgets('gives up with no navigator instead of hanging', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final gateway = RecordingGateway();
      final repo = FakeNotesRepository(_noteWithReminder());
      final preferences = FakePreferences();

      // A key that never attaches has no context; with no retries left the
      // prompt must give up at once, not spin forever.
      final orphanKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(const SizedBox.shrink());

      await promptReminderSnooze(
        'n1',
        gateway: gateway,
        repo: repo,
        preferences: preferences,
        navigatorKey: orphanKey,
        maxFrames: 0,
      );

      expect(gateway.scheduled, isEmpty);
    });
  });
}
