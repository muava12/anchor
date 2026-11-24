import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/core/theme/tokens/anchor_tokens.dart';
import 'package:anchor/features/journal/presentation/widgets/journal_photo_strip.dart';
import 'package:anchor/features/notes/data/repository/attachment_file_provider.dart';
import 'package:anchor/features/notes/domain/note.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

List<NoteImagePreview> _previews(int count) => [
  for (var i = 0; i < count; i++)
    NoteImagePreview(attachmentId: 'a$i', noteId: 'n', filename: '$i.jpg'),
];

Future<void> pumpStrip(
  WidgetTester tester, {
  required int previews,
  int more = 0,
  String? filePath,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [attachmentFileProvider.overrideWith((ref, key) => filePath)],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: JournalPhotoStrip(
                previews: _previews(previews),
                more: more,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<double> widthOfCell(WidgetTester tester, {required int previews}) async {
  await pumpStrip(tester, previews: previews);
  return tester.getSize(find.byKey(const ValueKey('journal-photo-0'))).width;
}

void main() {
  testWidgets('one photo keeps the 4-column cell width', (tester) async {
    final one = await widthOfCell(tester, previews: 1);
    final four = await widthOfCell(tester, previews: 4);
    expect(one, four);
  });

  testWidgets('+N overlay only on the 4th cell', (tester) async {
    await pumpStrip(tester, previews: 4, more: 2);
    expect(find.text('+2'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('journal-photo-3')),
        matching: find.text('+2'),
      ),
      findsOneWidget,
    );

    await pumpStrip(tester, previews: 4, more: 0);
    expect(find.textContaining('+'), findsNothing);
  });

  testWidgets('an unresolved file path (offline) does not throw', (
    tester,
  ) async {
    await pumpStrip(tester, previews: 3, filePath: null);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the strip keeps its design height inside a safe-area inset', (
    tester,
  ) async {
    // The strip sits inside a card, far from any screen edge. A phone with a
    // gesture bar reports a bottom inset, and a scroll view without its own
    // padding silently adds that inset as blank space, so the gap under the
    // pictures grows to twice the design's 10 px.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [attachmentFileProvider.overrideWith((ref, key) => null)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: MediaQuery(
            data: const MediaQueryData(
              padding: EdgeInsets.only(top: 32, bottom: 48),
            ),
            child: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: JournalPhotoStrip(previews: _previews(4)),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Design strip: 10 px above the cells, 68 px cells, nothing below.
    expect(
      tester.getSize(find.byType(JournalPhotoStrip)).height,
      AnchorTokens.space10 + 68,
    );
  });
}
