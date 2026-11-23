import 'journal_day.dart';

/// The run of consecutive entry days ending today or yesterday, as a day
/// count. Null when the run is shorter than two days.
int? journalStreakOf(List<JournalDay> days, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final entryDays = <DateTime>{for (final day in days) day.day};

  var anchor = entryDays.contains(today)
      ? today
      : entryDays.contains(DateTime(now.year, now.month, now.day - 1))
      ? DateTime(now.year, now.month, now.day - 1)
      : null;
  if (anchor == null) return null;

  var length = 0;
  var cursor = anchor;
  while (entryDays.contains(cursor)) {
    length++;
    cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
  }
  return length >= 2 ? length : null;
}

/// The nearest prior year (before [now]'s) with an entry on today's
/// month-day, with that day's entry count. Null when no such year exists.
/// A leap-day entry (29 Feb) matches no 28 Feb of a common year.
({int year, int entryCount})? journalThrowbackOf(
  List<JournalDay> days,
  DateTime now,
) {
  int? year;
  var entryCount = 0;
  for (final day in days) {
    if (day.day.year >= now.year) continue;
    if (day.day.month != now.month || day.day.day != now.day) continue;
    if (year == null || day.day.year > year) {
      year = day.day.year;
      entryCount = day.entries.length;
    }
  }
  return year == null ? null : (year: year, entryCount: entryCount);
}
