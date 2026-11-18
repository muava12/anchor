import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/features/journal/domain/journal_day.dart';
import 'package:anchor/features/journal/domain/journal_meta.dart';
import 'package:anchor/features/journal/presentation/widgets/journal_stats_row.dart';
import 'package:anchor/features/notes/domain/note.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Note note(String id) {
  return Note(
    id: id,
    title: id,
    content: '{"ops":[{"insert":"$id\n"}]}',
  );
}

JournalDayEntry entry(String id, DateTime at) {
  return JournalDayEntry(note: note(id), meta: JournalMeta(entryAt: at));
}

Future<void> pump(WidgetTester tester, List<JournalDay> days) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: JournalStatsRow(days: days)),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets(
    'renders all three cards when streak, on-this-day and throwback data exist',
    (tester) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = DateTime(now.year, now.month, now.day - 1);
      final dayBefore = DateTime(now.year, now.month, now.day - 2);
      final priorYear = DateTime(now.year - 1, now.month, now.day);
      final olderYear = DateTime(now.year - 2, now.month, now.day);

      await pump(tester, [
        JournalDay(day: today, entries: [entry('today', today)]),
        JournalDay(day: yesterday, entries: [entry('y', yesterday)]),
        JournalDay(day: dayBefore, entries: [entry('db', dayBefore)]),
        JournalDay(day: priorYear, entries: [entry('py', priorYear)]),
        JournalDay(day: olderYear, entries: [entry('oy', olderYear)]),
      ]);

      expect(find.text('On this day'), findsOneWidget);
      expect(find.text('3-day streak'), findsOneWidget);
      expect(find.text('Throwback · ${priorYear.year}'), findsOneWidget);
    },
  );

  testWidgets('renders nothing when no stat data exists', (tester) async {
    final now = DateTime.now();
    final old = DateTime(now.year - 1, now.month, now.day == 1 ? 2 : 1);

    await pump(tester, [
      JournalDay(day: old, entries: [entry('old', old)]),
    ]);

    expect(find.text('On this day'), findsNothing);
    expect(find.textContaining('streak'), findsNothing);
    expect(find.textContaining('Throwback'), findsNothing);
    expect(find.byType(Row), findsNothing);
  });

  testWidgets('streak of one (only today) shows no streak card', (
    tester,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    await pump(tester, [
      JournalDay(day: today, entries: [entry('today', today)]),
    ]);

    expect(find.textContaining('streak'), findsNothing);
  });

  testWidgets('streak ending yesterday (today empty) still counts', (
    tester,
  ) async {
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final dayBefore = DateTime(now.year, now.month, now.day - 2);

    await pump(tester, [
      JournalDay(day: yesterday, entries: [entry('y', yesterday)]),
      JournalDay(day: dayBefore, entries: [entry('db', dayBefore)]),
    ]);

    expect(find.text('2-day streak'), findsOneWidget);
  });
}