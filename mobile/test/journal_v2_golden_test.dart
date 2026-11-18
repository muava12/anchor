// Golden (pixel) tests for the Journal v2 UI.
//
// These render the v2 widgets with the real app fonts and compare against
// the checked-in goldens under test/goldens/. Run `rflutter test` to verify;
// `rflutter test --update-goldens` to regenerate after an intentional change.
//
// The goldens are generated on the Linux test host; keep them in step with
// the Flutter version the host runs.

import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/features/journal/domain/journal_day.dart';
import 'package:anchor/features/journal/domain/journal_meta.dart';
import 'package:anchor/features/journal/presentation/journal_providers.dart';
import 'package:anchor/features/journal/presentation/widgets/journal_day_cards.dart';
import 'package:anchor/features/journal/presentation/widgets/journal_stats_row.dart';
import 'package:anchor/features/journal/presentation/widgets/journal_timeline.dart';
import 'package:anchor/features/journal/presentation/widgets/mood_face.dart';
import 'package:anchor/features/notes/domain/note.dart';
import 'package:anchor/features/tags/domain/tag.dart';
import 'package:anchor/features/tags/presentation/tags_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads the app's bundled fonts so goldens render the real type, not Ahem.
Future<void> _loadAppFonts() async {
  Future<void> load(String family, List<String> paths) async {
    final loader = FontLoader(family);
    for (final path in paths) {
      final data = await rootBundle.load(path);
      loader.addFont(Future.value(data));
    }
    await loader.load();
  }

  await load('DM Sans', ['assets/fonts/DMSans-Variable.ttf']);
  await load('Manrope', ['assets/fonts/Manrope-Variable.ttf']);
  await load('Playfair Display', ['assets/fonts/PlayfairDisplay-Bold.ttf']);
  await load('Literata', [
    'assets/fonts/Literata-Regular.ttf',
    'assets/fonts/Literata-Bold.ttf',
  ]);
  await load('JetBrains Mono', [
    'assets/fonts/JetBrainsMono-Regular.ttf',
    'assets/fonts/JetBrainsMono-Bold.ttf',
  ]);
}

class _Tags extends TagsController {
  _Tags(this.tags);
  final List<Tag> tags;
  @override
  Stream<List<Tag>> build() => Stream.value(tags);
}

const _journalTag = Tag(id: 'journal', name: 'journal');
const _travelTag = Tag(id: 't1', name: 'travel');
final _tags = [_journalTag, _travelTag];

/// Pumps [sliver] in a phone-sized, light-theme scroll view.
Future<void> _pumpPhone(WidgetTester tester, Widget sliver) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tagsControllerProvider.overrideWith(() => _Tags(_tags)),
        journalTagProvider.overrideWithValue(_journalTag),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: CustomScrollView(slivers: [sliver])),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// A journal entry with an optional mood and tag list.
JournalDayEntry _entry({JournalMood? mood, List<String> tagIds = const []}) {
  final at = DateTime(2026, 11, 17, 9, 41);
  final content = composeJournalContent(JournalMeta(mood: mood, entryAt: at), 'body line')!;
  return JournalDayEntry(
    note: Note(
      id: 'n1',
      title: 'Morning pages',
      content: content,
      tagIds: tagIds,
    ),
    meta: JournalMeta(mood: mood, entryAt: at),
  );
}

void main() {
  setUpAll(_loadAppFonts);

  testWidgets('journal timeline: mood + tag meta row', (tester) async {
    await _pumpPhone(
      tester,
      JournalTimeline(
        days: [
          JournalDay(
            day: DateTime(2026, 11, 17),
            entries: [_entry(mood: JournalMood.calm, tagIds: ['journal', 't1'])],
          ),
        ],
        onOpen: (_) {},
      ),
    );
    await expectLater(
      find.byType(JournalTimeline),
      matchesGoldenFile('goldens/journal_timeline.png'),
    );
  });

  testWidgets('journal day cards: mood chip + tag', (tester) async {
    await _pumpPhone(
      tester,
      JournalDayCards(
        days: [
          JournalDay(
            day: DateTime(2026, 11, 17),
            entries: [_entry(mood: JournalMood.calm, tagIds: ['journal', 't1'])],
          ),
        ],
        journalTagId: 'journal',
        onOpen: (_) {},
      ),
    );
    await expectLater(
      find.byType(JournalDayCards),
      matchesGoldenFile('goldens/journal_day_cards.png'),
    );
  });

  testWidgets('journal stats row: streak + on-this-day + throwback', (
    tester,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    await _pumpPhone(
      tester,
      SliverToBoxAdapter(
        child: JournalStatsRow(
          days: [
            JournalDay(day: today, entries: [_entry()]),
            JournalDay(day: DateTime(today.year, today.month, today.day - 1), entries: [_entry()]),
            JournalDay(day: DateTime(today.year, today.month, today.day - 2), entries: [_entry()]),
            JournalDay(day: DateTime(today.year - 1, today.month, today.day), entries: [_entry()]),
          ],
        ),
      ),
    );
    await expectLater(
      find.byType(JournalStatsRow),
      matchesGoldenFile('goldens/journal_stats_row.png'),
    );
  });
}