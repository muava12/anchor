# FSI Escalation (60 s) + Draggable Snooze Sheet: Design

**Date:** 2026-11-23 · **Status:** approved in conversation · **Author:** Claude
**Supersedes (in part):** `2026-11-22-standalone-reminder-sheet-design.md` §Constraints ("a background app cannot be forced to full-screen over another app when awake"). This change does exactly that, with the user's "Display over other apps" grant.

## Intent / why
A fired reminder must not be missed. While the phone is **unlocked**, the reminder currently shows only as a heads-up banner. The banner already persists (>1 min) because `USE_FULL_SCREEN_INTENT` is declared and granted (AOSP FSI limits: persistent HUN when granted; 60 s when denied). The owner still wants a stronger nudge: if nobody acts on the banner for **60 s**, the reminder sheet (`FullScreenReminderActivity`) appears over whatever app is open.
Separately, the snooze sheet's top area does not drag like a normal bottom sheet (the 32×4 dp handle is decorative).

## Goals
1. Draggable snooze sheet: drag down → sheet follows the finger; past threshold → slides out and closes; otherwise springs back.
2. 60 s escalation from banner to the reminder sheet while unlocked, via `AlarmManager` + a new receiver, using `SYSTEM_ALERT_WINDOW` (a documented exemption from background-activity-launch limits since Android 10).
3. A permission flow for "Display over other apps", asked in context (when the user sets a reminder), with a sane fallback when refused.

## Non-goals / anti-goals
- No attempt to extend the system heads-up duration (re-post loops, AccessibilityService): fragile, vendor-dependent.
- Escalation must never fire after the user has acted, opened the note, snoozed, or the card is gone (a stale sheet is worse than none).
- No drag on `FullScreenReminderActivity` in this change; no iOS.

## Constraints
- Kotlin is verified by CI job `mobile-android` (`flutter build apk --debug`); there are no Kotlin unit tests. Device check is the gate.
- Notification is `ongoing`, not auto-cancel; a banner tap goes straight to `MainActivity` (Android 12+ forbids notification trampolines), so cancelling on tap must happen in `MainActivity`.
- `FullScreenReminderActivity` is `singleInstance` and has no `onNewIntent` (pre-existing); escalation makes a stale-content bug likelier, so it is fixed here.
- The Dart FSI prompt gates on `int.tryParse(Platform.operatingSystemVersion) >= 14`, which very likely evaluates to 0 on Android (unverified), replaced by an SDK value from native.

## Approaches
1. **Alarm + receiver + `startActivity(FullScreenReminderActivity)` under SYSTEM_ALERT_WINDOW: chosen.** Reuses the existing sheet; permission is documented as exempting background launches.
2. Overlay window via `WindowManager` (`TYPE_APPLICATION_OVERLAY`): needs the same permission and duplicates the sheet UI. Rejected.
3. Re-post the notification only: no sheet. Used only as the **fallback** when the overlay grant is missing.
4. Prolong the heads-up by tricks: rejected (see non-goals).

## Design
### (a) Draggable snooze sheet
- `SheetDragHelper` (new, small, reusable): attaches to a drag zone (handle + header, ≥48 dp touch height) and animates the sheet's `translationY`, clamped ≥ 0; the scrim alpha follows.
- Release: dismiss if `translationY > 25 %` of sheet height or downward velocity > ~1000 dp/s → slide out with the exit curve already used by the FSI sheet (≈280 ms), then `finish()`; otherwise animate back to 0 (≈200 ms).
- Closing by drag behaves exactly like "Cancel" / Back: no reschedule, reminder stays as is.
- Touch handling only on the drag zone, so chips and presets are unaffected. Accessibility: content description on the zone.

### (b) Escalation
- `FsiEscalationScheduler` (schedule/cancel/cancelAllActive) and `FsiEscalationReceiver` (new, `exported=false`), request code derived from the reminder id, `FLAG_IMMUTABLE`.
- Scheduled from `ReminderFireReceiver` after posting, only when the screen is interactive and the keyguard is not locked (locked/off already gets the FSI). The builder returns the `when` it set so the receiver can match the exact occurrence.
- Cancelled by: Done/Dismiss (`ReminderActionReceiver`), every snooze path (`SnoozeScheduleHelper`), banner tap / "Open note" (hook in `MainActivity` using a new `notification_id` extra on both intents), and `cancelReminder` / `cancelAllReminders` in `ReminderActionChannel`.
- Receiver guards, in order: notification still active **and** same occurrence (`when`); no reminder/snooze sheet currently visible (lifecycle flag); interruption filter is ALL (my call: DND is respected); `Settings.canDrawOverlays` → launch the sheet; otherwise fallback re-post once. One-shot per occurrence: Close on the escalated sheet does not re-arm.
- If the screen is off at 60 s the sheet still launches (my call; the reminder is unacknowledged).
- Sheet intent construction moves to one shared factory used by the builder and the receiver. `FullScreenReminderActivity` gets `onNewIntent` + rebind.
- Manifest: `SYSTEM_ALERT_WINDOW`, the receiver.

### Permission flow
- Native `ReminderActionChannel` gains `canDrawOverlays`, `openOverlaySettings` (`ACTION_MANAGE_OVERLAY_PERMISSION` with the `package:` URI) and `sdkInt`.
- Dart `NotificationGateway` / `ReminderPermissionsController` expose them; `ensureReminderPermissions` gets an overlay step (explanatory dialog, offered once, remembered like `hasOfferedExact`), and the broken Android-14 check uses native `sdkInt`. The overlay and FSI steps no longer sit behind the exact-alarm early return.
- Result is re-read on resume (the settings screen returns no reliable result).

## Edge cases
Multiple simultaneous reminders (per-id alarms; one sheet, rebind via `onNewIntent`), Doze (exact-and-allow-while-idle, like the reminder alarm), reboot (notifications and escalation alarms are gone together; nothing to re-arm), grant revoked after scheduling (guard re-checks), OEM-specific popup toggles (fallback covers), Android 15+ overlay narrowing applies to foreground services, not activities (re-verify on a recent device).

## Verification
`flutter analyze` + `flutter test` (new Dart tests for the permission step), `flutter build apk --debug` in CI. On device: unlocked + no action → sheet at ~60 s over another app; act/tap/snooze/Done before 60 s → no sheet; overlay denied → one re-post; locked → unchanged; two reminders back-to-back; snooze sheet drag: follow, dismiss, spring back, chips still tappable.

## Left to the builder
Exact strings (native `strings.xml`, ARB), dialog copy, interpolator details, flag/naming conventions.

## Rulings
Closing the visible sheet does not cancel the 60 s escalation: the banner stays, and the re-shown sheet at 60 s is the intended no-snooze behavior.
