import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/text/date_formats.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/context_extensions.dart';
import '../../../../core/theme/tokens/anchor_tokens.dart';
import '../../../../l10n/l10n.dart';
import '../../../notes/presentation/widgets/note_chips.dart';
import '../../../notes/presentation/widgets/note_surface.dart';
import '../../../tags/domain/tag.dart';
import '../../domain/journal_day.dart';
import '../journal_entry_text.dart';
import 'journal_photo_strip.dart';
import 'mood_face.dart';

/// One journal entry as it renders inside a [JournalCardShell]: a time and
/// mood, a title with a snippet or a lead when the entry is untitled, and a
/// footer of the entry's location and tags.
///
/// A photo slot renders between the text and the footer; the day's card adds
/// it.
class JournalEntryCard extends StatelessWidget {
  const JournalEntryCard({super.key, required this.entry, required this.tags});

  final JournalDayEntry entry;
  final List<Tag> tags;

  @override
  Widget build(BuildContext context) {
    final note = entry.note;
    final location = journalLocationOf(entry.meta);
    final time = journalTimeLabel(entry);

    final children = <Widget>[
      if (note.hasTitle) ..._titled(context) else ..._untitled(context, time),
      if (note.imagePreviewData.isNotEmpty)
        JournalPhotoStrip(
          previews: note.imagePreviewData,
          more: journalMoreImages(note),
        ),
      if (location != null || tags.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(
            key: const ValueKey('journal-card-footer'),
            spacing: AnchorTokens.space8,
            runSpacing: AnchorTokens.space8,
            children: [
              if (location != null) _LocationChip(place: location),
              for (final tag in tags)
                TagChip(tag: tag, appearance: NoteAppearance.of(context, null)),
            ],
          ),
        ),
    ];

    return Padding(
      padding: const EdgeInsets.all(
        AnchorTokens.space14,
      ), // off-scale: design card padding 14
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  /// The entry's text: time, title and a two-line snippet, mood on the right.
  List<Widget> _titled(BuildContext context) {
    final note = entry.note;
    final colors = context.anchor;
    final time = journalTimeLabel(entry);
    final title = journalTitleOf(note, context.l10n);
    final snippet = journalPreviewOf(note, title);
    final mood = entry.meta.mood;

    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (time.isNotEmpty) _TimeLabel(entry),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.cardTitle.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colors.appText,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (mood != null) ...[
            const SizedBox(width: 12),
            MoodFace(
              mood: mood,
              size: 28, // off-scale: design mood face 28
            ),
          ],
        ],
      ),
      if (snippet.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(
            top: AnchorTokens.space2, // off-scale: design snippet gap 2
          ),
          child: Text(
            snippet,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.cardBody.copyWith(color: colors.appMuted),
          ),
        ),
    ];
  }

  /// An untitled entry: the whole body as a lead under a time-and-mood line.
  List<Widget> _untitled(BuildContext context, String time) {
    final note = entry.note;
    final colors = context.anchor;
    final mood = entry.meta.mood;
    final lead = journalLeadOf(note);
    final short = isShortLead(lead);

    final headerChildren = <Widget>[
      if (time.isNotEmpty) _TimeLabel(entry),
      if (mood != null)
        MoodFace(mood: mood, size: 28), // off-scale: design mood face 28
    ];

    return [
      SizedBox(
        height: 28, // off-scale: design untitled header height 28
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: headerChildren,
        ),
      ),
      if (lead.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            lead,
            key: const ValueKey('journal-lead'),
            maxLines: short ? 3 : 4,
            overflow: TextOverflow.ellipsis,
            style: short
                ? AppTypography.noteBody.copyWith(color: colors.appText)
                : AppTypography.cardTitle.copyWith(
                    fontWeight: FontWeight.w500,
                    height: 1.55,
                    color: colors.appText,
                  ),
          ),
        ),
    ];
  }
}

/// The entry's clock time, with a muted GMT suffix when the entry's timezone
/// is known.
class _TimeLabel extends StatelessWidget {
  const _TimeLabel(this.entry);

  final JournalDayEntry entry;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    final at = entry.meta.entryAt ?? entry.note.updatedAt?.toLocal();
    final clock = at == null ? '' : clockLabel(at);
    final tz = entry.meta.tzOffset;
    if (clock.isEmpty) return const SizedBox.shrink();

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: clock,
            style: AppTypography.caption
                .copyWith(fontWeight: FontWeight.w700, color: colors.appText)
                .tabular,
          ),
          if (tz != null)
            TextSpan(
              text: ' · ${gmtLabel(tz)}',
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w500,
                color: colors.appMuted,
              ),
            ),
        ],
      ),
    );
  }
}

/// The entry's place: a pin and its name, which ellipsizes at the card's
/// edge. The screen reader reads it as "Location: …".
class _LocationChip extends StatelessWidget {
  const _LocationChip({required this.place});

  final String place;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    return Semantics(
      label: context.l10n.journalLocationLabel(place),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.mapPin,
            size: 13, // off-scale: design pin icon 13
            color: colors.appMuted,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              place,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w500,
                color: colors.appMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
