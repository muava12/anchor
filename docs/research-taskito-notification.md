# Taskito Notification & Shortcut Behavior (APK Reverse-Engineering)

> **Target**: `com.fenchtose.reflog` (Taskito)
> **Decoded APK path (box-02)**: `/data/home/tools/taskito-apk/`
> **Scope**: Notification channels, scheduling, triggers, snooze, actions, full-screen intent, priority/importance table, quick menu / app shortcuts.

---

## A. Notification Channels

App membuat 5 channel utama + 2 channel silent twin di `ReflogApp.onCreate()` via `data/notification/u->e(Context)`:

### NotificationChannelType (`smali_classes2/com/fenchtose/reflog/data/notification/a.smali`)

| Enum (`a.smali`) | Channel ID (`getId()`) | Importance (`f()`) | Name / Description (`res/values/strings.xml`) |
|---|---|---|---|
| `C` (`REMINDERS`) | `reminders` | `5` (`IMPORTANCE_MAX`) | `"Reminders"` / `"Your daily, weekly or monthly reminders."` |
| `D` (`TASK_REMINDERS`) | `task_reminders` | `5` (`IMPORTANCE_MAX`) | `"Task reminders"` / `"Your task reminders"` |
| `E` (`PINNED_NOTES`) | `pinned_notes` | `1` (`IMPORTANCE_MIN`) | `"Pinned notes"` / `"Notes that you add to notifications."` |
| `F` (`BACKUP`) | `backup` | `2` (`IMPORTANCE_LOW`) | `"Backup"` / `"Notifications shown when the app is downloading data from backup"` |
| `G` (`CREATE_TASK`) | `create_task` | `1` (`IMPORTANCE_MIN`) | `"Create tasks"` / `"Create tasks from notification"` |

### Silent Twin Channels (`smali_classes2/com/fenchtose/reflog/data/notification/u.smali`)

- **IDs**: `reminders_silent`, `task_reminders_silent`
- **Importance**: Sama dengan channel utama (`5` / `IMPORTANCE_MAX`)
- **Sound**: `setSound(null, null)` (`r.a(channel, null, null)`) + `enableVibration(true)` (`s.a(channel, true)`)
- **Description**: `"Used to play your chosen custom sound instead of system default sound."` (`notification_channel_silent_twin_description`)

---

## B. Scheduling, Trigger & Snooze

### AlarmManager & Classes

- **Scheduler Class**: `s6/j.smali` (`ReminderScheduler`) -> `s6/g.smali` (`AlarmScheduler`)
  - `c(v7.a)` -> Repeating reminder (`"RepeatingReminder"`)
  - `e(v7.e)` -> Single reminder (`"SingleReminder"`)
  - `a(id, key, time)` -> Snooze reminder (`"SnoozeReminder"`)
- **Trigger Logic (`s6/g.smali->n(reminder)`)**:
  - **Repeating (`repeat == DAY`)**: `setInexactRepeating(0 /* ELAPSED_REALTIME */, triggerAtMillis, 86_400_000L, pi)`
  - **Single (`repeat == ONCE`)**:
    - Lewat dari waktu sekarang -> dibatalkan (`return false`).
    - Lebih dari 10 hari ke depan -> dibatalkan (`return false`).
    - `triggerAtMillis = epochSecond * 1000`
    - `SDK_INT < 31`: `setExactAndAllowWhileIdle(0, triggerAtMillis, pi)`
    - `SDK_INT >= 31`:
      - Cek `AlarmManager.canScheduleExactAlarms()` (`s6/a.smali`).
      - Jika diizinkan: `setExactAndAllowWhileIdle(0, triggerAtMillis, pi)`
      - Jika tidak diizinkan (fallback): `setAndAllowWhileIdle(0, triggerAtMillis, pi)`
  - **Intent & PendingIntent**:
    - `Intent(context, ReminderAlarmReceiver.class)`
    - Repeating: extra `"reminder_id"` = reminderId, `"snooze"` = boolean
    - Single: extra `"single_reminder_id"` = reminderId, `"snooze"` = boolean
    - `PendingIntent.getBroadcast(context, code=count, intent, 0x18 /* FLAG_UPDATE_CURRENT | FLAG_CANCEL_CURRENT */)`

