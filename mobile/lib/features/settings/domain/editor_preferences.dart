import '../../../core/theme/note_typography.dart';

class EditorPreferences {
  /// Sorts checked items to the bottom.
  final bool sortChecklistItems;

  final NoteFont noteFont;
  final double noteTextSize;

  const EditorPreferences({
    this.sortChecklistItems = true,
    this.noteFont = NoteFont.sans,
    this.noteTextSize = NoteTextSize.standard,
  });

  EditorPreferences copyWith({
    bool? sortChecklistItems,
    NoteFont? noteFont,
    double? noteTextSize,
  }) {
    return EditorPreferences(
      sortChecklistItems: sortChecklistItems ?? this.sortChecklistItems,
      noteFont: noteFont ?? this.noteFont,
      noteTextSize: noteTextSize ?? this.noteTextSize,
    );
  }
}
