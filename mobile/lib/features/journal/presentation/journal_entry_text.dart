import 'package:intl/intl.dart';

import '../../../core/text/date_formats.dart';
import '../../../l10n/l10n.dart';
import '../../notes/domain/note.dart';
import '../../notes/domain/note_blocks.dart';
import '../../notes/domain/note_dates.dart';
import '../../notes/presentation/note_labels.dart';
import '../domain/journal_day.dart';
import '../domain/journal_meta.dart';

/// The entry's body, without the journal metadata header.
String journalBodyOf(Note note) =>
    plainTextOf(parseJournalContent(note.content).body ?? note.content);

/// The entry's first line: the title, or the body's first line when untitled.
String journalTitleOf(Note note, AppLocalizations l10n) {
  if (note.hasTitle) return displayTitleOf(note.title, l10n);
  for (final line in journalBodyOf(note).split('\n')) {
    if (line.trim().isNotEmpty) return line;
  }
  return l10n.noteUntitled;
}

/// The body below a title. Empty when it only repeats the title.
String journalPreviewOf(Note note, String title) {
  if (!note.hasTitle) return '';
  final body = journalBodyOf(note).trim();
  if (body.isEmpty) return '';
  final lines = body.split('\n');
  if (lines.first.trim() == title.trim()) {
    return lines.skip(1).join('\n').trim();
  }
  return body;
}

/// The entry's time in the phone's 12- or 24-hour form.
String journalTimeOf(JournalDayEntry entry) {
  final at = entry.meta.entryAt ?? entry.note.updatedAt?.toLocal();
  return at == null ? '' : clockLabel(at);
}

/// The day header: "TODAY, 12 AUG 2025" or "MONDAY, 13 AUG 2026". When the
/// day's entries were made in a timezone that differs from the device now,
/// a "\u00b7 GMT+07" suffix is added.
String journalDayHeader(
  JournalDay day,
  AppLocalizations l10n, {
  DateTime? now,
}) {
  final d = day.day;
  final today = now ?? DateTime.now();
  final word = switch (daysFromToday(d, today)) {
    0 => l10n.commonToday,
    -1 => l10n.commonYesterday,
    _ => DateFormat('EEEE', dateLocale).format(d),
  };
  final date = DateFormat('d MMM yyyy', dateLocale).format(d);
  var header = '$word, $date'.toUpperCase();
  final tz = _dayTz(day, today);
  if (tz != null) header = '$header \u00b7 ${gmtLabel(tz)}';
  return header;
}

/// The UTC offset (minutes) to show, when the day's first dated entry was
/// made in a timezone that differs from [now]'s.
int? _dayTz(JournalDay day, DateTime now) {
  final current = now.timeZoneOffset.inMinutes;
  for (final entry in day.entries) {
    final tz = entry.meta.tzOffset;
    if (tz != null && tz != current) return tz;
  }
  return null;
}

/// "GMT+07" (whole hours) or "GMT+05:30" from a UTC offset in minutes.
String gmtLabel(int tzOffsetMinutes) {
  final sign = tzOffsetMinutes < 0 ? '-' : '+';
  final abs = tzOffsetMinutes.abs();
  final h = (abs ~/ 60).toString().padLeft(2, '0');
  final m = abs % 60;
  return m == 0
      ? 'GMT$sign$h'
      : 'GMT$sign$h:${m.toString().padLeft(2, '0')}';
}