import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/text/date_formats.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/context_extensions.dart';
import '../../../../core/theme/tokens/anchor_tokens.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../notes/domain/note_dates.dart';

/// A month grid with a dot under days that have an entry.
class JournalCalendar extends StatelessWidget {
  const JournalCalendar({
    super.key,
    required this.month,
    required this.entryDays,
    this.selectedDay,
    required this.onPickDay,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  /// The first day of the displayed month.
  final DateTime month;
  final Set<DateTime> entryDays;
  final DateTime? selectedDay;
  final ValueChanged<DateTime> onPickDay;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  static const _weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    final dayCount = DateTime(month.year, month.month + 1, 0).day;
    final leadingBlanks = DateTime(month.year, month.month, 1).weekday - 1;
    final today = DateTime.now();

    final cells = <Widget>[
      for (var i = 0; i < leadingBlanks; i++) const SizedBox.shrink(),
      for (var d = 1; d <= dayCount; d++)
        _DayCell(
          date: DateTime(month.year, month.month, d),
          isEntry: entryDays.any((e) => isSameDay(e, dateOf(month.year, month.month, d))),
          isSelected: selectedDay != null && isSameDay(selectedDay!, dateOf(month.year, month.month, d)),
          isToday: isSameDay(today, dateOf(month.year, month.month, d)),
          onPick: onPickDay,
        ),
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        context.density.space8,
        16,
        context.density.space8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _NavButton(id: 'prev', icon: LucideIcons.chevronLeft, onTap: onPreviousMonth),
              Expanded(
                child: Center(
                  child: Text(
                    DateFormat.yMMMM(dateLocale).format(month),
                    style: AppTypography.secondary.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.appText,
                    ),
                  ),
                ),
              ),
              _NavButton(id: 'next', icon: LucideIcons.chevronRight, onTap: onNextMonth),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final label in _weekdays)
                Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: AppTypography.footnote.copyWith(color: colors.appMuted),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent: 48,
            ),
            children: cells,
          ),
        ],
      ),
    );
  }
}

DateTime dateOf(int year, int month, int day) => DateTime(year, month, day);

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
      child: SizedBox(
        width: 40, // off-scale: seven cells fit the phone
        height: 40, // off-scale: seven cells fit the phone
        child: Center(
          child: Icon(
            key: ValueKey('calendar-$id'),
            icon,
            size: AnchorTokens.sizeIconMedium,
            color: colors.appMuted,
          ),
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.isEntry,
    required this.isSelected,
    required this.isToday,
    required this.onPick,
  });

  final DateTime date;
  final bool isEntry;
  final bool isSelected;
  final bool isToday;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    final number = date.day;
    final key = ValueKey(
      'calendar-day-${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${number.toString().padLeft(2, '0')}',
    );
    return GestureDetector(
      key: key,
      behavior: HitTestBehavior.opaque,
      onTap: () => onPick(date),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? colors.accentStrong : null,
              border: isToday && !isSelected
                  ? Border.all(color: colors.accentStrong, width: 1.5)
                  : null,
            ),
            child: Text(
              '$number',
              style: AppTypography.footnote.copyWith(
                color: isSelected
                    ? colors.appOnInverse
                    : colors.appText,
              ),
            ),
          ),
          const SizedBox(height: 2),
          isEntry
              ? Container(
                  key: const ValueKey('journal-entry-dot'),
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.accentStrong,
                  ),
                )
              : const SizedBox(width: 4, height: 4),
        ],
      ),
    );
  }
}
