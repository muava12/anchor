import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';
import '../../../../core/text/date_formats.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/context_extensions.dart';
import '../../../../core/theme/tokens/anchor_tokens.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../notes/domain/note.dart';
import '../../../notes/domain/note_blocks.dart';
import '../../../notes/presentation/note_labels.dart';
import '../../domain/journal_day.dart';
import '../../domain/journal_meta.dart';

/// A day-grouped journal, as a sliver for a [CustomScrollView].
class JournalTimeline extends StatelessWidget {
  const JournalTimeline({required this.days, required this.onOpen});

  final List<JournalDay> days;
  final ValueChanged<Note> onOpen;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      for (final day in days) ...[
        _DayHeader(day: day),
        for (final entry in day.entries)
          _EntryRow(entry: entry, onOpen: onOpen),
      ],
    ];
    return SliverList(delegate: SliverChildListDelegate(children));
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day});

  final JournalDay day;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        context.density.space16,
        16,
        context.density.space8,
      ),
      child: Text(
        dayLabel(day.day, DateTime.now(), context.l10n),
        style: AppTypography.secondary.copyWith(
          fontWeight: FontWeight.w600,
          color: context.anchor.appMuted,
        ),
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry, required this.onOpen});

  final JournalDayEntry entry;
  final ValueChanged<Note> onOpen;

  String _timeOf(JournalDayEntry entry) {
    final at = entry.meta.entryAt ?? entry.note.updatedAt?.toLocal();
    return at == null ? '' : clockLabel(at);
  }

  String _firstBodyLine(BuildContext context, Note note) {
    final text =
        plainTextOf(parseJournalContent(note.content).body ?? note.content).trim();
    for (final line in text.split('\n')) {
      if (line.trim().isNotEmpty) return line;
    }
    return context.l10n.noteUntitled;
  }

  @override
  Widget build(BuildContext context) {
    final note = entry.note;
    final colors = context.anchor;
    final mood = entry.meta.mood;
    final time = _timeOf(entry);
    final title = note.hasTitle
        ? displayTitleOf(note.title, context.l10n)
        : _firstBodyLine(context, note);

    return Pressable(
      style: PressStyle.plain,
      onTap: () => onOpen(note),
      semanticLabel: time.isEmpty ? title : '$title · $time',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 12, child: const _TimelineRail()),
            const SizedBox(width: 8),
            SizedBox(
              width: 56,
              child: Text(
                time,
                style: AppTypography.footnote.copyWith(color: colors.appMuted),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.row.copyWith(color: colors.appText),
                  ),
                  if (mood != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        mood.emoji,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                ],
              ),
            ),
            if (note.imagePreviewData.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: const _PlaceholderThumbnail(),
              ),
          ],
        ),
      ),
    );
  }
}

class _TimelineRail extends StatelessWidget {
  const _TimelineRail();

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    return Column(
      children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.accentStrong,
          ),
        ),
        Container(width: 2, color: colors.appBorder),
      ],
    );
  }
}

/// A placeholder for the entry's picture; the image load is a follow-up.
class _PlaceholderThumbnail extends StatelessWidget {
  const _PlaceholderThumbnail();

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: colors.appSurface,
        borderRadius: BorderRadius.circular(AnchorTokens.radiusMd),
        border: Border.all(color: colors.appBorder),
      ),
    );
  }
}
