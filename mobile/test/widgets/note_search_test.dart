import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/features/notes/presentation/editor/editor_palette.dart';
import 'package:anchor/features/notes/presentation/editor/note_search.dart';
import 'package:anchor/features/notes/presentation/editor/rich_text_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the editor paints a search without touching the document', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: RichTextEditor(
            initialContent: '{"ops":[{"insert":"tram 28\\n"}]}',
            contentVersion: 0,
            canEdit: false,
            focusNode: FocusNode(),
            sortChecklistItems: true,
            scrollController: ScrollController(),
            palette: const EditorPalette(
              muted: Color(0xFF000000),
              surface: Color(0xFFFFFFFF),
              border: Color(0xFFDDDDDD),
              background: Color(0xFFFFFFFF),
              highlightFill: _none,
              highlightInk: _none,
            ),
            search: const NoteSearch(
              query: 'tram',
              matches: [TextRange(start: 0, end: 4)],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}

Color _none(String name) => const Color(0x00000000);
