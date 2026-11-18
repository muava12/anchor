import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/text/date_formats.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/context_extensions.dart';
import '../../../../core/theme/tokens/anchor_tokens.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../l10n/l10n.dart';
import '../../domain/journal_meta.dart';
import 'journal_mood_sheet.dart';
import 'mood_face.dart';

/// The journal entry's metadata as pills under the title: the day and the
/// time, then the mood. Each pill opens its sheet.
class JournalEntryMetaRow extends StatelessWidget {
  const JournalEntryMetaRow({
    super.key,
    required this.meta,
    this.onEditDateTime,
    this.onEditMood,
  });

  final JournalMeta meta;

  /// Keys of the two pills, so a test can tap one of them.
  static const Key dateKey = ValueKey('journal-date-pill');
  static const Key moodKey = ValueKey('journal-mood-pill');

  /// Null keeps the day read-only.
  final VoidCallback? onEditDateTime;

  /// Null keeps the mood read-only.
  final VoidCallback? onEditMood;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AnchorTokens.spaceGutterPhone,
        0,
        AnchorTokens.spaceGutterPhone,
        AnchorTokens.space8,
      ),
      child: Wrap(
        spacing: AnchorTokens.space8,
        runSpacing: AnchorTokens.space8,
        children: [
          _DateTimePill(entryAt: meta.entryAt, onTap: onEditDateTime),
          _MoodPill(mood: meta.mood, onTap: onEditMood),
        ],
      ),
    );
  }
}

class _DateTimePill extends StatelessWidget {
  const _DateTimePill({required this.entryAt, this.onTap});

  final DateTime? entryAt;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    final l10n = context.l10n;
    final at = entryAt;
    final day = at == null
        ? l10n.journalDateTimeTitle
        : DateFormat('EEE, d MMM', dateLocale).format(at);
    final label = at == null ? day : '$day · ${clockLabel(at)}';
    final pill = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AnchorTokens.space12,
        vertical: AnchorTokens.space4,
      ),
      decoration: BoxDecoration(
        color: colors.appSurface,
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
          const SizedBox(width: AnchorTokens.space8),
          Text(
            day,
            style: AppTypography.footnote.copyWith(color: colors.appText),
          ),
          if (at != null) ...[
            const SizedBox(width: AnchorTokens.space8),
            Icon(
              LucideIcons.clock,
              size: AnchorTokens.sizeIconSmall,
              color: colors.accentStrong,
            ),
            const SizedBox(width: AnchorTokens.space4),
            Text(
              clockLabel(at),
              style: AppTypography.footnote.copyWith(color: colors.appMuted),
            ),
          ],
        ],
      ),
    );
    return _pill(key: JournalEntryMetaRow.dateKey, label: label, onTap: onTap, child: pill);
  }
}

class _MoodPill extends StatelessWidget {
  const _MoodPill({required this.mood, this.onTap});

  final JournalMood? mood;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchor;
    final l10n = context.l10n;
    final picked = mood;
    final label = picked == null
        ? l10n.journalAddMood
        : moodLabel(picked, l10n);
    final tint = colors.accentStrong.withValues(alpha: 0.1);
    final pill = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AnchorTokens.space12,
        vertical: AnchorTokens.space4,
      ),
      decoration: picked == null
          ? null
          : BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(AnchorTokens.radiusPill),
            ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (picked case final face?)
            MoodFace(mood: face, size: AnchorTokens.sizeIconMedium)
          else
            Icon(
              LucideIcons.smilePlus,
              size: AnchorTokens.sizeIconSmall,
              color: colors.accentStrong,
            ),
          const SizedBox(width: AnchorTokens.space8),
          Text(
            label,
            style: AppTypography.footnote.copyWith(
              color: picked == null ? colors.appMuted : colors.accentStrong,
            ),
          ),
        ],
      ),
    );
    final outlined = picked == null
        ? _DashedOutline(color: colors.accentStrong, child: pill)
        : pill;
    return _pill(key: JournalEntryMetaRow.moodKey, label: label, onTap: onTap, child: outlined);
  }
}

/// A pill: dashed until it is filled, tappable when [onTap] is set.
Widget _pill({
  required Key key,
  required String label,
  required VoidCallback? onTap,
  required Widget child,
}) {
  final pill = ConstrainedBox(
    constraints: const BoxConstraints(minHeight: AnchorTokens.sizeTargetTouch),
    child: Center(widthFactor: 1, heightFactor: 1, child: child),
  );
  if (onTap == null) {
    return ExcludeSemantics(key: key, child: pill);
  }
  return Pressable(
    key: key,
    style: PressStyle.button,
    onTap: onTap,
    semanticLabel: label,
    tintRadius: BorderRadius.circular(AnchorTokens.radiusPill),
    child: pill,
  );
}

/// The border of an empty pill: a rounded outline drawn as dashes.
class _DashedOutline extends StatelessWidget {
  const _DashedOutline({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _DashPainter(color: color),
    child: child,
  );
}

class _DashPainter extends CustomPainter {
  const _DashPainter({required this.color});

  final Color color;

  static const double _dash = AnchorTokens.space8;
  static const double _gap = AnchorTokens.space4;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(AnchorTokens.radiusPill),
    );
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var start = 0.0;
      while (start < metric.length) {
        final end = (start + _dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(start, end), paint);
        start = end + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashPainter oldDelegate) => oldDelegate.color != color;
}