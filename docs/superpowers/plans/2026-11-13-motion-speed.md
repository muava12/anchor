# Motion speed setting — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Slow / Fast / Off motion setting to the mobile app, stop the lock cover's button from spinning while the system prompt is up, and add an extra small note text size shown as XS.

**Architecture:** One enum, `MotionSpeed`, holds the scale. A static `MotionSpeed.current` is set at startup and on change, because `isSystemMotionReduced` is read from code with no `Ref` and no `BuildContext`. The two existing chokepoints (`isSystemMotionReduced` and `context.motion`) consult it, so all 73 call sites follow without edits.

**Tech Stack:** Flutter 3.47.9, Riverpod (codegen), flutter_secure_storage, flutter_test, mocktail.

## Global Constraints

- Flutter 3.47.9; `flutter analyze` must report no issues, warnings included.
- All user-facing copy is English and lives in `lib/l10n/app_en.arb`; the generated `app_localizations*.dart` files are committed and edited by hand here.
- Generated Riverpod files (`*.g.dart`) are committed. This plan writes them by hand, matching the existing generator output.
- The device's Reduce Motion always wins over the app setting.
- Haptics and loading indicators (spinner, shimmer, pull-to-refresh sway) keep their durations.
- Verify with `flutter analyze` and `flutter test` on box-03 (`/data/workspace/toolchain/flutter/bin/flutter`), never on the local host.

---

### Task 1: The MotionSpeed enum and its scale

**Files:**
- Create: `mobile/lib/core/motion/motion_speed.dart`
- Test: `mobile/test/motion_speed_test.dart`

