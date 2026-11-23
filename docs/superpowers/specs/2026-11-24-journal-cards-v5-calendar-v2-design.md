# Journal cards v5 + calendar grid v2 — design mapping (spec)

Repo: `/home/mimin/projects/anchorx` (branch `main`), kode di `mobile/`. Hanya Flutter; tak sentuh `server/`, `web/`, DB, sync.
Sumber desain (canvas Doop `-IAXF4NORn`, semua `ready_for_dev`, approved by moe):

| Kode | Frame ID | Nama |
| --- | --- | --- |
| F1 | `iQ7khvzQwZ` | Journal · 5b Cards — all items in one card (full + long content), 360x1120 |
| F2 | `2U-HM5j_dP` | Journal · 5c Cards — entries without title, 360x1180 |
| F3 | `YesVmaWc4W` | Journal · 3 Calendar grid v2, 360x880 |

Catatan sumber: plan ini dibuat dari HTML+CSS frame (`doop:get_frame`) dan pembacaan kode. Screenshot PNG belum dilihat, style guide Doop `anchor-shadow-motion` belum dibuka, dan `flutter test` belum dijalankan. Verifikasi visual ada di bagian 8.

## 0. Temuan penting (baca dulu)

1. **Sebagian besar F3 sudah ada.** `journal_calendar.dart` sudah punya heatmap, legend Less/More, hitung `N entries this month`, ring today, `JournalDayCards`. Thumbnail stack miring sudah ada di `journal_timeline.dart` (`_EntryThumbnails`). Yang dikerjakan untuk F3 adalah delta visual dan struktur, bukan fitur baru.
2. **Lokasi tidak ada di data.** Tidak ada field lokasi di `Note`, tidak ada dependency geolocator/geocoding di `pubspec.yaml`, tidak ada file `*location*`/`*geo*`/`*place*` di `lib/`. `JournalMeta` hanya mengenal `mood`, `date`, `time`, `tz`. Header key lain disimpan di `JournalMeta.extras` (round-trip aman, lihat `composeJournalContent`). **Tidak ada UI/produser yang menulis lokasi.** Lihat D1.
3. **Hitung gambar tidak persis.** `notes_repository.dart` membatasi `imagePreviewData` ke `maxImagePreviews = 4` (hanya gambar). `Note.attachmentCount` menghitung SEMUA attachment non-delete (bukan hanya gambar). Jadi badge `+N` tidak bisa persis tanpa menambah data. Lihat D4.
4. **Urutan entri dalam satu hari bertentangan.** F1, F2, F3 menampilkan entri hari yang sama dari pagi ke sore (naik). `groupJournalDays` mengurutkan terbaru dulu (turun). Lihat D3.
5. **Frame saling tak konsisten** pada: chevron di judul (F3 ada, F1/F2 tidak), aturan teks lead pendek vs panjang (D5), warna `#` chip (F1/F2 `accent-strong`, F3 `tag-green-hash`). Lihat D2, D5.
6. **Token sudah ada.** `shadowRaised` = bayangan kartu desain (`0 1px 2px .05` + `0 8px 24px .06`). `shadowControl` = bayangan sel terpilih. `shadowKnob` + `shadowEdge` = bayangan thumbnail. `shadowFab` = FAB. `radiusCard`/`radius2xl` = 16, `radius3xl` = 20, `radiusXl` = 14, `radiusTile` = 12. `sizeFieldPhone`/`sizeButtonPhone` = 52. `sizeControlSmall` = 32. `sizeJournalThumb` = 56. Tidak perlu token baru di `design/tokens/` selama angka off-scale diberi komentar.
7. **Bottom bar F1/F2/F3** (search pill 52 + FAB 52 + gap 12) sudah dipenuhi `NotesBottomBar` (shared dengan Notes). Hanya diverifikasi, tidak diubah (D8).

## 1. Keputusan owner (default dipakai bila tak dijawab)

