import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/features/journal/domain/journal_day.dart';
import 'package:anchor/features/journal/domain/journal_meta.dart';
import 'package:anchor/features/journal/presentation/widgets/journal_card_shell.dart';
import 'package:anchor/features/journal/presentation/widgets/journal_day_cards.dart';
import 'package:anchor/features/journal/presentation/widgets/journal_thumb_stack.dart';
import 'package:anchor/features/journal/presentation/widgets/mood_face.dart';
import 'package:anchor/features/notes/data/repository/attachment_file_provider.dart';
import 'package:anchor/features/notes/domain/note.dart';
import 'package:anchor/features/notes/presentation/widgets/card_registry.dart';
import 'package:anchor/features/notes/presentation/widgets/note_chips.dart';
import 'package:anchor/features/tags/domain/tag.dart';
import 'package:anchor/features/tags/presentation/tags_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const journalTag = Tag(id: 'j1', name: 'journal');
const tagA = Tag(id: 't1', name: 'morning');
const tagB = Tag(id: 't2', name: 'evening');

Note _note({
  required String id,
  String title = '',
  String body = 'plain',
  List<String> tagIds = const [],
  List<NoteImagePreview> previews = const [],
}) => Note(
  id: id,
  title: title,
  content: '{"ops":[{"insert":"$body\\n"}]}',
  tagIds: tagIds,
  imagePreviewData: previews,
);

JournalDayEntry _entry({
  required String id,
  DateTime? at,
  String title = '',
  String body = 'plain',
  List<String> tagIds = const [],
  JournalMood? mood,
  List<NoteImagePreview> previews = const [],
}) => JournalDayEntry(
  note: _note(
    id: id,
    title: title,
    body: body,
    tagIds: tagIds,
    previews: previews,
  ),
  meta: JournalMeta(mood: mood, entryAt: at),
);

List<NoteImagePreview> _pics(int count) => [
  for (var i = 0; i < count; i++)
    NoteImagePreview(attachmentId: 'a$i', noteId: 'id', filename: '$i.jpg'),
];

void _noOpen(Note note) {}

Widget _wrap({
  required List<JournalDay> days,
  required List<Tag> tags,
  String journalTagId = 'j1',
  void Function(Note) onOpen = _noOpen,
}) {
  return ProviderScope(
    overrides: [
      tagsControllerProvider.overrideWith(() => _Tags(tags)),
      attachmentFileProvider.overrideWith((ref, key) => null),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: CustomScrollView(
          slivers: [
            JournalDayCards(
              days: days,
              journalTagId: journalTagId,
              onOpen: onOpen,
            ),
          ],
        ),
      ),
    ),
  );
}

JournalDay twoEntriesOn(DateTime day) => JournalDay(
  day: day,
  entries: [
    _entry(id: 'late', at: DateTime(day.year, day.month, day.day, 17, 40)),
    _entry(id: 'early', at: DateTime(day.year, day.month, day.day, 8, 30)),
  ],
);

double opacityOf(WidgetTester tester, String noteId) {
  final boundary = find.byKey(CardRegistry.keyFor(noteId));
  final opacity = tester.widget<Opacity>(
    find.ancestor(of: boundary, matching: find.byType(Opacity)).first,
  );
  return opacity.opacity;
}

