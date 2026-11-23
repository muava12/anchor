import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/context_extensions.dart';
import '../../../../core/theme/tokens/anchor_tokens.dart';
import '../../../../l10n/l10n.dart';
import '../../domain/journal_day.dart';
import '../../domain/journal_stats.dart';

/// The timeline's headline stats: a row of up to three cards, each shown only
/// when its data exists.
///
/// - **On this day** — at least one entry on today's month-day in a prior year.
/// - **N-day streak** — at least two consecutive entry days ending today or
///   yesterday.
/// - **Throwback · year** — the most recent prior year with an entry on
///   today's month-day.
///
/// When no stat applies the row collapses to nothing, so it never leaves a
/// gap in the timeline.
class JournalStatsRow extends StatelessWidget {
  const JournalStatsRow({super.key, required this.days});

  final List<JournalDay> days;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final streak = journalStreakOf(days, now);
    final throwback = journalThrowbackOf(days, now);
    if (throwback == null && streak == null) return const SizedBox.shrink();

    final l10n = context.l10n;
    final cards = <Widget>[
      if (throwback != null)
        _StatCard(icon: _StatIcon.history, label: l10n.journalStatOnThisDay),
      if (streak != null)
        _StatCard(
          icon: _StatIcon.streak,
          label: l10n.journalStatStreak(streak!),
        ),
      if (throwback != null)
        _StatCard(
          icon: _StatIcon.throwback,
          label: l10n.journalStatThrowback('${throwback.year}'),
        ),
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        context.density.space8,
        16,
        context.density.space8,
      ),
      child: Row(
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) SizedBox(width: context.density.space8),
            Expanded(child: cards[i]),
          ],
        ],
      ),
    );
  }
}

enum _StatIcon { history, streak, throwback }

/// One labelled tile: a coloured memory tile with a caption under it.
class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.label});

  final _StatIcon icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    final tile = AnchorTokens.sizeJournalStatTile;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: tile,
          height: tile,
          decoration: BoxDecoration(
            color: colors.accentStrong.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(AnchorTokens.radiusTile),
          ),
          child: Icon(
            switch (icon) {
              _StatIcon.history => LucideIcons.history,
              _StatIcon.streak => LucideIcons.flame,
              _StatIcon.throwback => LucideIcons.rotateCcw,
            },
            size: AnchorTokens.sizeIconMedium,
            color: colors.accentStrong,
          ),
        ),
        SizedBox(height: context.density.space8),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.footnote.copyWith(
            fontWeight: FontWeight.w600,
            color: colors.appText,
          ),
        ),
      ],
    );
  }
}
