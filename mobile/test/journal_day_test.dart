import 'package:anchor/features/journal/domain/journal_day.dart';
import 'package:anchor/features/notes/domain/note.dart';
import 'package:flutter_test/flutter_test.dart';

Note note(String id, String iso) {
  final at = DateTime.parse(iso);
  String pad(int value) => value.toString().padLeft(2, '0');
  final content = '{"ops":[{"insert":"mood: good\\n'
      'date: ${at.year.toString().padLeft(4, '0')}-${pad(at.month)}-${pad(at.day)}\\n'
      'time: ${pad(at.hour)}:${pad(at.minute)}\\n'
      '---\\n$id\\n"}]}';
  return Note(id: id, title: id, content: content);
}

void main() {
  test('groups by local entry day, newest day first', () {
    final days = groupJournalDays([
      note('a', '2026-11-17T23:30:00'),
      note('b', '2026-11-17T08:00:00'),
      note('c', '2026-11-16T10:00:00'),
    ]);
    expect([for (final day in days) day.day], [
      DateTime(2026, 11, 17),
      DateTime(2026, 11, 16),
    ]);
    expect([for (final e in days.first.entries) e.note.id], ['a', 'b']);
  });

  test('a note with no metadata falls back to its updatedAt', () {
    final at = DateTime.utc(2026, 11, 15, 19, 30).toLocal();
    final days = groupJournalDays([
      Note(
        id: 'x',
        title: 'X',
        content: 'plain',
        updatedAt: at.toUtc(),
      ),
    ]);
    expect(days.single.day, DateTime(at.year, at.month, at.day));
    expect(days.single.entries.single.note.id, 'x');
  });

  test('a note with no date at all groups under today', () {
    final now = DateTime.now();
    final days = groupJournalDays([
      const Note(id: 'y', title: 'Y', content: 'plain'),
    ]);
    expect(days.single.day, DateTime(now.year, now.month, now.day));
  });

  test('heat buckets map entry counts to a level', () {
    expect(heatLevelOf(0), 0);
    expect(heatLevelOf(1), 1);
    expect(heatLevelOf(2), 2);
    expect(heatLevelOf(3), 2);
    expect(heatLevelOf(4), 3);
    expect(heatLevelOf(10), 3);
  });

  test('journalEntryCounts maps each day to its entry count', () {
    final days = groupJournalDays([
      note('a', '2026-11-17T08:00:00'),
      note('b', '2026-11-17T09:00:00'),
      note('c', '2026-11-16T10:00:00'),
    ]);
    final counts = journalEntryCounts(days);
    expect(counts[DateTime(2026, 11, 17)], 2);
    expect(counts[DateTime(2026, 11, 16)], 1);
    expect(counts[DateTime(2026, 11, 18)], isNull);
  });
}
