import 'package:anchor/core/text/date_formats.dart';
import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/features/journal/domain/journal_day.dart';
import 'package:anchor/features/journal/domain/journal_meta.dart';
import 'package:anchor/features/journal/presentation/widgets/journal_timeline.dart';
import 'package:anchor/features/notes/data/repository/attachment_file_provider.dart';
import 'package:anchor/features/notes/domain/note.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows a day header, the time and title, and opens the note', (
    tester,
  ) async {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    final entryTime = DateTime(now.year, now.month, now.day, 9, 41);
    final note = Note(
      id: 'n1',
      title: 'Morning pages',
      content: '{"ops":[{"insert":"body line\\n"}]}',
      updatedAt: DateTime.utc(now.year, now.month, now.day),
    );
    final entry = JournalDayEntry(
      note: note,
      meta: JournalMeta(entryAt: entryTime),
    );
    Note? opened;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                JournalTimeline(
                  days: [JournalDay(day: day, entries: [entry])],
                  onOpen: (n) => opened = n,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text(clockLabel(entryTime)), findsOneWidget);
    expect(find.text('Morning pages'), findsOneWidget);

    await tester.tap(find.text('Morning pages'));
    await tester.pump();
    expect(opened, note);
  });

  testWidgets('an entry with a picture shows its thumbnail', (tester) async {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    final note = Note(
      id: 'n1',
      title: 'With a picture',
      imagePreviewData: const [
        NoteImagePreview(
          attachmentId: 'a1',
          noteId: 'n1',
          filename: 'pic.jpg',
        ),
      ],
    );
    final entry = JournalDayEntry(note: note, meta: JournalMeta(entryAt: day));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          attachmentFileProvider.overrideWith((ref, key) => '/tmp/pic.jpg'),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                JournalTimeline(
                  days: [JournalDay(day: day, entries: [entry])],
                  onOpen: (_) {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(Image), findsOneWidget);
  });
}
