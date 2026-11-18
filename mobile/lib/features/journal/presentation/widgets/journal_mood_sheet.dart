import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/motion/springs.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/context_extensions.dart';
import '../../../../core/theme/tokens/anchor_tokens.dart';
import '../../../../core/widgets/anchor_sheet.dart';
import '../../../../core/widgets/app_buttons.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../l10n/l10n.dart';
import '../../domain/journal_meta.dart';
import 'mood_face.dart';

/// Shows the journal mood sheet: a 4x3 grid of mood faces with a
/// Clear / Done footer. [onPick] fires with the tapped mood, or with
/// null after [onClear].
Future<void> showJournalMoodSheet(
  BuildContext context, {
  required JournalMood? selected,
  required ValueChanged<JournalMood?> onPick,
  VoidCallback? onClear,
}) {
  return showAnchorSheet<void>(
    context,
    semanticLabel: context.l10n.journalMoodPickerTitle,
    builder: (sheet) => _JournalMoodSheet(
      selected: selected,
      onPick: onPick,
      onClear: onClear,
    ),
  );
}

/// The localized label of a mood.
String moodLabel(JournalMood mood, AppLocalizations l10n) => switch (mood) {
  JournalMood.happy => l10n.journalMoodHappy,
  JournalMood.calm => l10n.journalMoodCalm,
  JournalMood.grateful => l10n.journalMoodGrateful,
  JournalMood.excited => l10n.journalMoodExcited,
  JournalMood.okay => l10n.journalMoodOkay,
  JournalMood.tired => l10n.journalMoodTired,
  JournalMood.anxious => l10n.journalMoodAnxious,
  JournalMood.sad => l10n.journalMoodSad,
  JournalMood.angry => l10n.journalMoodAngry,
  JournalMood.lonely => l10n.journalMoodLonely,
  JournalMood.stressed => l10n.journalMoodStressed,
  JournalMood.sick => l10n.journalMoodSick,
};

class _JournalMoodSheet extends StatelessWidget {
  const _JournalMoodSheet({
    required this.selected,
    required this.onPick,
    this.onClear,
  });

  final JournalMood? selected;
  final ValueChanged<JournalMood?> onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(
          title: l10n.journalMoodPickerTitle,
          subtitle: l10n.journalMoodPickerSubtitle,
        ),
        Flexible(
          child: SingleChildScrollView(
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 4,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              mainAxisSpacing: AnchorTokens.space12,
              crossAxisSpacing: AnchorTokens.space12,
              childAspectRatio: 0.9,
              children: [
                for (final mood in JournalMood.values)
                  _MoodTile(
                    mood: mood,
                    isSelected: mood == selected,
                    onTap: () => onPick(mood),
                  ),
              ],
            ),
          ),
        ),
        SheetFooter(
          children: [
            AppButton(
              label: l10n.journalMoodClear,
              kind: AppButtonKind.secondary,
              onPressed: onClear == null && selected == null
                  ? null
                  : () {
                      onClear?.call();
                      onPick(null);
                    },
            ),
            AppButton(
              label: l10n.commonDone,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
      ],
    );
  }
}

class _MoodTile extends StatelessWidget {
  const _MoodTile({
    required this.mood,
    required this.isSelected,
    required this.onTap,
  });

  final JournalMood mood;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    final label = moodLabel(mood, context.l10n);
    return Pressable(
      style: PressStyle.plain,
      onTap: onTap,
      semanticLabel: label,
      child: AnimatedContainer(
        duration: context.motion(AnchorTokens.motionDurationHover),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.accentStrong.withValues(alpha: 0.1)
              : colors.appSurface,
          borderRadius: BorderRadius.circular(AnchorTokens.radiusTile),
          border: Border.all(
            color: isSelected ? colors.accentStrong : colors.appBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                MoodFace(mood: mood, size: AnchorTokens.sizeIconMedium),
                if (isSelected)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: AnchorTokens.sizeIconSmall,
                      height: AnchorTokens.sizeIconSmall,
                      decoration: BoxDecoration(
                        color: colors.accentStrong,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        LucideIcons.check,
                        size: AnchorTokens.space12,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AnchorTokens.space4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.footnote.copyWith(
                  color: isSelected ? colors.accentStrong : colors.appMuted,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}