# Reminder Phase 2 — Native Android (refined)

> **Status:** ACTIVE — worktree `feature/phase2-reminders`
> **Design refs:** Doop frames `nx07-wSkMw` (FSI sheet), `Wn02ojCMhA` (snooze picker), `6XFPivzxyQ` (HUN banner)

## Decisions (from design review + research)

1. **FSI sheet** = flat, NO scrim (clear bg), 4 flat buttons: Mark as done / Dismiss / Snooze / Close↓
2. **Snooze picker** = rounded + scrim (overlay), BottomSheet component
3. **Background actions** (Done/Dismiss): BroadcastReceiver (Kotlin) + SharedPreferences flag. Done=toast, Dismiss=silent. No app UI.
4. **Snooze**: opens app (showsUserInterface: true) → snooze picker sheet
5. **Close↓**: slides sheet down (finish activity), banner/sticky notification stays
6. **USE_FULL_SCREEN_INTENT**: declared in manifest (v0.25.14), prompt at reminder setup (v0.25.15)
7. **fullScreenIntent: true** on important-tier notifications (v0.25.14)
8. **HomeBackground** = reusable Doop component (full opacity, no dimming)
9. **Buttons**: flat (no border, no background), left-aligned icon + text, 44px min touch target

## Global Constraints
- Tak sentuh `server/`. Mobile-only.
- FSI hanya untuk reminder importance-MAX + tak-pinned.
- Done/Dismiss = background (BroadcastReceiver + SharedPreferences). Tak buka UI.
- Snooze = buka app (showsUserInterface: true).
- UI pakai design tokens (AnchorTokens/AppTypography). Tak hardcode warna.
- l10n: text di `app_en.arb` + `@key.description`.
- Conventional Commits `type(mobile): what`.

## Tasks

### Task 1: BroadcastReceiver — background action handler
**Goal:** Receive Done/Dismiss action intents in the background. Write action to SharedPreferences. Show toast for Done.
**Files:**
- Create `mobile/android/app/src/main/kotlin/.../ReminderActionReceiver.kt`
- Modify `mobile/android/app/src/main/AndroidManifest.xml` (register receiver)
- Modify `mobile/lib/features/reminders/presentation/notification_launch.dart` (read pending actions from SharedPreferences on app start)
- Modify `mobile/lib/features/reminders/presentation/reminder_tap_handler.dart` (drain pending actions)

**Interface:**
- Receiver reads `action_id` + `note_id` from intent extras
- Writes to SharedPreferences: `pending_reminder_action` = `{"noteId":"...","type":"done|dismiss"}`
- Done: `Toast.makeText(ctx, "Selesai", LENGTH_SHORT)`
- Dismiss: no toast
- Flutter side: `takePendingReminderActions()` checks SharedPreferences for stored actions

**Steps:**
- [ ] Write ReminderActionReceiver.kt (onReceive: read extras, write SharedPreferences, toast if done)
- [ ] Register receiver in AndroidManifest.xml (exported=true, intent-filter for ACTION_REMINDER_DONE/DISMISS)
- [ ] Update notification_gateway.dart: set PendingIntent extras (action_id, note_id) on action buttons
- [ ] Update notification_launch.dart: read SharedPreferences for pending actions in `initializeNotifications()`
- [ ] Test: unit test SharedPreferences read/write
- [ ] Commit

### Task 2: FullScreenReminderActivity (Kotlin)
**Goal:** Host the FSI sheet. Shows on lockscreen + screen off. Translucent, `showWhenLocked`, `turnScreenOn`.
**Files:**
- Create `mobile/android/app/src/main/kotlin/.../FullScreenReminderActivity.kt`
- Modify `mobile/android/app/src/main/AndroidManifest.xml` (declare activity)
- Create `mobile/android/app/src/main/res/values/styles.xml` (translucent theme)

**Interface:**
- Launched via `setFullScreenIntent(PendingIntent→FullScreenReminderActivity, highPriority=true)`
- Activity reads note_id from intent extra
- Hosts a Flutter fragment OR shows a native layout with the sheet
- `turnScreenOn` + `showWhenLocked` + `hideLockscreen`
- Finish = slide sheet down + banner stays (sticky notification)

**Steps:**
- [ ] Create FullScreenReminderActivity.kt (translucent, showWhenLocked, turnScreenOn)
- [ ] Native layout: bottom sheet with 4 flat buttons (or Flutter fragment)
- [ ] Register in manifest (android:showWhenLocked, android:turnScreenOn, exported=true)
- [ ] Modify notification_gateway.dart: set fullScreenIntent PendingIntent → FullScreenReminderActivity
- [ ] Commit

### Task 3: Flutter side — pending action drain
**Goal:** On app cold start, check SharedPreferences for pending Done/Dismiss actions. Settle the occurrence.
**Files:**
- Modify `mobile/lib/features/reminders/presentation/notification_launch.dart`
- Modify `mobile/lib/features/reminders/presentation/reminder_tap_handler.dart`

**Steps:**
- [ ] Add `readPendingReminderAction()` (reads SharedPreferences)
- [ ] In `ReminderTapHandler.build()`, drain pending actions + settle
- [ ] Test: mock SharedPreferences, verify settle
- [ ] Commit

### Task 4: l10n + toast strings
**Files:** `mobile/lib/l10n/app_en.arb` + generated files
**Steps:**
- [ ] Add "Selesai" toast string (or use existing)
- [ ] Add FSI sheet strings (if any new)
- [ ] Patch generated files
- [ ] Commit

### Task 5: Quick menu shortcuts (optional, later)
**Files:** `res/xml/shortcuts.xml` + `ShortcutWrapperActivity.kt`
- 3 shortcuts: New note / New journal / New reminder
- `ShortcutWrapperActivity` reads `shortcut_type` → deep-link → Flutter create form

### Task 6: Verifikasi final
- `flutter analyze` + `flutter test`
- Manual device: lock + reminder MAX → FSI sheet → actions work
- Manual device: HUN tap → snooze picker opens

