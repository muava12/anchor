import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/text/date_formats.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/context_extensions.dart';
import '../../../../core/theme/tokens/anchor_tokens.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../l10n/l10n.dart';
import '../../../notes/presentation/note_labels.dart';

/// The journal entry's day and time, as a small pill above the title.
class JournalDatePill extends StatelessWidget {
  const JournalDatePill({super.key, required this.entryAt, this.onTap});

  final DateTime? entryAt;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (entryAt == null) return const SizedBox.shrink();
    final colors = context.anchor;
    final label =
        '${shortDayLabel(entryAt!, context.l10n)} · ${clockLabel(entryAt!)}';
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: colors.appPage,
        borderRadius: BorderRadius.circular(AnchorTokens.radiusPill),
        border: Border.all(color: colors.appBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.calendarDays,
            size: AnchorTokens.sizeIconSmall,
            color: colors.accentStrong,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: AppTypography.footnote.copyWith(color: colors.appMuted),
          ),
        ],
      ),
    );
    if (onTap == null) return ExcludeSemantics(child: pill);
    return Pressable(
      style: PressStyle.plain,
      onTap: onTap,
      semanticLabel: label,
      child: pill,
    );
  }
}
