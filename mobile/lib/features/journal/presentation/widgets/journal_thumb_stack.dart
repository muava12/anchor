import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/context_extensions.dart';
import '../../../../core/theme/tokens/anchor_tokens.dart';
import '../../../notes/data/repository/attachment_file_provider.dart';
import '../../../notes/domain/note.dart';

/// The entry's pictures: one, a pair, or a stack of three.
///
/// Every card in the stack loads its own real file, not a blank placeholder.
class JournalThumbStack extends ConsumerWidget {
  const JournalThumbStack({super.key, required this.previews});

  final List<NoteImagePreview> previews;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.anchor;
    final count = previews.length;
    final paths = <String?>[
      for (final preview in previews)
        ref.watch(attachmentFileProvider(previewFileKeyOf(preview))).value,
    ];
    const off = 6.0; // off-scale: the step between stacked pictures
    final behind = count - 1 > 2 ? 2 : count - 1;
    // The token's 56 is off the layout scale; the design fixes that size.
    final side = AnchorTokens.sizeJournalThumb;

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

    // The design fans the stack: the furthest card leans the most and fades
    // the most, the next one a little, the front card is square-on and solid.
    const lean = [0.0, -0.07, 0.13]; // off-scale: the design's stack angles
    const fade = [1.0, 0.8, 0.7]; // off-scale: the design's stack opacity

    // One card of the stack: the real picture, or blank while it is unresolved.
    Widget thumb(int index) {
      final path = paths[index];
      final card = ClipRRect(
        borderRadius: BorderRadius.circular(AnchorTokens.radiusTile),
        child: SizedBox(
          width: side,
          height: side,
          child: path != null
              ? Image.file(
                  File(path),
                  fit: BoxFit.cover,
                  cacheWidth: 96,
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) => missing,
                )
              : ColoredBox(color: colors.appSurface),
        ),
      );
      if (index == 0) return card;
      return Opacity(
        opacity: fade[index],
        child: Transform.rotate(angle: lean[index], child: card),
      );
    }

    return SizedBox(
      width: side + off * behind,
      height: side + off * behind,
      child: Stack(
        alignment: Alignment.topLeft,
        clipBehavior: Clip.none,
        children: [
          // The back cards, furthest first, peaking up and to the right.
          for (var i = behind; i >= 1; i--)
            Positioned(
              left: off * i,
              top: off * (behind - i),
              child: thumb(i),
            ),
          Positioned(left: 0, top: off * behind, child: thumb(0)),
        ],
      ),
    );
  }
}
