import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/context_extensions.dart';
import '../../../../core/theme/tokens/anchor_tokens.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../l10n/l10n.dart';

/// The journal list's section heading: the uppercase "ENTRIES" label and an
/// inert options icon on the right, which has no action yet.
class JournalSectionHeader extends StatelessWidget {
  const JournalSectionHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20, // off-scale: design section padding 20
        AnchorTokens.space6, // off-scale: design section padding 6
        20, // off-scale: design section padding 20
        0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            l10n.journalEntriesSection.toUpperCase(),
            style: AppTypography.label.copyWith(
              fontWeight: FontWeight.w700,
              color: colors.appMuted,
            ),
          ),
          // Placeholder for a future entries menu; it does nothing yet.
          Pressable(
            style: PressStyle.plain,
            semanticLabel: l10n.journalEntriesOptions,
            child: Icon(
              LucideIcons.menu,
              size: 20, // off-scale: design section icon 20
              color: colors.appMuted,
            ),
          ),
        ],
      ),
    );
  }
}
