# Journal v2 polish — plan

Repo: `/home/mimin/projects/anchorx`, branch `main` = `fork/main` @ `b4b6fe6`.
Konteks: rilis `v0.25.7` sudah jalan. 5 isu dari live-sc owner + aturan upstream.

## Aturan (wajib)
- **Tak sentuh `server/`.** Semua perubahan di `mobile/` (+ `design/tokens/` hanya jika perlu — semua token doop SUDAH ada di kode, jadi kemungkinan tak perlu).
- Tak ada DB/schema/sync change. `tz:` masuk ke note content (string), backward-compatible.
- Conventional Commits `type(scope): what`; scope `mobile`.
- l10n: teks app di `mobile/lib/l10n/app_en.arb` + `@key.description`.
- Cek: `cd mobile && rflutter analyze && rflutter test` (+ golden regen bila timeline berubah).
- Semua ukuran dari token (`AnchorTokens`, `AppTypography`), tak hardcode.
- Git hygiene: stage HANYA `mobile/`, tak `git add -A`.

## Task

### T1 — Editor jurnal saat edit (gambar 2) [A: route]
Masuk: `NoteEditScreen` (shared) flag `journal` default false. Timeline `_open` → `AppRoutes.note(id)` → tak ada flag → metadata mentah.
- `app_routes.dart`: tambah `static String journalEdit(String id) => '/journal/edit/$id';`
- `app_router.dart`: tambah `GoRoute(path: 'journal/edit/:id')` → `NoteMorphPage(noteId: id, child: NoteEditScreen(noteId: id, note: state.extra as Note?, journal: true))`. (additive, tak ubah `note/:id`)
- `journal_screen.dart`: `_open` → `context.go(AppRoutes.journalEdit(note.id), extra: note)`.
- Test: tap entry journal → editor mode journal (metadata tersembunyi, `JournalEntryMetaRow` tampil, mood tool ada).

### T2 — Date header timeline (gambar 1) + GMT
- `journal_entry_text.dart`: helper baru `journalDayHeader(JournalDay, l10n)` → format SATU baris:
  - hari ini → `TODAY, {d MMM yyyy}`; kemarin → `YESTERDAY, {d MMM yyyy}`; lain → `{WEEKDAY}, {d MMM yyyy}` (uppercase)
  - append ` · GMT+{tz}` jika `tz` entry ≠ tz perangkat saat ini.
- `_DayHeader` (`journal_timeline.dart`): ganti dua-span (label + rel) jadi SATU `Text` header format baru. Font lebih besar dari title (`cardTitle` 15.5) → `typeLead`(15) tak cukup; pakai `typeDisplay`? Terlalu besar. **Detail: ukuran exact → verifikasi doop / konfirmasi owner.** (rekomendasi: `textLead` 15px bold, atau token baru bila mau >15.5).
- Dependensi T3 (field `tz`).

### T3 — Field `tz:` di journal meta
- `journal_meta.dart`: `JournalMeta` tambah `int? tzOffset` (menit UTC). 
- `journal_entry_meta.dart`: `composeJournalContent` tulis `tz: +07:00` (jika non-null); `parseJournalContent` baca (backward-compat: absent → null).
- `journal_date_time_sheet.dart`: saat save, rekam `DateTime.now().timeZoneOffset.inMinutes` → `tzOffset`.
- Display: `journalDayHeader` bandingkan `tzOffset` vs offset perangkat → beda, tampilkan suffix. (Detail: jika 1 hari punya entry tz beda, pakai tz entry pertama.)

### T4 — Rail timeline (gambar 3)
- Hapus bullet 8px circle di `_DayHeader` (yesterday + other-day indicator). Pin "today" = **konfirmasi: tetap atau hapus?**
- Vertical line menembus ring: **fill ring solid** (`_RailRing` bg `appPage`) supaya garis di belakang ter-cover — atau potong garis di ring. (pemilihan implementasi)
- Spacing antar item: perbesar padding entry bottom (8 → 16?).
- Rail (garis + ring) tetap ada sesuai doop.

### T5 — Mood picker 1:1 (gambar 4, element w8pqaj)
File `journal_mood_sheet.dart`:
- `MoodFace` size 20 → **36**.
- Badge centang: 16px `top:0 right:0` (di atas face) → **20px overhang pojok TILE** (`top:-6 right:-6` relatif tile; tile perlu `Clip.none`).
- Label `footnote`(12) → `caption`(11.5).
- Polish: tile height fixed 78 (dari aspect 0.9); grid gap 12 → 10; selected ring 2+2 → 2+4 (periksa `SelectionRing` bisa 2+4, kalau tak bisa → painter khusus).

### T6 — Calendar view 1:1 (gambar 5)
File `journal_calendar.dart` (+ `journal_day_cards`, `journal_stats_row`):
- Cek terhadap doop frame `YesVmaWc4W`(card) / `7qh8EyOQ9B`(flat): sel hari, stat row, day cards, warna heat, radius.
- Fix delta. (Detail: hasil cek saat implementasi; laporkan token baru jika ada.)

### T7 — Skill `upstream-contribution`
- Buat skill (di `~/.agents/skills/upstream-contribution/SKILL.md` atau project `.agents/skills/`) berisi:
  - Conventional Commits `type(scope)`; scope web|mobile|server
  - l10n ARB + `@key.description`; tak string mentah
  - Test: `flutter analyze && flutter test` + `dart format`
  - Design token: ubah `design/tokens/` + `node design/build/build.mjs`
  - AI policy: tak cantumkan AI sebagai author/co-author; sebutkan di deskripsi PR
  - Bukti visual: before/after light+dark
  - 1 PR 1 hal; fitur besar butuh issue
- Atau pointer singkat di `AGENTS.md` root. **(konfirmasi: skill vs AGENTS.md, dan lokasi)**

### T8 — Verifikasi + rilis
- `rflutter analyze` + `rflutter test` (full suite, 1389+).
- Golden: timeline/mood berubah → regen `test/journal_v2_golden_test.dart` + golden PNG (di box-05, scp balik).
- Bump `mobile/pubspec.yaml`, tag `v0.25.8`, push → release.

## Keputusan owner (konfirmasi)
- [x] T1: pakai **A (route)** — lebih merge-friendly
- [x] T3: tambah field `tz:` di meta block
- [ ] T4: pin "today" tetap atau hapus?
- [ ] T4: garis vertikal — fill ring solid vs potong di ring?
- [ ] T2: ukuran font date header exact (token mana)?
- [ ] T7: skill file vs pointer AGENTS.md + lokasi?
- [ ] Grup PR: semua 1 PR, atau pecah (journal polish / calendar / skill)?

## Catatan
- Mayoritas task di file FORK-ONLY. Yang sentuh shared: T1 (`app_router.dart`, additive). Minimal → merge-friendly.
- box-05 (rflutter) bisa idle; golden regen butuh box bangun.
