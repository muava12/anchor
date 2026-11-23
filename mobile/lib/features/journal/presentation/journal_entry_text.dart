import 'package:intl/intl.dart';

import '../../../core/text/date_formats.dart';
import '../../../l10n/l10n.dart';
import '../../notes/data/repository/notes_repository.dart';
import '../../notes/domain/note.dart';
import '../../notes/domain/note_blocks.dart';
import '../../notes/presentation/note_labels.dart';
import '../../tags/domain/tag.dart';
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

/// The entry time in the phone's clock form, plus " · GMT+7" when the
/// entry's timezone is known. Empty when the entry has no time.
String journalTimeLabel(JournalDayEntry entry) {
  final at = entry.meta.entryAt ?? entry.note.updatedAt?.toLocal();
  if (at == null) return '';
  var label = clockLabel(at);
  final tz = entry.meta.tzOffset;
  if (tz != null) label = '$label · ${gmtLabel(tz)}';
  return label;
}

/// The day separator: "November 19, 2026 · Thu".
String journalDaySeparator(DateTime day) =>
    '${DateFormat('MMMM d, y', dateLocale).format(day)} · '
    '${DateFormat('EEE', dateLocale).format(day)}';

/// The entry's whole body, trimmed, without the metadata header.
String journalLeadOf(Note note) => journalBodyOf(note).trim();

/// A short lead: no newline and at most 90 characters.
bool isShortLead(String lead) => !lead.contains('\n') && lead.length <= 90;

/// The entry's place from the `location:` header key, trimmed. Null when
/// absent or blank.
String? journalLocationOf(JournalMeta meta) {
  final place = meta.extras['location']?.trim();
  return place == null || place.isEmpty ? null : place;
}

/// Every tag of the note except the journal tag, in [note]'s tagIds order.
List<Tag> journalDisplayTags(Note note, List<Tag> all, String? journalTagId) =>
    [
      for (final id in note.tagIds)
        if (id != journalTagId) ...all.where((tag) => tag.id == id),
    ];

/// The number of images beyond the four-preview strip. Zero when the note
/// has fewer than four previews, so a "+N" badge never appears alone.
int journalMoreImages(Note note) =>
    note.imagePreviewData.length == maxImagePreviews
    ? note.attachmentCount - note.imagePreviewData.length
    : 0;

/// "GMT+7" (whole hours) or "GMT+5:30" from a UTC offset in minutes.
String gmtLabel(int tzOffsetMinutes) {
  final sign = tzOffsetMinutes < 0 ? '-' : '+';
  final abs = tzOffsetMinutes.abs();
  final h = abs ~/ 60;
  final m = abs % 60;
  return m == 0 ? 'GMT$sign$h' : 'GMT$sign$h:${m.toString().padLeft(2, '0')}';
}
