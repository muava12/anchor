import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/core/theme/context_extensions.dart';
import 'package:anchor/core/widgets/selection_ring.dart';
import 'package:anchor/features/journal/domain/journal_meta.dart';
import 'package:anchor/features/journal/presentation/widgets/journal_mood_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> openSheet(WidgetTester tester, {JournalMood? selected}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => showJournalMoodSheet(
                  context,
                  selected: selected,
                  onPick: (_) {},
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  /// Counts the [SelectionRing]s that are shown, so the selected tile is one
  /// ring. With [label] it counts only the ring on that tile.
  int shownRings(WidgetTester tester, {String? label}) {
    final finder = label == null
        ? find.byType(SelectionRing)
        : find.ancestor(
            of: find.text(label),
            matching: find.byType(SelectionRing),
          );
    return tester
        .widgetList<SelectionRing>(finder)
        .where((ring) => ring.isShown)
        .length;
  }

  testWidgets('shows the title, the subtitle and all 12 moods', (tester) async {
    await openSheet(tester);

    expect(find.text('How are you feeling?'), findsOneWidget);
    expect(find.text('Pick a mood for this entry'), findsOneWidget);
    expect(find.text('Happy'), findsOneWidget);
    expect(find.text('Calm'), findsOneWidget);
    expect(find.text('Sick'), findsOneWidget);
    expect(find.text('Clear mood'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('tapping a mood fires onPick with it', (tester) async {
    JournalMood? picked;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => showJournalMoodSheet(
                  context,
                  selected: null,
                  onPick: (mood) => picked = mood,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Calm'));
    expect(picked, JournalMood.calm);
  });

  testWidgets('tapping a second mood moves the selection to it', (
    tester,
  ) async {
    final picked = <JournalMood?>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => showJournalMoodSheet(
                  context,
                  selected: JournalMood.happy,
                  onPick: picked.add,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(shownRings(tester), 1);

    await tester.tap(find.text('Calm'));
    await tester.pumpAndSettle();

    expect(picked, [JournalMood.calm]);
    expect(shownRings(tester), 1);
    expect(shownRings(tester, label: 'Calm'), 1);
    expect(shownRings(tester, label: 'Happy'), 0);
  });

  testWidgets('Clear mood drops the selection ring', (tester) async {
    await openSheet(tester, selected: JournalMood.tired);
    expect(shownRings(tester), 1);

    await tester.tap(find.text('Clear mood'));
    await tester.pumpAndSettle();

    expect(shownRings(tester), 0);
  });

  testWidgets('Clear mood fires onClear and onPick(null)', (tester) async {
    var cleared = 0;
    JournalMood? picked;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => showJournalMoodSheet(
                  context,
                  selected: JournalMood.tired,
                  onPick: (mood) => picked = mood,
                  onClear: () => cleared++,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Clear mood'));
    expect(cleared, 1);
    expect(picked, isNull);
  });

  testWidgets('Done closes the sheet', (tester) async {
    await openSheet(tester);
    expect(find.text('How are you feeling?'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('How are you feeling?'), findsNothing);
    expect(find.text('Open'), findsOneWidget);
  });

  testWidgets('unselected tiles show a resting appBorder', (tester) async {
    // No selection, so every one of the 12 tiles is unselected.
    await openSheet(tester);
    final colors = tester.element(find.byType(SelectionRing).first).anchor;

    // The visible resting card edge: a hairline in appBorder on each tile.
    // Without it the faces + labels float on the appSurface sheet.
    final tiles = find.descendant(
      of: find.byType(SelectionRing),
      matching: find.byType(AnimatedContainer),
    );
    expect(tiles, findsNWidgets(JournalMood.values.length));

    for (final tile in tester.widgetList<AnimatedContainer>(tiles)) {
      final border = (tile.decoration! as BoxDecoration).border;
      expect(border, isNotNull, reason: 'each tile needs a resting border');
      expect((border! as Border).top.color, colors.appBorder);
    }
  });
}