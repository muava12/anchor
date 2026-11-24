# FSI Escalation + Draggable Snooze Sheet Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the snooze sheet draggable, and escalate an unacknowledged reminder banner to the reminder sheet after 60 s while the phone is unlocked.

**Architecture:** A reusable `SheetDragHelper` drives the snooze sheet. Escalation is an exact alarm (`FsiEscalationScheduler`) that fires `FsiEscalationReceiver`, which guards and then launches `FullScreenReminderActivity` under `SYSTEM_ALERT_WINDOW` (fallback: one re-post). Permission steps are added to the existing Dart `ensureReminderPermissions` flow via new native channel methods.

**Tech Stack:** Kotlin (Android native, `moek.anchor.notex.reminders`), Flutter/Dart + Riverpod, `flutter test`.

**Spec:** `docs/superpowers/specs/2026-11-23-fsi-escalation-snooze-drag-design.md`

## Global Constraints

- Paths: native `mobile/android/app/src/main/kotlin/moek/anchor/notex/reminders/` (`<R>` below), manifest `mobile/android/app/src/main/AndroidManifest.xml`, layouts/strings under `mobile/android/app/src/main/res/`, Dart under `mobile/lib/features/reminders/`, tests under `mobile/test/`.
- Drag: zone ≥ 48 dp; dismiss if `translationY` > 25 % of sheet height or downward velocity > ~1000 dp/s; slide-out ≈ 280 ms with `PathInterpolator(0.5f, 0f, 0.8f, 0.4f)` (the FSI exit curve); spring back ≈ 200 ms with `PathInterpolator(0.2f, 0.7f, 0.2f, 1f)`. Drag-close = Cancel/Back (no reschedule).
- Escalation: 60 s, one-shot per occurrence, only scheduled when screen interactive and keyguard not locked; receiver `exported=false`; `PendingIntent.FLAG_IMMUTABLE`; DND (filter ≠ ALL) skips; screen off at 60 s still launches.
- Overlay step only on SDK ≥ 29; full-screen-intent step only on SDK ≥ 34; each offered once and remembered.
- Kotlin has no unit-test infrastructure and is compiled only by CI job `mobile-android` (`flutter build apk --debug`); do not build locally. Kotlin tasks are verified by that job plus the on-device checklist in the task. Dart tasks are TDD with `flutter test`.
- Repo docs and code comments in English.

## Review Focus

1. Banner tapped or "Open note" pressed before 60 s → no sheet (Task 4).
2. Banner Snooze/Done/Dismiss at ~55 s → no sheet at 60 s (Task 4).
3. Second reminder fires while the sheet is open → sheet shows the second reminder and Done acts on the second id (Task 2).
4. Overlay revoked after scheduling, or card swiped away (Android 14) → no crash, no sheet; revoked → exactly one re-post (Task 3).
5. Drag edge cases: second finger / `ACTION_CANCEL` mid-drag springs back; a short fast fling dismisses; rotation mid-drag leaves the sheet at rest; chips still tap (Task 1).

---

### Task 1: Draggable snooze sheet

**Files:**
- Create: `<R>/SheetDragHelper.kt`
- Modify: `res/layout/activity_snooze_reminder.xml`, `<R>/SnoozeReminderActivity.kt`, `res/values/strings.xml`

**Interfaces:**
- Produces: `class SheetDragHelper(sheet: View, scrim: View, dragZone: View, onDismissed: () -> Unit) { fun attach() }`

