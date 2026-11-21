# Reminder notifikasi ala Taskito — design

Repo: `anchorx` (mobile/ = Flutter offline notes app). Tanggal 2026-11-19.

## Intent & why
Owner pakai Taskito dan nyaman dengan perilaku notif-nya. Cherry-pick perilaku
reminder-notif Taskito ke Anchor (Notesx): reminder yang penting **tak terlewat**
(bunyi + layar nyala + nempel sampai di-action), bisa di-**snooze**, **re-notif**
kalau belum di-action, notif **individual tak grouping + expanded**, ada
**action button**, plus **quick menu** tap-tahan icon. Semua **local**
(offline-first, tak sentuh `server/`).

## Scope (6 item, semua dikonfirmasi owner)
1. **Tier importance + channel terpisah** — reminder = importance MAX (bunyi +
   status bar); pinned/silent = MIN (sunyi, shade only).
2. **Full-screen head's-up** — reminder penting: layar nyala + unlock + UI
   alarm (Done/Snooze/Dismiss), tak terlewat.
3. **Snooze** di notif — 10m/30m/1j/4j (+1h utk repeating), simpan durasi
   terakhir.
4. **Re-notif** — reminder belum di-action → bunyi lagi sampai di-action.
5. **Quick menu** (tap-tahan icon) — New note / Journal / Reminder.
6. **Boot-reschedule** — re-arm semua alarm saat device restart.

Non-goal: iOS parity dulu (fokus Android; iOS pakai `UNUserNotification`
nanti). Tak ubah `server/`. Tak ubah format data note (reminder sudah ada di
`note.reminder`).

## Constraints
- Flutter `flutter_local_notifications` (FLLP) untuk channel/importance/zoned
  schedule/action. **Tak ada API bersih di FLLP untuk full-screen intent +
  screen-on** → 2 bagian native Android kecil (item #2 + #5).
- Android exact-alarm: `SCHEDULE_EXACT_ALARM` (Android 14+) — sudah ada
  `requestExactPermission` di gateway sekarang.
- Quick menu = `res/xml/shortcuts.xml` + activity wrapper + deep-link ke
  Flutter (native).

## Approach (dipilih — final)
- **Re-notif = FIRE-ONCE (bukan re-post, bukan sound loop).** Taskito (verified di
  smali) fire reminder **1×**: single = 1× total; repeating = 1× per period
  (`setInexactRepeating`). Suara 1× (SoundPool `play` loop=0). **Tak ada**
  re-schedule loop / re-post / nge-nagging. Anti-miss-nya dari **banner
  (importance MAX) + FSI bottom-sheet**, bukan dari re-notif.
- **Banner (fase 1):** reminder importance-MAX → notif heads-up banner + masuk
  top-shade, individual tak-grouping, expanded, 1 bunyi, 3 tombol
  (Done/Snooze/Dismiss). Pure FLLP (`zonedSchedule` + `AndroidNotificationDetails`
  importance MAX + ongoing).
- **FSI bottom-sheet (fase 2, native):** reminder penting → bottom-sheet muncul
  saat (a) phone lock, atau (b) banner tak di-action sampai auto-hide. UI = Doop
  frame `HjrIhIyNkd` (5 baris aksi). Native = `FullScreenIntentActivity`
  (`turnScreenOn`+`showWhenLocked`+scrim+sheet) + `setFullScreenIntent`.
- **Snooze / channel / importance / repeating / no-group / expanded /
  boot-reschedule = FLLP** (+ manifest receiver untuk boot).
- **Quick menu (fase 2, native):** `shortcuts.xml` (New note/Journal/Reminder)
  + wrapper activity + deep-link.

### Semantik done/dismiss (per occurrence)
- Reminder punya **recurrence** (once/daily/weekly/…). **Occurrence** = satu kali
  fire. **Done / Dismiss = selesaikan occurrence ini**, BUKAN hapus recurrence.
- Recurring → period berikutnya tetap terjadwal + tetap fire. One-off → selesai.
- Re-notif (kalau ada) berlaku per occurrence, bukan selamanya.

## Desain (Doop)
- Full-screen head's-up: frame `Z6ZCF2UPBd`
  (https://doop.design/c/-IAXF4NORn?frame=Z6ZCF2UPBd) — statusbar → header
  (ikon lonceng + "REMINDER" + judul note + jam) → tengah (isi note) → 3
  tombol full-width Done/Snooze/Dismiss. Dark (muncul di lockscreen).
- Varian bottom-sheet: frame `JTLvS1ykNh`.
- Spec shade notif: channel "Reminders" (id `reminders`, MAX; variant
  `pinned_notes` MIN). Title = nama reminder atau judul note; body = isi note
  (±100 char) atau "Tap to open". 3 tombol: Done (check) / Snooze (clock-plus)
  / Dismiss (×). Ongoing selama belum done; tap = buka note.
- Quick menu: New note (`square-pen`) / Journal (`book-open`) / Reminder
  (`alarm-clock`), label ≤10 char.

## Native vs Flutter (breakdown)
| Item | Di mana |
|------|---------|
| channel + importance tier (#1) | FLLP `AndroidNotificationChannel` |
| full-screen head's-up (#2) | **native** activity + `setFullScreenIntent` (platform hook) |
| snooze (#3) | FLLP action button + reschedule (pure) |
| re-notif loop (#4) | FLLP `zonedSchedule` reschedule (pure) |
| quick menu (#5) | **native** `shortcuts.xml` + wrapper activity + deep-link |
| boot-reschedule (#6) | manifest `BOOT_COMPLETED` receiver + resync (pure) |
| no-group + expanded | FLLP config (tak setGroup, isi penuh) |

## Yang ditinggalkan untuk builder
- Interval re-notif X + cap (default 5m, cap esok hari / max 8x) — konfirmasi.
- Mapping action button → handler (Done tandai reminder done + cancel loop;
  Snooze reschedule; Dismiss = senyapkan doang).
- Platform hook `setFullScreenIntent` (FLLP tak expose; perlu
  `MethodChannel` kecil atau plugin).
- l10n string baru (judul tombol, label channel, quick menu) di `app_en.arb` +
  patch `_en.dart`.
- Test: re-notif loop (unit), snooze reschedule, boot-reschedule, shortcut
  intent (widget test mock), native = manual di device.
- Golden: UI alarm (kalau jadi widget Flutter di dalam activity).
