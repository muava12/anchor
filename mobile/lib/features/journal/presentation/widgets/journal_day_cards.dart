import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/text/date_formats.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/context_extensions.dart';
import '../../../../core/theme/tokens/anchor_tokens.dart';
import '../../../../l10n/l10n.dart';
import '../../../notes/domain/note.dart';
import '../../../notes/domain/note_dates.dart';
import '../../../notes/presentation/widgets/note_chips.dart';
import '../../../notes/presentation/widgets/note_surface.dart';
import '../../../tags/domain/tag.dart';
import '../../../tags/presentation/tags_controller.dart';
import '../../domain/journal_day.dart';
import '../journal_entry_text.dart';
import 'journal_card_shell.dart';
import 'journal_thumb_stack.dart';
import 'mood_face.dart';

/// The selected day in the calendar: a day header, then one card holding all
/// of the day's entries, oldest first, with a thumbnail stack per entry.
class JournalDayCards extends ConsumerWidget {
  const JournalDayCards({
    super.key,
    required this.days,
    required this.journalTagId,
    required this.onOpen,
  });

  final List<JournalDay> days;
  final String? journalTagId;
  final ValueChanged<Note> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SliverList(
      delegate: SliverChildListDelegate([
        for (final day in days) ...[
          _DayHeader(day: day),
          Padding(
            padding: const EdgeInsets.only(bottom: AnchorTokens.space12),
            child: _DayCard(
              day: day,
              journalTagId: journalTagId,
              onOpen: onOpen,
            ),
          ),
        ],
      ]),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day});

  final JournalDay day;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    final l10n = context.l10n;
    final isToday = isSameDay(day.day, DateTime.now());
    final label = DateFormat(
      'EEE, d MMM',
      dateLocale,
    ).format(day.day).toUpperCase();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        14,
        16,
        8,
      ), // off-scale: design day header padding
      child: Row(
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.label.copyWith(
              fontWeight: FontWeight.w700,
              color: colors.appText,
            ),
          ),
          if (isToday)
            Padding(
              padding: const EdgeInsets.only(
                left: 6,
              ), // off-scale: design pill gap 6
              child: _TodayPill(),
            ),
          const Spacer(),
          Text(
            l10n.journalEntriesCount(day.entries.length),
            style: AppTypography.caption
                .copyWith(color: colors.appMuted)
                .tabular,
          ),
        ],
      ),
    );
  }
}

/// A small accent-tint "TODAY" pill beside the day label.
class _TodayPill extends StatelessWidget {
  const _TodayPill();

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AnchorTokens.space6, // off-scale: design pill padding 6
        vertical: 2, // off-scale: design pill padding 2
      ),
      decoration: BoxDecoration(
        color: colors.accentStrong.withValues(
          alpha: 0.20,
        ), // off-scale: design pill tint 20
        borderRadius: BorderRadius.circular(AnchorTokens.radiusPill),
      ),
      child: Text(
        context.l10n.commonToday.toUpperCase(),
        style: AppTypography.caption.copyWith(
          fontWeight: FontWeight.w700,
          color: colors.accentStrong,
        ),
      ),
    );
  }
}

/// One day's card: a [JournalCardShell] with every entry registered for the
/// note morph, oldest entry first.
class _DayCard extends ConsumerWidget {
  const _DayCard({
    required this.day,
    required this.journalTagId,
    required this.onOpen,
  });

  final JournalDay day;
  final String? journalTagId;
  final ValueChanged<Note> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allTags = ref.watch(tagsControllerProvider).value ?? const <Tag>[];

    // The day's entries are stored newest first; the card shows them in
    // chronological order.
    final entries = [for (final entry in day.entries) entry].reversed.toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: JournalCardShell(
        children: [
          for (final entry in entries)
            JournalRegisteredEntry(
              noteId: entry.note.id,
              semanticLabel: _label(context, entry),
              onTap: () => onOpen(entry.note),
              child: _DayEntryRow(
                entry: entry,
                tags: journalDisplayTags(entry.note, allTags, journalTagId),
              ),
            ),
        ],
      ),
    );
  }

  /// "title · time"; the time drops out when the entry has none.
  String _label(BuildContext context, JournalDayEntry entry) {
    final title = journalTitleOf(entry.note, context.l10n);
    final time = journalTimeOf(entry);
    return time.isEmpty ? title : '$title · $time';
  }
}

/// One entry inside the day card: the text on the left, a thumbnail stack on
/// the right when the entry has pictures.
class _DayEntryRow extends StatelessWidget {
  const _DayEntryRow({required this.entry, required this.tags});

  final JournalDayEntry entry;
  final List<Tag> tags;

  @override
  Widget build(BuildContext context) {
    final note = entry.note;
    final colors = context.anchor;
    final title = journalTitleOf(note, context.l10n);
    final snippet = journalPreviewOf(note, title);
    final lead = note.hasTitle ? '' : journalLeadOf(note);
    final mood = entry.meta.mood;
    final time = journalTimeOf(entry);
    final hasPictures = note.imagePreviewData.isNotEmpty;

    final metaParts = <Widget>[
      if (time.isNotEmpty)
        Text(
          time,
          style: AppTypography.caption.copyWith(color: colors.appMuted).tabular,
        ),
      if (mood != null)
        MoodFace(mood: mood, size: 20), // off-scale: design day-card mood 20
      for (final tag in tags)
        TagChip(tag: tag, appearance: NoteAppearance.of(context, null)),
    ];
    final metaChildren = <Widget>[];
    for (var i = 0; i < metaParts.length; i++) {
      if (i > 0) metaChildren.add(const _MetaDot());
      metaChildren.add(metaParts[i]);
    }

    return Padding(
      padding: const EdgeInsets.all(
        AnchorTokens.space14,
      ), // off-scale: design entry padding 14
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (note.hasTitle)
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.cardTitle.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colors.appText,
                    ),
                  )
                else if (lead.isNotEmpty)
                  Text(
                    lead,
                    key: const ValueKey('journal-lead'),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.cardTitle.copyWith(
                      fontWeight: FontWeight.w500,
                      height: 1.55,
                      color: colors.appText,
                    ),
                  ),
                if (note.hasTitle && snippet.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      snippet,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.cardBody.copyWith(
                        color: colors.appMuted,
                      ),
                    ),
                  ),
                if (metaChildren.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(
                      top:
                          AnchorTokens.space10, // off-scale: design meta gap 10
                    ),
                    child: Wrap(
                      spacing:
                          AnchorTokens.space6, // off-scale: design meta gap 6
                      runSpacing:
                          AnchorTokens.space6, // off-scale: design meta gap 6
                      children: metaChildren,
                    ),
                  ),
              ],
            ),
          ),
          if (hasPictures) ...[
            const SizedBox(width: 12),
            JournalThumbStack(previews: note.imagePreviewData),
          ],
        ],
      ),
    );
  }
}

/// The dot between two meta parts.
class _MetaDot extends StatelessWidget {
  const _MetaDot();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AnchorTokens.space2,
      ), // off-scale: meta dot gap
      child: Container(
        width: 3, // off-scale: the meta row's separator dot
        height: 3, // off-scale: the meta row's separator dot
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: context.anchor.appMuted,
        ),
      ),
    );
  }
}