### Boot Behavior (`RECEIVE_BOOT_COMPLETED`)

- **Receiver**: `smali_classes2/com/fenchtose/reflog/BootBroadcastReceiver.smali`
- **Flow (`BootBroadcastReceiver$a`)**:
  1. `features/reminders/q->c(Context, Continuation)` (`reScheduleAllReminders`):
     - Ambil semua repeating & single reminder dari `ReminderRepository` (`g0.smali`).
     - Batalkan alarm lama (`w7.c.d(reminder)`), lalu jadwalkan ulang (`w7.c.c` / `w7.c.e`) hingga maksimal 450 alarm (`0x1c2`).
  2. `data/notification/o0->h(Context, Continuation)` (`rePostPinnedNotifications`):
     - Refresh notifikasi pinned notes (maksimal 16 notifikasi).

### Snooze (`features/reminders/snooze/n.smali`)

- **Pilihan Cepat**:
  - 10 menit (`0xa`)
  - 30 menit (`0x1e`)
  - 1 jam (`0x3c` = 60m)
  - 4 jam (`0xf0` = 240m)
  - 1 hari (`0x5a0` = 1440m, khusus repeating reminder)
- **Pilihan Kustom**: `"Suggestions (Today)"`, `"Suggestions (Tomorrow)"`, atau date+time picker manual.
- **Logika (`X()` -> `N(mins)`)**:
  - Simpan durasi ke `SettingsPreferences` (`"latest_snooze_duration"`).
  - Hitung `time = Instant.now() + mins`.
  - Jadwalkan via `s6/j.a(reminderId, reminderKey, time)` dengan `isSnooze = true`.
  - Batalkan notifikasi yang sedang tampil via `b0.g(context, q7.a)`.

---

## C. Push vs Local (FCM)

- **Service**: `com.fenchtose.reflog.core.fcm.AppFirebaseMessageService` (extends `FirebaseMessagingService`)
- **Jenis Pesan**: Hanya 1 tipe data (`core/fcm/o.smali`):
  - `SYNC_TRIGGER` (key data `"type": "sync_trigger"`)
  - Saat diterima: memanggil `SyncManager.triggerSync(context)` (`core/networking/sync/d.a`).
- **Kesimpulan**: Tidak ada push notifikasi visual dari server; semua notifikasi reminder/task adalah **100% local** dari `AlarmManager`.

---

## D. Full-Screen Intent & Urgency

- **Permissions (`AndroidManifest.xml`)**:
  - `android.permission.USE_FULL_SCREEN_INTENT`
  - `android.permission.SCHEDULE_EXACT_ALARM`
  - `android.permission.RECEIVE_BOOT_COMPLETED`
  - `android.permission.POST_NOTIFICATIONS`
- **Trigger Logic (`data/notification/b0.smali->o()`)**:
  - Jika `item.p()` (`fullScreen` aktif di `notification_options/<channel>_full_screen`, default `true`) DAN `item.t()` (`pinned` non-aktif) DAN `SDK_INT >= 26` DAN feature flag aktif DAN channel importance `>= IMPORTANCE_HIGH (4)`:
    - Buat `PendingIntent.getActivity` ke `com.fenchtose.reflog.features.reminders.notification.FullScreenNotificationActivity`.
    - Panggil `NotificationCompat.Builder.setFullScreenIntent(pendingIntent, true)`.
