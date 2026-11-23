import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/features/journal/domain/journal_day.dart';
import 'package:anchor/features/journal/domain/journal_meta.dart';
import 'package:anchor/features/journal/domain/journal_stats.dart';
import 'package:anchor/features/journal/presentation/widgets/journal_stats_row.dart';
import 'package:anchor/features/notes/domain/note.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Note note(String id) {
  return Note(id: id, title: id, content: '{"ops":[{"insert":"$id\n"}]}');
}

JournalDayEntry entry(String id, DateTime at) {
  return JournalDayEntry(
    note: note(id),
    meta: JournalMeta(entryAt: at),
  );
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
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  /// [n] consecutive entry days ending today.
  List<JournalDay> daysWithStreak(int n) => [
    for (var i = 0; i < n; i++)
      JournalDay(
        day: DateTime(today.year, today.month, today.day - i),
        entries: [
          entry('s$i', DateTime(today.year, today.month, today.day - i)),
        ],
      ),
  ];

  /// A day [yearsAgo] on today's month-day, with [entries] entries.
  List<JournalDay> daysWithThrowback({required int yearsAgo, int entries = 1}) {
    final day = DateTime(now.year - yearsAgo, now.month, now.day);
    return [
      JournalDay(
        day: day,
        entries: [for (var i = 0; i < entries; i++) entry('t$i', day)],
      ),
    ];
  }

  group('journal stats domain', () {
    test('throwback is the nearest prior year with its entry count', () {
      final days = [
        JournalDay(
          day: DateTime(2025, 11, 23),
          entries: [
            entry('a', DateTime(2025, 11, 23)),
            entry('b', DateTime(2025, 11, 23)),
          ],
        ),
        JournalDay(
          day: DateTime(2024, 11, 23),
          entries: [entry('c', DateTime(2024, 11, 23))],
        ),
      ];
      expect(journalThrowbackOf(days, DateTime(2026, 11, 23)), (
        year: 2025,
        entryCount: 2,
      ));
    });

    test('a leap-day entry gives no throwback on 28 Feb of a common year', () {
      final days = [
        JournalDay(
          day: DateTime(2024, 2, 29),
          entries: [entry('a', DateTime(2024, 2, 29))],
        ),
      ];
      expect(journalThrowbackOf(days, DateTime(2027, 2, 28)), isNull);
    });

    test('streak needs two days', () {
      final today = DateTime(2026, 11, 23);
      expect(
        journalStreakOf([
          JournalDay(day: today, entries: [entry('a', today)]),
        ], today),
        isNull,
      );
    });
  });

  testWidgets('today tile shows the date and the streak badge', (tester) async {
    await pump(tester, daysWithStreak(3));
    expect(find.byKey(const ValueKey('journal-tile-today')), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('3 days'), findsOneWidget);
  });

  testWidgets('throwback tile shows count and years ago', (tester) async {
    // On 29 Feb of a leap year the clamped prior year throws no throwback.
    if (now.month == 2 && now.day == 29) return;
    await pump(tester, daysWithThrowback(yearsAgo: 2, entries: 2));
    expect(find.text('Throwback'), findsOneWidget);
    expect(find.text('2 entries'), findsOneWidget);
    expect(find.text('2 years ago'), findsOneWidget);
  });

  testWidgets('no throwback hides the tile; no streak hides the badge', (
    tester,
  ) async {
    await pump(tester, [
      JournalDay(day: today, entries: [entry('t', today)]),
    ]);
    expect(find.byKey(const ValueKey('journal-tile-throwback')), findsNothing);
    expect(find.textContaining(RegExp(r'\d+ days?$')), findsNothing);
  });
}
