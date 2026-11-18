import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/features/journal/domain/journal_meta.dart';
import 'package:anchor/features/journal/presentation/widgets/journal_mood_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the moods and picks one', (tester) async {
    JournalMood? picked;
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                child: JournalMoodPicker(
                  selected: JournalMood.happy,
                  onPick: (mood) => picked = mood,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Happy'), findsOneWidget);
    expect(find.text('Sad'), findsOneWidget);

    await tester.tap(find.text('Sad'));
    expect(picked, JournalMood.sad);
    semantics.dispose();
  });
}