- [ ] **Step 1: Branch and commit the docs.** `git switch -c feat/fsi-escalation-snooze-drag`; `git add docs/superpowers/specs/2026-11-23-fsi-escalation-snooze-drag-design.md docs/superpowers/plans/2026-11-23-fsi-escalation-snooze-drag.md`; commit `docs: FSI escalation + snooze drag spec and plan`.
- [ ] **Step 2: Layout.** Wrap `snooze_handle`, `snooze_title`, `snooze_subtitle` in a `LinearLayout` with id `snooze_drag_zone`, `minHeight=48dp`, `contentDescription=@string/snooze_drag_hint` (new string "Drag down to close"). Chips, presets and Cancel stay outside it.
- [ ] **Step 3: Implement `SheetDragHelper.attach()`.** Touch listener on `dragZone` with `VelocityTracker` and `ViewConfiguration.scaledTouchSlop`; `ACTION_MOVE` sets `sheet.translationY = max(0, dy)` and `scrim.alpha = 1 - translationY/sheet.height`; `ACTION_UP` dismisses per the Global Constraints (animate `translationY` to `sheet.height`, then call `onDismissed`), else animates back to 0; `ACTION_CANCEL` and a second pointer always spring back; ignore touches while an animation runs; `requestDisallowInterceptTouchEvent(true)` once dragging.
- [ ] **Step 4: Wire it** in `SnoozeReminderActivity.onCreate` after `paintScrimAndOptionBackgrounds()`: `SheetDragHelper(findViewById(R.id.snooze_sheet), findViewById(R.id.snooze_scrim), findViewById(R.id.snooze_drag_zone)) { finish() }.attach()`.
- [ ] **Step 5: Verify.** Push; Expected: CI job `mobile-android` green. On device (Review Focus 5): handle and title drag; release at <25 % springs back; >25 % or fast flick closes; scrim fades; chips/presets/Cancel still work; Back and Cancel unchanged.
- [ ] **Step 6: Commit** `feat(reminders): draggable snooze sheet`.

### Task 2: Shared sheet intent, sheet state, `onNewIntent`

**Files:**
- Create: `<R>/ReminderSheetState.kt`
- Modify: `<R>/FullScreenReminderActivity.kt`, `<R>/SnoozeReminderActivity.kt`, `<R>/ReminderNotificationBuilder.kt`

**Interfaces:**
- Produces: `FullScreenReminderActivity.buildIntent(context: Context, noteId: String, title: String, body: String, notificationId: Int, recurrence: String): Intent` (companion; adds `FLAG_ACTIVITY_NEW_TASK`); `object ReminderSheetState { fun shown(); fun hidden(); val anyVisible: Boolean }`; `ReminderNotificationBuilder.show(...)` now returns `Long`, the `setWhen` value it used.

- [ ] **Step 1: `ReminderSheetState`** with a `@Volatile` counter; call `shown()` in `onStart` and `hidden()` in `onStop` of both sheet activities.
- [ ] **Step 2: `buildIntent`** holds the extras now assembled inline in `ReminderNotificationBuilder.show`; the builder calls it. `show` stores `val whenMs = System.currentTimeMillis()`, uses it for `setWhen`, and returns it.
- [ ] **Step 3: Rebind on new intent.** Move the extras/text binding out of `FullScreenReminderActivity.onCreate` into `private fun bind(intent: Intent)`; keep `noteId`, `notificationId`, `title`, `body`, `recurrence` in fields that every click listener reads; add `override fun onNewIntent(intent: Intent)` → `setIntent(intent); bind(intent)`.
- [ ] **Step 4: Verify.** Push; CI green. On device (Review Focus 3): lock the phone, fire two reminders ~10 s apart while the sheet is open → sheet shows the second; Done removes the second card only.
- [ ] **Step 5: Commit** `refactor(reminders): shared sheet intent, sheet state, rebind on new intent`.

### Task 3: Escalation scheduler and receiver

**Files:**
- Create: `<R>/FsiEscalationScheduler.kt`, `<R>/FsiEscalationReceiver.kt`
- Modify: `<R>/ReminderFireReceiver.kt`, `AndroidManifest.xml`

**Interfaces:**
- Consumes: `FullScreenReminderActivity.buildIntent`, `ReminderSheetState.anyVisible`, `ReminderNotificationBuilder.show(...): Long` (Task 2).
- Produces: `object FsiEscalationScheduler { const val ACTION_ESCALATE = "moek.anchor.notex.FSI_ESCALATE"; const val DELAY_MS = 60_000L; fun scheduleIfUnlocked(context: Context, id: Int, noteId: String, title: String, body: String, recurrence: String, postedWhen: Long); fun cancel(context: Context, id: Int); fun cancelAllActive(context: Context) }`

