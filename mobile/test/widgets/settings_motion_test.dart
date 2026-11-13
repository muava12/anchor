import 'package:anchor/app/app_bootstrap.dart';
import 'package:anchor/core/motion/motion_speed.dart';
import 'package:anchor/core/storage/preferences_repository.dart';
import 'package:anchor/core/theme/app_theme.dart';
import 'package:anchor/features/settings/presentation/motion_speed_controller.dart';
import 'package:anchor/features/settings/presentation/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockPreferences extends Mock implements PreferencesRepository {}

void main() {
  late _MockPreferences preferences;

  setUp(() {
    preferences = _MockPreferences();
    when(() => preferences.setMotionSpeedName(any())).thenAnswer((_) async {});
    when(() => preferences.setThemeMode(any())).thenAnswer((_) async {});
    when(() => preferences.setDisplayDensity(any())).thenAnswer((_) async {});
    when(() => preferences.setSortChecklistItems(any()))
        .thenAnswer((_) async {});
    when(() => preferences.setNoteFont(any())).thenAnswer((_) async {});
    when(() => preferences.setNoteTextSize(any())).thenAnswer((_) async {});
  });

  Future<ProviderContainer> pump(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        appBootstrapProvider.overrideWithValue(const AppBootstrap()),
        preferencesRepositoryProvider.overrideWithValue(preferences),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('the motion row offers slow, fast and off', (tester) async {
    await pump(tester);

    expect(find.text('Motion'), findsOneWidget);
    expect(find.text('Slow'), findsOneWidget);
    expect(find.text('Fast'), findsOneWidget);
    expect(find.text('Off'), findsOneWidget);
  });

  testWidgets('picking fast stores it and moves the selection', (tester) async {
    final container = await pump(tester);

    await tester.tap(find.text('Fast'));
    await tester.pumpAndSettle();

    expect(container.read(motionSpeedControllerProvider), MotionSpeed.fast);
    verify(() => preferences.setMotionSpeedName('fast')).called(1);
  });

  testWidgets('the four text sizes fit a 360 px screen', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await pump(tester);
    await tester.scrollUntilVisible(find.text('XS'), 200);

    for (final letter in ['XS', 'S', 'M', 'L']) {
      expect(find.text(letter), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });
}
