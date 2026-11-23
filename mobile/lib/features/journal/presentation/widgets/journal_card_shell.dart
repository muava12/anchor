import 'package:flutter/material.dart';

import '../../../../core/theme/context_extensions.dart';
import '../../../../core/theme/tokens/anchor_tokens.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../notes/presentation/widgets/card_registry.dart';

/// The card surface that groups a day's journal entries.
///
/// One child is a whole card. Several children are joined by a 1 px divider
/// set back from the card's edge; each child carries its own padding.
class JournalCardShell extends StatelessWidget {
  const JournalCardShell({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;

    return Container(
      decoration: BoxDecoration(
        color: colors.appSurface,
        borderRadius: BorderRadius.circular(AnchorTokens.radiusCard),
        border: Border.all(color: colors.appDivider),
        boxShadow: colors.shadowRaised,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Container(
                key: const ValueKey('journal-card-divider'),
                height: 1,
                margin: const EdgeInsets.symmetric(
                  horizontal: AnchorTokens
                      .space14, // off-scale: design divider margin 14
                ),
                color: colors.appDivider,
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// A tappable, morph-registered journal entry.
///
/// The note's [noteId] keeps its [RepaintBoundary] in the [CardRegistry],
/// so opening and closing the note flies from and back to this entry. The
/// entry dims when its note is hidden while another note is open.
class JournalRegisteredEntry extends StatelessWidget {
  const JournalRegisteredEntry({
    super.key,
    required this.noteId,
    required this.semanticLabel,
    required this.onTap,
    required this.child,
  });

  final String noteId;
  final String semanticLabel;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      style: PressStyle.plain,
      onTap: onTap,
      semanticLabel: semanticLabel,
      child: ValueListenableBuilder<Set<String>>(
        valueListenable: CardRegistry.hidden,
        builder: (context, hidden, child) =>
            Opacity(opacity: hidden.contains(noteId) ? 0 : 1, child: child),
        child: RepaintBoundary(
          // The morph close target: the note flies back to this entry.
          key: CardRegistry.keyFor(noteId),
          child: child,
        ),
      ),
    );
  }
}
