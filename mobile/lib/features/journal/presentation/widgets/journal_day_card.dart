import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';
import '../../../notes/domain/note.dart';
import '../../../tags/domain/tag.dart';
import '../../domain/journal_day.dart';
import '../journal_entry_text.dart';
import 'journal_card_shell.dart';
import 'journal_entry_card.dart';

/// One day of the journal list: its entries inside one [JournalCardShell],
/// oldest entry first.
///
/// A day with one entry keeps the whole shell inside its
/// [JournalRegisteredEntry], so the note morph flies from the card's
/// surface. A day with several entries registers each entry separately,
/// inside the shell's dividers.
class JournalDayCard extends StatelessWidget {
  const JournalDayCard({
    super.key,
    required this.day,
    required this.tags,
    required this.journalTagId,
    required this.onOpen,
  });

  final JournalDay day;
  final List<Tag> tags;
  final String? journalTagId;
  final ValueChanged<Note> onOpen;

  @override
  Widget build(BuildContext context) {
    // The day's entries are stored newest first; the card shows them in
    // chronological order.
    final entries = [for (final entry in day.entries) entry].reversed.toList();
    List<Tag> displayTagsOf(Note note) =>
        journalDisplayTags(note, tags, journalTagId);

    if (entries.length == 1) {
      final entry = entries.single;
      return JournalRegisteredEntry(
        noteId: entry.note.id,
        semanticLabel: _label(context, entry),
        onTap: () => onOpen(entry.note),
        child: JournalCardShell(
          children: [
            JournalEntryCard(entry: entry, tags: displayTagsOf(entry.note)),
          ],
        ),
      );
    }

    return JournalCardShell(
      children: [
        for (final entry in entries)
          JournalRegisteredEntry(
            noteId: entry.note.id,
            semanticLabel: _label(context, entry),
            onTap: () => onOpen(entry.note),
            child: JournalEntryCard(
              entry: entry,
              tags: displayTagsOf(entry.note),
            ),
          ),
      ],
    );
  }

  /// "title · time"; the time drops out when the entry has none.
  String _label(BuildContext context, JournalDayEntry entry) {
    final title = journalTitleOf(entry.note, context.l10n);
    final time = journalTimeLabel(entry);
    return time.isEmpty ? title : '$title · $time';
  }
}
