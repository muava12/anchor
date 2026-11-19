import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/motion/haptics.dart';
import '../../../core/motion/springs.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/context_extensions.dart';
import '../../../core/theme/tokens/anchor_tokens.dart';
import '../../../core/widgets/anchor_sheet.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/pressable.dart';
import '../../../l10n/l10n.dart';
import '../data/reminder_snooze.dart';
import '../domain/reminder_times.dart';
import 'month_grid.dart';
import 'time_wheel.dart';

/// The snooze sheet: pick a duration or a custom date and time.
///
/// Returns the chosen minutes, or null if the person dismissed the sheet.
Future<int?> showSnoozeSheet(
  BuildContext context, {
  required bool recurring,
  required Future<void> Function(int minutes) onSnooze,
  int? latestMinutes,
}) {
  return showAnchorSheet<int>(
    context,
    semanticLabel: context.l10n.snoozeSheetTitle,
    builder: (_) => _SnoozeSheet(
      recurring: recurring,
      onSnooze: onSnooze,
      latestMinutes: latestMinutes,
    ),
  );
}

enum _Picker { date, time }

class _SnoozeSheet extends StatefulWidget {
  const _SnoozeSheet({
    required this.recurring,
    required this.onSnooze,
    this.latestMinutes,
  });

  final bool recurring;
  final Future<void> Function(int minutes) onSnooze;
  final int? latestMinutes;

  @override
  State<_SnoozeSheet> createState() => _SnoozeSheetState();
}

class _SnoozeSheetState extends State<_SnoozeSheet> {
  final _pickerKey = GlobalKey();
  _Picker? _openPicker;
  DateTime? _customAt;
  late DateTime _month;
  late final List<int> _durations;

  @override
  void initState() {
    super.initState();
    _durations = snoozeDurations(recurring: widget.recurring);
    final now = DateTime.now();
    _customAt = tomorrowAtNine(now);
    _month = DateTime(_customAt!.year, _customAt!.month);
  }

  void _pickCustom() {
    Haptics.selection();
    setState(() {
      _openPicker = _openPicker == null ? _Picker.date : null;
      if (_openPicker != null) {
        Timer(const Duration(milliseconds: 120), () {
          final target = _pickerKey.currentContext;
          if (target != null && target.mounted) {
            Scrollable.ensureVisible(
              target,
              duration: context.motion(AnchorTokens.motionDurationFade),
              curve: Curves.easeOut,
              alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
            );
          }
        });
      }
    });
  }

  void _pickDay(DateTime day) {
    Haptics.selection();
    final base = _customAt ?? tomorrowAtNine(DateTime.now());
    setState(() {
      _customAt = DateTime(
        day.year,
        day.month,
        day.day,
        base.hour,
        base.minute,
      );
      _openPicker = _Picker.time;
    });
  }

  Future<void> _chooseDuration(int minutes) async {
    await widget.onSnooze(minutes);
    if (mounted) Navigator.of(context).pop(minutes);
  }

