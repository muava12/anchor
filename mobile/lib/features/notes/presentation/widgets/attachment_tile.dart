import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/context_extensions.dart';
import '../../../../core/theme/tokens/anchor_tokens.dart';
import '../../../../core/widgets/pressable.dart';
import 'note_surface.dart';

class AttachmentTile extends StatelessWidget {
  const AttachmentTile({
    super.key,
    required this.width,
    required this.appearance,
    required this.deleteLabel,
    required this.onDelete,
    required this.child,
  });

  static const double height = 96; // off-scale: a picture tile

  /// The 24 dp remove circle. Tests read its rect to pin the corner offset.
  static const Key removeKnobKey = ValueKey('attachment-remove-knob');

  /// How far the remove circle hangs past the tile's top and right edge.
  /// The touch target is 44 dp and is centred on the circle, so the
  /// positioned box is offset by `44 / 2 - 24 / 2 + 8` = 18 dp.
  static const double removeKnobOutset = 8; // off-scale: knob overhang
  static const double _removeTarget = 44;
  static const double removeCircle = 24;
  static const double _removeOffset =
      _removeTarget / 2 - removeCircle / 2 + removeKnobOutset;

  final double width;
  final NoteAppearance appearance;
  final String deleteLabel;
  final VoidCallback? onDelete;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: child),
          if (onDelete != null)
            Positioned(
              top: -_removeOffset,
              right: -_removeOffset,
              child: _RemoveButton(
                label: deleteLabel,
                appearance: appearance,
                onTap: onDelete!,
              ),
            ),
        ],
      ),
    );
  }
}

class _RemoveButton extends StatelessWidget {
  const _RemoveButton({
    required this.label,
    required this.appearance,
    required this.onTap,
  });

  final String label;
  final NoteAppearance appearance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    return Pressable(
      style: PressStyle.plain,
      onTap: onTap,
      semanticLabel: label,
      minSize: const Size.square(AnchorTokens.sizeControlMedium),
      child: Container(
        key: AttachmentTile.removeKnobKey,
        width: AttachmentTile.removeCircle,
        height: AttachmentTile.removeCircle,
        decoration: BoxDecoration(
          color: appearance.colors.surface.withValues(alpha: 0.92),
          shape: BoxShape.circle,
          boxShadow: colors.shadowKnob,
        ),
        child: Icon(
          LucideIcons.x,
          size: 12, // off-scale: remove mark on a tile
          color: colors.appText,
        ),
      ),
    );
  }
}
