import 'package:flutter/material.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/context_extensions.dart';
import '../../../../core/theme/tokens/anchor_tokens.dart';
import '../../../../l10n/l10n.dart';
import '../../domain/journal_day.dart';

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
    final stats = _Stats.of(days, DateTime.now());
    if (stats == null) return const SizedBox.shrink();

    final l10n = context.l10n;
    final cards = <Widget>[
      if (stats.onThisDay)
        _StatCard(
          icon: _StatIcon.history,
          label: l10n.journalStatOnThisDay,
        ),
      if (stats.streak != null)
        _StatCard(
          icon: _StatIcon.streak,
          label: l10n.journalStatStreak(stats.streak!),
        ),
      if (stats.throwbackYear != null)
        _StatCard(
          icon: _StatIcon.throwback,
          label: l10n.journalStatThrowback('${stats.throwbackYear}'),
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
              _StatIcon.history => Icons.history,
              _StatIcon.streak => Icons.local_fire_department,
              _StatIcon.throwback => Icons.replay,
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

/// The three trigger computations, evaluated once per build.
class _Stats {
  const _Stats({
    required this.onThisDay,
    required this.streak,
    required this.throwbackYear,
  });

  /// An entry exists on today's month-day in a prior year.
  final bool onThisDay;

  /// Length of the consecutive-days run ending today or yesterday, or null
  /// when fewer than two days qualify.
  final int? streak;

  /// The most recent prior year (not the current one) with an entry on
  /// today's month-day.
  final int? throwbackYear;

  static _Stats? of(List<JournalDay> days, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final todayMonth = now.month;
    final todayDay = now.day;

    // Distinct entry days, as local midnights, for fast lookup.
    final entryDays = <DateTime>{for (final day in days) day.day};

    // On this day: any entry day in a prior year with the same month-day.
    final onThisDay = entryDays.any(
      (day) =>
          day.year < now.year &&
          day.month == todayMonth &&
          day.day == todayDay,
    );

    // Throwback: the most recent prior year with today's month-day.
    int? throwbackYear;
    for (final day in entryDays) {
      if (day.year >= now.year) continue;
      if (day.month != todayMonth || day.day != todayDay) continue;
      if (throwbackYear == null || day.year > throwbackYear) {
        throwbackYear = day.year;
      }
    }

    // Streak: consecutive entry days ending today or yesterday.
    var anchor = entryDays.contains(today)
        ? today
        : (entryDays.contains(DateTime(now.year, now.month, now.day - 1))
              ? DateTime(now.year, now.month, now.day - 1)
              : null);
    int? streak;
    if (anchor != null) {
      var length = 0;
      var cursor = anchor;
      while (entryDays.contains(cursor)) {
        length++;
        cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
      }
      if (length >= 2) streak = length;
    }

    if (!onThisDay && streak == null && throwbackYear == null) return null;
    return _Stats(
      onThisDay: onThisDay,
      streak: streak,
      throwbackYear: throwbackYear,
    );
  }
}