| # | Pertanyaan | Default plan |
| --- | --- | --- |
| D1 | Lokasi: key header apa? Siapa yang menulis? | Baca `meta.extras['location']` (read-only, tanpa ubah parser). Chip lokasi tampil hanya bila ada. Produser (picker/GPS) = issue terpisah, di luar plan ini. Praktisnya chip belum pernah muncul sampai ada produser. |
| D2 | Chevron di judul list view (F1/F2 tak punya, F3 punya) | Pertahankan chevron di kedua mode (fungsional: buka drawer, sudah dites di `journal_screen_test`). |
| D3 | Urutan entri dalam hari: naik (frame) atau turun (kode)? | Ikuti frame (naik/kronologis) di LAYER PRESENTASI (`entries.reversed` di widget). `groupJournalDays` tak diubah. |
| D4 | Badge `+N` foto | Pendekatan: `N = attachmentCount - imagePreviewData.length` bila > 0. Tidak persis bila ada attachment non-gambar. Alternatif: tambah `imageCount` ke `Note` + `notes_repository` (field aditif, regen freezed, menyentuh file shared dengan upstream). Pilih alternatif hanya bila owner mau persis. |
| D5 | Aturan lead pendek vs panjang (F2) | Pendek bila teks tanpa newline dan <= 90 karakter: pakai `typeBody` 16.5, clamp 3. Panjang: `typeCardTitle` 15.5 medium, clamp 4. Di frame CSS `.lead.short` = heading 18 tapi inline override ke body 16.5; yang tampil 16.5. Frame: pendek = 66 dan 69 karakter, panjang = 213 karakter. Ambang 90 = tebakan. |
| D6 | Heat 2 level (F3) vs 3 level kode | Ikuti desain: l1 = 1 entri (14%), l2 = >=2 entri (28%). Mengubah `heatLevelOf` (domain) dan alpha `[0, .14, .30, .55]`. Disebut di sini karena menyentuh domain; tes `journal_day_test` dan `journal_calendar_test` ikut berubah. |
| D7 | Tile Throwback saat tak ada data / streak < 2 | Throwback tak ada: tile disembunyikan, tile Today melebar. Streak < 2: badge flame disembunyikan. Definisi throwback tetap kode saat ini (tahun lalu terdekat yang punya entri pada bulan-hari yang sama), label `N years ago`; untuk N=1 persis frame. |
| D8 | Bottom bar | Verifikasi saja. Beda visual (mis. gradient fade F3, ikon pen) dikerjakan di PR fix terpisah, bukan campur refactor. |
| D9 | Ikon filter/sort di sebelah label `ENTRIES` (F1/F2) | Render sebagai placeholder tak aktif (`onPressed: null`) seperti tombol Grid sekarang. Perilaku tidak didefinisikan di frame. |
| D10 | Format GMT: frame `GMT+7`, kode `gmtLabel` = `GMT+07` | Ubah `gmtLabel` ke jam tanpa padding (`GMT+7`, `GMT+5:30`). Tampilkan `· GMT±x` di baris waktu tiap entri bila `meta.tzOffset != null`. Hapus suffix GMT dari header hari (separator baru tidak punya). |

## 2. Pemetaan per frame

### F1 (5b) — kartu entri penuh + stats tiles

