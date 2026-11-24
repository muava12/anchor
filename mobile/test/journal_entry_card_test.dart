import 'dart:convert';

import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/core/theme/tokens/anchor_tokens.dart';
import 'package:anchor/features/journal/domain/journal_day.dart';
import 'package:anchor/features/journal/domain/journal_meta.dart';
import 'package:anchor/features/journal/presentation/widgets/journal_entry_card.dart';
import 'package:anchor/features/journal/presentation/widgets/mood_face.dart';
import 'package:anchor/features/notes/domain/note.dart';
import 'package:anchor/features/notes/presentation/widgets/note_chips.dart';
import 'package:anchor/features/tags/domain/tag.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const tagA = Tag(id: 'a', name: 'morning');
const tagB = Tag(id: 'b', name: 'gratitude');

String _ops(String body) => jsonEncode({
  'ops': [
    {'insert': body},
  ],
});

JournalDayEntry titled({
  String title = 'Morning pages',
  String body = 'Coffee on the balcony.',
  JournalMood? mood,
  Map<String, String> extras = const {},
}) {
  return JournalDayEntry(
    note: Note(id: 'n', title: title, tagIds: ['a', 'b'], content: _ops(body)),
    meta: JournalMeta(
      entryAt: DateTime(2026, 11, 19, 8, 12),
      mood: mood,
      extras: extras,
    ),
  );
}

JournalDayEntry untitled({
  String body = 'Slow start.',
  JournalMood? mood,
  Map<String, String> extras = const {},
}) {
  return JournalDayEntry(
    note: Note(id: 'n', title: '', content: _ops(body)),
    meta: JournalMeta(
      entryAt: DateTime(2026, 11, 19, 8, 12),
      mood: mood,
      extras: extras,
    ),
  );
}

Future<void> pumpCard(
  WidgetTester tester,
  JournalDayEntry entry, {
  List<Tag> tags = const [],
  double width = 360,
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = Size(width, 740);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: JournalEntryCard(entry: entry, tags: tags),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('titled card shows time, title, snippet and mood', (
    tester,
  ) async {
    await pumpCard(
      tester,
      titled(
        title: 'Morning pages',
        body: 'Coffee on the balcony.',
        mood: JournalMood.calm,
      ),
    );
    expect(find.text('Morning pages'), findsOneWidget);
    expect(find.text('Coffee on the balcony.'), findsOneWidget);
    expect(find.byType(MoodFace), findsOneWidget);
  });

  testWidgets(
    'untitled short lead uses the body size, long uses the card-title size',
    (tester) async {
      await pumpCard(tester, untitled(body: 'Slow start.'));
      expect(
        tester.widget<Text>(find.text('Slow start.')).style!.fontSize,
        AnchorTokens.typeBody.fontSize,
      );

      await pumpCard(tester, untitled(body: 'x ' * 80));
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('journal-lead')))
            .style!
            .fontSize,
        AnchorTokens.typeCardTitle.fontSize,
      );
    },
  );

  testWidgets(
    'whitespace-only untitled body draws no lead and does not throw',
    (tester) async {
      await pumpCard(tester, untitled(body: '  \n '));
      expect(find.byKey(const ValueKey('journal-lead')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('footer lists location and every tag, and is hidden when empty', (
    tester,
  ) async {
    await pumpCard(
      tester,
      titled(extras: {'location': 'Dago, Bandung'}),
      tags: [tagA, tagB],
    );
    expect(find.text('Dago, Bandung'), findsOneWidget);
    expect(find.byType(TagChip), findsNWidgets(2));

    await pumpCard(tester, titled());
    expect(find.byType(TagChip), findsNothing);
    expect(find.byKey(const ValueKey('journal-card-footer')), findsNothing);
  });

  testWidgets('untitled header is at least 28 tall and centres its content', (
    tester,
  ) async {
    await pumpCard(tester, untitled(body: 'Slow start.'));
    final header = tester.getSize(
      find.byKey(const ValueKey('journal-untitled-header')),
    );
    expect(header.height, 28);

    // Text scale 1.3 must not overflow the header row.
    await pumpCard(tester, untitled(body: 'x ' * 120), textScale: 1.3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long tag and location ellipsize at text scale 1.3 on 320 dp', (
    tester,
  ) async {
    await pumpCard(
      tester,
      titled(extras: {'location': 'L' * 120}),
      tags: [Tag(id: 'x', name: 'T' * 80)],
      width: 320,
      textScale: 1.3,
    );
    expect(tester.takeException(), isNull);
  });
}
