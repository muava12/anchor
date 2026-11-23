import 'dart:convert';

import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/features/journal/domain/journal_day.dart';
import 'package:anchor/features/journal/domain/journal_meta.dart';
import 'package:anchor/features/journal/presentation/widgets/journal_card_shell.dart';
import 'package:anchor/features/journal/presentation/widgets/journal_day_card.dart';
import 'package:anchor/features/notes/domain/note.dart';
import 'package:anchor/features/notes/presentation/widgets/card_registry.dart';
import 'package:anchor/features/tags/domain/tag.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

String _ops(String body) => jsonEncode({
  'ops': [
    {'insert': body},
  ],
});

JournalDay dayWith(List<(String, DateTime)> specs) {
  final first = specs.first.$2;
  return JournalDay(
    day: DateTime(first.year, first.month, first.day),
    // Newest first, as groupJournalDays stores the day's entries.
    entries: [
      for (final (label, at) in specs)
        JournalDayEntry(
          note: Note(id: label, title: label, content: _ops('$label body')),
          meta: JournalMeta(entryAt: at),
        ),
    ],
  );
}

void _noOpen(Note note) {}

Future<void> pumpDay(
  WidgetTester tester,
  JournalDay day, {
  List<Tag> tags = const [],
  String? journalTagId,
  void Function(Note) onOpen = _noOpen,
}) async {
  tester.view.physicalSize = const Size(360, 740);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: JournalDayCard(
                  day: day,
                  tags: tags,
                  journalTagId: journalTagId,
                  onOpen: onOpen,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

double opacityOf(WidgetTester tester, String noteId) {
  final boundary = find.byKey(CardRegistry.keyFor(noteId));
  final opacity = tester.widget<Opacity>(
    find.ancestor(of: boundary, matching: find.byType(Opacity)).first,
  );
  return opacity.opacity;
}

void main() {
  testWidgets(
    'two entries: one shell, one divider, oldest first, each registered',
    (tester) async {
      await pumpDay(
        tester,
        dayWith([
          ('late', DateTime(2026, 11, 15, 17, 40)),
          ('early', DateTime(2026, 11, 15, 8, 30)),
        ]),
      );
      expect(find.byType(JournalCardShell), findsOneWidget);
      expect(
        find.byKey(const ValueKey('journal-card-divider-1')),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(find.text('early')).dy,
        lessThan(tester.getTopLeft(find.text('late')).dy),
      );
      expect(CardRegistry.keyFor('early').currentContext, isNotNull);
      expect(CardRegistry.keyFor('late').currentContext, isNotNull);
    },
  );

  testWidgets('three entries: two keyed dividers, no crash, all registered', (
    tester,
  ) async {
    await pumpDay(
      tester,
      dayWith([
        ('c', DateTime(2026, 11, 15, 20, 0)),
        ('b', DateTime(2026, 11, 15, 14, 0)),
        ('a', DateTime(2026, 11, 15, 8, 0)),
      ]),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(JournalCardShell), findsOneWidget);
    expect(
      find.byKey(const ValueKey('journal-card-divider-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('journal-card-divider-2')),
      findsOneWidget,
    );
    for (final id in ['a', 'b', 'c']) {
      expect(CardRegistry.keyFor(id).currentContext, isNotNull);
    }
    expect(
      tester.getTopLeft(find.text('a')).dy,
      lessThan(tester.getTopLeft(find.text('c')).dy),
    );
  });

  testWidgets('single entry: the registered boundary wraps the whole card', (
    tester,
  ) async {
    await pumpDay(tester, dayWith([('only', DateTime(2026, 11, 19, 8, 12))]));
    expect(
      find.descendant(
        of: find.byKey(CardRegistry.keyFor('only')),
        matching: find.byType(JournalCardShell),
      ),
      findsOneWidget,
    );
  });

  testWidgets('hiding one entry hides only that entry', (tester) async {
    await pumpDay(
      tester,
      dayWith([
        ('b', DateTime(2026, 11, 15, 17, 40)),
        ('a', DateTime(2026, 11, 15, 8, 30)),
      ]),
    );
    CardRegistry.hide('a');
    await tester.pump();
    expect(opacityOf(tester, 'a'), 0);
    expect(opacityOf(tester, 'b'), 1);
    CardRegistry.show('a');
  });

  testWidgets('tapping an entry opens that note', (tester) async {
    Note? opened;
    await pumpDay(
      tester,
      dayWith([('tap-me', DateTime(2026, 11, 15, 8, 30))]),
      onOpen: (note) => opened = note,
    );
    await tester.tap(find.text('tap-me'));
    await tester.pump();
    expect(opened, isNotNull);
    expect(opened!.id, 'tap-me');
  });
}
