# Slider UX + Compression Feedback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tiga perbaikan UX di `mobile/`: (1) slider ukuran teks di Settings dapat label rentang + tema slider Anchor; (2) dialog angka backup (period/keep files) mendapat nilai besar + unit + label min/max + chip cepat; (3) kompresi gambar memberi feedback visual "Compressing…" di add sheet dan info penghematan di snackbar.

**Architecture:** Tidak ada arsitektur baru. A = styling + label di `_EditorSection`. B = rework `_pickNumber` di `backup_section.dart` (StatefulBuilder dalam AlertDialog). C = `add_sheet.dart` menambah status row sementara selama `imageCompressorProvider.compress` berjalan; `AddedFile` (typedef record) diperluas `originalBytes`/`compressedBytes` (nullable); `_showAdd` di `note_edit_screen.dart` menyematkan suffix "from → to" ke snackbar sukses bila shrink ≥ 5%.

**Tech Stack:** Flutter, Dart 3, material `Slider` + `SliderTheme`, `flutter gen-l10n` (l10n.yaml ada, `generate: true`).

**Spec:** `docs/superpowers/specs/2026-11-16-slider-and-compression-ux-design.md`
**Design:** Doop canvas `Anchor — UI/UX` (`-IAXF4NORn`), frame `aQYM9UiQJ2`, `QHiJXx9KNO`, `5TU_sY7gzl`.

## Global Constraints

- Hanya `mobile/` diubah. `server/` dan `web/` tidak disentuh.
- Token warna/radius/spacing dari `AnchorTokens` + `context.anchor`: jangan hardcode hex baru di widget.
- Semua teks UI lewat l10n; tambah string di `lib/l10n/app_en.arb` lalu generate.
- Kompresi gagal = fallback ke original, tetap tanpa error UI (perilaku lama dipertahankan).
- Tidak ada field DB baru, tidak ada provider baru.
- Aksesibilitas: pertahankan `semanticFormatterCallback` slider dan `semanticLabel` yang ada; status "Compressing…" harus terbaca (bukan cuma spinner).
- Motion (Apple fluid-design pass): animasi baru harus bisa di-collapse oleh `MotionSpeed.off` (reduced motion). Thumb→value dari chip pakai critically-damped spring (`Spring.snappy`, tanpa overshoot) via `ImplicitlyAnimatedSlider`; drag selalu menang 1:1 (interruptible). Haptics hanya saat commit (chip tap = `Haptics.selection()`). Teks nilai update frame-same, tanpa debounce.
- Setiap task diakhiri `flutter analyze` (via rflutter) dan test terkait.

## Review Focus

- Chip cepat (Daily/Weekly/Monthly) harus sinkron dua arah: geser slider ke 1/7/30 mengaktifkan chip, klik chip menggeser value.
- Snakbar sukses gambar dengan suffix tidak boleh memecahkan snackbar audio/other (cuma branch untuk picture).
- `AddedFile` adalah record public; ekstensi field harus default-friendly (pemanggil lama tidak berubah).
- Dialog backup: unit "days" vs "files" beda per caller, jadi lewat parameter, bukan string global.
- HEIC/large image: `compress` tetap async lama; status row harus aman bila widget unmount di tengah await.

---

## Task 1: Text size slider, tema + label rentang

File: `mobile/lib/features/settings/presentation/settings_screen.dart`

- [ ] Bungkus `Slider` dengan `SliderTheme` (track 4px, active `accentStrong`, inactive `border`, thumb 20px putih + shadow, `tickColor` transparan).
- [ ] Tambah Row label min/max (`NoteTextSize.min` / `.max`, 11px `appMuted`) di bawah track.
- [ ] Simpan `value badge` (labelMedium, kanan) seperti sekarang.

Verify: `flutter analyze`; screenshot Settings di emulator/hot reload, lalu bandingkan frame Doop `aQYM9UiQJ2`.

## Task 2: Backup number dialog rework

File: `mobile/lib/features/backup/presentation/backup_section.dart`

