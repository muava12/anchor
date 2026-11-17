import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/text/date_formats.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/context_extensions.dart';
import '../../../../core/theme/tokens/anchor_tokens.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../l10n/l10n.dart';
import '../../../notes/domain/note.dart';
import '../../../notes/domain/note_dates.dart';
import '../../domain/journal_day.dart';
import '../journal_entry_text.dart';

/// The selected day in the calendar: a day header, then a card per entry.
class JournalDayCards extends StatelessWidget {
  const JournalDayCards({super.key, required this.days, required this.onOpen});

  final List<JournalDay> days;
  final ValueChanged<Note> onOpen;

  @override
  Widget build(BuildContext context) {
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
              child: _EntryCard(entry: entry, onOpen: onOpen),
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

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry, required this.onOpen});

  final JournalDayEntry entry;
  final ValueChanged<Note> onOpen;

  @override
  Widget build(BuildContext context) {
    final note = entry.note;
    final colors = context.anchor;
    final title = journalTitleOf(note, context.l10n);
    final preview = journalPreviewOf(note, title);
    final time = journalTimeOf(entry);

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
            if (time.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  time,
                  style: AppTypography.footnote.copyWith(
                    color: colors.appMuted,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}