| Elemen desain | Spesifikasi (dari frame) | Widget / file | Sumber data |
| --- | --- | --- | --- |
| App bar | Judul `Journal` (display), ikon calendar + grid, target 40 | `journal_screen.dart` (tetap `AppScaffold` + `ListBarTitle`) | ada |
| Tiles | 2 tile `flex:1`, tinggi 92, radius 2xl, padding 12/14, bg `appSurface`, border `appBorder`; ikon lingkaran 28 (accent 16%); badge pill (caption bold) di kanan; judul bold `typeUi`; sub muted caption | **ubah** `journal_stats_row.dart` (ganti 3 kartu 72px jadi 2 tile). Tinggi 92 = `minHeight` (bukan fixed) agar aman text-scale. `// off-scale: design tile height 92` | lihat tabel sumber data di bawah |
| Section `ENTRIES` | label uppercase muted + ikon 20 di kanan, padding 6/20 | **baru** `journal_section_header.dart` | l10n baru `journalEntriesSection` |
| Separator tanggal | teks tengah `November 19, 2026 · Thu`, `typeMeta` medium muted, padding 16/0/8 | **baru** helper `journalDaySeparator(JournalDay, l10n)` di `journal_entry_text.dart` | `JournalDay.day` + `dateLocale` |
| Kartu 1 entri | `appSurface`, border `appDivider`, radius 16, padding 14, `shadowRaised`, margin horizontal 16 | **baru** `journal_card_shell.dart` (single + multi dengan divider 1px, margin 0/14) | ada |
| Header entri | kiri: waktu (caption bold, tabular) + ` · GMT+7` (muted medium), judul (card-title bold, clamp 2); kanan: mood 28 | **baru** `journal_entry_card.dart` | `journalTimeOf` (+ tz baru), `journalTitleOf`, `meta.mood` (ada) |
| Snippet | card-body muted, clamp 2, margin-top 2 | `journal_entry_card.dart` | `journalPreviewOf` (ada) |
| Strip foto | grid 4 kolom gap 6, tinggi 68, radius tile 12, bayangan `shadowKnob`+`shadowEdge`; sel ke-4 overlay hitam 45% + teks `+N` bold putih (`typeUi`) | **baru** `journal_photo_strip.dart` (reuse `attachmentFileProvider` + `previewFileKeyOf` seperti `_EntryThumbnails`) | `note.imagePreviewData` (<=4) + `+N` dari D4 |
| Footer | `Wrap` gap 8, margin-top 8; kosong -> disembunyikan | `journal_entry_card.dart` | lihat bawah |
| Chip lokasi | ikon pin 13 + nama, ellipsis | `journal_entry_card.dart` (`_LocationChip`) | **D1**: `meta.extras['location']` |
| Tag chips | `#` + nama, `typeChip`, pill, border `appBorder`, bg text 6% | reuse `TagChip` (`note_chips.dart`, shared). Jangan fork; cek paritas (8.2) | `note.tagIds` minus tag `journal` (SEMUA, bukan hanya `_firstOtherTag`) |
| Kartu multi | satu kartu, tiap entri punya padding 14 sendiri, divider antar entri | `journal_card_shell.dart` | `JournalDay.entries.length > 1` |
| Bottom bar | search pill + FAB | `NotesBottomBar` (tak diubah) | ada |

Sumber data stats tiles:

| Elemen | Sumber | Status |
| --- | --- | --- |
| Tile 1 judul `Today` + sub `Thu, Nov 19` | `l10n.commonToday` + `DateFormat('EEE, MMM d', dateLocale)` dari `DateTime.now()` | ada, tak perlu parse baru |
| Badge `12 days` | streak = `_Stats.streak` (hari berurutan berakhir hari ini/kemarin, minimal 2) | logika ada; **ekstrak** `_Stats` jadi fungsi domain `journal_stats.dart` agar bisa dites tanpa widget |
| Tile 2 judul `Throwback` | l10n baru `journalThrowback` | baru (string) |
| Badge `2 entries` | `JournalDay.entries.length` untuk hari throwback (tahun terdekat dengan bulan-hari sama) | **hitung baru** (kode sekarang hanya menyimpan tahun) |
| Sub `1 year ago` | `now.year - throwbackYear` | **hitung baru**; l10n plural `journalStatYearsAgo` |
| Edge: 29 Feb | tahun non-kabisat tak punya 29 Feb | belum ditangani kode sekarang; tambah tes, perilaku = tidak ada throwback |

### F2 (5c) — kartu tanpa judul

Semua komponen F1 dipakai ulang. Varian tanpa judul di `journal_entry_card.dart` (cabang `!note.hasTitle`):

- Header: waktu kiri + mood kanan, `min-height 28`, align center (di F1 varian judul: align start). Mood 28.
- Lead = seluruh isi body: **baru** `journalLeadOf(Note)` di `journal_entry_text.dart` (`journalPreviewOf` mengembalikan kosong untuk tanpa judul, `journalTitleOf` hanya baris pertama).
- Gaya lead: aturan D5. Margin-top 8, clamp 4 (panjang) / 3 (pendek).
- Entri tanpa judul tetap boleh punya strip foto dan footer (F2 kartu pertama punya strip + lokasi + tag).
- Kartu multi F2: entri pertama tanpa judul pendek, kedua berjudul tanpa foto (judul + snippet + chip). Ini kasus uji.

