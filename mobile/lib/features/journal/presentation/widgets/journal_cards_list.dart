import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/context_extensions.dart';
import '../../../../core/theme/tokens/anchor_tokens.dart';
import '../../../notes/domain/note.dart';
import '../../../tags/domain/tag.dart';
import '../../../tags/presentation/tags_controller.dart';
import '../../domain/journal_day.dart';
import '../journal_entry_text.dart';
import 'journal_day_card.dart';

/// The journal's entries as day-grouped cards, a sliver for a
/// [CustomScrollView].
///
/// Each day gets a centred separator, then one [JournalDayCard] with its
/// entries in chronological order.
class JournalCardsList extends ConsumerWidget {
  const JournalCardsList({
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
    final allTags = ref.watch(tagsControllerProvider).value ?? const <Tag>[];

    return SliverList(
      delegate: SliverChildListDelegate([
        for (final day in days) ...[
          _DaySeparator(day: day),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: JournalDayCard(
              day: day,
              tags: allTags,
              journalTagId: journalTagId,
              onOpen: onOpen,
            ),
          ),
        ],
      ]),
    );
  }
}

/// "November 19, 2026 · Thu", centred between two day cards.
class _DaySeparator extends StatelessWidget {
  const _DaySeparator({required this.day});

  final JournalDay day;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Center(
        child: Text(
          journalDaySeparator(day.day),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AnchorTokens.typeMeta.copyWith(
            fontFamily: AppTypography.sans,
            fontFamilyFallback: AppTypography.sansFallback,
            fontWeight: FontWeight.w500,
            color: colors.appMuted,
          ),
        ),
      ),
    );
  }
}
