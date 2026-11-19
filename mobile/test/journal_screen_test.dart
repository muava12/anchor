import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/features/journal/presentation/journal_providers.dart';
import 'package:anchor/features/journal/presentation/journal_screen.dart';
import 'package:anchor/features/journal/presentation/widgets/journal_calendar.dart';
import 'package:anchor/features/notes/domain/note.dart';
import 'package:anchor/features/tags/domain/tag.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

void main() {
  Note entry(String id, String title, String mood) => Note(
    id: id,
    title: title,
    tagIds: ['journal'],
    content: '{"ops":[{"insert":"mood: $mood\\n---\\n$title\\n"}]}',
    updatedAt: DateTime.utc(2026, 11, 17),
  );

  const tag = Tag(id: 'journal', name: 'journal');

  Future<void> pump(
    WidgetTester tester,
    List<Note> notes, {
    Tag? journalTag = tag,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          journalTagProvider.overrideWithValue(journalTag),
          journalNotesProvider.overrideWith((ref) => Stream.value(notes)),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const JournalScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the timeline entries', (tester) async {
    await pump(tester, [entry('a', 'Morning pages', 'good')]);
    expect(find.text('Morning pages'), findsOneWidget);
  });

  testWidgets('the calendar action shows the month grid', (tester) async {
    await pump(tester, [entry('a', 'Morning pages', 'good')]);
    await tester.tap(find.byIcon(LucideIcons.calendarDays));
    await tester.pump();
    expect(find.byType(JournalCalendar), findsOneWidget);
  });

  testWidgets('the top bar shows the calendar and grid icons', (tester) async {
    await pump(tester, [entry('a', 'Morning pages', 'good')]);
    expect(find.byIcon(LucideIcons.calendarDays), findsOneWidget);
    expect(find.byIcon(LucideIcons.layoutGrid), findsOneWidget);
    expect(find.byIcon(LucideIcons.rows3), findsNothing);
  });

  testWidgets('tapping the calendar icon twice returns to the timeline', (
    tester,
  ) async {
    await pump(tester, [entry('a', 'Morning pages', 'good')]);
    await tester.tap(find.byIcon(LucideIcons.calendarDays));
    await tester.pump();
    expect(find.byType(JournalCalendar), findsOneWidget);
    expect(find.byIcon(LucideIcons.rows3), findsOneWidget);
    await tester.tap(find.byIcon(LucideIcons.rows3));
    await tester.pump();
    expect(find.byType(JournalCalendar), findsNothing);
    expect(find.byIcon(LucideIcons.calendarDays), findsOneWidget);
  });

  testWidgets('the grid icon has no effect', (tester) async {
    await pump(tester, [entry('a', 'Morning pages', 'good')]);
    await tester.tap(find.byIcon(LucideIcons.layoutGrid));
    await tester.pump();
    expect(find.byType(JournalCalendar), findsNothing);
    expect(find.byIcon(LucideIcons.calendarDays), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a missing tag shows the empty state', (tester) async {
    await pump(tester, const [], journalTag: null);
    expect(find.text('No entries yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping an entry navigates to the journal edit route', (
    tester,
  ) async {
    final note = entry('a', 'Morning pages', 'good');
    final router = GoRouter(
      initialLocation: '/journal',
      routes: [
        GoRoute(
          path: '/journal',
          builder: (_, _) => const JournalScreen(),
        ),
        GoRoute(
          path: '/journal/edit/:id',
          builder: (_, state) =>
              Text('journal-edit-${state.pathParameters['id']}'),
        ),
        GoRoute(
          path: '/note/:id',
          builder: (_, state) =>
              Text('note-${state.pathParameters['id']}'),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          journalTagProvider.overrideWithValue(tag),
          journalNotesProvider.overrideWith((ref) => Stream.value([note])),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Morning pages'));
    await tester.pumpAndSettle();

    expect(find.text('journal-edit-a'), findsOneWidget);
    expect(find.text('note-a'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
