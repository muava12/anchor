import 'package:flutter/material.dart';

import '../../../core/theme/tokens/anchor_tokens.dart';
import '../../../l10n/l10n.dart';
import '../domain/restore_mode.dart';

/// Asks which restore mode to use. The backup carries no account name, so the
/// person has to say whether this is the same account.
Future<RestoreMode?> showRestoreSheet(
  BuildContext context, {
  required int notes,
  required int attachments,
}) {
  return showModalBottomSheet<RestoreMode>(
    context: context,
    showDragHandle: true,
    builder: (context) => _RestoreSheet(notes: notes, attachments: attachments),
  );
}

class _RestoreSheet extends StatelessWidget {
  const _RestoreSheet({required this.notes, required this.attachments});

  final int notes;
  final int attachments;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.restoreTitle, style: textTheme.titleMedium),
            const SizedBox(height: AnchorTokens.space4),
            Text(
              l10n.restoreContents(notes, attachments),
              style: textTheme.bodySmall,
            ),
            const SizedBox(height: AnchorTokens.space12),
            _ModeTile(
              title: l10n.restoreKeepIds,
              hint: l10n.restoreKeepIdsHint,
              onTap: () => Navigator.of(context).pop(RestoreMode.keepIds),
            ),
            const SizedBox(height: AnchorTokens.space8),
            _ModeTile(
              title: l10n.restoreNewIds,
              hint: l10n.restoreNewIdsHint,
              onTap: () => Navigator.of(context).pop(RestoreMode.newIds),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.title,
    required this.hint,
    required this.onTap,
  });

  final String title;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AnchorTokens.radiusLg),
      child: Padding(
        padding: const EdgeInsets.all(AnchorTokens.space12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: textTheme.titleSmall),
            const SizedBox(height: AnchorTokens.space4),
            Text(hint, style: textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