### F3 (Calendar grid v2) — delta terhadap kode

| Elemen | Frame | Kode sekarang | Perubahan |
| --- | --- | --- | --- |
| Chevron judul | lingkaran 28, surface + border, ikon muted | `ListBarTitle` (shared, `chevronDown`) | Verifikasi paritas (8.2). Bila beda, tambah parameter kecil di file shared dalam commit terpisah. |
| Tombol calendar | tile `on` (accent-strong, `check-mark`, `shadowControl`), ikon calendar tetap | ikon ganti `rows3` saat kalender aktif, `isOn: true` | Pertahankan ikon calendar saat aktif; `isOn` dipertahankan. Update `journal_screen_test` (cek ikon). |
| Kartu kalender | radius 3xl (20), border `appBorder`, padding 14/14/12, `shadowRaised` | radius 16, padding 16, tanpa bayangan | ubah `journal_calendar.dart` |
| Nav bulan | tombol 32 (`sizeControlSmall`), bg text 7%; `November` heading 18 bold + `2026` kecil label muted | tombol 40, bg `appPage`; serif large title tengah | ubah; ganti `Text` jadi `Text.rich`. Tes `find.text('November 2026')` perlu diganti (`find.textContaining`) |
| Weekday | caption semibold uppercase, spasi label | `AppTypography.label` | ubah |
| Sel hari | persegi (aspect 1), radius xl 14, gap 4 baris / 3 kolom, angka `typeUi` tabular; sel di luar bulan opacity .4 | tinggi tetap 44 (`sizeControlMedium`), radius 12, margin 2 | `childAspectRatio: 1`, radius `radiusXl`; gap 3px = `// off-scale:` |
| Heat | l1 14%, l2 28% | 4 level, alpha `[0,.14,.30,.55]` | D6 |
| Ring today | inset 1.5 accent-strong untuk sel non-terpilih mana pun | hanya jika level == 0 | hapus kondisi level |
| Sel terpilih | accent-strong, `check-mark`, bold, `shadowControl` | accent-strong, `appOnInverse` | tambah bayangan, cek warna teks |
| Legend | border-top, `N entries this month` (angka bold) kiri; kanan `Less` + 3 swatch (text 8%, l1, l2) 12px radius 4 + `More` | 3 swatch (14/30/55%), tanpa swatch kosong | tambah swatch nol, ganti alpha; hitung bulan sudah ada |
| Day header | `Tue, 17 Nov` uppercase + pill `Today` (accent 20%) + `2 entries` kanan | format `EEE, MMM d`, pill 14% | format -> `EEE, d MMM`; pill 20%. Tes `TUE, NOV 17` berubah |
| Kartu hari | SATU kartu (radius 16, border divider, `shadowRaised`), entri di dalamnya dengan divider | kartu per entri tanpa surface, hairline antar entri | **tulis ulang** `journal_day_cards.dart` memakai `journal_card_shell.dart` |
| Entri (titled) | grid `1fr 56px`: kiri judul (bold) + snippet (2 baris) + meta; kanan thumbnail STACK | tanpa thumbnail | tambah stack |
| Entri (untitled) | satu kolom: lead (clamp 4) + meta | judul = baris pertama | pakai `journalLeadOf` |
| Meta | jam `HH:mm` (24h), dot 3, mood 20, chip tag | jam + mood + SATU tag | semua tag non-journal; jam pakai `clockLabel` (ikut setelan telepon; frame 24h cuma mock) |
| Stack 3 lapis | wadah 56; belakang 42px rot 9deg opacity .7 (kanan-atas); tengah 44px rot 4deg opacity .9; depan 46px (kiri-bawah) | `_EntryThumbnails`: sisi 56, offset 6, rot `[0,-.07,.13]`, opacity `[1,.8,.7]`, 1-3 foto | **ekstrak** `journal_thumb_stack.dart` dari timeline; sesuaikan geometri ke F3 (42/44/46, 9deg/4deg, `// off-scale:` per angka); ditambah tes 1/2/3 foto |
| Tanpa foto | frame tak menampilkan | - | tanpa kolom kosong (asumsi; flag di PR) |
| Bottom bar | + gradient fade `appPage` | `FrostedGlass` | verifikasi saja (D8) |

