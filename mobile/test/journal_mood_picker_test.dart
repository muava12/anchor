import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/features/journal/domain/journal_meta.dart';
import 'package:anchor/features/journal/presentation/widgets/journal_mood_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the four moods and picks one', (tester) async {
    JournalMood? picked;
    var closed = 0;
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Center(
              child: JournalMoodPicker(
                selected: JournalMood.good,
                onPick: (mood) => picked = mood,
                onClose: () => closed++,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Amazing'), findsOneWidget);
    expect(find.text('Rough'), findsOneWidget);

    await tester.tap(find.text('Rough'));
    expect(picked, JournalMood.rough);

    await tester.tap(find.bySemanticsLabel('Cancel'));
    expect(closed, 1);
    semantics.dispose();
  });
}
