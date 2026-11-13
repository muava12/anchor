import 'package:anchor/core/theme/app_typography.dart';
import 'package:anchor/core/theme/note_typography.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('extra small is three quarters of the body size', () {
    expect(NoteTextSize.extraSmall.scale, 0.73);
    const typography = NoteTypography(
      textSize: NoteTextSize.extraSmall,
      lineHeight: 1.7,
    );
    expect(typography.bodySize, closeTo(12.0, 0.05));
  });

  test('the sizes run from extra small to large', () {
    expect(NoteTextSize.values, [
      NoteTextSize.extraSmall,
      NoteTextSize.small,
      NoteTextSize.standard,
      NoteTextSize.large,
    ]);
  });

  test('the body size at standard is the design size', () {
    const typography = NoteTypography(lineHeight: 1.7);
    expect(typography.bodySize, AppTypography.noteBodySize);
  });
}
