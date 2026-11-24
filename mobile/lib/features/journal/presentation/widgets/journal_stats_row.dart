import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/text/date_formats.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/context_extensions.dart';
import '../../../../core/theme/tokens/anchor_tokens.dart';
import '../../../../l10n/l10n.dart';
import '../../domain/journal_day.dart';
import '../../domain/journal_stats.dart';

/// The two headline tiles above the journal's entries.
///
/// **Today** is always shown, with a streak badge when there is a run of at
/// least two consecutive entry days. **Throwback** is shown only when a prior
/// year has an entry on today's month-day: it names the day's entry count and
/// how many years ago it was written.
class JournalStatsRow extends StatelessWidget {
  const JournalStatsRow({super.key, required this.days});

  final List<JournalDay> days;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final streak = journalStreakOf(days, now);
    final throwback = journalThrowbackOf(days, now);

    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        4,
        16,
        14,
      ), // off-scale: design tile row padding
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _StatTile(
                key: const ValueKey('journal-tile-today'),
                icon: LucideIcons.bookmark,
                title: l10n.commonToday,
                meta: DateFormat('EEE, MMM d', dateLocale).format(now),
                badge: streak == null ? null : l10n.journalStatDays(streak),
                badgeIcon: LucideIcons.flame,
              ),
            ),
            if (throwback != null) ...[
              const SizedBox(
                width: AnchorTokens.space10,
              ), // off-scale: design tile gap 10
              Expanded(
                child: _StatTile(
                  key: const ValueKey('journal-tile-throwback'),
                  icon: LucideIcons.history,
                  title: l10n.journalThrowback,
                  meta: l10n.journalStatYearsAgo(now.year - throwback.year),
                  badge: l10n.journalEntriesCount(throwback.entryCount),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One headline tile: an icon circle and an optional badge up top, the title
/// and a muted sub line at the bottom.
class _StatTile extends StatelessWidget {
  const _StatTile({
    super.key,
    required this.icon,
    required this.title,
    required this.meta,
    this.badge,
    this.badgeIcon,
  });

  final IconData icon;
  final String title;
  final String meta;
  final String? badge;
  final IconData? badgeIcon;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    final accent = colors.accentStrong;

    return Container(
      constraints: const BoxConstraints(
        minHeight: 92, // off-scale: design tile height 92
      ),
      decoration: BoxDecoration(
        color: colors.appSurface,
        borderRadius: BorderRadius.circular(AnchorTokens.radius2xl),
        border: Border.all(color: colors.appBorder),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: AnchorTokens.space14, // off-scale: design tile padding 14
        vertical: AnchorTokens.space12,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: AnchorTokens.sizeToolbarButtonHeight,
                height: AnchorTokens.sizeToolbarButtonHeight,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.16),
                ),
                child: Icon(
                  icon,
                  size: AnchorTokens.sizeIconSmall,
                  color: accent,
                ),
              ),
              if (badge != null)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.density.space8,
                    vertical: 2, // off-scale: design badge padding 2
                  ),
                  decoration: BoxDecoration(
                    color: colors.appText.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(
                      AnchorTokens.radiusPill,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (badgeIcon != null)
                        Icon(
                          badgeIcon!,
                          size: 12, // off-scale: design badge icon 12
                          color: accent,
                        ),
                      if (badgeIcon != null) const SizedBox(width: 4),
                      Text(
                        badge!,
                        style: AppTypography.caption
                            .copyWith(
                              fontWeight: FontWeight.w700,
                              color: colors.appText,
                            )
                            .tabular,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.secondary.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.appText,
                ),
              ),
              const SizedBox(height: 2), // off-scale: design tile line gap 2
              Text(
                meta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(color: colors.appMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
