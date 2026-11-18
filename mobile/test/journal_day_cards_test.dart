import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/features/journal/domain/journal_day.dart';
import 'package:anchor/features/journal/domain/journal_meta.dart';
import 'package:anchor/features/journal/presentation/widgets/journal_day_cards.dart';
import 'package:anchor/features/journal/presentation/widgets/mood_face.dart';
import 'package:anchor/features/notes/domain/note.dart';
import 'package:anchor/features/notes/presentation/widgets/note_chips.dart';
import 'package:anchor/features/tags/domain/tag.dart';
import 'package:anchor/features/tags/presentation/tags_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the day header, its entry count, and a card per entry', (
    tester,
  ) async {
    final entryAt = DateTime(2026, 11, 17, 8, 12);
    final note = Note(
      id: 'n1',
      title: 'Morning pages',
      content: '{"ops":[{"insert":"Coffee on the balcony.\\n"}]}',
    );
    final entry = JournalDayEntry(
      note: note,
      meta: JournalMeta(entryAt: entryAt),
    );
    Note? opened;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                JournalDayCards(
                  days: [
                    JournalDay(
                      day: DateTime(2026, 11, 17),
                      entries: [entry],
                    ),
                  ],
                  journalTagId: null,
                  onOpen: (n) => opened = n,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('TUE, NOV 17'), findsOneWidget);
    expect(find.text('1 entry'), findsOneWidget);
    expect(find.text('Morning pages'), findsOneWidget);
    expect(find.text('Coffee on the balcony.'), findsOneWidget);

    await tester.tap(find.text('Morning pages'));
    await tester.pump();
    expect(opened, note);
  });

  testWidgets('an empty day draws no header', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: CustomScrollView(
              slivers: [JournalDayCards(days: const [], journalTagId: null, onOpen: (_) {})],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('NOV'), findsNothing);
  });

  testWidgets('a day equal to today shows the TODAY pill', (tester) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    const entry = JournalDayEntry(
      note: Note(id: 'n1', title: 'T', content: 'plain'),
      meta: JournalMeta(),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                JournalDayCards(
                  days: [JournalDay(day: today, entries: [entry])],
                  journalTagId: null,
                  onOpen: (_) {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('TODAY'), findsOneWidget);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                JournalDayCards(
                  days: [JournalDay(day: yesterday, entries: const [])],
                  journalTagId: null,
                  onOpen: (_) {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('TODAY'), findsNothing);
  });

  testWidgets('shows a chip for the first tag that is not the journal tag', (
    tester,
  ) async {
    const journalTag = Tag(id: 'j1', name: 'journal');
    const morning = Tag(id: 't1', name: 'morning');
    final note = Note(
      id: 'n1',
      title: 'Morning pages',
      content: 'plain',
      tagIds: const ['j1', 't1'],
    );

    await tester.pumpWidget(
      _wrap(
        entry: JournalDayEntry(
          note: note,
          meta: JournalMeta(entryAt: DateTime(2026, 11, 17, 8, 12)),
        ),
        tags: const [journalTag, morning],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('morning'), findsOneWidget);
    expect(find.text('journal'), findsNothing);
  });

  testWidgets('shows no chip when the only tag is the journal tag', (
    tester,
  ) async {
    const journalTag = Tag(id: 'j1', name: 'journal');
    final note = Note(
      id: 'n1',
      title: 'Morning pages',
      content: 'plain',
      tagIds: const ['j1'],
    );

    await tester.pumpWidget(
      _wrap(
        entry: JournalDayEntry(
          note: note,
          meta: JournalMeta(entryAt: DateTime(2026, 11, 17, 8, 12)),
        ),
        tags: const [journalTag],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TagChip), findsNothing);
  });

  testWidgets('shows the mood face between the time and the tag chip', (
    tester,
  ) async {
    const journalTag = Tag(id: 'j1', name: 'journal');
    const morning = Tag(id: 't1', name: 'morning');
    final content = composeJournalContent(
      JournalMeta(
        mood: JournalMood.calm,
        entryAt: _entryAt,
      ),
      'plain',
    );
    final note = Note(
      id: 'n1',
      title: 'Slow morning',
      content: content!,
      tagIds: const ['j1', 't1'],
    );

    await tester.pumpWidget(
      _wrap(
        entry: JournalDayEntry(note: note, meta: parseJournalContent(content).meta),
        tags: const [journalTag, morning],
      ),
    );
    await tester.pumpAndSettle();

    final face = tester.widget<MoodFace>(find.byType(MoodFace));
    expect(face.mood, JournalMood.calm);
    expect(face.size, 20);
    expect(find.byType(TagChip), findsOneWidget);

    // The face sits between the time text and the tag chip.
    final row = tester.widget<Row>(
      find.ancestor(of: find.byType(MoodFace), matching: find.byType(Row)),
    );
    expect(row.children.map((c) => c.runtimeType).toList(), [
      Text,
      SizedBox,
      MoodFace,
      SizedBox,
      Flexible,
    ]);
    final timeIndex = tester.getTopLeft(find.byType(Text).first).dx;
    final faceIndex = tester.getTopLeft(find.byType(MoodFace)).dx;
    final chipIndex = tester.getTopLeft(find.byType(TagChip)).dx;
    expect(timeIndex < faceIndex, isTrue, reason: 'time before face');
    expect(faceIndex < chipIndex, isTrue, reason: 'face before tag chip');
  });

  testWidgets('a long tag name ellipsizes instead of overflowing the row', (
    tester,
  ) async {
    // A narrow phone: the meta row has to give way somewhere.
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    const journalTag = Tag(id: 'j1', name: 'journal');
    const longTag = Tag(
      id: 't1',
      name: 'a-very-long-tag-name-that-must-not-overflow-the-row',
    );
    final note = Note(
      id: 'n1',
      title: 'Slow morning',
      content: 'body line',
      tagIds: const ['j1', 't1'],
    );

    await tester.pumpWidget(
      _wrap(
        entry: JournalDayEntry(
          note: note,
          meta: JournalMeta(
            mood: JournalMood.calm,
            entryAt: _entryAt,
          ),
        ),
        tags: const [journalTag, longTag],
      ),
    );
    await tester.pumpAndSettle();

    // No overflow error (Flutter would report a painted overflow stripe).
    expect(tester.takeException(), isNull);

    // The chip stays inside the meta row's right edge.
    final chip = tester.getRect(find.byType(TagChip));
    final row = tester.getRect(
      find.ancestor(of: find.byType(TagChip), matching: find.byType(Row)),
    );
    expect(chip.right, lessThanOrEqualTo(row.right + 0.01));
    expect(chip.left, greaterThanOrEqualTo(row.left));
  });

  testWidgets('an old four-mood entry shows no face but keeps the tag chip', (
    tester,
  ) async {
    const journalTag = Tag(id: 'j1', name: 'journal');
    const morning = Tag(id: 't1', name: 'morning');
    // "amazing" was a 4-mood value; it now parses to null.
    final content = composeJournalContent(
      JournalMeta(
        mood: null,
        entryAt: _entryAt,
        extras: const {'mood': 'amazing'},
      ),
      'plain',
    )!;
    final note = Note(
      id: 'n1',
      title: 'Old entry',
      content: content,
      tagIds: const ['j1', 't1'],
    );

    expect(parseJournalContent(content).meta.mood, isNull);

    await tester.pumpWidget(
      _wrap(
        entry: JournalDayEntry(note: note, meta: parseJournalContent(content).meta),
        tags: const [journalTag, morning],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MoodFace), findsNothing);
    expect(find.byType(TagChip), findsOneWidget);
    expect(find.text('morning'), findsOneWidget);
  });
}

final _entryAt = DateTime(2026, 11, 17, 8, 12);

Widget _wrap({required JournalDayEntry entry, required List<Tag> tags}) {
  return ProviderScope(
    overrides: [tagsControllerProvider.overrideWith(() => _Tags(tags))],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: CustomScrollView(
          slivers: [
            JournalDayCards(
              days: [JournalDay(day: DateTime(2026, 11, 17), entries: [entry])],
              journalTagId: 'j1',
              onOpen: (_) {},
            ),
          ],
        ),
      ),
    ),
  );
}

class _Tags extends TagsController {
  _Tags(this.tags);

  final List<Tag> tags;

  @override
  Stream<List<Tag>> build() => Stream.value(tags);
}