- **Activity (`FullScreenNotificationActivity`)**:
  - Di `AndroidManifest.xml`: `android:launchMode="singleInstance"`, `android:theme="@style/TranslucentTheme.Dark"`, `android:autoRemoveFromRecents="true"`, `android:noHistory="true"`.
  - Di `onCreate`: menyalakan layar (`setTurnScreenOn(true)`) & membuka layar kunci (`setShowWhenLocked(true)`) pada API >= 27, menampilkan UI alarm full-screen dengan tombol **Done**, **Snooze**, dan **Dismiss**.
  - Memanggil `b0.g(context, q7.a)` untuk menghapus notifikasi dari shade.

---

## E. Tombol / Aksi di Notifikasi

1. **Aksi Done (`b0.smali->i()`)**:
   - Icon: `u.d0` (`ic_done_black_18dp`)
   - Label: `z.o8` (`"Done"`)
   - Target: `PendingIntent.getBroadcast` -> `com.fenchtose.reflog.broadcasts.MarkDoneBroadcastReceiver`
   - Extra: `notification_id`, `notification_tag`, `notification_item_id`, `source="notification"`
   - Opsi: `notification_options/<channel>_done` (default `true`)
2. **Aksi Dismiss (`b0.smali->h()`)**:
   - Icon: `u.W` (`ic_close_black_18dp`)
   - Label: `z.n8` (`"Dismiss"`)
   - Target: `PendingIntent` -> `com.fenchtose.reflog.notifications.NotificationDismissBroadcastReceiver`
   - Ditampilkan jika notifikasi `pinned` (`notification_options/<channel>_pinned`) atau sudah `done`.
3. **Quick Add Task Notification (`data/notification/i.smali`, channel `create_task`, ID `1308` / `0x51c`)**:
   - Aktif jika `notification_options/quick_add_activated` = `true`.
   - Menampilkan notifikasi dengan **RemoteInput** (`quick_add_task_title`) dan 3 aksi cepat:
     - `+ Today` (`u.E1`, `ic_today_black_24dp`)
     - `+ Tomorrow` (`u.b0`, `ic_date_range_black_24dp`)
     - `+ No date` (`u.w1`, `ic_send_black_24dp`)
   - Dikirim ke `CreateTaskQuickAddBroadcastReceiver`.

---

## F. Tabel Posisi & Priority per Jenis Notifikasi

| Jenis Notifikasi | Class / Method | Channel ID | Priority (`setPriority`) | Importance (`NotificationChannel`) | Full-Screen Intent | Defaults / Sound / Vibrasi | Kategori / Ongoing / AutoCancel | Posisi Akhir (Hasil) |
|---|---|---|---|---|---|---|---|---|
| **User Reminder** (daily/weekly/monthly) | `data/notification/b0->o()` (`j0.smali->i()`) | `reminders` (atau `reminders_silent` jika custom sound) | `5` (`a.f()` = `IMPORTANCE_MAX`) | `5` (`IMPORTANCE_MAX`) | Ya (jika `fullScreen=true` & `pinned=false`) | Default suara+vibrasi (atau custom sound via `SonificationManager` di `reminders_silent`) | `setOngoing(!done)`, `setAutoCancel(done)` | **Status bar + Shade + Head's-up / Full-Screen** |
| **Task Reminder** (single / repeating) | `data/notification/b0->o()` (`j0.smali->l()`) | `task_reminders` (atau `task_reminders_silent` jika custom sound) | `5` (`a.f()` = `IMPORTANCE_MAX`) | `5` (`IMPORTANCE_MAX`) | Ya (jika `fullScreen=true` & `pinned=false`) | Default suara+vibrasi (atau custom sound via `SonificationManager` di `task_reminders_silent`) | `setOngoing(!done)`, `setAutoCancel(done)` | **Status bar + Shade + Head's-up / Full-Screen** |
| **Pinned Notes** (sticky notes) | `data/notification/b0->o()` (`o0.smali`) | `pinned_notes` | `1` (`a.f()` = `IMPORTANCE_MIN`) | `1` (`IMPORTANCE_MIN`) | Tidak | Sunyi (tidak ada suara/vibrasi) | `setOngoing(false)`, `setAutoCancel(true)`, `setSilent(true)` | **Shade (sunyi, tanpa ikon status bar)** |
| **Background Sync / Polling** | `core/networking/sync/PollingSyncWorker->C()` | `backup` | `2` (`a.f()` = `IMPORTANCE_LOW`) | `2` (`IMPORTANCE_LOW`) | Tidak | Sunyi (foreground service notif) | Progress bar (`0..100`, indeterminate), `setOngoing(true)` (foreground service) | **Shade (sunyi, tanpa ikon status bar)** |
| **Quick Add Task** | `data/notification/i->c()` | `create_task` | `4` (`setDefaults(4)` = lights only) + silent | `1` (`IMPORTANCE_MIN`) | Tidak | `setDefaults(4)` (LED only), `setSilent(true)` | `setOngoing(false)`, `setAutoCancel(true)`, RemoteInput + 3 aksi | **Shade (sunyi, hanya LED)** |
| **Forced Logout** | `features/user/d->j()` | `task_reminders` | `5` (`a.f()` = `IMPORTANCE_MAX`) | `5` (`IMPORTANCE_MAX`) | Tidak | Default suara+vibrasi | `setOngoing(true)`, ID `1008` (`0x3f0`) | **Status bar + Shade + Head's-up** |

