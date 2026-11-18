import 'package:anchor/features/journal/domain/journal_meta.dart';
import 'package:anchor/features/journal/presentation/widgets/mood_face.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the full-colour Wangcai face for a mood', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: MoodFace(mood: JournalMood.happy)),
        ),
      ),
    );
    await tester.pump();

    final picture = tester.widget<SvgPicture>(
      find.byType(SvgPicture),
    );
    expect(picture.width, 20);
    expect(picture.height, 20);
    // Full-colour: no tint is applied to the asset.
    expect(picture.colorFilter, isNull);
  });
}