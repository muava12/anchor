import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'app_typography.dart';

enum NoteFont {
  sans(AppTypography.sans, 1, 0.992, 0.31),
  serif(AppTypography.noteSerif, 1, 1.177, 0.308),
  mono(AppTypography.mono, 0.9, 1.02, 0.3);

  const NoteFont(this.family, this.editorScale, this.ascent, this.descent);

  final String family;

  final double editorScale;

  /// Per em, from each bundled font's hhea table.
  final double ascent;
  final double descent;

  /// From the middle of a line to the middle of its letters' ascent and
  /// descent. Flutter gives each a share of the leading as big as itself.
  double lettersMiddleOffset(double fontSize, double lineHeight) =>
      fontSize * (lineHeight / (ascent + descent) - 1) * (ascent - descent) / 2;

  String labelIn(AppLocalizations l10n) => switch (this) {
    NoteFont.sans => l10n.noteFontSans,
    NoteFont.serif => l10n.noteFontSerif,
    NoteFont.mono => l10n.noteFontMono,
  };
}

/// The note text size, in sp. The slider picks any value in the range.
abstract final class NoteTextSize {
  static const double min = 12;
  static const double max = 32;
  static const double step = 0.5;

  /// Anchor's own medium, and the default.
  static const double standard = 16.5;

  /// The four names the app used before the slider, for stored values.
  static const Map<String, double> legacyNames = {
    'extraSmall': 12,
    'small': 14.5,
    'standard': 16.5,
    'large': 18.5,
  };

  static double clamp(double sp) => sp.clamp(min, max);

  /// A stored value: a number, or one of the old names.
  static double fromStored(String? stored) {
    if (stored == null) return standard;
    final number = double.tryParse(stored);
    if (number != null) return clamp(number);
    return legacyNames[stored] ?? standard;
  }
}

@immutable
class NoteTypography extends ThemeExtension<NoteTypography> {
  const NoteTypography({
    this.font = NoteFont.sans,
    this.textSize = NoteTextSize.standard,
    required this.lineHeight,
  });

  final NoteFont font;
  final double textSize;

  final double lineHeight;

  String get family => font.family;

  double get scale => textSize / NoteTextSize.standard * font.editorScale;

  double get bodySize => textSize * font.editorScale;

  TextStyle get title => AppTypography.noteTitle
      .copyWith(fontFamily: family)
      .withSize(AppTypography.noteTitle.fontSize! * scale);

  TextStyle get body => AppTypography.noteBody
      .withSize(bodySize)
      .copyWith(
        fontFamily: family,
        height: lineHeight,
        leadingDistribution: TextLeadingDistribution.even,
      );

  TextStyle heading(int level) =>
      AppTypography.noteHeading(level, bodySize: bodySize).copyWith(
        fontFamily: family,
        leadingDistribution: TextLeadingDistribution.even,
      );

  TextStyle get listNumber => AppTypography.noteBody.tabular
      .withSize(bodySize * 0.9)
      .copyWith(
        fontFamily: family,
        fontWeight: FontWeight.w600,
        height: lineHeight,
        leadingDistribution: TextLeadingDistribution.even,
      );

  TextStyle get previewTitle => AppTypography.sheetTitle
      .withSize(AppTypography.sheetTitle.fontSize! * scale)
      .copyWith(
        fontFamily: family,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      );

  TextStyle get cardTitle =>
      AppTypography.cardTitle.copyWith(fontFamily: family);

  TextStyle get cardBody => AppTypography.cardBody.copyWith(fontFamily: family);

  TextStyle get versionTitle =>
      AppTypography.noteTitle.copyWith(fontFamily: family);

  TextStyle get versionBody =>
      AppTypography.noteBody.copyWith(fontFamily: family, height: lineHeight);

  TextStyle versionHeading(int level) =>
      AppTypography.noteHeading(level).copyWith(fontFamily: family);

  @override
  NoteTypography copyWith({
    NoteFont? font,
    double? textSize,
    double? lineHeight,
  }) => NoteTypography(
    font: font ?? this.font,
    textSize: textSize ?? this.textSize,
    lineHeight: lineHeight ?? this.lineHeight,
  );

  @override
  NoteTypography lerp(NoteTypography? other, double t) {
    if (other == null) return this;
    return t < 0.5 ? this : other;
  }

  @override
  bool operator ==(Object other) =>
      other is NoteTypography &&
      other.font == font &&
      other.textSize == textSize &&
      other.lineHeight == lineHeight;

  @override
  int get hashCode => Object.hash(font, textSize, lineHeight);
}