---

## G. Quick Menu / App Shortcuts

1. **File & Manifest**:
   - `res/xml/shortcuts.xml` (direferensikan via `android.app.shortcuts` di `AndroidManifest.xml`).
   - Mendaftarkan **2 static shortcuts**:
     - `shortcutId="create_task"`:
       - Label pendek & panjang: `@string/timeline_action_add_task`
       - Icon: `@drawable/ic_add_task_shortcut`
       - Target: `com.fenchtose.reflog.features.shortcuts.ShortcutWrapperActivity` (action `android.intent.action.VIEW`)
       - Extra: `shortcut_type` = `"task"`
       - Kategori: `android.shortcut.conversation`
     - `shortcutId="create_note"`:
       - Label pendek & panjang: `@string/timeline_action_add_note`
       - Icon: `@drawable/ic_add_note_shortcut`
       - Target: `com.fenchtose.reflog.features.shortcuts.ShortcutWrapperActivity` (action `android.intent.action.VIEW`)
       - Extra: `shortcut_type` = `"note"`
       - Kategori: `android.shortcut.conversation`

2. **Alur `ShortcutWrapperActivity` (`smali_classes2/com/fenchtose/reflog/features/shortcuts/ShortcutWrapperActivity.smali`)**:
   - Di `onCreate(Bundle)`:
     1. Memuat layout `x.b` (`activity_shortcut_wrapper`) dengan background transparan (`setBackgroundDrawable(null)`) dan menyembunyikan `BottomNavigationBar` (`u5/b0.G(bottomNav, false)`).
     2. Memanggil `h1(router)`:
        - Membaca `intent.getStringExtra("shortcut_type")`.
        - Jika bernilai `"note"`: memanggil `features/note/o2.h()` yang membuat route `features/note/h2` dengan `initialType = p7.f.c` (Note Editor mode Note).
        - Jika bernilai `"task"`: memanggil `features/note/o2.o()` yang membuat route `features/note/h2` dengan `initialType = p7.f.z` (Note Editor mode Task).
        - Memanggil `router.e("timeline", route, true)` untuk membuka Note Editor langsung di atas Timeline.

3. **Dynamic Shortcuts**:
   - Tidak ada. Pencarian `ShortcutManager`, `addDynamicShortcuts`, `createShortcutInfo` di seluruh `smali*`: **0 hasil**.

