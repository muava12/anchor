import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/text/date_formats.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/context_extensions.dart';
import '../../../../core/theme/tokens/anchor_tokens.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../l10n/l10n.dart';
import '../../../notes/data/repository/attachment_file_provider.dart';
import '../../../notes/domain/note.dart';
import '../../../notes/domain/note_dates.dart';
import '../../../notes/presentation/note_labels.dart';
import '../../domain/journal_day.dart';
import '../journal_entry_text.dart';

/// A day-grouped journal, as a sliver for a [CustomScrollView].
class JournalTimeline extends StatelessWidget {
  const JournalTimeline({super.key, required this.days, required this.onOpen});

  final List<JournalDay> days;
  final ValueChanged<Note> onOpen;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      for (final day in days) ...[
        _DayHeader(day: day),
        for (var i = 0; i < day.entries.length; i++)
          _EntryRow(
            entry: day.entries[i],
            onOpen: onOpen,
            isLastOfDay: i == day.entries.length - 1,
          ),
      ],
    ];
    return SliverList(delegate: SliverChildListDelegate(children));
  }
}

/// The day's name in capitals, its date on the right.
class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day});

  final JournalDay day;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    final l10n = context.l10n;
    final rel = daysFromToday(day.day, DateTime.now());
    final isRelative = rel == 0 || rel == -1;
    final label = isRelative
        ? shortDayLabel(day.day, l10n).toUpperCase()
        : DateFormat('d MMM', dateLocale).format(day.day).toUpperCase();
    final date = isRelative
        ? DateFormat('EEE, d MMM', dateLocale).format(day.day)
        : null;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        context.density.space16,
        16,
        context.density.space8,
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: colors.accentStrong, width: 1.5),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.label.copyWith(color: colors.appMuted),
            ),
          ),
          if (date != null)
            Text(
              date,
              style: AppTypography.footnote.copyWith(color: colors.appMuted),
            ),
        ],
      ),
    );
  }
}

/// One entry: the ring on the rail, the title, the body's first lines and the
/// time under them, and the first picture on the right.
class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.entry,
    required this.onOpen,
    required this.isLastOfDay,
  });

  final JournalDayEntry entry;
  final ValueChanged<Note> onOpen;
  final bool isLastOfDay;

  @override
  Widget build(BuildContext context) {
    final note = entry.note;
    final colors = context.anchor;
    final time = journalTimeOf(entry);
    final title = journalTitleOf(note, context.l10n);
    final preview = journalPreviewOf(note, title);
    final hasPicture = note.imagePreviewData.isNotEmpty;

    return Pressable(
      style: PressStyle.plain,
      onTap: () => onOpen(note),
      semanticLabel: time.isEmpty ? title : '$title · $time',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (!isLastOfDay)
              Positioned(
                left: 7, // off-scale: the 16px ring's centre
                top: 22, // off-scale: just under the ring
                bottom: -8,
                width: 2,
                child: ColoredBox(color: colors.appBorder),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _RailRing(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.cardTitle.copyWith(
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
                          padding: const EdgeInsets.only(top: 4),
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
                if (hasPicture) ...[
                  const SizedBox(width: 12),
                  _EntryThumbnail(preview: note.imagePreviewData.first),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The open ring that marks an entry, on the timeline's rail.
class _RailRing extends StatelessWidget {
  const _RailRing();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      margin: const EdgeInsets.only(top: 2), // off-scale: ring alignment
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: context.anchor.accentStrong, width: 2),
      ),
    );
  }
}

/// The entry's first picture, loaded from the attachment store.
class _EntryThumbnail extends ConsumerWidget {
  const _EntryThumbnail({required this.preview});

  final NoteImagePreview preview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.anchor;
    final loaded = ref.watch(attachmentFileProvider(previewFileKeyOf(preview)));
    final path = loaded.value;
    final missing = ColoredBox(
      color: colors.appSurface,
      child: Center(
        child: Icon(
          LucideIcons.imageOff,
          size: AnchorTokens.sizeIconMedium,
          color: colors.appMuted,
        ),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(AnchorTokens.radiusTile),
      child: SizedBox(
        width: 52, // off-scale: the list card's picture
        height: 52, // off-scale: the list card's picture
        child: path != null
            ? Image.file(
                File(path),
                fit: BoxFit.cover,
                cacheWidth: 400,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => missing,
              )
            : loaded.isLoading
            ? ColoredBox(color: colors.appSurface)
            : missing,
      ),
    );
  }
}