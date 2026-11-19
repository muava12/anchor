import 'dart:math' as math;

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

    expect(find.textContaining('TODAY,'), findsOneWidget);
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

  testWidgets('a picture is 56, the size the token sets', (tester) async {
    expect(AnchorTokens.sizeJournalThumb, 56);

    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    final note = Note(
      id: 'n1',
      title: 'With a picture',
      imagePreviewData: const [
        NoteImagePreview(attachmentId: 'a1', noteId: 'n1', filename: 'pic.jpg'),
      ],
    );
    final entry = JournalDayEntry(note: note, meta: JournalMeta(entryAt: day));

    await tester.pumpWidget(
      _wrapTimeline(
        entry: entry,
        files: const {'a1': '/tmp/pic.jpg'},
      ),
    );
    await tester.pump();

    final image = tester.widget<Image>(find.byType(Image));
    expect(_filePathOf(image.image), '/tmp/pic.jpg');
    expect(tester.getSize(find.byType(Image)), const Size(56, 56));
  });

  testWidgets('a stack of three fans the back cards, no count badge', (
    tester,
  ) async {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    final note = Note(
      id: 'n1',
      title: 'Three pictures',
      imagePreviewData: const [
        NoteImagePreview(attachmentId: 'a1', noteId: 'n1', filename: 'a.jpg'),
        NoteImagePreview(attachmentId: 'a2', noteId: 'n1', filename: 'b.jpg'),
        NoteImagePreview(attachmentId: 'a3', noteId: 'n1', filename: 'c.jpg'),
      ],
    );
    final entry = JournalDayEntry(note: note, meta: JournalMeta(entryAt: day));

    await tester.pumpWidget(
      _wrapTimeline(
        entry: entry,
        files: const {
          'a1': '/tmp/a.jpg',
          'a2': '/tmp/b.jpg',
          'a3': '/tmp/c.jpg',
        },
      ),
    );
    await tester.pump();

    // Every card in the stack is a real image, not a blank swatch.
    final paths = tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => _filePathOf(image.image))
        .toList();
    expect(paths.length, 3);
    expect(paths.toSet(), {'/tmp/a.jpg', '/tmp/b.jpg', '/tmp/c.jpg'});
    for (final image in tester.widgetList<Image>(find.byType(Image))) {
      expect(tester.getSize(find.byWidget(image)), const Size(56, 56));
    }

    // The design fans the stack: the back cards rotate and fade. The tree
    // order is the furthest card first, then the middle one, then the front.
    final images = tester.widgetList<Image>(find.byType(Image)).toList();
    expect(images.length, 3);
    expect(_angleAbove(tester, images[0]), closeTo(0.13, 1e-9));
    expect(_opacityAbove(tester, images[0]), closeTo(0.7, 1e-9));
    expect(_angleAbove(tester, images[1]), closeTo(-0.07, 1e-9));
    expect(_opacityAbove(tester, images[1]), closeTo(0.8, 1e-9));
    // The front card is square-on and solid.
    expect(_angleAbove(tester, images[2]), 0);
    expect(_opacityAbove(tester, images[2]), 1);

    // The stack carries no count badge.
    expect(find.text('3'), findsNothing);
    expect(find.byIcon(LucideIcons.image), findsNothing);
  });

  testWidgets('four pictures still stack three, with no count badge', (
    tester,
  ) async {
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
      _wrapTimeline(
        entry: entry,
        files: const {
          'a1': '/tmp/a.jpg',
          'a2': '/tmp/b.jpg',
          'a3': '/tmp/c.jpg',
          'a4': '/tmp/d.jpg',
        },
      ),
    );
    await tester.pump();

    expect(find.byType(Image), findsNWidgets(3));
    expect(find.text('4'), findsNothing);
    expect(find.byIcon(LucideIcons.image), findsNothing);
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

    // The day header: one line "TODAY, 17 NOV 2026", dayHeader 18 / w700 /
    // appText. No pin, no separate date range.
    final header = tester.widget<Text>(find.textContaining('TODAY,'));
    expect(header.style?.fontSize, AppTypography.dayHeader.fontSize);
    expect(header.style?.fontWeight, FontWeight.w700);
    expect(header.style?.color, colors.appText);
    expect(find.byIcon(LucideIcons.pin), findsNothing);

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

Widget _wrapTimeline({
  required JournalDayEntry entry,
  required Map<String, String> files,
}) {
  return ProviderScope(
    overrides: [
      attachmentFileProvider.overrideWith(
        (ref, key) => files[key.attachmentId],
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: CustomScrollView(
          slivers: [
            JournalTimeline(
              days: [
                JournalDay(
                  day: DateTime(entry.meta.entryAt!.year, entry.meta.entryAt!.month, entry.meta.entryAt!.day),
                  entries: [entry],
                ),
              ],
              onOpen: (_) {},
            ),
          ],
        ),
      ),
    ),
  );
}

final _entryAt = DateTime(2026, 11, 17, 8, 12);

/// The file path an [ImageProvider] draws, through any `cacheWidth` wrapper.
String _filePathOf(ImageProvider provider) {
  var current = provider;
  while (current is ResizeImage) {
    current = current.imageProvider;
  }
  return (current as FileImage).file.path;
}

/// The z-rotation above [image], in radians; 0 when nothing rotates it.
double _angleAbove(WidgetTester tester, Image image) {
  final finder = find.ancestor(
    of: find.byWidget(image),
    matching: find.byType(Transform),
  );
  if (finder.evaluate().isEmpty) return 0;
  final matrix = tester.widget<Transform>(finder.first).transform;
  return math.atan2(matrix[1], matrix[0]);
}

/// The opacity above [image]; 1 when nothing fades it.
double _opacityAbove(WidgetTester tester, Image image) {
  final finder = find.ancestor(
    of: find.byWidget(image),
    matching: find.byType(Opacity),
  );
  if (finder.evaluate().isEmpty) return 1;
  return tester.widget<Opacity>(finder.first).opacity;
}

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