## 3. Daftar file

Baru (`mobile/lib/features/journal/`):
- `domain/journal_stats.dart` — streak, throwback (tahun, jumlah entri) sebagai fungsi murni.
- `presentation/widgets/journal_card_shell.dart` — kartu single/multi + divider.
- `presentation/widgets/journal_entry_card.dart` — isi entri list view (judul / tanpa judul, mood, footer).
- `presentation/widgets/journal_photo_strip.dart` — strip 4 foto + `+N`.
- `presentation/widgets/journal_thumb_stack.dart` — stack miring (diekstrak dari timeline).
- `presentation/widgets/journal_cards_list.dart` — sliver list: separator tanggal + shell + entri, menggantikan `JournalTimeline` di mode list.
- `presentation/widgets/journal_section_header.dart`.

Ubah:
- `journal_screen.dart` — mode list pakai `JournalCardsList`; section header; tombol calendar (ikon tetap).
- `journal_stats_row.dart` — 2 tile.
- `journal_calendar.dart` — visual F3.
- `journal_day_cards.dart` — satu kartu + stack.
- `journal_entry_text.dart` — `journalDaySeparator`, `journalLeadOf`, `journalTimeLabel` (waktu + GMT), `journalLocationOf`, `gmtLabel` (D10), pembantu tag non-journal.
- `domain/journal_day.dart` — hanya `heatLevelOf` (D6).
- `mobile/lib/l10n/app_en.arb`, `app_localizations.dart`, `app_localizations_en.dart`.

Dihapus di PR3: `journal_timeline.dart`, `journal_timeline_test.dart`, golden `journal_timeline.png`, key l10n yang tak terpakai (`journalStatOnThisDay`, `journalStatThrowback` lama, `journalStatStreak` lama bila tak dipakai).

Tak diubah: `journal_meta.dart` (parser), `journal_providers.dart`, `NotesBottomBar`, `CardRegistry`.

## 4. l10n baru (`app_en.arb`, tiap key + `@key.description`)

| Key | Teks | Dipakai di |
| --- | --- | --- |
| `journalEntriesSection` | `Entries` | label section list |
| `journalThrowback` | `Throwback` | judul tile 2 |
| `journalStatDays` | `{count, plural, =1{1 day} other{{count} days}}` | badge streak |
| `journalStatYearsAgo` | `{count, plural, =1{1 year ago} other{{count} years ago}}` | sub tile 2 |
| `journalPhotosMore` | `+{count}` | overlay strip foto |
| `journalLocationLabel` | `Location: {place}` | semantics chip lokasi |
| `journalEntriesOptions` | `Entry options` | semantics ikon section (D9; hanya bila ikon dirender) |

Teks yang sudah ada dan dipakai ulang: `commonToday`, `journalEntriesCount` (badge `2 entries`, header hari F3), `journalMonthEntries`, `journalCalendarLess`, `journalCalendarMore`, `journalSearchHint`, `journalNew`.

Aturan repo: edit ARB, lalu patch tangan `app_localizations.dart` (getter/method abstrak + doc) dan `app_localizations_en.dart` (implementasi, plural lewat `intl.Intl.pluralLogic`), jalankan `l10n_test.dart`. Di luar cakupan: `_weekdays` dan `semanticLabel: id` ('prev'/'next') di `journal_calendar.dart` masih string mentah (sudah ada sebelumnya; jangan dicampur ke PR ini).

## 5. Urutan PR dan task (opsi A: 3 PR berurutan)

Setiap commit: `type(mobile): ...`, stage hanya file yang disentuh, tanpa `git add -A`, tanpa AI sebagai author/co-author (sebut alat di body PR). Pisahkan commit refactor murni dari commit fitur.

### PR1 — kartu list view + stats tiles (F1, F2)

