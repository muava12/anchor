import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/text/date_formats.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/context_extensions.dart';
import '../../../../core/theme/tokens/anchor_tokens.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../l10n/l10n.dart';
import '../../../notes/domain/note_dates.dart';
import '../../domain/journal_day.dart';

/// A month grid in a card: the days are shaded by how many entries they hold,
/// with a footer that counts the month and legends the scale.
class JournalCalendar extends StatelessWidget {
  const JournalCalendar({
    super.key,
    required this.month,
    required this.entryCounts,
    this.selectedDay,
    this.now,
    required this.onPickDay,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  /// The first day of the displayed month.
  final DateTime month;

  /// Every day's journal entry count, unfiltered by the search query.
  final Map<DateTime, int> entryCounts;
  final DateTime? selectedDay;

  /// What "today" is; the real clock when left out.
  final DateTime? now;

  final ValueChanged<DateTime> onPickDay;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  static const _weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  /// The heat alphas: none, one entry, two or more.
  static const _heatAlpha = [0.0, 0.14, 0.28];

  Color _tint(int level, AnchorColors colors) =>
      colors.accentStrong.withValues(alpha: _heatAlpha[level]);

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    final today = now ?? DateTime.now();
    final first = DateTime(month.year, month.month, 1);
    // The Monday of the week that holds the 1st, then six full weeks.
    final start = first.subtract(Duration(days: first.weekday - 1));
    DateTime dayAt(int i) => start.add(Duration(days: i));
    final monthEntries = entryCounts.entries
        .where((e) => e.key.year == month.year && e.key.month == month.month)
        .fold(0, (sum, e) => sum + e.value);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        AnchorTokens.space10, // off-scale: design card margin 10
        16,
        AnchorTokens.space6, // off-scale: design card margin 6
      ),
      child: Container(
        decoration: BoxDecoration(
          color: colors.appSurface,
          borderRadius: BorderRadius.circular(
            AnchorTokens.radius3xl,
          ), // off-scale: design card radius 20
          border: Border.all(color: colors.appBorder),
          boxShadow: colors.shadowRaised,
        ),
        padding: const EdgeInsets.fromLTRB(
          AnchorTokens.space14, // off-scale: design card padding 14
          AnchorTokens.space14, // off-scale: design card padding 14
          AnchorTokens.space14, // off-scale: design card padding 14
          AnchorTokens.space12,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _NavButton(
                  id: 'prev',
                  icon: LucideIcons.chevronLeft,
                  onTap: onPreviousMonth,
                ),
                Expanded(
                  child: Center(
                    child: Text.rich(
                      key: const ValueKey('calendar-month'),
                      TextSpan(
                        children: [
                          TextSpan(
                            text: DateFormat('MMMM', dateLocale).format(month),
                            style: AnchorTokens.typeHeading.copyWith(
                              fontFamily: AppTypography.sans,
                              fontFamilyFallback: AppTypography.sansFallback,
                              color: colors.appText,
                            ),
                          ),
                          TextSpan(
                            text: ' ${month.year}',
                            style: AnchorTokens.typeLabel.copyWith(
                              fontFamily: AppTypography.sans,
                              fontFamilyFallback: AppTypography.sansFallback,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0,
                              color: colors.appMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                _NavButton(
                  id: 'next',
                  icon: LucideIcons.chevronRight,
                  onTap: onNextMonth,
                ),
              ],
            ),
            SizedBox(
              height: AnchorTokens.space10, // off-scale: design nav gap 10
            ),
            Row(
              children: [
                for (final label in _weekdays)
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          label,
                          style: AnchorTokens.typeCaption.copyWith(
                            fontFamily: AppTypography.sans,
                            fontFamilyFallback: AppTypography.sansFallback,
                            fontWeight: FontWeight.w600,
                            letterSpacing:
                                0.72, // off-scale: design label tracking
                            color: colors.appMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AnchorTokens.space4),
            GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1,
                mainAxisSpacing: 4,
                crossAxisSpacing: 3, // off-scale: design column gap 3
              ),
              children: [
                for (var i = 0; i < 42; i++)
                  _DayCell(
                    date: dayAt(i),
                    month: month,
                    count: entryCounts[dayAt(i)] ?? 0,
                    isSelected:
                        selectedDay != null &&
                        isSameDay(selectedDay!, dayAt(i)),
                    isToday: isSameDay(today, dayAt(i)),
                    tintOf: (level) => _tint(level, colors),
                    onPick: onPickDay,
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(
                top: AnchorTokens.space12,
                // off-scale: design legend padding 12
              ),
              child: Column(
                children: [
                  Container(height: 1, color: colors.appBorder),
                  Padding(
                    padding: const EdgeInsets.only(
                      top: AnchorTokens
                          .space10, // off-scale: design legend padding 10
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.l10n.journalMonthEntries(monthEntries),
                            style: AppTypography.caption.copyWith(
                              color: colors.appMuted,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _HeatLegend(
                          colors: colors,
                          less: context.l10n.journalCalendarLess,
                          more: context.l10n.journalCalendarMore,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.id, required this.icon, required this.onTap});

  final String id;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    return Pressable(
      style: PressStyle.plain,
      onTap: onTap,
      semanticLabel: id,
      child: Container(
        width: AnchorTokens.sizeControlSmall,
        height: AnchorTokens.sizeControlSmall,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.appText.withValues(alpha: 0.07),
        ),
        child: Center(
          child: Icon(
            key: ValueKey('calendar-$id'),
            icon,
            size: AnchorTokens.sizeIconMedium,
            color: colors.appText,
          ),
        ),
      ),
    );
  }
}

/// The heat scale: an empty swatch, the two levels, with "Less" / "More".
class _HeatLegend extends StatelessWidget {
  const _HeatLegend({
    required this.colors,
    required this.less,
    required this.more,
  });

  final AnchorColors colors;
  final String less;
  final String more;

  @override
  Widget build(BuildContext context) {
    // Swatch 0 is the "no entries" surface: a faint text tint.
    final swatches = [
      colors.appText.withValues(alpha: 0.08),
      colors.accentStrong.withValues(alpha: 0.14),
      colors.accentStrong.withValues(alpha: 0.28),
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          less,
          style: AppTypography.caption.copyWith(color: colors.appMuted),
        ),
        const SizedBox(width: 4),
        for (var i = 0; i < swatches.length; i++)
          Container(
            key: ValueKey('journal-heat-$i'),
            width: 12,
            height: 12,
            margin: const EdgeInsets.symmetric(
              horizontal: AnchorTokens.space2,
            ), // off-scale: heat swatch gap
            decoration: BoxDecoration(
              color: swatches[i],
              borderRadius: BorderRadius.circular(4), // off-scale: heat swatch
            ),
          ),
        const SizedBox(width: 4),
        Text(
          more,
          style: AppTypography.caption.copyWith(color: colors.appMuted),
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.month,
    required this.count,
    required this.isSelected,
    required this.isToday,
    required this.tintOf,
    required this.onPick,
  });

  final DateTime date;
  final DateTime month;
  final int count;
  final bool isSelected;
  final bool isToday;
  final Color Function(int level) tintOf;
  final ValueChanged<DateTime> onPick;

  bool get _inMonth => date.year == month.year && date.month == month.month;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    final number = date.day;
    final key = ValueKey(
      'calendar-day-${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${number.toString().padLeft(2, '0')}',
    );
    final level = heatLevelOf(_inMonth ? count : 0);
    final background = isSelected ? colors.accentStrong : tintOf(level);
    final ringToday = isToday && !isSelected;
    final cell = Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(
          AnchorTokens.radiusXl,
        ), // off-scale: design cell radius 14
        border: ringToday
            ? Border.all(color: colors.accentStrong, width: 1.5)
            : null,
        boxShadow: isSelected ? colors.shadowControl : null,
      ),
      child: Center(
        child: Text(
          '$number',
          style: AppTypography.secondary
              .copyWith(
                fontWeight: isSelected
                    ? FontWeight.w700
                    : level == 2
                    ? FontWeight.w600
                    : FontWeight.w400,
                color: isSelected
                    ? colors.appOnInverse
                    : _inMonth
                    ? colors.appText
                    : colors.appMuted,
              )
              .tabular,
        ),
      ),
    );

    // A day from the month beside this one is shown, but not picked here.
    Widget cellWidget = IgnorePointer(key: key, child: cell);
    if (_inMonth) {
      cellWidget = GestureDetector(
        key: key,
        behavior: HitTestBehavior.opaque,
        onTap: () => onPick(date),
        child: cell,
      );
    }
    if (!isSelected) {
      cellWidget = Opacity(opacity: _inMonth ? 1 : 0.4, child: cellWidget);
    }
    if (ringToday) {
      cellWidget = KeyedSubtree(
        key: const ValueKey('calendar-today-ring'),
        child: cellWidget,
      );
    }
    return cellWidget;
  }
}