4. **Mengapa hanya 2 shortcut (bukan 3)?**:
   - Taskito hanya memiliki 2 aksi quick-add utama dari launcher (Create Task dan Create Note). Batas maksimal 3 shortcut adalah batas OS Android; Taskito tidak menambahkan shortcut ketiga karena tidak ada aksi create/compose ketiga yang setara (Quick Add dari notifikasi/progress sync bukan shortcut launcher).
## H. Full-Screen Sheet & "Kapan Pakai Yang Mana" (research box-02, revisi D)

> Ditemukan: `FullScreenNotificationActivity` bukan layar alarm klasik, tapi
> **dim scrim + bottom sheet** (layout `full_screen_notification_activity_layout.xml`
> + `full_screen_notification_bottomsheet_layout.xml`). Ini yang terlihat di screenshot
> sebagai "sheet 5 baris" di atas home screen.

### Layout sheet
- Scrim full-screen: `#11343434` (dark ~7%) di atas home/lockscreen; `fitsSystemWindows`.
- Sheet: `NestedScrollView` bottom-gravity, bg `@drawable/bottom_sheet_background`,
  padding vertikal 16dp, wrap-content (bukan height penuh).
- Isi (`full_screen_notification_bottomsheet_layout`):
  1. Header row: `@string/app_name` + "•" + `@id/item_summary` (gaya `BottomSheetHeaderStyle.Small`).
  2. `@id/item_title` — `Text.Primary.Medium.Large`, max 3 baris, ellipsize.
  3. `@id/item_desc` — `Text.Secondary`, max 3 baris, ellipsize.
  4. Spacer 16dp.
  5. 5 baris aksi (gaya `NoteActionStyle`, teks+ikon):
     - `option_show_details` → "Show details" (`generic_show_details`)
     - `option_done` → "Mark as done" (`note_mark_as_done_cta`)
     - `option_dismiss` → "Dismiss" (`notification_action_dismiss`)
     - `option_snooze` → "Snooze" (`notification_action_snooze`)
     - `option_ok` → default "Show details" di XML, di-runtime menjadi "Close" (`generic_close`) untuk item reminder
- Ikon baris (sesuai screenshot): info, check, bell-off, bell, arrow-down.

### Tabel perilaku: kapan pakai yang mana
| Kondisi | Yang muncul |
|---|---|
| Reminder importance-MAX bunyi (default, tidak pinned, opsi `full_screen` on) | **Banner heads-up persisten** (notif sistem, 3 tombol inline Done/Snooze/Dismiss) **DAN** full-screen intent: layar menyala + **dim scrim + sheet 5 baris**. Notif juga menempel di **paling atas shade** (individual, tanpa grouping). |
| Opsi `full_screen` dimatikan (notification options) | Hanya **banner heads-up + shade**, tanpa sheet. |
| Reminder di-pinned (sticky) | Channel/importance MIN → **sunyi**, hanya card di shade, tanpa banner, tanpa FSI. |
| Tap banner (chevron) | Ekspansi content banner (judul besar + isi). |
| Baris "Snooze" di sheet | Buka picker durasi: 10m / 30m / 1j / 4j (+1 hari untuk repeating), atau kustom (lihat B). |
| "Mark as done" | Reminder selesai; notif di-cancel (autoCancel), sheet tutup. |
| "Dismiss" | Notif ini disenyapkan saja (tidak tandai done). |
| "Close" | Tutup sheet; banner/notif shade tetap ada sampai handled. |
| "Show details" | Buka item (reminder/note) di dalam app. |

Catatan: perilaku "tidak rawan miss" Taskito = kombinasi banner persisten + card
paling atas shade + sheet FSI; ketiganya hidup bersamaan saat importance MAX.

---

## I. Sonification / Custom Sound (`core/sonification/SonificationManager`)

> Koreksi: TIDAK ADA loop suara tiap 4 detik. `0xfa0 = 4000` adalah
> **timeout tunggu `SoundPool.load()` selesai**, bukan interval ulang.
> Suara berbunyi **sekali per notifikasi**.