Cabang: `feat/journal-cards-v5`.

| Task | Isi | Commit |
| --- | --- | --- |
| 1.1 | Ekstrak `_Stats` ke `domain/journal_stats.dart` tanpa ubah perilaku; `journal_stats_test` tetap hijau | `refactor(mobile): extract journal stats into the domain layer` |
| 1.2 | Helper teks: `journalDaySeparator`, `journalLeadOf`, `journalTimeLabel`, `journalLocationOf`, `gmtLabel` (D10), tag non-journal, ambang lead (D5), throwback + count | `feat(mobile): add journal card text helpers` |
| 1.3 | `JournalStatsRow` 2 tile (+ l10n) | `feat(mobile): show today and throwback tiles on the journal` |
| 1.4 | `JournalCardShell` + `JournalEntryCard` (judul/tanpa judul/mood/footer, tanpa strip dulu) + penempatan `CardRegistry` | `feat(mobile): render journal entries as cards` |
| 1.5 | `JournalPhotoStrip` + `+N` (D4) | `feat(mobile): add the photo strip to journal cards` |
| 1.6 | `JournalCardsList` + `JournalSectionHeader`; `journal_screen.dart` mode list pakai ini (timeline masih ada di repo) | `feat(mobile): switch the journal list to cards` |
| 1.7 | Regenerasi golden yang berubah (stats row) + golden baru | `test(mobile): add journal card goldens` |

### PR2 — calendar grid v2 (F3)

Cabang: `feat/journal-calendar-v2` (dari main setelah PR1 merge).

| Task | Isi | Commit |
| --- | --- | --- |
| 2.1 | Ekstrak `JournalThumbStack` dari `_EntryThumbnails` tanpa ubah tampilan (timeline masih pakai) | `refactor(mobile): extract the journal thumbnail stack` |
| 2.2 | D6 + visual `JournalCalendar` (kartu, nav, sel persegi, ring, legend) | `feat(mobile): restyle the journal calendar grid` |
| 2.3 | `JournalDayCards` = satu kartu + stack + meta row + header hari `EEE, d MMM` | `feat(mobile): show the selected day as one card with a thumbnail stack` |
| 2.4 | Ikon calendar tetap saat aktif; verifikasi chevron | `feat(mobile): keep the calendar icon while the calendar is on` |
| 2.5 | Golden calendar + day cards | `test(mobile): update journal calendar goldens` |

### PR3 — polish, hapus kode lama, visual test

Cabang: `chore/journal-cards-cleanup`.

| Task | Isi | Commit |
| --- | --- | --- |
| 3.1 | Hapus `JournalTimeline` + tes + golden + l10n tak terpakai | `refactor(mobile): remove the unused journal timeline` |
| 3.2 | Golden gelap untuk widget baru; tes `layout_scale_test` bersih | `test(mobile): add dark journal goldens` |
| 3.3 | Tune ambang lead (D5) bila owner koreksi; fix hasil verifikasi device | `fix(mobile): ...` (satu per masalah) |

Opsi B (satu PR) hanya bila owner mau review sekali; sulit di-bisect untuk regresi morph/golden, jadi tidak direkomendasikan.

## 6. TDD per bagian (merah dulu)

Tes di `mobile/test/` (gaya existing: `journal_*_test.dart`, `AppTheme.light()`, `ProviderScope`).

