# Standalone Reminder Sheet: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** The reminder card appears standalone (no dashboard): a restyled full-screen reminder sheet (Doop `nx07-wSkMw`, with a new "Open note" button) and a new standalone snooze sheet (Doop `Wn02ojCMhA`) that re-schedules the reminder natively without opening the app.

**Architecture:** Two native activities (`FullScreenReminderActivity` restyled + `SnoozeReminderActivity` new), both translucent/`showWhenLocked`. "Snooze" opens the snooze sheet instead of the main app; picking an option re-arms the AlarmManager and stashes a pending-snooze record that Dart applies to the drift DB on next open. Only "Open note" and tapping the banner launch the app.

**Tech Stack:** Android native (Kotlin + XML + vector drawables), Flutter/Dart (MethodChannel drain), DM Sans font.

**Spec:** `docs/superpowers/specs/2026-11-22-standalone-reminder-sheet-design.md`

## Global Constraints
- Work in worktree `fsi/design` (branch `fsi/design`, base `1864c67`). FSI restyle is ~80% done there (font, colors, 5 icons, layout, Kotlin), so build on it and do not redo it.
- Commit format: Conventional Commits `type(scope): what`, scope `mobile`. One thing per commit. No `git add -A`.
- Native reminder strings live in `res/values/strings.xml` (English), matching existing `reminder_action_*`.
- `flutter analyze` must stay clean (Dart). Kotlin compiles via `rflutter build apk --debug` (box-05). On-device test is the visual gate.
- Colors are theme-aware: `@color/fsi_*` (light + night) already created; reuse them for the snooze sheet.

