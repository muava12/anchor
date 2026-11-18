import 'package:flutter/material.dart';

import '../../../../core/theme/tokens/anchor_tokens.dart';
import '../../../../core/widgets/anchor_sheet.dart';
import '../../../../core/widgets/app_buttons.dart';
import '../../../../l10n/l10n.dart';
import '../../../reminders/presentation/month_grid.dart';
import '../../../reminders/presentation/time_wheel.dart';

/// Shows the journal date & time sheet: the month grid picks the day, the
/// time wheel picks the hour and minute. Returns the picked date & time,
/// or null when the sheet is cancelled.
Future<DateTime?> showJournalDateTimeSheet(
  BuildContext context, {
  required DateTime initial,
}) {
  return showAnchorSheet<DateTime>(
    context,
    semanticLabel: context.l10n.journalDateTimeTitle,
    builder: (sheet) => _JournalDateTimeSheet(initial: initial),
  );
}

class _JournalDateTimeSheet extends StatefulWidget {
  const _JournalDateTimeSheet({required this.initial});

  final DateTime initial;

  @override
  State<_JournalDateTimeSheet> createState() => _JournalDateTimeSheetState();
}

class _JournalDateTimeSheetState extends State<_JournalDateTimeSheet> {
  /// The month the grid shows, without a day.
  late DateTime _month;

  /// The picked day, at midnight.
  late DateTime _day;

  /// The picked date & time, kept whole.
  late DateTime _at;

  @override
  void initState() {
    super.initState();
    _month = DateTime(widget.initial.year, widget.initial.month);
    _day = DateTime(
      widget.initial.year,
      widget.initial.month,
      widget.initial.day,
    );
    _at = widget.initial;
  }

  void _pickDay(DateTime day) {
    setState(() {
      _day = DateTime(day.year, day.month, day.day);
      _at = DateTime(day.year, day.month, day.day, _at.hour, _at.minute);
    });
  }

  void _pickTime(DateTime time) {
    setState(() {
      _at = DateTime(_day.year, _day.month, _day.day, time.hour, time.minute);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(title: l10n.journalDateTimeTitle),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: MonthGrid(
            month: _month,
            selected: _day,
            now: DateTime.now(),
            onDay: _pickDay,
            onMonth: (month) => setState(() => _month = month),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: AnchorTokens.space8,
          ),
          child: TimeWheel(at: _at, onChanged: _pickTime),
        ),
        SheetFooter(
          children: [
            AppButton(
              label: l10n.commonCancel,
              kind: AppButtonKind.secondary,
              onPressed: () => Navigator.of(context).pop(),
            ),
            AppButton(
              label: l10n.commonSave,
              onPressed: () => Navigator.of(context).pop(_at),
            ),
          ],
        ),
      ],
    );
  }
}