# Reminder Notif Taskito-Parity — Plan Fase 1 (pure FLLP)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task.
> Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reminder penting di-Anchor nendang ala Taskito: notif importance-MAX yang
bunyi + banner + masuk top-shade (individual, tak grouping, expanded), ada tombol
**Done/Snooze/Dismiss**, bisa di-**snooze** (10/30/60/240/1440m), recurring
**fire per period** (bukan re-notif), dan re-arm saat device **boot**.

**Architecture:** Pure `flutter_local_notifications` (FLLP). Reminder yang sudah
ada (`NoteReminder` + `reminder_slot` + `reminder_scheduler` reconcile) di-upgrade:
channel importance naik ke MAX + nama "Reminders", notif jadi individual dengan
3 tombol aksi, action di-handle via broadcast/onUpdated → handler done/snooze/
dismiss per-occurrence, snooze reschedule occurrence, repeating reschedule per
period, boot-receiver re-sync. **Tak re-notif (fire-once), tak looping sound.**

**Tech Stack:** Flutter, `flutter_local_notifications`, `flutter_timezone`,
Riverpod, drift (note.reminder), FFI `MethodChannel`/broadcast untuk action.

**Spec:** `docs/superpowers/specs/2026-11-19-reminders-taskito-parity-design.md`
+ `GLOSSARY.md` (section Reminders). Fase 2 (native FSI bottom-sheet + quick menu)
**di luar plan ini**.

## Global Constraints
- Tak sentuh `server/`. Semua lokal (offline-first).
- Reminder fire-once: single = 1× total; repeating = 1× per period. Tak re-post.
- Importance: reminder penting = **MAX** (bunyi + banner + status bar); pinned/
  silent = **MIN** (sunyi, shade only).
- Notif individual: tak `setGroup`; body penuh; importance MAX → natural top-shade.
- Tombol aksi (max 3): **Done** (selesaikan occurrence), **Snooze** (reschedule
  occurrence, durasi pilihan), **Dismiss** (senyapkan occurrence ini saja).
- Snooze durasi: 10/30/60/240 menit (+1440/1 hari untuk repeating). Simpan durasi
  terakhir.
- Done/Dismiss = **per occurrence** (istilah GLOSSARY): recurring tetap fire
  period depan; one-off selesai.
- l10n: string baru di `mobile/lib/l10n/app_en.arb` + `@key.description`, patch
  manual `app_localizations.dart` + `_en.dart`.
- Check: `cd mobile && rflutter analyze && rflutter test`.

## Review Focus
1. **Reminder lewat (missed):** occurrence-nya tak boleh bocor jadi notif numpuk
   / schedule ganda. → Task 4/6.
2. **Recurring + snooze:** setelah snooze, period berikutnya tetap terjadwal
   (snooze hanya delay occurrence saat ini). → Task 6.
3. **Action dari state app mati (cold start):** handler action harus jalan walau
   app tak terbuka (broadcast + payload), tak crash. → Task 3.
4. **Boot:** alarm harus re-arm setelah device restart (tak hilang). → Task 7.
5. **Dismiss vs Done:** dismiss tak boleh mark done (recurring tetap fire);
   done barulah selesaikan. → Task 4.

## File Structure
- `lib/features/reminders/data/notification_gateway.dart` — `ScheduledNotification`
  (tambah `tier` + `actions`), channel MAX/MIN, action handling.
- `lib/features/reminders/data/reminder_actions.dart` (baru) — handler
  done/snooze/dismiss per-occurrence + parsing action.
- `lib/features/reminders/data/reminder_scheduler.dart` — reschedule per-period
  + boot-resync hook.
- `lib/features/reminders/data/reminder_snooze.dart` (baru) — durasi + reschedule
  + simpan durasi terakhir.
- `lib/features/reminders/presentation/snooze_sheet.dart` (baru) — UI pilih durasi.
- Android: `NotificationActionReceiver` (broadcast) + manifest; BOOT receiver.
- `lib/features/notes/domain/note.dart` — tak ubah (reminder sudah ada).

---

