import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/context_extensions.dart';
import '../../../../core/theme/tokens/anchor_tokens.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../l10n/l10n.dart';
import '../../../notes/data/repository/attachment_file_provider.dart';
import '../../../notes/domain/note.dart';
import '../../../notes/presentation/widgets/card_registry.dart';
import '../../../notes/presentation/widgets/note_chips.dart';
import '../../../notes/presentation/widgets/note_surface.dart';
import '../../../tags/domain/tag.dart';
import '../../../tags/presentation/tags_controller.dart';
import '../../domain/journal_day.dart';
import '../../domain/journal_meta.dart';
import '../journal_entry_text.dart';
import '../journal_providers.dart';
import 'mood_face.dart';

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
    final header = journalDayHeader(day, context.l10n);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        context.density.space16,
        16,
        context.density.space8,
      ),
      child: Text(
        header,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.dayHeader.copyWith(color: colors.appText),
      ),
    );
  }
}

/// One entry: the ring on the rail, the title, the body's first lines and the
/// time under them, and the first picture on the right.
class _EntryRow extends ConsumerWidget {
  const _EntryRow({
    required this.entry,
    required this.onOpen,
    required this.isLastOfDay,
  });

  final JournalDayEntry entry;
  final ValueChanged<Note> onOpen;
  final bool isLastOfDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final note = entry.note;
    final colors = context.anchor;
    final time = journalTimeOf(entry);
    final title = journalTitleOf(note, context.l10n);
    final preview = journalPreviewOf(note, title);
    final mood = entry.meta.mood;
    final tag = _firstOtherTag(ref, note, ref.watch(journalTagProvider)?.id);
    final hasPicture = note.imagePreviewData.isNotEmpty;

    return ValueListenableBuilder<Set<String>>(
      valueListenable: CardRegistry.hidden,
      builder: (context, hidden, child) =>
          Opacity(opacity: hidden.contains(note.id) ? 0 : 1, child: child),
      child: Pressable(
        style: PressStyle.plain,
        onTap: () => onOpen(note),
        semanticLabel: time.isEmpty ? title : '$title · $time',
        child: RepaintBoundary(
          // The morph close target: the card flies back to this row.
          key: CardRegistry.keyFor(note.id),
          child: Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (!isLastOfDay)
                  Positioned(
                    left: 7, // off-scale: the 16px ring's centre
                    top: 0,
                    bottom: -16,
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
                              fontWeight: FontWeight.w700,
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
                          if (time.isNotEmpty || mood != null || tag != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: _MetaRow(
                                time: time,
                                mood: mood,
                                tag: tag,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (hasPicture) ...[
                      const SizedBox(width: 12),
                      _EntryThumbnails(previews: note.imagePreviewData),
                    ],
                  ],
                ),
              ],
            ),
          ),
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

/// The entry's meta line: time, mood face, tag chip, in one row.
///
/// Each part drops out when the entry has none; the dot separators only
/// appear between two present parts.
class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.time, required this.mood, required this.tag});

  final String time;
  final JournalMood? mood;
  final Tag? tag;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    final parts = <Widget>[
      if (time.isNotEmpty)
        Text(
          time,
          style: AppTypography.caption.tabular.copyWith(color: colors.appMuted),
        ),
      if (mood != null) MoodFace(mood: mood!, size: AnchorTokens.sizeIconMedium),
      if (tag != null)
        // The chip is the only part that can give way, so a long tag name
        // ellipsizes instead of overflowing the row.
        Flexible(
          child: TagChip(
            tag: tag!,
            appearance: NoteAppearance.of(context, null),
          ),
        ),
    ];
    final children = <Widget>[];
    for (var i = 0; i < parts.length; i++) {
      if (i > 0) children.add(const _MetaDot());
      children.add(parts[i]);
    }
    return Row(children: children);
  }
}

/// The dot between two meta parts.
class _MetaDot extends StatelessWidget {
  const _MetaDot();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AnchorTokens.space8),
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

/// The open ring that marks an entry, on the timeline's rail.
class _RailRing extends StatelessWidget {
  const _RailRing();

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    // A solid page-coloured fill hides the rail line that passes behind the
    // ring's centre, so the line reads as cut at every marker.
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: colors.appPage,
        shape: BoxShape.circle,
        border: Border.all(color: colors.accentStrong, width: 2),
      ),
    );
  }
}

/// The entry's pictures: one, a pair, or a stack of three.
class _EntryThumbnails extends ConsumerWidget {
  const _EntryThumbnails({required this.previews});

  final List<NoteImagePreview> previews;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.anchor;
    final count = previews.length;
    // Every stacked picture loads its own real file, not a blank placeholder.
    final paths = <String?>[
      for (final preview in previews)
        ref.watch(attachmentFileProvider(previewFileKeyOf(preview))).value,
    ];
    const off = 6.0; // off-scale: the step between stacked pictures
    final behind = count - 1 > 2 ? 2 : count - 1;
    // The token's 56 is off the layout scale; the design fixes that size.
    final side = AnchorTokens.sizeJournalThumb;

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

    // The design fans the stack: the furthest card leans the most and fades
    // the most, the next one a little, the front card is square-on and solid.
    const lean = [0.0, -0.07, 0.13]; // off-scale: the design's stack angles
    const fade = [1.0, 0.8, 0.7]; // off-scale: the design's stack opacity

    // One card of the stack: the real picture, or blank while it is unresolved.
    Widget thumb(int index) {
      final path = paths[index];
      final card = ClipRRect(
        borderRadius: BorderRadius.circular(AnchorTokens.radiusTile),
        child: SizedBox(
          width: side,
          height: side,
          child: path != null
              ? Image.file(
                  File(path),
                  fit: BoxFit.cover,
                  cacheWidth: 96,
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) => missing,
                )
              : ColoredBox(color: colors.appSurface),
        ),
      );
      if (index == 0) return card;
      return Opacity(
        opacity: fade[index],
        child: Transform.rotate(angle: lean[index], child: card),
      );
    }

    return SizedBox(
      width: side + off * behind,
      height: side + off * behind,
      child: Stack(
        alignment: Alignment.topLeft,
        clipBehavior: Clip.none,
        children: [
          // The back cards, furthest first, peaking up and to the right.
          for (var i = behind; i >= 1; i--)
            Positioned(
              left: off * i,
              top: off * (behind - i),
              child: thumb(i),
            ),
          Positioned(left: 0, top: off * behind, child: thumb(0)),
        ],
      ),
    );
  }
}