| Task | Tes merah pertama | File |
| --- | --- | --- |
| 1.1 | tes lama harus tetap hijau (refactor) | `journal_stats_test.dart` |
| 1.2 | `journalDaySeparator` = `November 19, 2026 · Thu`; `journalLeadOf` untuk tanpa judul = seluruh body; ambang pendek/panjang (66 dan 69 char = pendek, 213 = panjang, newline = panjang); `journalTimeLabel` menambah ` · GMT+7` hanya bila `tzOffset != null`; `gmtLabel(330)` = `GMT+5:30`; `journalLocationOf` membaca `extras['location']`, kosong bila tak ada, trim; throwback mengembalikan tahun + jumlah entri; 29 Feb | `journal_entry_text_test.dart`, tes domain baru untuk `journal_stats.dart` |
| 1.3 | dua tile tampil; badge `12 days` hanya bila streak >= 2; tile 2 hilang tanpa throwback; badge `2 entries` dan `1 year ago`/`2 years ago`; angka tak berubah saat search aktif | `journal_stats_test.dart` |
| 1.4 | kartu berjudul: waktu, judul, snippet, mood; tanpa judul: lead tanpa baris judul; footer kosong disembunyikan; semua tag non-journal tampil; chip lokasi hanya dengan `extras['location']`; **`CardRegistry.keyFor(note.id)` ada untuk tiap entri (single dan multi)**; `CardRegistry.hide(id)` menyembunyikan hanya entri itu | `journal_entry_card_test.dart` (baru), `journal_day_cards_test.dart` |
| 1.5 | 0/1/4/6 gambar: jumlah sel, `+N` hanya pada sel ke-4 saat ada sisa; path null (offline) tidak crash | `journal_photo_strip_test.dart` (baru) |
| 1.6 | layar: separator hari, urutan entri naik (D3), tap entri memanggil `_open`, pencarian menyaring, kondisi kosong, bottom bar compact saat scroll | `journal_screen_test.dart` |
| 2.1 | tes timeline lama hijau | `journal_timeline_test.dart` |
| 2.2 | `heatLevelOf(1)=1`, `(2)=2`, `(5)=2`; legend 3 swatch + `Less`/`More`; ring today pada sel dengan heat; sel persegi; `November` + `2026` | `journal_day_test.dart`, `journal_calendar_test.dart` |
| 2.3 | satu kartu untuk hari dengan 2 entri + 1 divider; stack muncul hanya dengan foto; header `TUE, 17 NOV`; pill `TODAY` | `journal_day_cards_test.dart` |
| 2.4 | ikon calendar tetap (bukan `rows3`) saat aktif; tap lagi kembali ke list | `journal_screen_test.dart` |
| 1.7/2.5/3.2 | golden | `journal_v2_golden_test.dart` |

Golden: file dihasilkan di host Linux dengan font bawaan app; regen di box-05 (`rflutter test --update-goldens`), lalu salin balik. Jangan regen golden di commit yang sama dengan perubahan perilaku.

## 7. Bagian berisiko

**CardRegistry / morph open-close (risiko tertinggi).**
- `note_morph_route.dart` memakai `CardRegistry.rectOf(id)` sebagai target dan `CardRegistry.contentOf(id)` (anak `RepaintBoundary`) sebagai isi kartu yang terbang. Radius asal = `radiusCard` (16). `note_card.dart` menaruh `RepaintBoundary` membungkus seluruh isi kartu (`NoteCardContent`).
- Kode journal sekarang menaruh boundary di sekitar kolom teks saja (tanpa permukaan). Di v5 **permukaan kartu ada**, jadi: kartu 1 entri = `RepaintBoundary(key: keyFor(id))` membungkus SELURUH kartu (shell + isi) supaya rect dan radius 16 cocok. Kartu multi = satu boundary per entri (membungkus isi + padding entri, shell dan divider di luar); radius asal 16 pada segmen tanpa chrome kartu bisa tampak janggal, uji di device.
- Bungkus tetap `ValueListenableBuilder<Set<String>>(CardRegistry.hidden)` + `Opacity` per entri. `CardRegistry.leaving` dipakai `note_card.dart` tapi tidak oleh journal saat ini; jangan ditambahkan kecuali ada alasan.
- `GlobalKey` per note id harus unik: kalender dan list tak boleh render entri yang sama bersamaan (sudah dijamin: mode eksklusif). Jangan membuat dua widget dengan `keyFor(sameId)`.
- Tes: `CardRegistry.keyFor` terpasang pada tiap entri; `hide` hanya menyembunyikan satu entri dalam kartu multi; morph buka/tutup dari entri tunggal, entri kedua kartu multi, dan entri di kalender (device, 8.2).

**Golden.** `journal_day_cards.png`, `journal_stats_row.png`, `journal_timeline.png` akan berubah/hilang. Regen hanya di box-05, review PNG manual, satu commit khusus.