- [ ] `_pickNumber` terima tambahan: `unit` (String), `labelLeft` (String), opsional `chips` (List<(String label, int value)>).
- [ ] Layout dialog: header (labelLeft kiri; nilai 22px w700 accent + unit kanan) → slider (track 6px, thumb 24px ring accent, divisions=1) → ends min/max → chips (kalau ada) → actions Cancel/Save.
- [ ] `_pickPeriod` lewati `unit: l10n.backupDaysUnit`, labelLeft `l10n.backupEvery`, chips Daily=1/Weekly=7/Monthly=30.
- [ ] `_pickKeep` lewati `unit: l10n.backupFilesUnit`, labelLeft `l10n.backupKeepWord`, tanpa chips.
- [ ] Sinkron chip ⇄ value: chip aktif = value saat ini ada di list; ketuk chip set value.
- [ ] Motion: `Slider` → `ImplicitlyAnimatedSlider` (`animationDuration: Spring.snappy.duration`), agar thumb meluncur ke value chip dengan spring critically-damped (tanpa overshoot) dan bisa di-interupt oleh drag.
- [ ] `Haptics.selection()` saat chip diketuk (konsisten dengan segmented control di Settings).
- [ ] Teks nilai besar update synchronous di `onChanged` (frame-same, tanpa debounce).

l10n (Task 5 generate): `backupEvery`, `backupKeepWord`, `backupDaysUnit`, `backupFilesUnit`, `backupDaily`, `backupWeekly`, `backupMonthly`.

Verify: `flutter analyze`; buka Settings → Backup → period & keep, cocokkan frame `QHiJXx9KNO`.

## Task 3: Compression status row di add sheet

File: `mobile/lib/features/notes/presentation/widgets/add_sheet.dart`

- [ ] State `bool _compressing` di `_AddSheet`; set true sebelum `await …compress`, false di finally (periksa `mounted`).
- [ ] Saat `_compressing`: tampilkan row atas body sheet: `Spinner` (ukuran `sizeIconSmall`, warna `accentStrong`) + teks `l10n.imageCompressing` (13px); row muncul frame-same saat kompresi mulai (tanpa delay buatan); spinner = status kontinu, tanpa haptics/suara; semantik: terbaca, bukan cuma spinner.
- [ ] Disable tombol pick (camera/gallery) selama `_compressing` (onTap null / `IgnorePointer`).
- [ ] Setelah sukses, kemas `originalBytes`/`compressedBytes` ke `AddedFile`.

## Task 4: AddedFile ekstensi + snackbar suffix

File: `add_sheet.dart` (typedef), `note_edit_screen.dart` (`_showAdd`)

- [ ] `typedef AddedFile = ({String path, String mime, String name, int? originalBytes, int? compressedBytes});`: field record default null? (Record field tidak default, jadi semua pemanggil lama harus di-update; hanya `_pickPicture` dan audio/image branch yang bikin `AddedFile`, cek semua site.)
- [ ] Helper `humanReadableBytes(int)` (KB/MB; satu desimal bila ≥ 10 unit).
- [ ] Di `_showAdd`, setelah `addAttachment` sukses: bila `file.originalBytes != null && file.compressedBytes != null && file.compressedBytes! < file.originalBytes! * 0.95`, gunakan `l10n.attachmentCompressed(human(file.originalBytes), human(file.compressedBytes))` sebagai isi snackbar (menggantikan `attachmentAddedLabel` untuk picture).
- [ ] Branch audio/folder tidak berubah (pass null).

## Task 5: l10n strings + generate

File: `mobile/lib/l10n/app_en.arb`

- [ ] Tambah: `imageCompressing`, `attachmentCompressed` (placeholder `{from}`/`{to}`), `backupEvery`, `backupKeepWord`, `backupDaysUnit`, `backupFilesUnit`, `backupDaily`, `backupWeekly`, `backupMonthly`.
- [ ] `flutter gen-l10n` (atau `flutter pub get` dengan `generate: true` via rflutter).

Verify: `flutter analyze` bersih; test yang pakai `AppLocalizations` masih pass.

## Task 6: Uji + verifikasi

- [ ] `flutter analyze` + `flutter test` (rflutter, hapus `~/.rflutter/ws/mobile-*` dulu bila stale).
- [ ] Hot reload di HP: alur pick photo → liat "Compressing…" row → snackbar "4.2 MB → 310 KB" (gambar ≥ ~2MB); slider settings + dialog backup dibandingkan dengan frame Doop.
- [ ] Motion check: set `MotionSpeed = off` di Settings → animasi thumb chip jadi instan; default → meluncur smooth tanpa bounce.
- [ ] Haptics check: ketuk chip → terasa selection click (sesama dengan segmented control).
- [ ] Commit per task; PR ke `muava12/anchor`; rilis lewat tag `v0.25.2` (GitHub Runner).
