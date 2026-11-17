import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/features/journal/domain/journal_day.dart';
import 'package:anchor/features/journal/domain/journal_meta.dart';
import 'package:anchor/features/journal/presentation/widgets/journal_day_cards.dart';
import 'package:anchor/features/notes/domain/note.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the day header, its entry count, and a card per entry', (
    tester,
  ) async {
    final entryAt = DateTime(2026, 11, 17, 8, 12);
    final note = Note(
      id: 'n1',
      title: 'Morning pages',
      content: '{"ops":[{"insert":"Coffee on the balcony.\\n"}]}',
    );
    final entry = JournalDayEntry(
      note: note,
      meta: JournalMeta(entryAt: entryAt),
    );
    Note? opened;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                JournalDayCards(
                  days: [
                    JournalDay(
                      day: DateTime(2026, 11, 17),
                      entries: [entry],
                    ),
                  ],
                  onOpen: (n) => opened = n,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('TUE, NOV 17'), findsOneWidget);
    expect(find.text('1 entry'), findsOneWidget);
    expect(find.text('Morning pages'), findsOneWidget);
    expect(find.text('Coffee on the balcony.'), findsOneWidget);

    await tester.tap(find.text('Morning pages'));
    await tester.pump();
    expect(opened, note);
  });

  testWidgets('an empty day draws no header', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: CustomScrollView(
              slivers: [JournalDayCards(days: const [], onOpen: (_) {})],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('NOV'), findsNothing);
  });
}