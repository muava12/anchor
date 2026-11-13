# Note text size slider — design

Date: 2026-11-13
Status: approved for planning

## Problem

The note text size is four fixed steps: extra small, small, standard, large.
A person who wants 15 or 20 has no way to ask for it. NotallyX sets the size
with a slider from 12 to 32 sp, default 16 sp.

## Goal

Replace the four steps with a slider:

- Range 12 to 32 sp, in steps of 0.5.
- The default is Anchor's own medium, 16.5 sp, so nothing changes for anyone
  who never touches it.
- The preview above the slider follows the finger.

## What already exists

- `lib/core/theme/note_typography.dart` holds `enum NoteTextSize` with scales
  (0.73, 0.88, 1, 1.12) and `NoteTypography`, whose `bodySize` is
  `AppTypography.noteBodySize * textSize.scale * font.editorScale`. The design
  body size is 16.5, so `bodySize` is already `sp * font.editorScale` once the
  scale is read as a fraction of 16.5.
- `EditorPreferences.noteTextSize` carries the enum; `PreferencesRepository`
  stores its **name** under `editor_note_text_size`.
- Settings → Editor shows a `SegmentedControl` of four letters, above a live
  preview that animates with the motion setting.

## Design

### The numbers

`NoteTextSize` stops being an enum and becomes the one place the numbers live:

```dart
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
```

### Typography

`NoteTypography.textSize` becomes a `double` in sp:

```dart
  final double textSize;

  double get scale => textSize / NoteTextSize.standard * font.editorScale;

  double get bodySize => textSize * font.editorScale;
```

`bodySize` is the same number as today for every one of the four old sizes, so
an untouched install looks identical.

### Storage

- `PreferencesRepository.getNoteTextSize()` returns `double`, read through
  `NoteTextSize.fromStored`.
- `setNoteTextSize(double)` writes the number as a string, e.g. `"16.5"`.
- A stored name is read through `legacyNames` and rewritten as a number the
  first time the person moves the slider.

### The screen

Settings → Editor, where the four letters are today:

- A `Slider` from 12 to 32, `divisions: 40` (0.5 steps), value clamped.
- The current value shown beside the label, one decimal: `16.5`.
- The preview above keeps its animation, which already follows the motion
  setting.
- No save button: a change is stored as it happens.

### What does not change

- The font picker, the density setting, and every text size outside a note
  (card titles, chips, bars).
- The stored key name, so an existing install keeps its choice.

## Testing

Unit tests, `test/note_text_size_test.dart`:

- `fromStored('16.5')` is 16.5; `fromStored('small')` is 14.5;
  `fromStored(null)` is 16.5; `fromStored('nonsense')` is 16.5.
- `fromStored('99')` clamps to 32, and `fromStored('1')` clamps to 12.
- `bodySize` is `sp * editorScale` for sans, serif and mono.
- The four legacy names give the same body sizes as before the change.

Widget test, `test/widgets/settings_text_size_test.dart`:

- The editor section shows a slider, not four letters.
- Dragging the slider to the right raises the stored value and the preview's
  font size.
- The value label reads `16.5` on a fresh install.

## Risks

- The enum disappears, so every `NoteTextSize.small` in the app and its tests
  becomes a number. The plan lists each file.
- A slider is harder to hit exactly than four buttons. The 0.5 step and the
  printed value keep it predictable, and the preview shows the result at once.
