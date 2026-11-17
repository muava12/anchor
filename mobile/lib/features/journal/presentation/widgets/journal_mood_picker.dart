import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/motion/springs.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/context_extensions.dart';
import '../../../../core/theme/tokens/anchor_tokens.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../l10n/l10n.dart';
import '../../domain/journal_meta.dart';

/// The four journal moods, chosen above the keyboard.
class JournalMoodPicker extends StatelessWidget {
  const JournalMoodPicker({
    required this.selected,
    required this.onPick,
    required this.onClose,
  });

  final JournalMood? selected;
  final ValueChanged<JournalMood> onPick;
  final VoidCallback onClose;

  static String labelOf(JournalMood mood, AppLocalizations l10n) =>
      switch (mood) {
        JournalMood.amazing => l10n.journalMoodAmazing,
        JournalMood.good => l10n.journalMoodGood,
        JournalMood.neutral => l10n.journalMoodNeutral,
        JournalMood.rough => l10n.journalMoodRough,
      };

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.appSurface,
        borderRadius: BorderRadius.circular(AnchorTokens.radiusXl),
        border: Border.all(color: colors.appBorder),
        boxShadow: colors.shadowDialog,
      ),
      child: Padding(
        padding: EdgeInsets.all(context.density.space16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  context.l10n.journalMood,
                  style: AppTypography.secondary.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.appMuted,
                  ),
                ),
                const Spacer(),
                Pressable(
                  style: PressStyle.plain,
                  onTap: onClose,
                  semanticLabel: context.l10n.commonCancel,
                  child: Icon(
                    LucideIcons.x,
                    size: AnchorTokens.sizeIconSmall,
                    color: colors.appMuted,
                  ),
                ),
              ],
            ),
            SizedBox(height: context.density.space12),
            Row(
              children: [
                for (final mood in JournalMood.values)
                  Expanded(
                    child: _MoodOption(
                      mood: mood,
                      isSelected: mood == selected,
                      label: labelOf(mood, context.l10n),
                      onTap: () => onPick(mood),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MoodOption extends StatelessWidget {
  const _MoodOption({
    required this.mood,
    required this.isSelected,
    required this.label,
    required this.onTap,
  });

  final JournalMood mood;
  final bool isSelected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    return Pressable(
      style: PressStyle.plain,
      onTap: onTap,
      semanticLabel: label,
      child: Column(
        children: [
          AnimatedContainer(
            duration: context.motion(AnchorTokens.motionDurationHover),
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? colors.appPage : null,
              border: Border.all(
                color: isSelected ? colors.accentStrong : colors.appBorder,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Text(mood.emoji, style: const TextStyle(fontSize: 22)),
          ),
          SizedBox(height: context.density.space8),
          Text(
            label,
            style: AppTypography.footnote.copyWith(
              color: colors.appText,
              fontWeight:
                  isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
