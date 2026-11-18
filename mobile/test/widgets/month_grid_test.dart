import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/core/widgets/app_buttons.dart';
import 'package:anchor/features/reminders/presentation/month_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpAugust(WidgetTester tester, Locale locale) =>
      tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          locale: locale,
          supportedLocales: [locale],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Material(
            child: MonthGrid(
              month: DateTime(2026, 8),
              selected: null,
              now: DateTime(2026, 7),
              onDay: (_) {},
              onMonth: (_) {},
            ),
          ),
        ),
      );

  /// The day the last test tapped, when the grid accepted it.
  DateTime? picked;

  /// The month the last test asked to show, from the back or next arrow.
  DateTime? asked;

  Future<void> pumpMonth(
    WidgetTester tester,
    Locale locale,
    DateTime month, {
    bool allowPastDays = false,
  }) {
    picked = null;
    asked = null;
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: locale,
        supportedLocales: [locale],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Material(
          child: MonthGrid(
            month: month,
            selected: null,
            now: DateTime(2026, 9, 18),
            allowPastDays: allowPastDays,
            onDay: (day) => picked = day,
            onMonth: (next) => asked = next,
          ),
        ),
      ),
    );
  }

  double leftOf(WidgetTester tester, String day) =>
      tester.getRect(find.bySemanticsLabel(day)).left;

  testWidgets('weeks start on Sunday in US English', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpAugust(tester, const Locale('en', 'US'));

    expect(
      leftOf(tester, 'Sunday, July 26'),
      lessThan(leftOf(tester, 'Monday, July 27')),
    );
    expect(
      tester.getRect(find.bySemanticsLabel('Saturday, August 1')).top,
      tester.getRect(find.bySemanticsLabel('Sunday, July 26')).top,
    );
    expect(find.text('S'), findsNWidgets(2));
    semantics.dispose();
  });

  testWidgets('past days are disabled unless allowPastDays', (tester) async {
    // August 2026 with now September 2026: every August day is past.
    await pumpMonth(tester, const Locale('en', 'GB'), DateTime(2026, 8));
    await tester.tap(
      find.bySemanticsLabel('Monday, August 3'),
      warnIfMissed: false,
    );
    expect(picked, isNull, reason: 'default keeps past days disabled');
  });

  testWidgets('allowPastDays makes a past day pickable', (tester) async {
    await pumpMonth(
      tester,
      const Locale('en', 'GB'),
      DateTime(2026, 8),
      allowPastDays: true,
    );
    await tester.tap(find.bySemanticsLabel('Monday, August 3'));
    await tester.pump();

    expect(picked, isNotNull);
    expect(picked!.month, 8);
    expect(picked!.day, 3);
  });

  testWidgets('allowPastDays makes past months reachable', (tester) async {
    await pumpMonth(
      tester,
      const Locale('en', 'GB'),
      DateTime(2026, 9),
      allowPastDays: true,
    );

    // The back arrow is live and asks for August.
    final back = tester.widget<BarButton>(find.byType(BarButton).first);
    expect(back.onPressed, isNotNull);
    back.onPressed!();

    expect(asked, DateTime(2026, 8));
  });

  testWidgets('the back arrow is dead in the current month by default', (
    tester,
  ) async {
    await pumpMonth(tester, const Locale('en', 'GB'), DateTime(2026, 9));

    expect(
      tester.widget<BarButton>(find.byType(BarButton).first).onPressed,
      isNull,
    );
  });

  testWidgets('weeks start on Monday where the locale does', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpAugust(tester, const Locale('en', 'GB'));

    expect(find.bySemanticsLabel('Sunday, July 26'), findsNothing);
    expect(
      leftOf(tester, 'Monday, July 27'),
      lessThan(leftOf(tester, 'Tuesday, July 28')),
    );
    expect(
      tester.getRect(find.bySemanticsLabel('Sunday, August 2')).top,
      tester.getRect(find.bySemanticsLabel('Monday, July 27')).top,
    );
    semantics.dispose();
  });
}