### Task 1: Channel importance tier (MAX reminders / MIN silent)

**Files:**
- Modify: `lib/features/reminders/data/notification_gateway.dart`
- Test: `test/notification_gateway_test.dart` (ada? bikin kalau tak ada)

**Interfaces:**
- Produces: `enum NotificationTier { important, silent }`;
  `ScheduledNotification` tambah `tier` (default important). Channel id:
  `reminders` (important, `Importance.max`) + `pinned_notes` (silent,
  `Importance.min`). Nama/deskripsi dari l10n.

- [ ] **Step 1: failing test** — `schedule(...)` untuk `tier: important` membuat
  channel `reminders` dgn `Importance.max`; `tier: silent` → channel
  `pinned_notes` `Importance.min`. Assert via mock plugin atau channel-registry.
- [ ] **Step 2: run → FAIL** (channel belum tiered).
- [ ] **Step 3: implement** — tambah `NotificationTier`, `_channelId(tier)`,
  buat 2 channel di `initialize()` (importance MAX/MIN), set `Importance.max`
  + `Priority.max` untuk important.
- [ ] **Step 4: run → PASS**.
- [ ] **Step 5: commit** `feat(reminders): importance tier for reminder channels`.

### Task 2: Notif individual, tak-grouping, expanded

**Files:** Modify `notification_gateway.dart`. Test: `notification_gateway_test.dart`.
**Interfaces:** Consumes `ScheduledNotification`. Produces: notif tanpa
`setGroup`, `body` penuh, style `BigTextStyle` (expanded), `ongoing` selama belum
di-handle.

- [ ] **Step 1: test** — `AndroidNotificationDetails` yang di-generate: tak ada
  groupId, punya `body`, `bigTextStyle`/body, `ongoing: true` untuk reminder.
- [ ] **Step 2: run → FAIL**.
- [ ] **Step 3: implement** — hapus setGroup (kalau ada), set body + BigText +
  ongoing.
- [ ] **Step 4: run → PASS**.
- [ ] **Step 5: commit** `feat(reminders): individual expanded reminder notification`.

### Task 3: Action buttons Done/Snooze/Dismiss + handler plumbing

**Files:** Modify `notification_gateway.dart`; Create
`lib/features/reminders/data/reminder_actions.dart`; Android
`NotificationActionReceiver` + manifest. Test: `test/reminder_actions_test.dart`.
**Interfaces:**
- Produces: `class ReminderAction { id; ReminderActionType type; noteId; }`
  (enum `type` { done, snooze, dismiss }). FLLP `actions:` (3 `AndroidAction`) +
  `onAndroidNotificationUpdated` → broadcast/receiver → `handleReminderAction`.

- [ ] **Step 1: test** — `handleReminderAction(ReminderAction(type: dismiss,
  noteId: 'n1'))` memanggil gateway cancel(n1-slot); `done` → mark done;
  `snooze` → reschedule. (mock gateway + mock snooze service.)
- [ ] **Step 2: run → FAIL** (handler belum ada).
- [ ] **Step 3: implement** — `actions: [done, snooze, dismiss]` (ikon Lucide,
  label l10n) di `AndroidNotificationDetails`; `reminder_actions.dart` parse
  action-id + payload → `ReminderAction`; Android broadcast receiver meneruskan
  ke Flutter (MethodChannel).
- [ ] **Step 4: run → PASS**.
- [ ] **Step 5: commit** `feat(reminders): done/snooze/dismiss buttons on the reminder`.

### Task 4: Done / Dismiss semantik per-occurrence

**Files:** Modify `reminder_actions.dart` (+ domain call ke `NotesRepository`).
Test: `test/reminder_actions_test.dart`.
**Interfaces:** Consumes `ReminderAction`. Produces: `doneOccurrence(noteId)`
(one-off → unset `note.reminder`; recurring → tak hapus, occurrence selesai,
next period tetap via scheduler); `dismissOccurrence(noteId)` (hanya cancel
notif, tak mark done).

- [ ] **Step 1: test** — done on one-off → `note.reminder` di-unset (repo
  update); done on recurring → `note.reminder` tetap (recurrence hidup).
  dismiss → notif cancel, note tak berubah.
