import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/features/notes/presentation/widgets/note_more_sheet.dart';
import 'package:anchor/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> openSheet(
  WidgetTester tester, {
  DateTime? createdAt,
  bool isOwner = true,
}) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (home) => TextButton(
          onPressed: () => showNoteMoreSheet(
            home,
            isPinned: false,
            isOwner: isOwner,
            isArchived: false,
            canSeeHistory: true,
            shareCount: 0,
            createdAt: createdAt,
          ),
          child: const Text('Open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the created date sits under Move to trash', (tester) async {
    await openSheet(tester, createdAt: DateTime(2026, 3, 4, 9));

    expect(find.text('Move to trash'), findsOneWidget);
    final caption = find.text('Created Mar 4');
    expect(caption, findsOneWidget);
    expect(
      tester.getBottomLeft(find.text('Move to trash')).dy,
      lessThan(tester.getBottomLeft(caption).dy),
    );
  });

  testWidgets('an unknown created date shows no caption', (tester) async {
    await openSheet(tester);

    expect(find.textContaining('Created'), findsNothing);
    expect(find.text('Move to trash'), findsOneWidget);
  });

  testWidgets('a shared note keeps the caption under Remove from my notes', (
    tester,
  ) async {
    await openSheet(tester, createdAt: DateTime(2026, 3, 4, 9), isOwner: false);

    expect(find.text('Remove from my notes'), findsOneWidget);
    expect(find.text('Created Mar 4'), findsOneWidget);
  });
}