**Interfaces:**
- Produces: `enum MotionSpeed { slow, fast, off }` with `final double scale`, and `static MotionSpeed current`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:anchor/core/motion/motion_speed.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => MotionSpeed.current = MotionSpeed.slow);

  test('slow keeps the design durations', () {
    expect(MotionSpeed.slow.scale, 1);
  });

  test('fast runs at three tenths', () {
    expect(MotionSpeed.fast.scale, 0.3);
  });

  test('off has no time at all', () {
    expect(MotionSpeed.off.scale, 0);
  });

  test('the current speed starts at slow', () {
    expect(MotionSpeed.current, MotionSpeed.slow);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/motion_speed_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'anchor' ... motion_speed.dart`

- [ ] **Step 3: Write minimal implementation**

```dart
/// How much the app animates. The person picks one in Settings → Appearance.
enum MotionSpeed {
  /// Today's motion, unchanged.
  slow(1),

  /// The same motion, three tenths as long.
  fast(0.3),

  /// No motion: every animation lands at once.
  off(0);

  const MotionSpeed(this.scale);

  /// Multiplies a design duration. Zero means "no time at all".
  final double scale;

  /// The speed in force. Set at startup and when the person changes it, and
  /// read from code that has no [Ref] and no [BuildContext].
  static MotionSpeed current = MotionSpeed.slow;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/motion_speed_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/core/motion/motion_speed.dart mobile/test/motion_speed_test.dart
git commit -m "feat(mobile): add the motion speed scale"
```

---

### Task 2: Springs and durations follow the scale

**Files:**
- Modify: `mobile/lib/core/motion/springs.dart`
- Test: `mobile/test/motion_speed_test.dart`

**Interfaces:**
- Consumes: `MotionSpeed.current`, `MotionSpeed.off` from Task 1.
- Produces: `Spring.duration` as a getter (was a final field), `isSystemMotionReduced` true when the app is set to off, `context.motion(d)` scaled.

- [ ] **Step 1: Write the failing test**

Append to `mobile/test/motion_speed_test.dart`:

```dart
  test('a spring keeps its design duration at slow', () {
    MotionSpeed.current = MotionSpeed.slow;
    expect(Spring.smooth.duration, AnchorTokens.motionSpringSmoothDuration);
  });

  test('a spring is three tenths as long at fast', () {
    MotionSpeed.current = MotionSpeed.fast;
    expect(
      Spring.smooth.duration.inMicroseconds,
      (AnchorTokens.motionSpringSmoothDuration.inMicroseconds * 0.3).round(),
    );
  });

  test('a spring has no duration at off', () {
    MotionSpeed.current = MotionSpeed.off;
    expect(Spring.smooth.duration, Duration.zero);
  });

  test('off counts as reduced motion', () {
    MotionSpeed.current = MotionSpeed.off;
    expect(isSystemMotionReduced, isTrue);
  });
```

Add these imports at the top of the test file:

```dart
import 'package:anchor/core/motion/springs.dart';
import 'package:anchor/core/theme/tokens/anchor_tokens.dart';
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/motion_speed_test.dart`
Expected: FAIL — the fast and off cases report the unchanged duration.

- [ ] **Step 3: Write minimal implementation**

In `mobile/lib/core/motion/springs.dart`, replace the enum's `duration` field with a getter and build the description per call:

```dart
  const Spring(this._duration, this._bounce);

  final Duration _duration;
  final double _bounce;

  /// The design duration, shortened or removed by the motion setting.
  Duration get duration => _duration * MotionSpeed.current.scale;

  Curve get curve => _SpringCurve(simulation(0, 1));

  /// Starts at [velocity] (units per second) and lands exactly on [to] once
  /// it is within [precision] of it.
  Simulation simulation(
    double from,
    double to, {
    double velocity = 0,
    double precision = 0.0005,
  }) => _SettlingSpring(
    SpringSimulation(
      SpringDescription.withDurationAndBounce(
        duration: duration,
        bounce: _bounce,
      ),
      from,
      to,
      velocity,
      tolerance: Tolerance(distance: precision, velocity: precision * 20),
    ),
    to,
  );
```

Delete the now-unused `_descriptions` and `_curves` static lists.

Then change the reduced-motion getter:

```dart
/// The system's reduced motion setting, or the app's own "off", for code
/// without a [BuildContext].
bool get isSystemMotionReduced =>
    _reducesMotion(SemanticsBinding.instance.disableAnimations) ||
    MotionSpeed.current == MotionSpeed.off;
```

And the context extension:

```dart
extension ReducedMotion on BuildContext {
  bool get isMotionReduced =>
      _reducesMotion(MediaQuery.maybeDisableAnimationsOf(this) ?? false) ||
      MotionSpeed.current == MotionSpeed.off;

  /// [duration], shortened by the motion setting, or no time at all.
  Duration motion(Duration duration) =>
      isMotionReduced ? Duration.zero : duration * MotionSpeed.current.scale;
}
```

Add the import:

```dart
import 'motion_speed.dart';
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/motion_speed_test.dart`
Expected: PASS, 8 tests.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/core/motion/springs.dart mobile/test/motion_speed_test.dart
git commit -m "feat(mobile): scale springs and durations by the motion setting"
```

---

### Task 3: Store the choice and read it at startup

**Files:**
- Modify: `mobile/lib/core/storage/storage_keys.dart`
- Modify: `mobile/lib/core/storage/preferences_repository.dart`
- Modify: `mobile/lib/app/app_bootstrap.dart`
- Modify: `mobile/lib/app/bootstrap.dart`
- Create: `mobile/lib/features/settings/presentation/motion_speed_controller.dart`
- Create: `mobile/lib/features/settings/presentation/motion_speed_controller.g.dart`
- Test: `mobile/test/motion_speed_test.dart`

**Interfaces:**
- Consumes: `MotionSpeed` from Task 1.
- Produces: `StorageKeys.motionSpeed`, `PreferencesRepository.getMotionSpeed()` / `setMotionSpeed(MotionSpeed)`, `AppBootstrap.motionSpeed`, `motionSpeedControllerProvider` with `set(MotionSpeed)`.

- [ ] **Step 1: Write the failing test**

Append to `mobile/test/motion_speed_test.dart`:

```dart
  test('an unknown stored name reads as slow', () {
    expect(motionSpeedFromName('nonsense'), MotionSpeed.slow);
    expect(motionSpeedFromName(null), MotionSpeed.slow);
    expect(motionSpeedFromName('fast'), MotionSpeed.fast);
  });
```

Add the import:

```dart
import 'package:anchor/features/settings/presentation/motion_speed_controller.dart';
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/motion_speed_test.dart`
Expected: FAIL — `motionSpeedFromName` is not defined.

- [ ] **Step 3: Write minimal implementation**

`mobile/lib/core/storage/storage_keys.dart`, add beside the other keys:

```dart
  static const motionSpeed = 'motion_speed';
```

`mobile/lib/core/storage/preferences_repository.dart`, add before the closing brace of the class:

```dart
  Future<String?> getMotionSpeedName() =>
      _storage.read(key: StorageKeys.motionSpeed);

  Future<void> setMotionSpeedName(String name) async {
    await _storage.write(key: StorageKeys.motionSpeed, value: name);
  }
```

`mobile/lib/app/app_bootstrap.dart`, add the field:

```dart
    this.motionSpeed = MotionSpeed.slow,
```

```dart
  final MotionSpeed motionSpeed;
```

with the import:

```dart
import '../core/motion/motion_speed.dart';
```

`mobile/lib/app/bootstrap.dart`, in the returned `AppBootstrap(...)`:

```dart
    motionSpeed: motionSpeedFromName(await preferences.getMotionSpeedName()),
```

and before the return, apply it to the static so the first frame already obeys it:

```dart
  final motionSpeed = motionSpeedFromName(
    await preferences.getMotionSpeedName(),
  );
  MotionSpeed.current = motionSpeed;
```

`mobile/lib/features/settings/presentation/motion_speed_controller.dart`:

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/app_bootstrap.dart';
import '../../../core/motion/motion_speed.dart';
import '../../../core/storage/preferences_repository.dart';

part 'motion_speed_controller.g.dart';

/// The stored name, or slow when it is missing or unknown.
MotionSpeed motionSpeedFromName(String? name) => MotionSpeed.values.firstWhere(
  (speed) => speed.name == name,
  orElse: () => MotionSpeed.slow,
);

@Riverpod(keepAlive: true)
class MotionSpeedController extends _$MotionSpeedController {
  @override
  MotionSpeed build() => ref.watch(appBootstrapProvider).motionSpeed;

  Future<void> set(MotionSpeed speed) async {
    state = speed;
    MotionSpeed.current = speed;
    await ref
        .read(preferencesRepositoryProvider)
        .setMotionSpeedName(speed.name);
  }
}
```

`mobile/lib/features/settings/presentation/motion_speed_controller.g.dart`, written by hand in the generator's shape:

```dart
// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'motion_speed_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(MotionSpeedController)
final motionSpeedControllerProvider = MotionSpeedControllerProvider._();

final class MotionSpeedControllerProvider
    extends $NotifierProvider<MotionSpeedController, MotionSpeed> {
  MotionSpeedControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'motionSpeedControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$motionSpeedControllerHash();

  @$internal
  @override
  MotionSpeedController create() => MotionSpeedController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MotionSpeed value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MotionSpeed>(value),
    );
  }
}

String _$motionSpeedControllerHash() =>
    r'6f1c2a9d4b8e7f30a5c6d1e2b3a4c5d6e7f80912';

abstract class _$MotionSpeedController extends $Notifier<MotionSpeed> {
  MotionSpeed build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<MotionSpeed, MotionSpeed>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<MotionSpeed, MotionSpeed>,
              MotionSpeed,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/motion_speed_test.dart && flutter analyze`
Expected: PASS, 9 tests; analyze reports no issues.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/core/storage mobile/lib/app mobile/lib/features/settings/presentation/motion_speed_controller.dart mobile/lib/features/settings/presentation/motion_speed_controller.g.dart mobile/test/motion_speed_test.dart
git commit -m "feat(mobile): keep the motion speed on the device"
```

---

### Task 4: The Motion row in Settings

**Files:**
- Modify: `mobile/lib/l10n/app_en.arb`
- Modify: `mobile/lib/l10n/app_localizations.dart`
- Modify: `mobile/lib/l10n/app_localizations_en.dart`
- Modify: `mobile/lib/features/settings/presentation/settings_screen.dart`
- Test: `mobile/test/widgets/settings_motion_test.dart`

**Interfaces:**
- Consumes: `motionSpeedControllerProvider` from Task 3.
- Produces: l10n getters `settingsMotion`, `settingsMotionHelp`, `settingsMotionSlow`, `settingsMotionFast`, `settingsMotionOff`.

- [ ] **Step 1: Write the failing test**

```dart
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
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/widgets/settings_motion_test.dart`
Expected: FAIL — `find.text('Motion')` finds nothing.

- [ ] **Step 3: Write minimal implementation**

`mobile/lib/l10n/app_en.arb`, before `"settingsMoveChecked"`:

```json
  "settingsMotion": "Motion",
  "@settingsMotion": {
    "description": "Setting that picks how much the app animates."
  },
  "settingsMotionHelp": "How much the app animates.",
  "@settingsMotionHelp": {
    "description": "Under the motion setting: what it changes."
  },
  "settingsMotionSlow": "Slow",
  "@settingsMotionSlow": {
    "description": "Motion setting that keeps the design's own durations."
  },
  "settingsMotionFast": "Fast",
  "@settingsMotionFast": {
    "description": "Motion setting that runs animations at three tenths of the design duration."
  },
  "settingsMotionOff": "Off",
  "@settingsMotionOff": {
    "description": "Motion setting that removes animation entirely."
  },
```

`mobile/lib/l10n/app_localizations.dart`, before the `settingsMoveChecked` getter:

```dart
  /// Setting that picks how much the app animates.
  ///
  /// In en, this message translates to:
  /// **'Motion'**
  String get settingsMotion;

  /// Under the motion setting: what it changes.
  ///
  /// In en, this message translates to:
  /// **'How much the app animates.'**
  String get settingsMotionHelp;

  /// Motion setting that keeps the design's own durations.
  ///
  /// In en, this message translates to:
  /// **'Slow'**
  String get settingsMotionSlow;

  /// Motion setting that runs animations at three tenths of the design duration.
  ///
  /// In en, this message translates to:
  /// **'Fast'**
  String get settingsMotionFast;

  /// Motion setting that removes animation entirely.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get settingsMotionOff;

```

`mobile/lib/l10n/app_localizations_en.dart`, before the `settingsMoveChecked` getter:

```dart
  @override
  String get settingsMotion => 'Motion';

  @override
  String get settingsMotionHelp => 'How much the app animates.';

  @override
  String get settingsMotionSlow => 'Slow';

  @override
  String get settingsMotionFast => 'Fast';

  @override
  String get settingsMotionOff => 'Off';

```

`mobile/lib/features/settings/presentation/settings_screen.dart`, in `_AppearanceSection`, before the density tile:

```dart
          StackedListTile(
            label: l10n.settingsMotion,
            subtitle: l10n.settingsMotionHelp,
            child: SegmentedControl<MotionSpeed>(
              semanticLabel: l10n.settingsMotion,
              value: motion,
              segments: [
                Segment(value: MotionSpeed.slow, label: l10n.settingsMotionSlow),
                Segment(value: MotionSpeed.fast, label: l10n.settingsMotionFast),
                Segment(value: MotionSpeed.off, label: l10n.settingsMotionOff),
              ],
              onChanged: (speed) =>
                  ref.read(motionSpeedControllerProvider.notifier).set(speed),
            ),
          ),
```

with, at the top of `build`:

```dart
    final motion = ref.watch(motionSpeedControllerProvider);
```

and the imports:

```dart
import '../../../core/motion/motion_speed.dart';
import 'motion_speed_controller.dart';
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/widgets/settings_motion_test.dart && flutter analyze`
Expected: PASS, 2 tests; analyze reports no issues.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/l10n mobile/lib/features/settings/presentation/settings_screen.dart mobile/test/widgets/settings_motion_test.dart
git commit -m "feat(mobile): pick the motion speed in Settings"
```

---

### Task 5: The lock cover waits without a spinner

**Files:**
- Modify: `mobile/lib/features/settings/presentation/app_lock_gate.dart`
- Test: `mobile/test/widgets/app_lock_test.dart`

**Interfaces:**
- Consumes: nothing new.
- Produces: nothing new; the cover's button changes behaviour only.

- [ ] **Step 1: Write the failing test**

Append to `mobile/test/widgets/app_lock_test.dart`, inside `main()`:

```dart
  testWidgets('the cover waits without a spinner on its button', (
    tester,
  ) async {
    await _pump(
      tester,
      isLocked: true,
      authenticator: _FakeAuthenticator(holds: true),
    );

    expect(find.text('Waiting for the device…'), findsOneWidget);
    expect(find.byType(Spinner), findsNothing);
  });
```

Add the import:

```dart
import 'package:anchor/core/widgets/spinner.dart';
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/widgets/app_lock_test.dart`
Expected: FAIL — a `Spinner` is found, because the button is busy.

- [ ] **Step 3: Write minimal implementation**

In `mobile/lib/features/settings/presentation/app_lock_gate.dart`, replace the `AppButton` in `AppLockScreen`:

```dart
                AppButton(
                  label: _isAsking ? l10n.appLockAsking : l10n.appLockUnlock,
                  icon: _isAsking ? null : LucideIcons.fingerprint,
                  hasShadow: true,
                  onPressed: _isAsking ? null : _ask,
                ),
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/widgets/app_lock_test.dart`
Expected: PASS, 9 tests.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/features/settings/presentation/app_lock_gate.dart mobile/test/widgets/app_lock_test.dart
git commit -m "fix(mobile): wait on the lock cover without a spinner"
```

---

### Task 6: Extra small note text, shown as XS

**Files:**
- Modify: `mobile/lib/core/theme/note_typography.dart`
- Modify: `mobile/lib/core/widgets/segmented_control.dart`
- Modify: `mobile/lib/l10n/app_en.arb`
- Modify: `mobile/lib/l10n/app_localizations.dart`
- Modify: `mobile/lib/l10n/app_localizations_en.dart`
- Modify: `mobile/lib/features/settings/presentation/settings_screen.dart`
- Test: `mobile/test/note_text_size_test.dart`

**Interfaces:**
- Consumes: nothing new.
- Produces: `NoteTextSize.extraSmall`, `NoteTextSize.labelIn` (the letter), `NoteTextSize.spokenIn` (the words), `Segment.spokenLabel`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:anchor/core/theme/app_typography.dart';
import 'package:anchor/core/theme/note_typography.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('extra small is three quarters of the body size', () {
    expect(NoteTextSize.extraSmall.scale, 0.73);
    const typography = NoteTypography(textSize: NoteTextSize.extraSmall);
    expect(typography.bodySize, closeTo(12.0, 0.05));
  });

  test('the sizes run from extra small to large', () {
    expect(NoteTextSize.values, [
      NoteTextSize.extraSmall,
      NoteTextSize.small,
      NoteTextSize.standard,
      NoteTextSize.large,
    ]);
  });

  test('the body size at standard is the design size', () {
    const typography = NoteTypography();
    expect(typography.bodySize, AppTypography.noteBodySize);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/note_text_size_test.dart`
Expected: FAIL — `NoteTextSize.extraSmall` is not defined.

- [ ] **Step 3: Write minimal implementation**

`mobile/lib/core/theme/note_typography.dart`:

```dart
enum NoteTextSize {
  extraSmall(0.73),
  small(0.88),
  standard(1),
  large(1.12);

  const NoteTextSize(this.scale);

  final double scale;

  /// The letter the picker shows.
  String labelIn(AppLocalizations l10n) => switch (this) {
    NoteTextSize.extraSmall => l10n.textSizeExtraSmallShort,
    NoteTextSize.small => l10n.textSizeSmallShort,
    NoteTextSize.standard => l10n.textSizeStandardShort,
    NoteTextSize.large => l10n.textSizeLargeShort,
  };

  /// The words a screen reader says, so a letter is never read alone.
  String spokenIn(AppLocalizations l10n) => switch (this) {
    NoteTextSize.extraSmall => l10n.textSizeExtraSmall,
    NoteTextSize.small => l10n.textSizeSmall,
    NoteTextSize.standard => l10n.textSizeDefault,
    NoteTextSize.large => l10n.textSizeLarge,
  };
}
```

`mobile/lib/core/widgets/segmented_control.dart`, add to `Segment`:

```dart
  /// What a screen reader says. Falls back to [label].
  final String? spokenLabel;
```

with the constructor parameter:

```dart
    this.spokenLabel,
```

and in the build, replace `semanticLabel: segments[i].label` with:

```dart
                            semanticLabel:
                                segments[i].spokenLabel ?? segments[i].label,
```

`mobile/lib/l10n/app_en.arb`, before `"settingsMoveChecked"`:

```json
  "textSizeExtraSmall": "Extra small",
  "@textSizeExtraSmall": {
    "description": "Spoken name of the smallest note text size."
  },
  "textSizeExtraSmallShort": "XS",
  "@textSizeExtraSmallShort": {
    "description": "Letter shown for the smallest note text size."
  },
  "textSizeSmallShort": "S",
  "@textSizeSmallShort": {
    "description": "Letter shown for the small note text size."
  },
  "textSizeStandardShort": "M",
  "@textSizeStandardShort": {
    "description": "Letter shown for the default note text size."
  },
  "textSizeLargeShort": "L",
  "@textSizeLargeShort": {
    "description": "Letter shown for the large note text size."
  },
```

`mobile/lib/l10n/app_localizations.dart`, before the `settingsMoveChecked` getter:

```dart
  /// Spoken name of the smallest note text size.
  ///
  /// In en, this message translates to:
  /// **'Extra small'**
  String get textSizeExtraSmall;

  /// Letter shown for the smallest note text size.
  ///
  /// In en, this message translates to:
  /// **'XS'**
  String get textSizeExtraSmallShort;

  /// Letter shown for the small note text size.
  ///
  /// In en, this message translates to:
  /// **'S'**
  String get textSizeSmallShort;

  /// Letter shown for the default note text size.
  ///
  /// In en, this message translates to:
  /// **'M'**
  String get textSizeStandardShort;

  /// Letter shown for the large note text size.
  ///
  /// In en, this message translates to:
  /// **'L'**
  String get textSizeLargeShort;

```

`mobile/lib/l10n/app_localizations_en.dart`, before the `settingsMoveChecked` getter:

```dart
  @override
  String get textSizeExtraSmall => 'Extra small';

  @override
  String get textSizeExtraSmallShort => 'XS';

  @override
  String get textSizeSmallShort => 'S';

  @override
  String get textSizeStandardShort => 'M';

  @override
  String get textSizeLargeShort => 'L';

```

`mobile/lib/features/settings/presentation/settings_screen.dart`, in `_EditorSection`, pass the spoken label:

```dart
                for (final size in NoteTextSize.values)
                  Segment(
                    value: size,
                    label: size.labelIn(l10n),
                    spokenLabel: size.spokenIn(l10n),
                  ),
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/note_text_size_test.dart && flutter analyze`
Expected: PASS, 3 tests; analyze reports no issues.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/core/theme/note_typography.dart mobile/lib/core/widgets/segmented_control.dart mobile/lib/l10n mobile/lib/features/settings/presentation/settings_screen.dart mobile/test/note_text_size_test.dart
git commit -m "feat(mobile): add an extra small note text size, shown as XS"
```

---

### Task 7: Check the whole app and the narrow screen

**Files:**
- Test: `mobile/test/widgets/settings_motion_test.dart`

**Interfaces:**
- Consumes: everything above.
- Produces: nothing.

- [ ] **Step 1: Write the failing test**

Append to `mobile/test/widgets/settings_motion_test.dart`, inside `main()`:

```dart
  testWidgets('the four text sizes fit a 360 px screen', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await pump(tester);

    for (final letter in ['XS', 'S', 'M', 'L']) {
      expect(find.text(letter), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/widgets/settings_motion_test.dart`
Expected: FAIL — the letters are not on screen yet, or the row overflows.

- [ ] **Step 3: Fix what the test shows**

If the letters are missing, the editor section is below the fold: scroll to it first with

```dart
    await tester.scrollUntilVisible(find.text('XS'), 200);
```

If the row overflows, wrap the picker in a `Wrap` inside `StackedListTile` so the segments take two rows rather than shrinking.

- [ ] **Step 4: Run the whole suite**

Run: `cd mobile && flutter analyze && flutter test`
Expected: analyze reports no issues; every test passes.

- [ ] **Step 5: Commit**

```bash
git add mobile/test/widgets/settings_motion_test.dart
git commit -m "test(mobile): check the four text sizes on a narrow screen"
```
