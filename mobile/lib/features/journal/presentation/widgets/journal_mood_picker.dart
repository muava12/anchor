import 'package:flutter/material.dart';

import '../../../../core/motion/springs.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/context_extensions.dart';
import '../../../../core/theme/tokens/anchor_tokens.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../l10n/l10n.dart';
import '../../domain/journal_meta.dart';

/// The journal moods, as a row of cards above the keyboard.
class JournalMoodPicker extends StatelessWidget {
  const JournalMoodPicker({
    super.key,
    required this.selected,
    required this.onPick,
  });

  final JournalMood? selected;
  final ValueChanged<JournalMood> onPick;

  /// The label shown on a mood card. Localized strings land with the mood
  /// faces (later task); until then the mood name is shown capitalized.
  static String labelOf(JournalMood mood, AppLocalizations l10n) =>
      '${mood.name[0].toUpperCase()}${mood.name.substring(1)}';

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    final selectedTint = colors.accentStrong.withValues(alpha: 0.1);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          for (final mood in JournalMood.values)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _MoodCard(
                  mood: mood,
                  isSelected: mood == selected,
                  selectedTint: selectedTint,
                  onTap: () => onPick(mood),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MoodCard extends StatelessWidget {
  const _MoodCard({
    required this.mood,
    required this.isSelected,
    required this.selectedTint,
    required this.onTap,
  });

  final JournalMood mood;
  final bool isSelected;
  final Color selectedTint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    final label = JournalMoodPicker.labelOf(mood, context.l10n);
    return Pressable(
      style: PressStyle.plain,
      onTap: onTap,
      semanticLabel: label,
      child: AnimatedContainer(
        duration: context.motion(AnchorTokens.motionDurationHover),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? selectedTint : colors.appSurface,
          borderRadius: BorderRadius.circular(AnchorTokens.radiusTile),
          border: Border.all(
            color: isSelected ? colors.accentStrong : colors.appBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTypography.footnote.copyWith(
                color: isSelected ? colors.accentStrong : colors.appMuted,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}