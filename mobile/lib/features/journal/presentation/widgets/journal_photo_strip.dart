import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/context_extensions.dart';
import '../../../../core/theme/tokens/anchor_tokens.dart';
import '../../../../l10n/l10n.dart';
import '../../../notes/data/repository/attachment_file_provider.dart';
import '../../../notes/data/repository/notes_repository.dart';
import '../../../notes/domain/note.dart';

/// The entry's pictures, in a row of four equal cells. The fourth cell
/// carries a "+N" badge when the entry has more pictures than the four
/// shown.
class JournalPhotoStrip extends ConsumerWidget {
  const JournalPhotoStrip({super.key, required this.previews, this.more = 0});

  final List<NoteImagePreview> previews;
  final int more;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shown = previews.take(maxImagePreviews).toList();

    // Every photo loads its own real file, or shows the missing-file
    // placeholder while it is unresolved.
    final paths = <String?>[
      for (final preview in shown)
        ref.watch(attachmentFileProvider(previewFileKeyOf(preview))).value,
    ];

    return Padding(
      padding: const EdgeInsets.only(
        top: AnchorTokens.space10, // off-scale: design strip gap 10
      ),
      child: GridView.count(
        crossAxisCount: maxImagePreviews,
        mainAxisExtent: 68, // off-scale: design strip cell height 68
        crossAxisSpacing: AnchorTokens.space6, // off-scale: design strip gap 6
        mainAxisSpacing: AnchorTokens.space6, // off-scale: design strip gap 6
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (var i = 0; i < shown.length; i++)
            _PhotoCell(
              key: ValueKey('journal-photo-$i'),
              path: paths[i],
              more: i == shown.length - 1 ? more : 0,
            ),
        ],
      ),
    );
  }
}

class _PhotoCell extends StatelessWidget {
  const _PhotoCell({super.key, required this.path, required this.more});

  final String? path;
  final int more;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    final missing = ColoredBox(
      color: colors.appSurface,
      child: Center(
        child: Icon(
          LucideIcons.imageOff,
          size: AnchorTokens.sizeIconMedium,
          color: colors.appMuted,
        ),
      ),
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AnchorTokens.radiusTile),
        boxShadow: [...colors.shadowKnob, ...colors.shadowEdge],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          path != null
              ? Image.file(
                  File(path!),
                  fit: BoxFit.cover,
                  cacheWidth: 96,
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) => missing,
                )
              : missing,
          if (more > 0)
            Container(
              color: Colors.black.withValues(
                alpha: 0.45,
              ), // off-scale: design overlay alpha
              child: Center(
                child: Text(
                  context.l10n.journalPhotosMore(more),
                  style: AppTypography.secondary.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.appOnInverse,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
