import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/core/widgets/app_buttons.dart';
import 'package:anchor/features/journal/presentation/widgets/journal_date_time_sheet.dart';
import 'package:anchor/features/reminders/presentation/month_grid.dart';
import 'package:anchor/features/reminders/presentation/time_wheel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// The sheet opened by [openSheet]. Awaiting it waits for the pop.
  late Future<DateTime?> sheet;

  Future<void> openSheet(
    WidgetTester tester, {
    required DateTime initial,
    Size screen = const Size(1170, 2532),
  }) async {
    // A phone-sized surface: the sheet holds the grid and the wheel.
    tester.view.physicalSize = screen;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    late BuildContext appContext;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              appContext = context;
              return const Center(child: Text('Home'));
            },
          ),
        ),
      ),
    );
    final result = showJournalDateTimeSheet(appContext, initial: initial);
    await tester.pumpAndSettle();
    sheet = result;
  }

  testWidgets('shows the title, a month grid and a time wheel', (
    tester,
  ) async {
    await openSheet(tester, initial: DateTime(2026, 12, 20, 9, 30));

    expect(find.text('Date & time'), findsOneWidget);
    expect(find.byType(MonthGrid), findsOneWidget);
    expect(find.byType(TimeWheel), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('Save returns the picked day with the picked hour and minute', (
    tester,
  ) async {
    await openSheet(tester, initial: DateTime(2026, 12, 20, 9, 30));

    // The day: Future 12 December 2026 sits in the open grid.
    await tester.tap(
      find.descendant(of: find.byType(MonthGrid), matching: find.text('12')),
    );
    await tester.pumpAndSettle();

    // The time: the wheel starts at the initial hour and minute.
    final at = tester.widget<TimeWheel>(find.byType(TimeWheel)).at;
    expect(at.hour, 9);
    expect(at.minute, 30);
    await tester.drag(find.byType(TimeWheel), const Offset(0, -120));
    await tester.pumpAndSettle();

    final pickedTime = tester.widget<TimeWheel>(find.byType(TimeWheel)).at;

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final picked = await sheet;
    expect(picked, isNotNull);
    expect(
      picked,
      DateTime(2026, 12, 12, pickedTime.hour, pickedTime.minute),
    );
  });

  testWidgets('Cancel returns null', (tester) async {
    await openSheet(tester, initial: DateTime(2026, 12, 20, 9, 30));

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(await sheet, isNull);
  });

  testWidgets('a past day can be picked (back-dating)', (tester) async {
    // March 2026 is months before today, so every day in the open grid is past.
    await openSheet(tester, initial: DateTime(2026, 3, 20, 9, 30));

    await tester.tap(
      find.descendant(of: find.byType(MonthGrid), matching: find.text('15')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final picked = await sheet;
    expect(picked, isNotNull);
    expect(picked!.month, 3);
    expect(picked.day, 15);
  });

  testWidgets('an earlier month can be reached (back-dating)', (tester) async {
    await openSheet(tester, initial: DateTime(2026, 3, 20, 9, 30));

    await tester.tap(_previousMonth(tester));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: find.byType(MonthGrid), matching: find.text('20')),
      findsOneWidget,
      reason: 'the grid still draws days in February 2026',
    );

    await tester.tap(
      find.descendant(of: find.byType(MonthGrid), matching: find.text('15')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final picked = await sheet;
    expect(picked, isNotNull);
    expect(picked!.month, 2);
    expect(picked.day, 15);
  });

  testWidgets('the body scrolls on a short screen', (tester) async {
    // 320x568 logical: the smallest phone we support.
    await openSheet(
      tester,
      initial: DateTime(2026, 3, 20, 9, 30),
      screen: const Size(960, 1704),
    );

    expect(tester.takeException(), isNull);
    // The grid and the wheel sit inside one scroll view.
    expect(
      find.descendant(
        of: find.byType(SingleChildScrollView),
        matching: find.byType(MonthGrid),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(SingleChildScrollView),
        matching: find.byType(TimeWheel),
      ),
      findsOneWidget,
    );
    // The header and the footer stay outside the scroll, always reachable.
    expect(
      find.descendant(
        of: find.byType(SingleChildScrollView),
        matching: find.text('Save'),
      ),
      findsNothing,
    );
    expect(find.text('Date & time'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });
}

/// The back arrow of the open [MonthGrid].
Finder _previousMonth(WidgetTester tester) => find
    .descendant(of: find.byType(MonthGrid), matching: find.byType(BarButton))
    .first;