void main() {
  testWidgets('header and one shell with a divider between two entries', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(days: [twoEntriesOn(DateTime(2026, 11, 17))], tags: []),
    );
    await tester.pump();

    expect(find.text('TUE, 17 NOV'), findsOneWidget);
    expect(find.text('2 entries'), findsOneWidget);
    expect(find.byType(JournalCardShell), findsOneWidget);
    expect(find.byKey(const ValueKey('journal-card-divider')), findsOneWidget);
  });

  testWidgets('stack only for entries with pictures', (tester) async {
    final day = JournalDay(
      day: DateTime(2026, 11, 17),
      entries: [
        _entry(
          id: 'with-pics',
          at: DateTime(2026, 11, 17, 9, 0),
          previews: _pics(2),
        ),
        _entry(id: 'no-pics', at: DateTime(2026, 11, 17, 8, 0)),
      ],
    );
    await tester.pumpWidget(_wrap(days: [day], tags: []));
    await tester.pump();

    expect(find.byType(JournalThumbStack), findsOneWidget);
  });

  testWidgets('untitled entry shows its lead and no title line', (
    tester,
  ) async {
    final day = JournalDay(
      day: DateTime(2026, 11, 17),
      entries: [
        _entry(
          id: 'untitled',
          at: DateTime(2026, 11, 17, 8, 0),
          body: 'Finally finished the book.',
        ),
      ],
    );
    await tester.pumpWidget(_wrap(days: [day], tags: []));
    await tester.pump();

    expect(find.byKey(const ValueKey('journal-lead')), findsOneWidget);
    expect(find.text('Finally finished the book.'), findsOneWidget);
    final lead = tester.widget<Text>(
      find.byKey(const ValueKey('journal-lead')),
    );
    expect(lead.style!.fontWeight, isNot(FontWeight.w700));
  });

  testWidgets('meta lists time, mood and every tag', (tester) async {
    final day = JournalDay(
      day: DateTime(2026, 11, 17),
      entries: [
        _entry(
          id: 'meta',
          at: DateTime(2026, 11, 17, 8, 12),
          title: 'Morning pages',
          mood: JournalMood.calm,
          tagIds: ['j1', 't1', 't2'],
        ),
      ],
    );
    await tester.pumpWidget(_wrap(days: [day], tags: [journalTag, tagA, tagB]));
    await tester.pump();

    expect(find.byType(TagChip), findsNWidgets(2));
    expect(find.byType(MoodFace), findsOneWidget);
    // The time carries no GMT suffix on the calendar card.
    expect(find.textContaining('GMT'), findsNothing);
  });

  testWidgets('every entry keeps its morph registration', (tester) async {
    await tester.pumpWidget(
      _wrap(days: [twoEntriesOn(DateTime(2026, 11, 17))], tags: []),
    );
    await tester.pump();

    expect(CardRegistry.keyFor('early').currentContext, isNotNull);
    expect(CardRegistry.keyFor('late').currentContext, isNotNull);
  });

  testWidgets('hiding one entry hides only that entry', (tester) async {
    await tester.pumpWidget(
      _wrap(days: [twoEntriesOn(DateTime(2026, 11, 17))], tags: []),
    );
    await tester.pump();

    CardRegistry.hide('early');
    await tester.pump();
    expect(opacityOf(tester, 'early'), 0);
    expect(opacityOf(tester, 'late'), 1);
    CardRegistry.show('early');
  });

  testWidgets('tapping an entry opens that note', (tester) async {
    Note? opened;
    await tester.pumpWidget(
      _wrap(
        days: [twoEntriesOn(DateTime(2026, 11, 17))],
        tags: [],
        onOpen: (note) => opened = note,
      ),
    );
    await tester.pump();

    await tester.tap(
      find.byKey(CardRegistry.keyFor('early')),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(opened, isNotNull);
    expect(opened!.id, 'early');
  });

  testWidgets('an empty day draws no header', (tester) async {
    await tester.pumpWidget(_wrap(days: const [], tags: []));
    await tester.pump();

    expect(find.textContaining('NOV'), findsNothing);
  });

  testWidgets('a day equal to today shows the TODAY pill', (tester) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    await tester.pumpWidget(
      _wrap(
        days: [
          JournalDay(
            day: today,
            entries: [
              _entry(
                id: 't',
                at: DateTime(today.year, today.month, today.day, 8, 0),
              ),
            ],
          ),
        ],
        tags: [],
      ),
    );
    await tester.pump();
    expect(find.text('TODAY'), findsOneWidget);

    await tester.pumpWidget(
      _wrap(
        days: [JournalDay(day: yesterday, entries: const [])],
        tags: [],
      ),
    );
    await tester.pump();
    expect(find.text('TODAY'), findsNothing);
  });

  testWidgets('an entry without a mood or tags shows only its time', (
    tester,
  ) async {
    final day = JournalDay(
      day: DateTime(2026, 11, 17),
      entries: [
        _entry(
          id: 'plain',
          at: DateTime(2026, 11, 17, 8, 12),
          title: 'Plain day',
          tagIds: ['j1'],
        ),
      ],
    );
    await tester.pumpWidget(_wrap(days: [day], tags: [journalTag]));
    await tester.pump();

    expect(find.byType(MoodFace), findsNothing);
    expect(find.byType(TagChip), findsNothing);
  });
}

class _Tags extends TagsController {
  _Tags(this.tags);

  final List<Tag> tags;

  @override
  Stream<List<Tag>> build() => Stream.value(tags);
}
