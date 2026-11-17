import '../../../core/text/date_formats.dart';
import '../../../l10n/l10n.dart';
import '../../notes/domain/note.dart';
import '../../notes/domain/note_blocks.dart';
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