- [ ] **Step 1: Scheduler.** `scheduleIfUnlocked` returns without scheduling unless `PowerManager.isInteractive && !KeyguardManager.isKeyguardLocked`. Alarm: broadcast `PendingIntent` to `FsiEscalationReceiver` (request code = `id`, extras `reminder_id`, `note_id`, `title`, `body`, `recurrence`, `posted_when`) armed with `setExactAndAllowWhileIdle(ELAPSED_REALTIME_WAKEUP, elapsedRealtime + DELAY_MS, pi)`; on `SecurityException` fall back to `set(...)`, as `ReminderAlarmScheduler.arm` does. `cancel` rebuilds the same component+action `PendingIntent` and cancels it. `cancelAllActive` calls `cancel` for every id in `NotificationManager.activeNotifications`.
- [ ] **Step 2: Receiver.** `private fun decide(context, id, postedWhen): Outcome` with `enum Outcome { LAUNCH, REPOST, SKIP }`, evaluated in order: no active notification with this `id` whose `notification.`when` == postedWhen` → SKIP; `ReminderSheetState.anyVisible` → SKIP; `currentInterruptionFilter` in {NONE, ALARMS, PRIORITY} → SKIP; `Settings.canDrawOverlays(context)` false → REPOST; else LAUNCH. LAUNCH calls `context.startActivity(FullScreenReminderActivity.buildIntent(...))` and treats any exception as REPOST. REPOST calls `ReminderNotificationBuilder.show(context, id, noteId, title, body, "", recurrence)` once and does not reschedule.
- [ ] **Step 3: Wire.** In `ReminderFireReceiver`, take the returned `whenMs` from `show` and call `FsiEscalationScheduler.scheduleIfUnlocked(context, id, noteId, title, body, recurrence, whenMs)`.
- [ ] **Step 4: Manifest.** Add `<uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW"/>` and `<receiver android:name="moek.anchor.notex.reminders.FsiEscalationReceiver" android:exported="false">` with the `FSI_ESCALATE` action, next to `ReminderFireReceiver`.
- [ ] **Step 5: Verify.** Push; CI green. On device with overlay granted: unlocked in another app, no action → sheet at ~60 s over that app; locked → unchanged (FSI at fire, no second sheet); DND on → no sheet; revoke overlay then repeat → exactly one re-post, no crash; swipe the card away on Android 14 before 60 s → nothing (Review Focus 4).
- [ ] **Step 6: Commit** `feat(reminders): escalate an unacknowledged banner to the sheet after 60 s`.

### Task 4: Cancel hooks

**Files:**
- Modify: `<R>/ReminderActionReceiver.kt`, `<R>/SnoozeScheduleHelper.kt`, `<R>/ReminderActionChannel.kt`, `<R>/ReminderNotificationBuilder.kt`, `<R>/FullScreenReminderActivity.kt`, `mobile/android/app/src/main/kotlin/moek/anchor/notex/MainActivity.kt`

**Interfaces:**
- Consumes: `FsiEscalationScheduler.cancel(context, id)`, `cancelAllActive(context)`.

