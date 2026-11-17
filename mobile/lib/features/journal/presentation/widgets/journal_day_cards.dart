import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/text/date_formats.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/context_extensions.dart';
import '../../../../core/theme/tokens/anchor_tokens.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../l10n/l10n.dart';
import '../../../notes/domain/note.dart';
import '../../../notes/domain/note_dates.dart';
import '../../../notes/presentation/widgets/note_chips.dart';
import '../../../notes/presentation/widgets/note_surface.dart';
import '../../../tags/domain/tag.dart';
import '../../../tags/presentation/tags_controller.dart';
import '../../domain/journal_day.dart';
import '../../domain/journal_meta.dart';
import '../journal_entry_text.dart';

/// The selected day in the calendar: a day header, then a card per entry.
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
          for (final entry in day.entries)
            Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                0,
                16,
                context.density.space8,
              ),
              child: _EntryCard(
                entry: entry,
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
    final isToday = isSameDay(day.day, DateTime.now());
    final label = DateFormat(
      'EEE, MMM d',
      dateLocale,
    ).format(day.day).toUpperCase();
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        context.density.space16,
        16,
        context.density.space8,
      ),
      child: Row(
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.label.copyWith(color: colors.appMuted),
          ),
          if (isToday)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _TodayPill(),
            ),
          const Spacer(),
          Text(
            context.l10n.journalEntriesCount(day.entries.length),
            style: AppTypography.footnote.copyWith(color: colors.appMuted),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.accentStrong.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AnchorTokens.radiusPill),
      ),
      child: Text(
        context.l10n.commonToday.toUpperCase(),
        style: AppTypography.footnote.copyWith(
          fontWeight: FontWeight.w700,
          color: colors.accentStrong,
        ),
      ),
    );
  }
}

class _EntryCard extends ConsumerWidget {
  const _EntryCard({
    required this.entry,
    this.journalTagId,
    required this.onOpen,
  });

  final JournalDayEntry entry;
  final String? journalTagId;
  final ValueChanged<Note> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final note = entry.note;
    final colors = context.anchor;
    final title = journalTitleOf(note, context.l10n);
    final preview = journalPreviewOf(note, title);
    final meta = parseJournalContent(note.content).meta;
    final time = meta.entryAt == null
        ? ''
        : clockLabel(meta.entryAt!);
    final otherTag = _firstOtherTag(ref, note, journalTagId);
    // TODO: mood emoji row is deferred; only the tag chip renders for now.
    final hasMeta = time.isNotEmpty || otherTag != null;

    return Pressable(
      style: PressStyle.plain,
      onTap: () => onOpen(note),
      semanticLabel: time.isEmpty ? title : '$title · $time',
      child: Container(
        decoration: BoxDecoration(
          color: colors.appSurface,
          borderRadius: BorderRadius.circular(AnchorTokens.radiusCard),
          border: Border.all(color: colors.appBorder),
        ),
        padding: EdgeInsets.all(context.density.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.row.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.appText,
              ),
            ),
            if (preview.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.cardBody.copyWith(
                    color: colors.appMuted,
                  ),
                ),
              ),
            if (hasMeta)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    if (time.isNotEmpty)
                      Text(
                        time,
                        style: AppTypography.footnote.copyWith(
                          color: colors.appMuted,
                        ),
                      ),
                    if (otherTag != null) ...[
                      if (time.isNotEmpty) const SizedBox(width: 8),
                      TagChip(
                        tag: otherTag,
                        appearance: NoteAppearance.of(context, null),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// The first tag on the note that is not the journal tag, if any.
  Tag? _firstOtherTag(WidgetRef ref, Note note, String? journalTagId) {
    final all = ref.watch(tagsControllerProvider).value ?? const <Tag>[];
    for (final id in note.tagIds) {
      if (id == journalTagId) continue;
      for (final tag in all) {
        if (tag.id == id) return tag;
      }
    }
    return null;
  }
}