### Pemicu (satu-satunya)
- `data/notification/b0.smali:1342` memanggil `SonificationManager->p(channel, continuation)`
  **sekali** per notifikasi yang diposting, di-guard `if-eqz v11` (flag sound-on).
- `p(String, dj/d;)` (`SonificationManager.smali:1474`):
  1. Tentukan `soundId`: `"task_reminders"` -> field `g`, `"reminders"` -> field `f`.
  2. `soundId == 0` -> return (tidak ada suara).
  3. Catat `currentTimeMillis`.
  4. Panggil `k(soundId, cont)` sekali -> Boolean.
  5. `false` -> log `"stopped"` (`sonification/c.java`) + return (tidak putar).
  6. `true` -> `x(soundId, c)` (putar) + return.
- Tidak ada loop di `p()`. Tidak ada caller lain yang meng-loop `p()`/`x()`.

### `k(int, dj/d;)` — gate "siap", bukan loop (`SonificationManager.smali:638`)
```
p2 = h.contains(soundId)      # keyset "ready"
if p2 != 0 (sudah ready): return true
else:                          # belum ready
  daftar channel ke i[soundId]  # CopyOnWriteArrayList
  delay(0xfa0 = 4000)           # TIMEOUT, bukan interval
  return h.contains(soundId)    # re-check sekali
```
Saat load selesai lebih cepat dari 4 detik, coroutine yang menunggu di `i[soundId]`
di-resume lebih awal oleh `A()`; 4 detik hanya batas atas bila load macet.

### Load & ready-set
- Constructor (`SonificationManager.smali:142`):
  - `h` = `ConcurrentHashMap.newKeySet()` (keyset "ready").
  - `i` = `ConcurrentHashMap` (soundId -> daftar channel penunggu).
  - `z()` -> `setOnLoadCompleteListener(sonification/d)`.
  - `o()`/`n()` -> `SoundPool.load(...)` (3 sound: task, reminders, task_reminders).
- `d.smali -> onLoadComplete -> A(SonificationManager;SoundPool;II)` (`SonificationManager.smali:243`):
  - `status == 0` (sukses) -> `h.add(sampleId)`.
  - `i.remove(sampleId)` -> resume semua channel penunggu (`o()` + `y(value)`).

### Putar sekali
- `x(int, SoundPool)` (`SonificationManager.smali:1951`):
  `SoundPool.play(soundId, leftVol, rightVol, priority=1, loop=0, rate=0.6f)`.
  - `loop = 0` -> tanpa loop native.
  - `rate = 0.6f`.
  - Volume dari `AudioManager` stream `4` (`STREAM_MUSIC`), di-clamp `0..1`.

### Berapa kali berbunyi
| Jenis reminder | Bunyi |
|---|---|
| Single (sekali) | **1x total** |
| Repeating | **1x per interval repeating** (via `AlarmManager.setInexactRepeating`), bukan tiap 4 detik |

Setiap alarm fire -> `b0.o()` -> `p()` -> sekali bunyi. Tidak ada notifikasi/suara berulang tiap 4 detik.

### File terkait
- `smali_classes2/com/fenchtose/reflog/core/sonification/SonificationManager.smali`
  (`p` 1474, `k` 638, `A` 243, `x` 1951, `z` 1267, `o` 997, `n` 879)
- `smali_classes2/com/fenchtose/reflog/core/sonification/d.smali` (OnLoadCompleteListener)
- `smali_classes2/com/fenchtose/reflog/core/sonification/b.smali` (`v()` body delay, daftar channel)
- Caller `p()`: `smali_classes2/com/fenchtose/reflog/data/notification/b0.smali:1342`

Catatan: `features/settings/notifications/w.smali:519` memanggil `x()` langsung = preview
"Customize Notifications" (putar sampel sekali), bukan loop.