- [ ] **Step 1: Receiver, snooze, channel.** `ReminderActionReceiver.onReceive`: `FsiEscalationScheduler.cancel(context, notificationId)` beside the notification cancel. `SnoozeScheduleHelper.snooze`: same call beside `ReminderAlarmScheduler.cancel`. `ReminderActionChannel`: `cancelReminder` → `cancel(context, id)`; `cancelAllReminders` → `cancelAllActive(context)`.
- [ ] **Step 2: Banner tap and "Open note".** Add `putExtra(ReminderActionReceiver.EXTRA_NOTIFICATION_ID, id)` to the banner `tap` intent in the builder and `notificationId` to the `appIntent` of `btn_open_note`. In `MainActivity.stashLaunchExtras`, when `open_note_id` or `snooze_note_id` is non-empty and `intent.getIntExtra("notification_id", -1) >= 0`, call `FsiEscalationScheduler.cancel(this, thatId)`.
- [ ] **Step 3: Verify.** Push; CI green. On device (Review Focus 1–2), each within 55 s, unlocked in another app: tap banner; banner Done; banner Dismiss; banner Snooze → pick a chip → in all four cases no sheet appears at 60 s. Delete the note's reminder in-app → no sheet.
- [ ] **Step 4: Commit** `feat(reminders): cancel the escalation on any user action`.

### Task 5: Native permission methods

**Files:**
- Modify: `<R>/ReminderActionChannel.kt`

**Interfaces:**
- Produces (MethodChannel `moek.anchor.notex/reminder_actions`): `canDrawOverlays → Boolean` (`Settings.canDrawOverlays`), `openOverlaySettings → true` (starts `Settings.ACTION_MANAGE_OVERLAY_PERMISSION` with `Uri.parse("package:" + packageName)`), `canUseFullScreenIntent → Boolean` (`NotificationManager.canUseFullScreenIntent()` on SDK ≥ 34, `true` below), `sdkInt → Int` (`Build.VERSION.SDK_INT`).

- [ ] **Step 1: Add the four `when` branches** in `onMethodCall`.
- [ ] **Step 2: Verify.** Push; CI green. (Exercised end to end in Task 6.)
- [ ] **Step 3: Commit** `feat(reminders): native overlay and full-screen-intent probes`.

### Task 6: Permission flow (Dart, TDD)

**Files:**
- Modify: `mobile/lib/features/reminders/data/notification_gateway.dart`, `mobile/lib/core/storage/storage_keys.dart`, `mobile/lib/core/storage/preferences_repository.dart`, `mobile/lib/features/reminders/data/reminder_permissions.dart`, `mobile/lib/features/reminders/presentation/reminder_permission_prompt.dart`, `mobile/lib/l10n/app_en.arb`, `mobile/test/reminder_permissions_test.dart` (`FakeGateway`), `mobile/test/reminder_permission_prompt_test.dart` (`FakePreferences`)

**Interfaces:**
- Produces on `NotificationGateway`: `Future<bool> canDrawOverlays()`, `Future<void> requestOverlayPermission()`, `Future<bool> canUseFullScreenIntent()`, `Future<int> androidSdkInt()` (0 off Android; implemented over the Task 5 channel methods, catching `PlatformException`/`MissingPluginException` like the existing channel calls). On `PreferencesRepository`: `getOverlayOffered/setOverlayOffered`, `getFullScreenOffered/setFullScreenOffered` (keys `StorageKeys.overlayOffered`, `StorageKeys.fullScreenOffered`). On `ReminderPermissionsController`: `hasOfferedOverlay()`, `markOverlayOffered()`, `hasOfferedFullScreen()`, `markFullScreenOffered()`, `openOverlaySettings()`. ARB: `reminderOverlayTitle` = "Show reminders over other apps?", `reminderOverlayMessage` = "If you don't react to a reminder banner within a minute, it can open as a sheet over the app you're using. Allow Notesx to display over other apps."

