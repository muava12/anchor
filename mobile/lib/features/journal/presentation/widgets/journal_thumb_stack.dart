import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/context_extensions.dart';
import '../../../../core/theme/tokens/anchor_tokens.dart';
import '../../../notes/data/repository/attachment_file_provider.dart';
import '../../../notes/domain/note.dart';

/// The entry's pictures, fanned into a 56 box: the back card leans to the
/// top right, the middle card behind it, the front card square-on at the
/// bottom left.
///
/// Every card in the stack loads its own real file, not a blank placeholder.
class JournalThumbStack extends ConsumerWidget {
  const JournalThumbStack({super.key, required this.previews});

  final List<NoteImagePreview> previews;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.anchor;
    final shown = previews.take(3).toList();
    final count = shown.length;
    final paths = <String?>[
      for (final preview in shown)
        ref.watch(attachmentFileProvider(previewFileKeyOf(preview))).value,
    ];
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

    // One card of the stack: the real picture, or blank while it is
    // unresolved.
    Widget thumb(int index, double size) {
      final path = paths[index];
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AnchorTokens.radiusTile),
          boxShadow: [...colors.shadowKnob, ...colors.shadowEdge],
        ),
        clipBehavior: Clip.antiAlias,
        child: path != null
            ? Image.file(
                File(path),
                fit: BoxFit.cover,
                cacheWidth: 96,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => missing,
              )
            : missing,
      );
    }

    // The frame's fan: the furthest card leans the most and fades the most,
    // the next one a little, the front card is square-on and solid.
    final children = <Widget>[
      // The back card: top right.
      if (count >= 3)
        Positioned(
          right: 0,
          top: 0,
          child: Opacity(
            opacity: 0.7, // off-scale: the design's stack opacity
            child: Transform.rotate(
              angle:
                  math.pi *
                  9 /
                  180, // off-scale: the design's back card 9 degrees
              child: thumb(2, 42), // off-scale: the design's back card 42
            ),
          ),
        ),
      // The middle card: a step down and to the left of the back one.
      if (count >= 2)
        Positioned(
          right: 4, // off-scale: the design's middle card
          top: 3, // off-scale: the design's middle card
          child: Opacity(
            opacity: 0.9, // off-scale: the design's stack opacity
            child: Transform.rotate(
              angle:
                  math.pi *
                  4 /
                  180, // off-scale: the design's middle card 4 degrees
              child: thumb(1, 44), // off-scale: the design's middle card 44
            ),
          ),
        ),
      // The front card: bottom left, square-on and solid.
      Positioned(
        left: 0,
        bottom: 0,
        child: thumb(0, 46), // off-scale: the design's front card 46
      ),
    ];

    return SizedBox(
      width: side,
      height: side,
      child: Stack(clipBehavior: Clip.none, children: children),
    );
  }
}