- [ ] **Step 2: run → FAIL**.
- [ ] **Step 3: implement** — sesuai `NoteReminder.recurrence`: one-off unset;
  recurring biarkan (next period di-schedule ulang Task 6).
- [ ] **Step 4: run → PASS**.
- [ ] **Step 5: commit** `feat(reminders): done/dismiss resolve the occurrence, not the recurrence`.

### Task 5: Snooze — durasi + reschedule + simpan terakhir

**Files:** Create `lib/features/reminders/data/reminder_snooze.dart` +
`lib/features/reminders/presentation/snooze_sheet.dart`. Test:
`test/reminder_snooze_test.dart`.
**Design:** Doop frame `Wn02ojCMhA` (snooze picker sheet: chips durasi
10/30/60/240/1440 + suggested today/tomorrow + custom date+time, sheet flat,
tokens app).
**Interfaces:**
- Produces: `snoozeDurations(recurring)` → `[10,30,60,240]` (+`[1440]` kalau
  recurring); `snooze(noteId, minutes)` → reschedule occurrence `now + minutes`
  (recurring → occurrence di-snooze, period tetap); simpan
  `settingsPreferences` key `latest_snooze_duration`.

- [ ] **Step 1: test** — `snooze(noteId, 30)` schedule ulang di now+30m; durasi
  list benar; durasi terakhir terbaca.
- [ ] **Step 2: run → FAIL**.
- [ ] **Step 3: implement** — reschedule via gateway (`zonedSchedule` di
  now+minutes), persist durasi, sheet UI 4-5 tombol durasi.
- [ ] **Step 4: run → PASS**.
- [ ] **Step 5: commit** `feat(reminders): snooze a reminder occurrence`.

### Task 6: Repeating reschedule per period (setelah fire + handle)

**Files:** Modify `reminder_scheduler.dart` (+ `reminder_schedule.dart`
`nextOccurrence` sudah ada). Test: `test/reminder_scheduler_test.dart`.
**Interfaces:** Consumes `nextOccurrence`. Produces: setelah occurrence recurring
di-handle (done) → schedule **occurrence berikutnya**; tak re-notif occurrence
yang sama.

- [ ] **Step 1: test** — recurring daily, occurrence hari ini di-done →
  ter-schedule besok; occurrence single setelah fire → tak reschedule.
- [ ] **Step 2: run → FAIL**.
- [ ] **Step 3: implement** — di reconcile: recurring → `matchDateTimeComponents`
  / `nextOccurrence`; satu occurrence = satu fire.
- [ ] **Step 4: run → PASS**.
- [ ] **Step 5: commit** `feat(reminders): recurring reminders fire per period`.

### Task 7: Boot-reschedule (re-arm semua alarm)

**Files:** Modify `reminder_scheduler.dart` (resync on app-start sudah ada) +
Android manifest `BOOT_COMPLETED` receiver + MethodChannel callback. Test:
`test/reminder_scheduler_test.dart`.
**Interfaces:** Produces: `resyncAll()` dipanggil saat boot + app-start;
reconcile semua reminder dari `allActiveNotesProvider`.

- [ ] **Step 1: test** — `resyncAll()` reschedule semua pending + cancel orphan.
- [ ] **Step 2: run → FAIL** (boot hook belum).
- [ ] **Step 3: implement** — receiver BOOT → MethodChannel →
  `resyncAll()` (sama jalur on-resume). Verifikasi manifest + manual di device.
- [ ] **Step 4: run → PASS** (unit) + catatan manual-test device.
- [ ] **Step 5: commit** `feat(reminders): re-arm reminders on device boot`.

---

## Verifikasi akhir (fase 1)
- `cd mobile && rflutter analyze && rflutter test` (full suite green).
- Manual (device): reminder penting → banner + bunyi, tombol kerja (done/snooze/
  dismiss), snooze reschedule, recurring fire besok, boot re-arm.
- Fase 2 (native FSI bottom-sheet + quick menu) = plan terpisah.
