import 'package:anchor/core/motion/motion_speed.dart';
import 'package:anchor/core/motion/springs.dart';
import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/core/theme/tokens/anchor_tokens.dart';
import 'package:anchor/features/notes/presentation/widgets/notes_bottom_bar.dart';
import 'package:anchor/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpBar(WidgetTester tester, {required bool compact}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: NotesBottomBar(
            placeholder: 'Search notes',
            compact: compact,
            searching: false,
            query: '',
            onStartSearch: () {},
            onQuery: (_) {},
            onCancel: () {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The duration the bar's shrink uses, read off the widget tree.
Duration barDuration(WidgetTester tester) {
  final container = tester.widget<AnimatedContainer>(
    find.descendant(
      of: find.byType(NotesBottomBar),
      matching: find.byType(AnimatedContainer),
    ),
  );
  return container.duration;
}

void main() {
  tearDown(() => MotionSpeed.current = MotionSpeed.slow);

  testWidgets('the shrink keeps the Normal duration at the Fast setting', (
    tester,
  ) async {
    MotionSpeed.current = MotionSpeed.fast;
    await pumpBar(tester, compact: true);

    // Fast would otherwise run the 320 ms shrink in 96 ms, which is easy to
    // miss. The owner asked for this one animation to stay at Normal.
    expect(barDuration(tester), AnchorTokens.motionSpringSnappyDuration);
  });

  testWidgets('the shrink keeps the Normal duration at the Normal setting', (
    tester,
  ) async {
    MotionSpeed.current = MotionSpeed.slow;
    await pumpBar(tester, compact: true);

    expect(barDuration(tester), AnchorTokens.motionSpringSnappyDuration);
  });

  testWidgets('the override is instant when motion is Off', (tester) async {
    MotionSpeed.current = MotionSpeed.off;
    late Duration normal;
    // A bare MediaQuery: MaterialApp would build a page transition, and those
    // already assert on a zero-length spring at Off.
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(),
        child: Builder(
          builder: (context) {
            normal = context.motionNormal(Spring.snappy.durationNormal);
            return const SizedBox();
          },
        ),
      ),
    );

    // Off is the accessibility path: an override for Fast must not defeat it.
    expect(normal, Duration.zero);
  });
}
