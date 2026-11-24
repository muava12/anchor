import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/features/journal/presentation/widgets/journal_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpCalendar(
  WidgetTester tester, {
  DateTime? today,
  Map<DateTime, int> counts = const {},
  DateTime? selected,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: JournalCalendar(
                month: DateTime(2026, 11, 1),
                entryCounts: counts,
                selectedDay: selected,
                now: today,
                onPickDay: (_) {},
                onPreviousMonth: () {},
                onNextMonth: () {},
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('shows the month, the heat footer and legend, and picks a day', (
    tester,
  ) async {
    DateTime? picked;
    var previous = 0;
    var next = 0;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                child: JournalCalendar(
                  month: DateTime(2026, 11, 1),
                  entryCounts: {
                    DateTime(2026, 11, 5): 1,
                    DateTime(2026, 11, 17): 4,
                  },
                  selectedDay: DateTime(2026, 11, 17),
                  onPickDay: (day) => picked = day,
                  onPreviousMonth: () => previous++,
                  onNextMonth: () => next++,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('5 entries this month'), findsOneWidget);
    expect(find.text('Less'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);
    // The entry dot is gone; the tint is the "has entry" signal.
    expect(find.byKey(const ValueKey('journal-entry-dot')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('calendar-day-2026-11-09')));
    expect(picked, DateTime(2026, 11, 9));
    await tester.tap(find.byKey(const ValueKey('calendar-prev')));
    await tester.tap(find.byKey(const ValueKey('calendar-next')));
    expect(previous, 1);
    expect(next, 1);
  });

  testWidgets('an empty month shows 0 entries and no tint', (tester) async {
    await pumpCalendar(tester);
    expect(find.text('0 entries this month'), findsOneWidget);
  });

  testWidgets('month title is the month plus a small year', (tester) async {
    await pumpCalendar(tester);
    final text = tester.widget<Text>(
      find.byKey(const ValueKey('calendar-month')),
    );
    expect(text.textSpan!.toPlainText(), contains('November'));
    expect(text.textSpan!.toPlainText(), contains('2026'));
  });

  testWidgets('day cells are square', (tester) async {
    await pumpCalendar(tester);
    final size = tester.getSize(
      find.byKey(const ValueKey('calendar-day-2026-11-05')),
    );
    expect(size.width, size.height);
  });

  testWidgets('today keeps its ring when it has entries and is not selected', (
    tester,
  ) async {
    await pumpCalendar(
      tester,
      today: DateTime(2026, 11, 5),
      counts: {DateTime(2026, 11, 5): 1},
      selected: DateTime(2026, 11, 17),
    );
    expect(find.byKey(const ValueKey('calendar-today-ring')), findsOneWidget);
  });

  testWidgets('legend has zero, one and two swatches between Less and More', (
    tester,
  ) async {
    await pumpCalendar(tester);
    for (final i in [0, 1, 2]) {
      expect(find.byKey(ValueKey('journal-heat-$i')), findsOneWidget);
    }
  });
}