## Review Focus
- **Snooze then open app:** after a native snooze, the app's next open must keep the snoozed time (not revert it to the stale DB value). → Task 4 test.
- **Recurring snooze:** snoozing delays only this occurrence; other pre-armed recurrence occurrences stay. → Task 3 (verify no mass-cancel).
- **One-shot reminder:** the "1 day" chip is hidden; snoozing still works via other options. → Task 2.
- **Device awake, banner tap:** tapping the notification body still opens the app (contentIntent unchanged). Do not break it. → Task 1 (don't touch contentIntent).
- **Empty/unknown recurrence in extras:** the snooze sheet subtitle degrades gracefully ("Snooze" with no recurrence word) when the extra is absent. → Task 2.

---

## Task 1: Finish FSI restyle, add "Open note" + point "Snooze" at the snooze sheet

**Files:**
- Modify: `mobile/android/app/src/main/res/layout/activity_full_screen_reminder.xml`
- Modify: `mobile/android/app/src/main/res/values/strings.xml`
- Create: `mobile/android/app/src/main/res/drawable/ic_fsi_open_note.xml`
- Modify: `mobile/android/app/src/main/kotlin/moek/anchor/notex/reminders/FullScreenReminderActivity.kt`
- Modify: `mobile/android/app/src/main/AndroidManifest.xml` (no change needed if `SnoozeReminderActivity` added in Task 2; here just confirm FSI is registered)

**Interfaces:**
- Produces: `R.id.btn_open_note` (LinearLayout row) and `R.id.btn_snooze` now targeting `SnoozeReminderActivity` (class from Task 2; add a temporary `TODO` target of `SnoozeReminderActivity` by name; it compiles once Task 2 lands; build order: do Task 2's manifest+class stub first if the build fails).

- [ ] **Step 1: Add the "Open note" action row at the top of the FSI actions block**

In `activity_full_screen_reminder.xml`, insert a new first action row (before `btn_mark_done`) with `android:id="@+id/btn_open_note"`, icon `@drawable/ic_fsi_open_note`, label `@string/fsi_action_open_note`. Copy the structure of the existing `btn_dismiss` row (LinearLayout row + ImageView 20dp + TextView `13.5sp` `'wght' 500`), and drop `android:layout_marginTop` (it's first). Give it the same `?android:attr/selectableItemBackground`, `minHeight 44dp`, `paddingTop/Bottom 4dp`, `gravity center_vertical`.

- [ ] **Step 2: Add the "Open note" icon + string**

Create `ic_fsi_open_note.xml`: lucide "notebook-text" or "file-text", a 24×24 vector, `strokeColor="@color/fsi_text"`, `strokeWidth="1.5"`, round caps. Use the file-text path: `M4 4h11a3 3 0 0 1 3 3v13a3 3 0 0 0 3-3V7`-style is wrong; use this concrete set:
```
M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z
M14 2v6h6
M8 13h8
M8 17h8
```
(add the last two as separate `<path>` lines, strokeWidth 1.5.)
Add to `strings.xml`: `<string name="fsi_action_open_note">Open note</string>`.

- [ ] **Step 3: Wire the two buttons in `FullScreenReminderActivity.kt`**

Add `findViewById<View>(R.id.btn_open_note).setOnClickListener { ... }` → launch `MainActivity` with `putExtra("open_note_id", noteId)` + `FLAG_ACTIVITY_NEW_TASK` (reuse the existing `open_note_id` extra that `LaunchExtrasChannel`/`MainActivity.stashLaunchExtras` already consumes). Change the existing `btn_snooze` handler from launching `MainActivity` with `snooze_note_id` to launching `SnoozeReminderActivity` with extras `note_id`, `title`, `body`, `recurrence`, `notification_id` (see Task 2 interface).

- [ ] **Step 4: Build (Kotlin compiles)**

Run: `cd .worktrees/fsi-design/mobile && rflutter build apk --debug`
Expected: BUILD SUCCESSFUL. (If `SnoozeReminderActivity` doesn't exist yet, do Task 2's Step 1–2 stub first so this compiles.)

- [ ] **Step 5: Commit**
```bash
git add mobile/android/app/src/main/res mobile/android/app/src/main/kotlin/moek/anchor/notex/reminders/FullScreenReminderActivity.kt
git commit -m "feat(mobile): add Open note to the reminder sheet and route Snooze to a standalone sheet"
```

## Task 2: SnoozeReminderActivity, standalone snooze sheet UI (Doop Wn02ojCMhA)

**Files:**
- Create: `mobile/android/app/src/main/kotlin/moek/anchor/notex/reminders/SnoozeReminderActivity.kt`
- Create: `mobile/android/app/src/main/res/layout/activity_snooze_reminder.xml`
- Create: `mobile/android/app/src/main/res/drawable/bg_snooze_sheet.xml`
- Create: `mobile/android/app/src/main/res/values/strings.xml` (add snooze strings)
- Create: `mobile/android/app/src/main/res/drawable/ic_snooze_clock.xml`, `ic_snooze_calendar.xml`
- Modify: `mobile/android/app/src/main/AndroidManifest.xml`

**Interfaces:**
- Consumes: extras from FSI/banner: `note_id` (String), `title` (String), `body` (String), `recurrence` (String, e.g. `none|daily|weekly|monthly`), `notification_id` (Int).
- Produces: `SnoozeReminderActivity` (class + `EXTRA_*` constants) that Task 1's "Snooze" button and the notification's "Snooze" action launch; and `SnoozeScheduleHelper` (Task 3) that its option rows call.

Design (dark + light via `@color/fsi_*`): scrim (`#000` ~60% in night, ~36% in light) behind a bottom sheet with `border-radius` top 28dp, surface bg, a 32×4dp handle (muted 38%), header (centered title "Snooze" 20sp bold + centered subtitle 14sp muted `<title> · <recurrence>`), body with:
- Label "SNOOZE FOR" (12sp semibold, muted, uppercase, tracking 0.05, mb 8)
- Chips row (wrap, gap 8, mb 16): `10 min`, `30 min`, `1 hour`, `4 hours`, `1 day`. Pill (radius 999), padding 8×16, 12.5sp medium, subtle bg, text color. **"1 day" chip only when `recurrence != none`.** Selected chip = 1.5dp accent border (default selected = "1 hour").
- Label "TODAY" (mb 8)
- Three full-width preset buttons (gap 8, radius 10dp, subtle bg, 1dp border, min-height 44, icon 18dp + 13.5sp label): "Later today" (clock icon), "Tomorrow" (calendar icon), "Pick a date and time" (calendar icon).

- [ ] **Step 1: Create the layout + background drawable + strings + icons**

`bg_snooze_sheet.xml` = rounded-top-28dp shape, solid `@color/fsi_surface`, plus (night) a 1dp top hairline like `bg_fsi_sheet`. Strings: `snooze_sheet_title`="Snooze", `snooze_label_snooze_for`="Snooze for", `snooze_label_today`="Today", `snooze_chip_10min`="10 min", `snooze_chip_30min`="30 min", `snooze_chip_1hour`="1 hour", `snooze_chip_4hours`="4 hours", `snooze_chip_1day`="1 day", `snooze_preset_later_today`="Later today", `snooze_preset_tomorrow`="Tomorrow", `snooze_preset_pick`="Pick a date and time", `snooze_toast_snoozed`="Snoozed until %1$s". Icons: `ic_snooze_clock` (lucide clock: `circle cx12 cy12 r10` + `M12 6v6l4 2`, stroke `@color/fsi_text` 1.5), `ic_snooze_calendar` (lucide calendar: `rect 3 4 18 18 rx2` + two top lines + mid line, stroke 1.5).

- [ ] **Step 2: Create `SnoozeReminderActivity.kt` (UI only, options log for now)**

`class SnoozeReminderActivity : Activity()` with `EXTRA_NOTE_ID/TITLE/BODY/RECURRANCE/NOTIFICATION_ID` constants. In `onCreate`: read extras, set the scrim + sheet, fill title/subtitle (subtitle = `title` + (if recurrence != none) ` · repeats <recurrence>` else ""), set the "1 day" chip visible only when `recurrence != none`. Each chip/preset row `setOnClickListener` → for now `finish()` + a `Toast` (logic lands in Task 3). Register in the manifest with `android:theme="@style/Theme.FsiActivity"`, `android:excludeFromRecents="true"`, `android:launchMode="singleTask"`, mirroring the existing `FullScreenReminderActivity` entry.

- [ ] **Step 3: Build**

Run: `rflutter build apk --debug` → BUILD SUCCESSFUL.

- [ ] **Step 4: Commit**
```bash
git add mobile/android/app/src/main/res mobile/android/app/src/main/kotlin/moek/anchor/notex/reminders/SnoozeReminderActivity.kt mobile/android/app/src/main/AndroidManifest.xml
git commit -m "feat(mobile): add the standalone snooze sheet UI"
```

## Task 3: Native snooze re-schedule (helper + store + arm/cancel + recurrence)

**Files:**
- Create: `mobile/android/app/src/main/kotlin/moek/anchor/notex/reminders/SnoozeScheduleHelper.kt`
- Create: `mobile/android/app/src/main/kotlin/moek/anchor/notex/reminders/PendingSnoozeStore.kt`
- Modify: `mobile/android/app/src/main/kotlin/moek/anchor/notex/reminders/ReminderAlarmStore.kt` (add `recurrence` field)
- Modify: `mobile/android/app/src/main/kotlin/moek/anchor/notex/reminders/SnoozeReminderActivity.kt` (wire options → helper)
- Modify: `mobile/android/app/src/main/kotlin/moek/anchor/notex/reminders/ReminderNotificationBuilder.kt` (snooze action → `SnoozeReminderActivity`; add `recurrence` extra)

**Interfaces:**
- Produces: `SnoozeScheduleHelper.snooze(context, noteId, notificationId, title, body, recurrence, targetMillis)`: cancels the current alarm + notification for the occurrence, arms a new alarm at `targetMillis`, writes `{noteId, newAtMillis, recurrence}` to `PendingSnoozeStore`, and shows the toast.
- Produces: `PendingSnoozeStore.put(context, noteId, newAtMillis, recurrence)` / `PendingSnoozeStore.drain(context): List<PendingSnooze>` (Task 4 consumes via channel).
- `reminderAlarmStore` entries gain `"recurrence"`.

Time math (mirror Dart `reminder_times.dart`):
- chips: `target = now + minutes*60000` (10/30/60/240; 1440 only if recurring).
- Later today: `later = now + 3h`, ceil to next 5-min boundary; hide the row if `later`'s date != `now`'s date.
- Tomorrow: next day 09:00 local.
- Pick a date & time: `DatePickerDialog` then `TimePickerDialog`, prefill now+1h; combine to millis.

- [ ] **Step 1: Add `recurrence` to `ReminderAlarmStore`**: include it in `save`/`load`/`upsert` maps (`optString` default `"none"`).

- [ ] **Step 2: Create `PendingSnoozeStore`**: SharedPreferences `pending_snoozes`; `put` upserts `{noteId,newAtMillis,recurrence}`; `drain` returns + clears all; `data class PendingSnooze(noteId, newAtMillis, recurrence)`.

- [ ] **Step 3: Create `SnoozeScheduleHelper.snooze(...)`**: use `ReminderAlarmScheduler` (cancel by noteId, then arm at `targetMillis` with the store's title/body/recurrence), `NotificationManagerCompat`-style cancel of `notificationId` to drop the card, `PendingSnoozeStore.put(...)`, `Toast` with `snooze_toast_snoozed` formatted by the target time. Then `activity.finish()`.

- [ ] **Step 4: Wire the options** in `SnoozeReminderActivity`: each chip/preset computes `targetMillis` (per the time math above) and calls `SnoozeScheduleHelper.snooze(...)`. "Pick a date and time" opens `DatePickerDialog` → `TimePickerDialog` → call.

- [ ] **Step 5: Point the notification "Snooze" action at the sheet**: in `ReminderNotificationBuilder`, change the snooze `PendingIntent` from `MainActivity` to `SnoozeReminderActivity` (pass the same extras incl. `recurrence`). Leave the banner `contentIntent` → `MainActivity` (unchanged).

- [ ] **Step 6: Build**: `rflutter build apk --debug` → BUILD SUCCESSFUL.

- [ ] **Step 7: Commit**
```bash
git add mobile/android/app/src/main/kotlin/moek/anchor/notex/reminders mobile/android/app/src/main/AndroidManifest.xml
git commit -m "feat(mobile): snooze re-arms the reminder natively and stashes it for the app"
```

## Task 4: Dart, pass recurrence to native + drain pending snoozes on open

**Files:**
- Modify: `mobile/lib/features/reminders/data/reminder_alarm_channel.dart` (or wherever the native arm/cancel channel calls live, and add a `recurrence` field to `armReminder`)
- Modify: `mobile/lib/features/reminders/data/reminder_scheduler.dart` (include recurrence when arming)
- Create: `mobile/lib/features/reminders/data/pending_snooze_channel.dart` (MethodChannel `drainPendingSnoozes` + apply to DB)
- Modify: `mobile/lib/features/reminders/presentation/reminder_tap_handler.dart` or `lib/app/bootstrap.dart` (call the drain on cold start, before the scheduler reconciles)
- Test: `mobile/test/pending_snooze_test.dart`

**Interfaces:**
- Produces: `drainPendingSnoozes({required NotesRepository repo})` → for each native `PendingSnooze`, set the note's `remindAt = newAt` (mark unsynced for the sync engine) and clear the native record. Runs on cold start and on resume-while-foreground.
- The native side exposes `drainPendingSnoozes()` on an existing reminder MethodChannel (add in Task 3's receiver/channel if needed).

- [ ] **Step 1: Write the failing Dart test** (`test/pending_snooze_test.dart`). With a fake repo, `drainPendingSnoozes` updates `remindAt` for the snoozed note and returns the count; when no records, it's a no-op. (Channel is mocked.)

- [ ] **Step 2: Run to verify it fails**: `rflutter test test/pending_snooze_test.dart` → FAIL (function not defined).

- [ ] **Step 3: Implement `pending_snooze_channel.dart`** + add `recurrence` to the arm channel + call the drain in bootstrap (cold start, before the scheduler pass) and on resume-while-foreground.

- [ ] **Step 4: Run test to verify it passes**: `rflutter test test/pending_snooze_test.dart` → PASS. Also `rflutter test` (reminder suite) stays green.

- [ ] **Step 5: Analyze + build**: `rflutter analyze` clean; `rflutter build apk --debug` SUCCESS.

- [ ] **Step 6: Commit**
```bash
git add mobile/lib mobile/test
git commit -m "feat(mobile): apply native snooze to the database and pass recurrence to the alarm"
```

## Task 5: Integration verify + release

**Files:** (verification only)

- [ ] **Step 1: Full build + on-device test (the gate)**: build a signed arm64 release (re-host non-GH for the user) and verify: locked at due → reminder sheet above lockscreen; all 5 buttons work; Snooze → snooze sheet; pick an option → toast, no app launch; open app → `remindAt` updated; Done/Dismiss settle + drop the card; "Open note" opens the note; one-shot hides the "1 day" chip.

- [ ] **Step 2: CI**: push the branch → `main`, watch `mobile-android` go green.

- [ ] **Step 3: Tag + release**: tag the next version (v0.28.0, a feature), push, confirm the release build.

---

## Self-review notes
- Spec coverage: FSI restyle (Task 1) + "Open note" (Task 1); snooze sheet UI (Task 2); native re-schedule + persistence + recurrence (Task 3); Dart drain (Task 4); release (Task 5). All spec sections map.
- The FSI restyle base (~80%) already exists in the worktree; Task 1 extends it (Open note + snooze target), Tasks 2–4 add the snooze system.
- Kotlin XML/UI is verified by build; on-device is the true visual gate (Task 5).
- Review Focus items are pinned to tasks (Task 4 test for revert; Task 3 for no mass-cancel; Task 2 for one-shot chip + empty recurrence; Task 1 for contentIntent; Task 2 for missing recurrence extra).
