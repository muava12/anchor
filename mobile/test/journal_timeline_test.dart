import 'package:anchor/core/text/date_formats.dart';
import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/core/theme/app_typography.dart';
import 'package:anchor/core/theme/tokens/anchor_tokens.dart';
import 'package:anchor/features/journal/domain/journal_day.dart';
import 'package:anchor/features/journal/domain/journal_meta.dart';
import 'package:anchor/features/journal/presentation/widgets/journal_timeline.dart';
import 'package:anchor/features/journal/presentation/widgets/mood_face.dart';
import 'package:anchor/features/notes/data/repository/attachment_file_provider.dart';
import 'package:anchor/features/notes/domain/note.dart';
import 'package:anchor/features/notes/presentation/widgets/note_chips.dart';
import 'package:anchor/features/tags/domain/tag.dart';
import 'package:anchor/features/tags/presentation/tags_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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

  testWidgets('three or more pictures stack, with a count badge', (tester) async {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    final note = Note(
      id: 'n1',
      title: 'Lots of pictures',
      imagePreviewData: const [
        NoteImagePreview(attachmentId: 'a1', noteId: 'n1', filename: 'a.jpg'),
        NoteImagePreview(attachmentId: 'a2', noteId: 'n1', filename: 'b.jpg'),
        NoteImagePreview(attachmentId: 'a3', noteId: 'n1', filename: 'c.jpg'),
        NoteImagePreview(attachmentId: 'a4', noteId: 'n1', filename: 'd.jpg'),
      ],
    );
    final entry = JournalDayEntry(note: note, meta: JournalMeta(entryAt: day));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          attachmentFileProvider.overrideWith((ref, key) => '/tmp/a.jpg'),
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

    // Only the front picture is a real image; the badge carries the count.
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('the meta row shows the time, the mood face and the tag chip', (
    tester,
  ) async {
    const journalTag = Tag(id: 'j1', name: 'journal');
    const morning = Tag(id: 't1', name: 'morning');
    final content = composeJournalContent(
      JournalMeta(mood: JournalMood.calm, entryAt: _entryAt),
      'body line',
    )!;
    final note = Note(
      id: 'n1',
      title: 'Slow morning',
      content: content,
      tagIds: const ['j1', 't1'],
    );

    await tester.pumpWidget(
      _wrap(
        entry: JournalDayEntry(
          note: note,
          meta: parseJournalContent(content).meta,
        ),
        tags: const [journalTag, morning],
      ),
    );
    await tester.pump();

    expect(find.text(clockLabel(_entryAt)), findsOneWidget);
    expect(find.text('morning'), findsOneWidget);
    expect(find.text('journal'), findsNothing);

    final face = tester.widget<MoodFace>(find.byType(MoodFace));
    expect(face.mood, JournalMood.calm);
    expect(face.size, AnchorTokens.sizeIconMedium);
    expect(find.byType(TagChip), findsOneWidget);

    // One horizontal row: time, a dot, the face, a dot, the tag chip.
    final row = tester
        .widgetList<Row>(find.ancestor(of: find.byType(MoodFace), matching: find.byType(Row)))
        .firstWhere((r) => r.children.any((c) => c is MoodFace));
    expect(row.children.length, 5);
    expect(row.children[0], isA<Text>());
    expect(row.children[2], isA<MoodFace>());
    // The chip is wrapped in a Flexible so a long tag name can shrink.
    final chipSlot = row.children[4];
    expect(chipSlot, isA<Flexible>());
    expect((chipSlot as Flexible).child, isA<TagChip>());
    final time = tester.getCenter(find.text(clockLabel(_entryAt)));
    final faceAt = tester.getCenter(find.byType(MoodFace));
    final chipAt = tester.getCenter(find.byType(TagChip));
    expect(time.dy, faceAt.dy, reason: 'the row is horizontal');
    expect(time.dx < faceAt.dx, isTrue, reason: 'time before the face');
    expect(faceAt.dx < chipAt.dx, isTrue, reason: 'face before the tag chip');
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
    final content = composeJournalContent(
      JournalMeta(mood: JournalMood.calm, entryAt: _entryAt),
      'body line',
    )!;
    final note = Note(
      id: 'n1',
      title: 'Slow morning',
      content: content,
      tagIds: const ['j1', 't1'],
    );

    await tester.pumpWidget(
      _wrap(
        entry: JournalDayEntry(
          note: note,
          meta: parseJournalContent(content).meta,
        ),
        tags: const [journalTag, longTag],
      ),
    );
    await tester.pump();

    // No overflow error (Flutter would report a painted overflow stripe).
    expect(tester.takeException(), isNull);

    // The other parts survive; the chip stays inside the row's right edge.
    expect(find.text(clockLabel(_entryAt)), findsOneWidget);
    expect(find.byType(MoodFace), findsOneWidget);
    final chip = tester.getRect(find.byType(TagChip));
    final row = tester.getRect(
      find
          .ancestor(
            of: find.byType(TagChip),
            matching: find.byType(Row),
          )
          .first,
    );
    expect(chip.right, lessThanOrEqualTo(row.right + 0.01));
    expect(chip.left, greaterThanOrEqualTo(row.left));

    // The tag text is the part that gave way: it ellipsizes in the chip.
    final tagText = tester.widget<Text>(
      find
          .descendant(of: find.byType(TagChip), matching: find.byType(Text))
          .first,
    );
    expect(tagText.maxLines, 1);
    expect(tagText.overflow, TextOverflow.ellipsis);
    final paragraph = _paragraphHolding(
      tester.element(find.byType(TagChip)),
      longTag.name,
    );
    expect(paragraph, isNotNull, reason: 'the tag text is laid out');
    expect(paragraph!.didExceedMaxLines, isTrue, reason: 'the tag name is cut');
  });

  testWidgets('an entry without a mood or another tag shows only the time', (
    tester,
  ) async {
    const journalTag = Tag(id: 'j1', name: 'journal');
    final note = Note(
      id: 'n1',
      title: 'Plain day',
      content: 'plain',
      tagIds: const ['j1'],
    );

    await tester.pumpWidget(
      _wrap(
        entry: JournalDayEntry(
          note: note,
          meta: JournalMeta(entryAt: _entryAt),
        ),
        tags: const [journalTag],
      ),
    );
    await tester.pump();

    expect(find.text(clockLabel(_entryAt)), findsOneWidget);
    expect(find.byType(MoodFace), findsNothing);
    expect(find.byType(TagChip), findsNothing);
    expect(find.text('journal'), findsNothing);
  });

  testWidgets('the day label and the title use the design typography', (
    tester,
  ) async {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    final colors = AppTheme.light().extension<AnchorColors>()!;
    final note = Note(
      id: 'n1',
      title: 'Morning pages',
      content: '{"ops":[{"insert":"body line\\n"}]}',
    );
    final entry = JournalDayEntry(
      note: note,
      meta: JournalMeta(entryAt: DateTime(now.year, now.month, now.day, 9, 41)),
    );

    await tester.pumpWidget(
      ProviderScope(
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

    // The day label: 12 / w700 / appText, with a pin for today.
    final label = tester.widget<Text>(find.text('TODAY'));
    expect(label.style?.fontSize, 12);
    expect(label.style?.fontWeight, FontWeight.w700);
    expect(label.style?.color, colors.appText);
    expect(find.byIcon(LucideIcons.pin), findsOneWidget);

    // The date range beside it: caption 11.5 / 500 / tabular.
    final date = tester.widget<Text>(
      find.text(DateFormat('EEE, d MMM', dateLocale).format(day)),
    );
    expect(date.style, AppTypography.caption.tabular.copyWith(color: colors.appMuted));

    // The entry title: cardTitle, bold.
    final title = tester.widget<Text>(find.text('Morning pages'));
    expect(title.style?.fontSize, AppTypography.cardTitle.fontSize);
    expect(title.style?.fontWeight, FontWeight.w700);

    // The meta time: caption 11.5 / 500 / tabular.
    final time = tester.widget<Text>(
      find.text(clockLabel(DateTime(now.year, now.month, now.day, 9, 41))),
    );
    expect(time.style, AppTypography.caption.tabular.copyWith(color: colors.appMuted));
  });
}

final _entryAt = DateTime(2026, 11, 17, 8, 12);

/// The paragraph that draws [text], somewhere under [root].
RenderParagraph? _paragraphHolding(Element root, String text) {
  RenderParagraph? found;
  void walk(Element element) {
    final render = element.renderObject;
    if (render is RenderParagraph && render.text.toPlainText() == text) {
      found = render;
      return;
    }
    element.visitChildren(walk);
  }

  walk(root);
  return found;
}
Widget _wrap({required JournalDayEntry entry, required List<Tag> tags}) {
  return ProviderScope(
    overrides: [tagsControllerProvider.overrideWith(() => _Tags(tags))],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: CustomScrollView(
          slivers: [
            JournalTimeline(
              days: [JournalDay(day: DateTime(2026, 11, 17), entries: [entry])],
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
