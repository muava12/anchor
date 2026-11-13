# Motion speed setting — design

Date: 2026-11-13
Status: approved for planning

## Problem

Anchor animates every screen: page transitions, note morph, sheets, springs,
list reordering. The speed is fixed in design tokens, and the only way to slow
it down or stop it is the system's own Reduce Motion switch. A person who wants
faster motion, or no motion at all, has no setting in the app.

## Goal

A setting in the app with three choices:

| Choice | Effect |
| --- | --- |
| Slow | Today's motion, unchanged. The default. |
| Fast | The same motion at 0.3× the duration. |
| Off | No motion: every animation lands at once. |

The system's Reduce Motion still wins. When the device asks for less motion,
the app shows none, whatever the app setting says.

## What already exists

Anchor keeps motion in two places, which is why this change is small:

- `lib/core/motion/springs.dart`
  - `enum Spring` (smooth, snappy, pop, keyboard), each with a duration from
    `AnchorTokens` and a bounce.
  - `isSystemMotionReduced`, a global getter with no `BuildContext`, used by
    `springTo`, `springBackTo`, `page_transitions.dart`, `note_morph_route.dart`
    and `main.dart`'s `themeAnimationStyle`.
  - `context.motion(duration)` and `context.isMotionReduced`, used at 73 call
    sites for plain `Duration` animations.
- `lib/core/theme/tokens/anchor_tokens.dart`, which holds the durations.

Both chokepoints already answer "no motion" by returning zero. The setting only
has to change what they answer.

## Design

### The setting

`lib/core/motion/motion_speed.dart`:

```dart
enum MotionSpeed {
  slow(1),
  fast(0.3),
  off(0);

  const MotionSpeed(this.scale);

  final double scale;
}
```

`MotionSpeed.current` is a static field, set at startup and whenever the person
changes the setting. A static field, not a provider read, because
`isSystemMotionReduced` is called from code that has no `Ref` and no
`BuildContext`.

### Storage and startup

- `StorageKeys.motionSpeed = 'motion_speed'`.
- `PreferencesRepository.getMotionSpeed()` returns `MotionSpeed.slow` when the
  key is absent or holds an unknown name.
- `PreferencesRepository.setMotionSpeed(MotionSpeed)`.
- `AppBootstrap.motionSpeed`, read in `initializeApp` beside the theme mode, and
  applied to `MotionSpeed.current` before the first frame.
- `@Riverpod(keepAlive: true) class MotionSpeedController extends _$MotionSpeedController`,
  built from `appBootstrapProvider`, with `set(MotionSpeed)` that writes the
  preference and updates `MotionSpeed.current`. It follows
  `ThemeModeController` exactly.

### Applying the scale

`Spring`:

- `duration` becomes a getter: the token duration times `MotionSpeed.current.scale`.
- The `SpringDescription` is built per call from that duration and the bounce,
  instead of a list built once at class load, so a change takes effect at once.
  Building it is cheap; the list was only a cache.

`springs.dart`:

- `isSystemMotionReduced` becomes `_reducesMotion(...) || MotionSpeed.current == MotionSpeed.off`.
- `context.motion(duration)` becomes `Duration.zero` when `isMotionReduced`,
  otherwise `duration * MotionSpeed.current.scale`.
- `context.isMotionReduced` keeps its meaning: the system asked, or the app is
  set to off.

`page_transitions.dart` keeps its two `isSystemMotionReduced` checks; they now
also answer for the app setting. `main.dart`'s `themeAnimationStyle` follows the
same getter.

### What does not change

- Haptics. They are feedback, not motion.
- Loading indicators: shimmer, spinners, the pull-to-refresh sway. A person who
  turns motion off must still see that the app is working. These keep their
  durations.
- The system's own Reduce Motion handling. `_reducesMotion` is untouched, so the
  device always wins.

### The screen

Settings → Appearance gains one row, above the theme picker:

- Label: "Motion" (l10n key `settingsMotion`).
- Help: "How much the app animates." (`settingsMotionHelp`).
- A `SegmentedControl<MotionSpeed>` with three segments: Slow, Fast, Off
  (`settingsMotionSlow`, `settingsMotionFast`, `settingsMotionOff`).
- Changing it applies at once; no restart, no dialog.

## Testing

Unit tests, `test/motion_speed_test.dart`:

- `MotionSpeed.slow.scale` is 1, `fast` is 0.3, `off` is 0.
- `Spring.smooth.duration` equals the token duration at `slow`, and 0.3× at
  `fast`.
- `context.motion(d)` returns `d` at slow, `d * 0.3` at fast, and zero at off.
- `isSystemMotionReduced` is true at `off` even when the system does not ask.

Widget test, `test/widgets/settings_motion_test.dart`:

- The Appearance section shows the three segments with Slow selected by default.
- Tapping Fast calls `setMotionSpeed(MotionSpeed.fast)` on the repository and
  moves the selection.

## Risks

- A static `MotionSpeed.current` is global state. It is set in one place at
  startup and in one place on change, and it is read-only elsewhere, so the risk
  is contained. Tests must reset it in `tearDown`.
- `Spring.duration` becoming a getter touches every caller. All callers read it
  as a value, so no call site changes.
