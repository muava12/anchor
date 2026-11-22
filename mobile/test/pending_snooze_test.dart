import 'package:anchor/features/notes/data/repository/notes_repository.dart';
import 'package:anchor/features/notes/domain/note.dart';
import 'package:anchor/features/reminders/data/pending_snooze_channel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

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

Note _note({
  String id = 'n1',
  ReminderRecurrence recurrence = ReminderRecurrence.none,
  String remindAt = '2026-09-04T18:00',
  int version = 3,
  NoteReminder? reminder,
}) => Note(
  id: id,
  title: 'Groceries',
  reminderSlot: 7,
  reminder:
      reminder ??
      NoteReminder(
        remindAt: remindAt,
        recurrence: recurrence,
        version: version,
      ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('anchor/pending_snoozes');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void mockNative(List<Map<String, Object>> records) {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'drainPendingSnoozes');
      return records;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
  }

  Map<String, Object> record(
    String noteId,
    DateTime local, {
    String recurrence = 'none',
  }) => {
    'noteId': noteId,
    'newAtMillis': local.millisecondsSinceEpoch,
    'recurrence': recurrence,
  };

  group('draining the native snooze stash', () {
    test('moves the snoozed note to the new time and counts it', () async {
      final repo = FakeNotesRepository(_note());
      mockNative([record('n1', DateTime(2026, 9, 4, 18, 30))]);

      final applied = await drainPendingSnoozes(repo: repo, channel: channel);

      expect(applied, 1);
      expect(repo.remindersSet, hasLength(1));
      final written = repo.remindersSet.single!;
      expect(written.remindAt, '2026-09-04T18:30');
      expect(written.recurrence, ReminderRecurrence.none);
      expect(written.version, 3);
      final saved = await repo.getNote('n1');
      expect(saved!.reminder!.remindAt, '2026-09-04T18:30');
    });

    test(
      'a repeating snooze keeps the recurrence and moves the time',
      () async {
        final repo = FakeNotesRepository(
          _note(recurrence: ReminderRecurrence.daily),
        );
        mockNative([
          record('n1', DateTime(2026, 9, 5, 9, 0), recurrence: 'daily'),
        ]);

        final applied = await drainPendingSnoozes(repo: repo, channel: channel);

        expect(applied, 1);
        final written = repo.remindersSet.single!;
        expect(written.remindAt, '2026-09-05T09:00');
        expect(written.recurrence, ReminderRecurrence.daily);
      },
    );

    test('is a no-op when the native side holds nothing', () async {
      final repo = FakeNotesRepository(_note());
      mockNative([]);

      final applied = await drainPendingSnoozes(repo: repo, channel: channel);

      expect(applied, 0);
      expect(repo.remindersSet, isEmpty);
    });

    test('skips a note that is gone', () async {
      final repo = FakeNotesRepository(_note());
      mockNative([record('n9', DateTime(2026, 9, 4, 18, 30))]);

      final applied = await drainPendingSnoozes(repo: repo, channel: channel);

      expect(applied, 0);
      expect(repo.remindersSet, isEmpty);
    });

    test('skips a note that lost its reminder', () async {
      final repo = FakeNotesRepository(
        Note(id: 'n1', title: 'Groceries', reminderSlot: 7),
      );
      mockNative([record('n1', DateTime(2026, 9, 4, 18, 30))]);

      final applied = await drainPendingSnoozes(repo: repo, channel: channel);

      expect(applied, 0);
      expect(repo.remindersSet, isEmpty);
    });

    test('counts several snoozes and writes each of them', () async {
      final repo = FakeNotesRepository(
        _note(
          id: 'n1',
          remindAt: '2026-09-04T08:00',
          recurrence: ReminderRecurrence.daily,
        ),
      );
      mockNative([
        record('n1', DateTime(2026, 9, 4, 9, 0), recurrence: 'daily'),
        record('n9', DateTime(2026, 9, 4, 10, 0)),
      ]);

      final applied = await drainPendingSnoozes(repo: repo, channel: channel);

      expect(applied, 1);
      expect(repo.remindersSet.single!.remindAt, '2026-09-04T09:00');
    });

    test('a missing native side drains nothing', () async {
      final repo = FakeNotesRepository(_note());

      final applied = await drainPendingSnoozes(repo: repo, channel: channel);

      expect(applied, 0);
      expect(repo.remindersSet, isEmpty);
    });
  });
}
