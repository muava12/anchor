import 'package:flutter/foundation.dart';

import '../../notes/domain/note.dart';
import 'journal_meta.dart';

/// One entry and the metadata parsed from it.
@immutable
class JournalDayEntry {
  const JournalDayEntry({required this.note, required this.meta});

  final Note note;
  final JournalMeta meta;
}

/// The entries of one local day, newest first.
@immutable
class JournalDay {
  const JournalDay({required this.day, required this.entries});

  final DateTime day;
  final List<JournalDayEntry> entries;
}

/// Group notes by their local entry day, newest day and newest entry first.
List<JournalDay> groupJournalDays(List<Note> notes) {
  final now = DateTime.now();
  final byDay = <DateTime, List<JournalDayEntry>>{};
  final timeOf = <String, DateTime>{};

  for (final note in notes) {
    final meta = parseJournalContent(note.content).meta;
    final at = meta.entryAt ?? note.updatedAt?.toLocal() ?? now;
    final day = DateTime(at.year, at.month, at.day);
    (byDay[day] ??= []).add(JournalDayEntry(note: note, meta: meta));
    timeOf[note.id] = at;
  }

  final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final day in days)
      JournalDay(
        day: day,
        entries: byDay[day]!
          ..sort((a, b) => timeOf[b.note.id]!.compareTo(timeOf[a.note.id]!)),
      ),
  ];
}

/// The heat level for a day: 0 none, 1 for one entry, 2 for two or more.
int heatLevelOf(int count) => switch (count) {
  0 => 0,
  1 => 1,
  _ => 2,
};

/// Each day's entry count, for shading the calendar.
Map<DateTime, int> journalEntryCounts(List<JournalDay> days) => {
  for (final day in days) day.day: day.entries.length,
};
