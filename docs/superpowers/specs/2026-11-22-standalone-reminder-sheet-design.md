# Standalone Reminder Sheet — Design

**Date:** 2026-11-22 · **Status:** draft for approval · **Author:** Pi
**Ref designs (Doop, `ready_for_dev`):** Reminder sheet `nx07-wSkMw`, Snooze picker `Wn02ojCMhA`

## Intent / why
The reminder card must appear **standalone — without loading the app's
dashboard**. It shows in two cases: (a) the phone is locked at the due time,
and (b) the heads-up has auto-hidden and the user has not acted. Every button
works from the sheet. Only **tapping the notification banner** and the **"Open
note" button** launch the main app; Done / Dismiss / Close / Snooze are
standalone (no app launch). This mirrors version `b1a2839`'s "snooze without
opening the app" behavior, now with the Doop visual design.

## Goals
- Restyle the full-screen reminder sheet (`FullScreenReminderActivity`) 1:1 to
  Doop `nx07-wSkMw` (dark card, accent bell + meta header, bold title, muted
  body, flat icon+label action rows).
- Add an **"Open note" button at the top** of the reminder sheet → deep-links
  to the note in the main app.
- Build a **standalone Snooze sheet** (new native activity) 1:1 to Doop
  `Wn02ojCMhA`: scrim + rounded bottom sheet, "Snooze" title + subtitle
  (`<note> · <recurrence>`), quick chips (10 min / 30 min / 1 hour / 4 hours /
  1 day), presets (Later today / Tomorrow / Pick a date & time).
- Picking a snooze option **re-schedules the reminder natively** (no app
  launch), persists it, and toasts.

## Non-goals
- No Flutter/dashboard overlay. No in-app full-screen reminder card.
- No change to the heads-up notification's system UI (that is OS-controlled).
- iOS: out of scope for this change (Android native reminder system).

## Constraints (Android platform)
- Superseded in part by `2026-11-23-fsi-escalation-snooze-drag-design.md`: with the overlay grant, a 60 s escalation does show the sheet over other apps while awake.
- A full-screen sheet **auto-appears only when the device is locked / screen
  off** (full-screen intent). When the device is **awake**, the standalone
  surface is the **system heads-up notification** (dashboard-free, in system
  UI); it auto-hides to the shade, and **tapping the banner** opens the main
  app (contentIntent → MainActivity, unchanged). A background app cannot be
  forced to full-screen over another app when awake.
- The Dart drift DB is the **source of truth** for `remindAt`. Native
  snooze therefore re-arms the AlarmManager *and* stashes the new time for
  Dart to apply on the next open (stash→drain, same pattern as
  `LaunchExtrasChannel`).

## Approach
- **Two native activities**, both translucent + `showWhenLocked` +
  `turnScreenOn`, styled to the Doop frames:
  1. `FullScreenReminderActivity` — restyled + new "Open note" action.
  2. `SnoozeReminderActivity` (new) — the standalone snooze picker.
- **Intent map (who launches the app):**
  - Tap notification banner → `MainActivity` (app). *unchanged.*
  - "Open note" (reminder sheet) → `MainActivity` with `open_note_id` → the note. *new.*
  - "Snooze" (reminder sheet + notification action) → `SnoozeReminderActivity`. *changed from MainActivity.*
  - Done / Dismiss / Close → native broadcast / finish. *unchanged.*
- **Native re-schedule (snooze):**
  - Add a `recurrence` field to `ReminderAlarmStore` + notification extras
    (needed for the subtitle and the recurring "1 day" chip).
  - On option pick: compute target time, `ReminderAlarmScheduler.cancel` the
    current alarm, `arm` at the target, and write a **pending-snooze** record
    `{noteId, newAt, recurrence}` to a native prefs store. Toast "Snoozed
    until <time>".
  - Dart drains pending-snooze on cold start (and live if the app is
    foreground) → sets the note's `remindAt` = newAt → reconciles the
    scheduler → clears the record.
- **Recurring snooze semantics (decided):** snooze delays **this
  occurrence only**; the rest of the recurrence series stays on schedule.
- **v1 snooze options (decided):** full set — quick chips + Later today +
  Tomorrow + Pick a date & time (native `DatePickerDialog` +
  `TimePickerDialog`, pre-filled). The "1 day" chip is shown **only for
  recurring** reminders (matches the Flutter snooze rule).
- **Open note (decided):** deep-link to the note (`open_note_id`, existing
  `LaunchExtrasChannel` path).

## Parts left to the builder (my calls unless you object)
- Native l10n: the reminder/snooze sheet labels live in `res/strings.xml`
  (English), consistent with the existing native reminder strings.
- Multiple pending snoozes: apply the latest per `noteId`.
- Snooze on a one-shot (non-recurring) reminder: chips + presets apply; the
  "1 day" chip is hidden.
- After "Close": the sticky notification remains in the shade (existing).
- "Pick a date & time" prefill: now + 1h (date) and the current wall time.
- The snooze sheet is reachable from the reminder sheet's "Snooze" button and
  from the notification's "Snooze" action (both → `SnoozeReminderActivity`).

## Verification
- `flutter analyze` clean; `flutter build apk --debug` (Kotlin compiles).
- On-device (the gate): locked at due → reminder sheet above lockscreen →
  all 5 buttons work; Snooze → snooze sheet → pick an option → toast + no app
  launch; open the app → `remindAt` updated; Done/Dismiss settle + drop the
  card; "Open note" opens the note.
