import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/motion/springs.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/context_extensions.dart';
import '../../../../core/theme/tokens/anchor_tokens.dart';
import '../../../../core/widgets/anchor_sheet.dart';
import '../../../../core/widgets/app_buttons.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../core/widgets/selection_ring.dart';
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

/// The grid order the mood sheet draws, from Doop frame `YB7mEERCyQ`.
///
/// The enum keeps its own order because stored moods and other screens read
/// it; only the picker follows the design.
const List<JournalMood> journalMoodPickerOrder = [
  JournalMood.happy,
  JournalMood.okay,
  JournalMood.grateful,
  JournalMood.excited,
  JournalMood.calm,
  JournalMood.tired,
  JournalMood.anxious,
  JournalMood.sad,
  JournalMood.angry,
  JournalMood.lonely,
  JournalMood.stressed,
  JournalMood.sick,
];

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

class _JournalMoodSheet extends StatefulWidget {
  const _JournalMoodSheet({
    required this.selected,
    required this.onPick,
    this.onClear,
  });

  final JournalMood? selected;
  final ValueChanged<JournalMood?> onPick;
  final VoidCallback? onClear;

  @override
  State<_JournalMoodSheet> createState() => _JournalMoodSheetState();
}

class _JournalMoodSheetState extends State<_JournalMoodSheet> {
  JournalMood? _picked;

  @override
  void initState() {
    super.initState();
    _picked = widget.selected;
  }

  void _pick(JournalMood mood) {
    setState(() => _picked = mood);
    widget.onPick(mood);
  }

  void _clear() {
    setState(() => _picked = null);
    widget.onClear?.call();
    widget.onPick(null);
  }

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
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                16,
                AnchorTokens.space6, // off-scale: design grid top gap 6
                16,
                0,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisExtent: 78,
                mainAxisSpacing: AnchorTokens.space10, // off-scale: design gap
                crossAxisSpacing:
                    AnchorTokens.space10, // off-scale: design gap
              ),
              itemCount: journalMoodPickerOrder.length,
              itemBuilder: (context, index) {
                final mood = journalMoodPickerOrder[index];
                return _MoodTile(
                  mood: mood,
                  isSelected: mood == _picked,
                  onTap: () => _pick(mood),
                );
              },
            ),
          ),
        ),
        SheetFooter(
          children: [
            AppButton(
              label: l10n.journalMoodClear,
              kind: AppButtonKind.secondary,
              onPressed: widget.onClear == null && _picked == null
                  ? null
                  : _clear,
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
    final radius = BorderRadius.circular(AnchorTokens.radiusTile);
    return Pressable(
      style: PressStyle.plain,
      onTap: onTap,
      semanticLabel: label,
      child: SelectionRing(
        isShown: isSelected,
        borderRadius: radius,
        child: AnimatedContainer(
          duration: context.motion(AnchorTokens.motionDurationHover),
          decoration: BoxDecoration(
            // The design keeps the page colour whether or not the tile is
            // chosen; the ring and the check mark say what is selected.
            color: colors.appPage,
            borderRadius: radius,
            border: Border.all(color: colors.appBorder),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MoodFace(mood: mood, size: 36), // off-scale: 36px face per the sheet design
                    const SizedBox(height: 5), // off-scale: design face gap 5
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        color: isSelected ? colors.appText : colors.appMuted,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Positioned(
                  top: -6, // off-scale: design badge overhang
                  right: -6, // off-scale: design badge overhang
                  child: Container(
                    width: AnchorTokens.sizeIconMedium,
                    height: AnchorTokens.sizeIconMedium,
                    decoration: BoxDecoration(
                      color: colors.accentStrong,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      LucideIcons.check,
                      size: AnchorTokens.space12,
                      color: colors.checkMark,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}