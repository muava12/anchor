import 'package:anchor/core/theme/app_typography.dart';
import 'package:anchor/core/theme/note_typography.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a stored number is read as it is', () {
    expect(NoteTextSize.fromStored('16.5'), 16.5);
    expect(NoteTextSize.fromStored('20'), 20);
  });

  test('a stored name from before the slider still reads', () {
    expect(NoteTextSize.fromStored('extraSmall'), 12);
    expect(NoteTextSize.fromStored('small'), 14.5);
    expect(NoteTextSize.fromStored('standard'), 16.5);
    expect(NoteTextSize.fromStored('large'), 18.5);
  });

  test('nothing stored, or nonsense, is the default', () {
    expect(NoteTextSize.fromStored(null), NoteTextSize.standard);
    expect(NoteTextSize.fromStored('nonsense'), NoteTextSize.standard);
  });

  test('a stored value outside the range is clamped', () {
    expect(NoteTextSize.fromStored('99'), NoteTextSize.max);
    expect(NoteTextSize.fromStored('1'), NoteTextSize.min);
  });

  test('the body size is the chosen size times the font scale', () {
    for (final font in NoteFont.values) {
      final typography = NoteTypography(textSize: 20, lineHeight: 1.7, font: font);
      expect(typography.bodySize, closeTo(20 * font.editorScale, 0.001));
    }
  });

  test('the default is the design body size', () {
    const typography = NoteTypography(lineHeight: 1.7);
    expect(typography.bodySize, AppTypography.noteBodySize);
  });

  test('the old names land on the nearest half step', () {
    // The four steps were 12.045, 14.52, 16.5 and 18.48. The slider snaps to
    // half steps, so a stored name moves by at most 0.05 sp.
    for (final name in NoteTextSize.legacyNames.keys) {
      final sp = NoteTextSize.fromStored(name);
      expect(sp * 2, closeTo((sp * 2).roundToDouble(), 0.0001));
    }
  });
}