- [ ] **Step 1: Extend the fakes.** `FakeGateway`: `int sdk = 0`, `bool overlay = false`, `bool fsi = false`, `int overlayScreensOpened = 0`, `int fsiRequests = 0`, implementing the four new methods and counting in `requestOverlayPermission` / `requestFullScreenIntentPermission`. `FakePreferences`: `offeredOverlay`, `offeredFullScreen`. Defaults keep every existing test green (`sdk = 0` skips both new steps). Also update any other `implements NotificationGateway` (grep) so the suite compiles.
- [ ] **Step 2: Write failing tests** in `reminder_permission_prompt_test.dart`, one `testWidgets` each:
  - `'overlay is offered on Android 10+ once notifications are granted'` (sdk 29, exact true): `find.text('Show reminders over other apps?')` findsOneWidget; tap `'Open settings'`; `gateway.overlayScreensOpened == 1`; `prefs.offeredOverlay` true.
  - `'overlay is still offered when exact alarms were offered before'` (sdk 29, `prefs.offeredExact = true`, exact false): dialog findsOneWidget.
  - `'overlay is not offered twice'` (`offeredOverlay = true`), `'... when already granted'` (`overlay = true`), `'... below Android 10'` (sdk 28): `find.text('Show reminders over other apps?')` findsNothing.
  - `'full-screen intent is offered on Android 14+ when not allowed'` (sdk 34, `overlay = true`, fsi false): `find.text('Keep reminders visible')` findsOneWidget; tap `'Open settings'`; `gateway.fsiRequests == 1`.
  - `'full-screen intent is not offered on Android 13, when allowed, or twice'` (sdk 33; `fsi = true`; `offeredFullScreen = true`): findsNothing.
- [ ] **Step 3: Run** `cd mobile && flutter test test/reminder_permission_prompt_test.dart`. Expected: new tests FAIL (compile errors on missing members until Step 4), existing ones pass.
- [ ] **Step 4: Implement.** In `ensureReminderPermissions` replace the exact-alarm early `return` with a guarded block (exact dialog unchanged, still once), then call two new private steps in order: `_offerOverlay` (needs `sdk >= 29`, `!canDrawOverlays()`, `!hasOfferedOverlay()`; mark offered, show dialog with `commonNotNow` / `commonOpenSettings`, open settings on confirm) and `_offerFullScreen` (needs `sdk >= 34`, `!canUseFullScreenIntent()`, `!hasOfferedFullScreen()`; same shape, existing title/message, `requestFullScreenIntentPermission`). Remove the `Platform.operatingSystemVersion` check. Add the ARB strings and regenerate l10n the way the repo does (`flutter gen-l10n`, or let `flutter pub get`/build generate).
- [ ] **Step 4b: Run** `flutter analyze && flutter test`. Expected: no issues, all tests PASS (update any old test that asserted the FSI dialog's previous placement to the new rule).
- [ ] **Step 5: Commit** `feat(reminders): overlay permission step; fix Android 14 full-screen prompt`.

### Task 7: Ship and device pass

**Files:**
- Modify: `docs/superpowers/specs/2026-11-22-standalone-reminder-sheet-design.md` (§Constraints)

- [ ] **Step 1:** Under §Constraints add one line: "Superseded in part by `2026-11-23-fsi-escalation-snooze-drag-design.md`: with the overlay grant, a 60 s escalation does show the sheet over other apps while awake." Commit `docs: note escalation supersedes awake-constraint`.
- [ ] **Step 2:** Push the branch; Expected: CI jobs `flutter` (analyze + test) and `mobile-android` green.
- [ ] **Step 3: Device pass** on one Android 14+ device and, if available, one Android 12: fresh install → set a reminder → the overlay (and FSI, if missing) dialogs appear once each, in that order, and are not asked again; run the Task 3–4 checklists once end to end with the final build; confirm the banner still persists past 60 s.

---

## Self-review (done)
- **Spec coverage:** (a) Task 1; escalation, guards, one-shot, DND, screen-off launch → Task 3; cancel points → Task 4; `onNewIntent` + shared factory → Task 2; native probes + Dart flow + broken SDK check + early-return fix → Tasks 5–6; spec supersede note → Task 7; manifest → Task 3.
- **Type consistency:** `scheduleIfUnlocked` / `cancel` / `cancelAllActive`, `buildIntent`, `ReminderSheetState.anyVisible`, `show(): Long`, channel method names and Dart gateway names are used identically across tasks.
- **Known limit:** no automated tests for Kotlin (none exist in the repo); its tests are the device checklists above.