  Future<void> _chooseCustom() async {
    final at = _customAt;
    if (at == null) return;
    final now = DateTime.now();
    final minutes = at.difference(now).inMinutes;
    if (minutes <= 0) return;
    await widget.onSnooze(minutes);
    if (mounted) Navigator.of(context).pop(minutes);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    final l10n = context.l10n;
    final now = DateTime.now();
    final latest = widget.latestMinutes;
    final showLatest = latest != null && _durations.contains(latest);
    final laterToday = roundUpToFive(now.add(const Duration(hours: 3)));
    final hasLaterToday = laterToday.day == now.day;
    final tomorrow = tomorrowAtNine(now);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(
          title: l10n.snoozeSheetTitle,
          subtitle: l10n.snoozeSheetSubtitle,
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: context.density.space16,
              children: [
                // Duration chips: 10, 30, 60, 240, (1440 for repeating)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final minutes in _durations)
                      _DurationChip(
                        key: ValueKey('snooze_minutes_$minutes'),
                        label: snoozeDurationLabel(minutes, l10n),
                        isRecommended: minutes == latest,
                        onTap: () => _chooseDuration(minutes),
                      ),
                  ],
                ),

                // Suggested quick choices
                if (hasLaterToday ||
                    showLatest ||
                    tomorrow.isBefore(now.add(const Duration(days: 1)))) ...[
                  Text(
                    l10n.commonToday,
                    style: AppTypography.secondary.copyWith(
                      color: colors.appMuted,
                    ),
                  ),
                  Column(
                    spacing: context.density.space8,
                    children: [
                      if (hasLaterToday)
                        _SuggestionTile(
                          icon: LucideIcons.clock,
                          label: l10n.snoozeSuggestionLaterToday,
                          onTap: () {
                            final minutes = laterToday
                                .difference(now)
                                .inMinutes;
                            _chooseDuration(minutes);
                          },
                        ),
                      if (tomorrow.isAfter(now))
                        _SuggestionTile(
                          icon: LucideIcons.sunrise,
                          label: l10n.snoozeSuggestionTomorrow,
                          onTap: () {
                            final minutes = tomorrow.difference(now).inMinutes;
                            _chooseDuration(minutes);
                          },
                        ),
                    ],
                  ),
                ],

                // Custom date and time
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: context.density.space8,
                  children: [
                    _SuggestionTile(
                      icon: LucideIcons.calendarClock,
                      label: l10n.snoozeCustomDate,
                      onTap: _pickCustom,
                    ),
                    if (_openPicker != null)
                      Padding(
                        key: _pickerKey,
                        padding: EdgeInsets.only(top: context.density.space8),
                        child: AnimatedSwitcher(
                          duration: context.motion(
                            AnchorTokens.motionDurationFade,
                          ),
                          child: switch (_openPicker) {
                            _Picker.date => MonthGrid(
                              key: const ValueKey('date'),
                              month: _month,
                              selected: _customAt,
                              now: now,
                              onDay: _pickDay,
                              onMonth: (m) => setState(() => _month = m),
                            ),
                            _Picker.time => TimeWheel(
                              key: const ValueKey('time'),
                              at: _customAt ?? tomorrow,
                              onChanged: (t) => setState(() {
                                final day = _customAt ?? tomorrow;
                                _customAt = DateTime(
                                  day.year,
                                  day.month,
                                  day.day,
                                  t.hour,
                                  t.minute,
                                );
                              }),
                            ),
                            null => const SizedBox.shrink(),
                          },
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        SheetFooter(
          children: [
            AppButton(
              label: l10n.commonCancel,
              kind: AppButtonKind.secondary,
              onPressed: () => Navigator.of(context).pop(),
            ),
            if (_openPicker != null)
              AppButton(label: l10n.commonSave, onPressed: _chooseCustom),
          ],
        ),
      ],
    );
  }
}

class _DurationChip extends StatelessWidget {
  const _DurationChip({
    super.key,
    required this.label,
    required this.onTap,
    this.isRecommended = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool isRecommended;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    return Pressable(
      style: PressStyle.button,
      onTap: () {
        Haptics.selection();
        onTap();
      },
      semanticLabel: label,
      child: AnimatedContainer(
        duration: context.motion(AnchorTokens.motionDurationHover),
        constraints: const BoxConstraints(
          minHeight: AnchorTokens.sizeControlSmall,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isRecommended
              ? colors.appText.withValues(alpha: 0.12)
              : colors.appText.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(AnchorTokens.radiusPill),
        ),
        child: Text(
          label,
          style: AppTypography.secondary.tabular.copyWith(
            color: colors.appText,
            fontWeight: isRecommended ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    return Pressable(
      style: PressStyle.button,
      onTap: () {
        Haptics.selection();
        onTap();
      },
      semanticLabel: label,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: context.density.space16,
          vertical: context.density.space12,
        ),
        decoration: BoxDecoration(
          color: colors.appText.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(AnchorTokens.radiusTile),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: AnchorTokens.sizeIconSmall,
              color: colors.appMuted,
            ),
            SizedBox(width: context.density.space12),
            Expanded(
              child: Text(
                label,
                style: AppTypography.row.copyWith(color: colors.appText),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
