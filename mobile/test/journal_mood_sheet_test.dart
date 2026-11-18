import 'package:anchor/core/theme/app_theme.dart';
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
}