**`layout_scale_test.dart` (pemindai sumber).** Angka dalam konteks ukuran harus dari skala 4/8/12/16/24/32/48 atau token; selainnya wajib `// off-scale: alasan` di baris itu atau berikutnya. `AnchorTokens.sizeRow|sizeFieldPhone|sizeButtonPhone|sizeControlLarge` butuh `// same in Compact:`. Daftar angka yang akan butuh komentar: tinggi tile 92, strip 68, mood 28, gap kolom sel 3, ikon pin 13, ring 1.5, stack 42/44/46 dan 9deg/4deg, swatch 12 dan radius 4, dot 3, `+N` overlay alpha .45. Gunakan token bila ada: `space10/14/20/28`, `radiusXl`, `radius3xl`, `sizeControlSmall`, `sizeJournalThumb`, `shadowRaised`/`shadowControl`/`shadowKnob`/`shadowEdge`. Jalankan `flutter test test/theme/layout_scale_test.dart` setiap task.

**Text scale dan density Compact.** Tile 92 dan strip 68 pakai `minHeight`/rasio, bukan tinggi mati. Cek Compact density dan text scale 1.3 (tak overflow di tile, header entri, chip).

**Perilaku data.** Tidak ada perubahan parser (`journal_meta.dart`). Perubahan domain yang disengaja: `heatLevelOf` (D6) dan format `gmtLabel` (D10, tampilan). D4 opsi `imageCount` menyentuh `Note` shared; hindari kecuali diminta.

**Merge dengan upstream.** Semua file journal fork-only kecuali `NotesBottomBar`, `ListBarTitle`, `TagChip`, `note.dart`, `notes_repository.dart` (shared). Rencana ini tak mengubahnya kecuali parameter kecil `ListBarTitle` bila paritas chevron gagal (commit terpisah).

## 8. Checklist verifikasi

### 8.1 Otomatis (box-05, rflutter)
- [ ] `cd mobile && dart format lib test`
- [ ] `rflutter analyze`
- [ ] `rflutter test` (full suite) + `rflutter test test/theme/layout_scale_test.dart`
- [ ] `l10n_test.dart` hijau; `app_localizations*.dart` konsisten dengan ARB
- [ ] Golden: diff PNG ditinjau manual sebelum commit

### 8.2 Device (tiap PR)
- [ ] List: hari dengan 1 entri, 2 entri (kartu multi), entri tanpa judul pendek/panjang, 0/1/4/6 foto, offline (foto belum terunduh), tanpa tag, banyak tag (wrap), judul panjang (clamp 2), body panjang (clamp 3/4)
- [ ] Stats tiles: streak aktif / tak aktif, throwback ada / tak ada (set tanggal perangkat atau data uji), search aktif tak mengubah angka
- [ ] Lokasi: entri uji dengan header `location:` tampil; tanpa header tak ada chip; round-trip simpan di editor tidak menghapus header
- [ ] Morph buka/tutup: kartu tunggal, entri pertama dan kedua kartu multi, entri di kalender; tak ada kedip, rect dan radius mulus, kartu kembali ke posisi benar setelah scroll
- [ ] Scroll: bottom bar compact saat scroll turun, kembali saat naik; search buka/tutup; drawer swipe
- [ ] Kalender: ganti bulan, pilih hari kosong / 1 entri / banyak entri, hari ini terpilih dan tidak terpilih (ring), heat 0/1/2, hitung `N entries this month`, ganti kembali ke list
- [ ] Dark dan light, density Default dan Compact, text scale 1.0 dan 1.3, 24 jam dan 12 jam
- [ ] Paritas TagChip dengan F1/F2/F3 (warna `#` accent vs tag color), paritas ListBarTitle chevron dengan F3, ikon FAB dengan frame

### 8.3 Bukti visual (AGENTS.md)
Screenshot before/after, light dan dark, di body PR untuk: list F1, list tanpa judul F2, kalender F3 (hari terpilih dengan stack), kartu multi. Tempel berdampingan dengan screenshot frame Doop. Sebut alat AI di body PR (bukan author/co-author).
