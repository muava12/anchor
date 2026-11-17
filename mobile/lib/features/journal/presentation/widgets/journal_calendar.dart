import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/text/date_formats.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/context_extensions.dart';
import '../../../../core/theme/tokens/anchor_tokens.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../notes/domain/note_dates.dart';

/// A month grid in a card: navigation, weekdays, and a dot on days that have
/// an entry.
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
    final density = context.density;
    final today = DateTime.now();
    final first = DateTime(month.year, month.month, 1);
    // The Monday of the week that holds the 1st, then six full weeks.
    final start = first.subtract(Duration(days: first.weekday - 1));
    DateTime dayAt(int i) => start.add(Duration(days: i));

    return Padding(
      padding: EdgeInsets.fromLTRB(16, density.space8, 16, density.space8),
      child: Container(
        decoration: BoxDecoration(
          color: colors.appSurface,
          borderRadius: BorderRadius.circular(AnchorTokens.radiusCard),
          border: Border.all(color: colors.appBorder),
        ),
        padding: EdgeInsets.all(density.space16),
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
                    child: Text(
                      DateFormat.yMMMM(dateLocale).format(month),
                      style: AppTypography.serifText(
                        fontSize: AnchorTokens.typeLargeTitle.fontSize,
                        fontWeight: FontWeight.w700,
                        color: colors.appText,
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
            SizedBox(height: density.space16),
            Row(
              children: [
                for (final label in _weekdays)
                  Expanded(
                    child: Center(
                      child: Text(
                        label,
                        style: AppTypography.label.copyWith(
                          color: colors.appMuted,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: density.space8),
            GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisExtent: AnchorTokens.sizeRow, // same in Compact: a grid row
              ),
              children: [
                for (var i = 0; i < 42; i++)
                  _DayCell(
                    date: dayAt(i),
                    month: month,
                    isEntry: entryDays.any((e) => isSameDay(e, dayAt(i))),
                    isSelected:
                        selectedDay != null && isSameDay(selectedDay!, dayAt(i)),
                    isToday: isSameDay(today, dayAt(i)),
                    onPick: onPickDay,
                  ),
              ],
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
        width: AnchorTokens.sizeTargetPhone,
        height: AnchorTokens.sizeTargetPhone,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.appPage,
        ),
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
    required this.month,
    required this.isEntry,
    required this.isSelected,
    required this.isToday,
    required this.onPick,
  });

  final DateTime date;
  final DateTime month;
  final bool isEntry;
  final bool isSelected;
  final bool isToday;
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
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: AnchorTokens.sizeTargetPhone,
          height: AnchorTokens.sizeTargetPhone,
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
            style: AppTypography.row.copyWith(
              color: isSelected
                  ? colors.appOnInverse
                  : _inMonth
                  ? colors.appText
                  : colors.appMuted,
            ),
          ),
        ),
        if (_inMonth && isEntry)
          Container(
            key: const ValueKey('journal-entry-dot'),
            width: 4,
            height: 4,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.accentStrong,
            ),
          ),
      ],
    );

    // A day from the month beside this one is shown, but not picked here.
    if (!_inMonth) return IgnorePointer(key: key, child: content);
    return GestureDetector(
      key: key,
      behavior: HitTestBehavior.opaque,
      onTap: () => onPick(date),
      child: content,
    );
  }
}