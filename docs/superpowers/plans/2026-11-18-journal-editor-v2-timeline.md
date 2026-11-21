# Journal v2 (remaining frames) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (Native) or superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Ship the remaining journal frames — the 12-mood "Wangcai" model + SVG assets, the calendar day-card mood chip, the v2 editor (metadata pills + two picker sheets), and timeline v2 (stats row, photo thumbnails, mood face, day headers, top bar).

**Architecture:** Extend `JournalMood` 4→12 (Wangcai), stored by name in content metadata. A shared `MoodFace` widget (flutter_svg, tinted `accentStrong`) renders the faces everywhere (day-card chip, timeline row, editor pill). Picker UIs reuse `showAnchorSheet` + `SheetHeader`/`SheetFooter` + `AppButton`. The editor moves metadata from the top bar/toolbar to pills under the title. The timeline gains a conditional stats row, a horizontal meta row, corrected typography, and real-photo stacked thumbnails.

**Tech Stack:** Flutter, Riverpod (manual providers), `flutter_svg` (new dep), Lucide, `intl`, `go_router`. No server/DB change.

**Spec:** `docs/superpowers/specs/2026-11-17-journal-editor-v2-timeline-design.md`

## Global Constraints

- Mobile only. No `server/` change. Mood stays in content metadata (`mood: <key>`).
- **Base: `fork/main` @ `c33441d`. Execute in a git worktree** (`superpowers:using-git-worktrees`), off `fork/main`.
- Reuse `showAnchorSheet`/`SheetHeader`/`SheetFooter` + `AppButton` (`AppButtonKind.primary` = inverse slate, NOT orange) + the `anchor-shadow-motion` recipe.
- Icons: Lucide only.
- `test/theme/layout_scale_test.dart` forbids off-scale sizes → escape a line with `// off-scale: <why>`; a raw `fontSize` always needs a comment.
- l10n: hand-patch `app_localizations.dart` + `app_localizations_en.dart`; every `app_en.arb` message needs an `@key.description`; gen-l10n does NOT rewrite checked-in files.
- Old 4-mood names (`amazing/good/neutral/rough`) fall back to **no mood** (null); no crash, no migration.
- Run via `rflutter` on box05: `cd mobile && rflutter analyze` (clean) + `rflutter test` (green) per task; full suite at the end.

## Review Focus

1. Old 4-mood entries → **no face** anywhere (day-card chip, timeline row, editor pill); `journalMoodFromName('amazing') == null`; no crash.
2. 1 vs 3+ photos → the timeline stack loads the **real back photo(s)**, not blank white.
3. No stats data → the stats row **collapses** (no empty cards, no layout break).
4. Date/time sheet Cancel vs Save → Cancel keeps the old `entryAt`, Save commits it; the month grid reflects the saved day.
5. Journal save/reopen round-trip → the metadata header (mood/date/time) survives `composeJournalContent`/`parseJournalContent`; the 2-row toolbar works in journal mode **without** the mood tool.

## File map

- **Modify** `mobile/lib/features/journal/domain/journal_meta.dart` — enum 4→12, `.asset` getter.
- **Create** `mobile/lib/features/journal/presentation/widgets/mood_face.dart` — `MoodFace`.
- **Modify** `mobile/pubspec.yaml` (+ `flutter_svg`, + `assets/mood/`); download 12 SVGs to `mobile/assets/mood/`.
- **Modify** `mobile/lib/features/journal/presentation/widgets/journal_day_cards.dart` — mood chip.
- **Modify** `mobile/lib/features/journal/presentation/widgets/journal_calendar.dart` — extract `JournalMonthGrid`.
- **Create** `mobile/lib/features/journal/presentation/widgets/journal_mood_sheet.dart`.
- **Create** `mobile/lib/features/journal/presentation/widgets/journal_date_time_sheet.dart`.
- **Create** `mobile/lib/features/journal/presentation/widgets/journal_entry_meta_row.dart` (date/time + mood pills).
- **Modify** `mobile/lib/features/notes/presentation/note_edit_screen.dart` — wire the meta row; remove v1 wiring.
- **Delete/keep** `mobile/lib/features/journal/presentation/widgets/journal_mood_picker.dart` (4-card row → replaced by the sheet).
- **Create** `mobile/lib/features/journal/presentation/widgets/journal_stats_row.dart`.
- **Modify** `mobile/lib/features/journal/presentation/widgets/journal_timeline.dart` — meta row, typography, thumbnails.
- **Modify** `mobile/lib/features/journal/presentation/journal_screen.dart` — top-bar 2-icon.
- **Modify** `mobile/lib/l10n/app_en.arb` + `app_localizations*.dart` — 12 mood labels + sheet strings.

---

## Phase 1 — Mood-12 model + Wangcai assets (foundation)

### Task 1: Extend `JournalMood` to the 12 Wangcai moods

**Files:**
- Modify: `mobile/lib/features/journal/domain/journal_meta.dart`
- Test: `mobile/test/journal_meta_test.dart`

**Interfaces:**
- Produces: `enum JournalMood { happy, calm, grateful, excited, okay, tired, anxious, sad, angry, lonely, stressed, sick }`; `JournalMoodX.asset` (`String get asset => 'assets/mood/${name}.svg'`); `journalMoodFromName(String?)` returning the 12 (old names → `null`).
- Consumes: `parseJournalContent`/`composeJournalContent` (unchanged; they already store `mood: <name>`).

- [ ] **Step 1: Write the failing test.** In `journal_meta_test.dart`, assert `JournalMood.values.length == 12` and the 12 keys; `journalMoodFromName('happy') == JournalMood.happy`; `journalMoodFromName('amazing') == null` (old name falls back); `JournalMood.happy.asset == 'assets/mood/happy.svg'`.
- [ ] **Step 2: Run it, confirm it fails** (`rflutter test test/journal_meta_test.dart`).
- [ ] **Step 3: Rewrite the enum + `JournalMoodX`.** Replace the 4 values with the 12; add `String get asset` (the SVG path) and drop `.emoji` (see Step 4 for call sites).
- [ ] **Step 4: Update every `JournalMoodX.emoji` call site.** Grep `grep -rn "\.emoji" mobile/lib mobile/test`; replace each with the `MoodFace` widget (Task 2) or remove it.
- [ ] **Step 5: Run the test, confirm it passes**; `rflutter analyze` clean.
- [ ] **Step 6: Commit.** `git add -A && git commit -m "feat(journal): 12-mood Wangcai model"`

### Task 2: `flutter_svg` + the 12 assets + `MoodFace`

**Files:**
- Modify: `mobile/pubspec.yaml`
- Create: `mobile/assets/mood/{happy,calm,grateful,excited,okay,tired,anxious,sad,angry,lonely,stressed,sick}.svg`
- Create: `mobile/lib/features/journal/presentation/widgets/mood_face.dart`
- Test: `mobile/test/mood_face_test.dart`

**Interfaces:**
- Produces: `MoodFace({required JournalMood mood, double size = 20})` → `flutter_svg` `SvgPicture.asset(mood.asset, width: size, height: size)` — **full-colour, no `colorFilter`**.
- Consumes: `JournalMoodX.asset` (Task 1).

- [ ] **Step 1: Add `flutter_svg`** to `pubspec.yaml` dependencies + declare `assets/mood/` under `flutter:` → `assets:`; run `rflutter pub get`.
- [ ] **Step 2: Download the 12 SVGs** to `mobile/assets/mood/<key>.svg` from the svgrepo URLs in the spec (`https://www.svgrepo.com/show/<id>/<name>.svg`). Verify each is `<svg`.
- [ ] **Step 3: Write the failing widget test** — `MoodFace(mood: JournalMood.happy)` renders an `SvgPicture` with the `happy` asset (full-colour, no tint).
- [ ] **Step 4: Implement `MoodFace`** in `mood_face.dart` (SvgPicture, full-colour, no tint).
- [ ] **Step 5: Run the test (pass); `rflutter analyze` clean; `rflutter test test/mood_face_test.dart`.**
- [ ] **Step 6: Commit.** `git add -A && git commit -m "feat(journal): MoodFace widget and 12 Wangcai SVG assets"`

## Phase 2 — Day-card mood chip (calendar remainder)

### Task 3: Mood chip on the calendar day card

**Files:**
- Modify: `mobile/lib/features/journal/presentation/widgets/journal_day_cards.dart`
- Test: `mobile/test/journal_day_cards_test.dart`

**Interfaces:**
- Consumes: `MoodFace` (Task 2), `JournalMeta.mood` (via `parseJournalContent`), the existing `TagChip` + `_firstOtherTag`.
- Produces: the day-card meta row shows `[time] [MoodFace] [# tag]` when the entry has a mood.

- [ ] **Step 1: Failing test.** A day-card for an entry with `mood: calm` renders a `MoodFace(calm)` in its meta row; an entry with an old `mood: amazing` (→ null) renders **no** face but still the tag chip.
- [ ] **Step 2: Run, confirm fail** (`rflutter test test/journal_day_cards_test.dart`).
- [ ] **Step 3: Add the mood face.** In `_EntryCard`, replace the `// TODO: mood emoji row is deferred` line: when `meta.mood != null`, render `MoodFace(mood, size: 20)` in the meta Row between the time and the tag chip.
- [ ] **Step 4: Run, confirm pass; `rflutter analyze` clean.**
- [ ] **Step 5: Commit.** `git add -A && git commit -m "feat(journal): mood chip on the calendar day card"`

## Phase 3 — Editor v2 + two picker sheets

### Task 4: Extract `JournalMonthGrid` from `JournalCalendar`

**Files:**
- Modify: `mobile/lib/features/journal/presentation/widgets/journal_calendar.dart`
- Test: `mobile/test/journal_calendar_test.dart`

**Interfaces:**
- Produces: `JournalMonthGrid({required DateTime month, required Map<DateTime,int> counts, required DateTime? selectedDay, required ValueChanged<DateTime> onPickDay, bool heat})` — the day-of-week header + 6×7 heat-shaded (or plain) day grid, with `heat: false` for the date/time picker (plain days, no heat/legend).
- Consumes: the existing `_HeatLegend`/`_DayCell` logic; `JournalCalendar` now composes `JournalMonthGrid` (behavior unchanged).

- [ ] **Step 1: Refactor `JournalCalendar`** so the month grid is a public `JournalMonthGrid` (pass `heat`, `onPickDay`, `counts`); `JournalCalendar` = `JournalMonthGrid(heat: true)` + nav + footer + legend. No behavior change.
- [ ] **Step 2: `rflutter test test/journal_calendar_test.dart` stays green; `rflutter analyze` clean.**
- [ ] **Step 3: Commit.** `git add -A && git commit -m "refactor(journal): extract JournalMonthGrid for reuse"`

### Task 5: `JournalMoodSheet` (12-grid + Clear/Done)

**Files:**
- Create: `mobile/lib/features/journal/presentation/widgets/journal_mood_sheet.dart`
- Modify: l10n (keys below)
- Test: `mobile/test/journal_mood_sheet_test.dart`

**Interfaces:**
- Produces: `Future<void> showJournalMoodSheet(BuildContext context, {required JournalMood? selected, required ValueChanged<JournalMood?> onPick, VoidCallback? onClear})` — `showAnchorSheet` + `SheetHeader(title: 'How are you feeling?', subtitle: 'Pick a mood for this entry')` + a **4×3 `GridView.count` of `MoodFace`+label** (selection ring + check) + `SheetFooter` with `AppButton('Clear mood', secondary)` + `AppButton('Done', primary)`.
- Consumes: `MoodFace` (Task 2), `showAnchorSheet`/`SheetHeader`/`SheetFooter`/`AppButton`.

**l10n keys:** `journalMoodHappy/...Sick` (12 labels), `journalMoodPickerTitle`, `journalMoodPickerSubtitle`, `journalMoodClear`, (`commonDone`, `commonCancel` reused).

- [ ] **Step 1: Add the l10n keys** (arb + both `app_localizations*` files, each with `@key.description`).
- [ ] **Step 2: Failing widget test** — tapping "calm" fires `onPick(calm)`; "Clear mood" fires `onClear` + `onPick(null)`; "Done" closes.
- [ ] **Step 3: Run, confirm fail; implement `showJournalMoodSheet`.**
- [ ] **Step 4: Run, confirm pass; `rflutter analyze` clean.**
- [ ] **Step 5: Commit.** `git add -A && git commit -m "feat(journal): 12-mood picker sheet"`

### Task 6: `JournalDateTimeSheet` (month + time wheel + Cancel/Save)

**Files:**
- Create: `mobile/lib/features/journal/presentation/widgets/journal_date_time_sheet.dart`
- Modify: l10n (keys below)
- Test: `mobile/test/journal_date_time_sheet_test.dart`

**Interfaces:**
- Produces: `Future<DateTime?> showJournalDateTimeSheet(BuildContext context, {required DateTime initial, Map<DateTime,int>? entryCounts})` — `showAnchorSheet` + `SheetHeader('Date & time')` + `JournalMonthGrid(heat: false, month, counts: entryCounts, selectedDay, onPickDay)` + a **native time wheel** (`CupertinoDatePicker` time mode, 24h, or `ListWheelScrollView` for hour+minute) + `SheetFooter` with `AppButton('Cancel', secondary)` (returns null) + `AppButton('Save', primary)` (returns the chosen date+time).
- Consumes: `JournalMonthGrid` (Task 4).

**l10n keys:** `journalDateTimeTitle`, (`commonCancel`, `commonSave`).

- [ ] **Step 1: Add the l10n keys.**
- [ ] **Step 2: Failing test** — picking a day + time then "Save" returns that `DateTime`; "Cancel" returns `null`.
- [ ] **Step 3: Run, confirm fail; implement `showJournalDateTimeSheet`.**
- [ ] **Step 4: Run, confirm pass; `rflutter analyze` clean.**
- [ ] **Step 5: Commit.** `git add -A && git commit -m "feat(journal): date & time picker sheet"`

### Task 7: `JournalEntryMetaRow` + editor v2 wiring

**Files:**
- Create: `mobile/lib/features/journal/presentation/widgets/journal_entry_meta_row.dart`
- Modify: `mobile/lib/features/notes/presentation/note_edit_screen.dart`
- Delete: `mobile/lib/features/journal/presentation/widgets/journal_mood_picker.dart` (4-card row, now dead) — or leave and stop using it.
- Test: `mobile/test/journal_editor_test.dart`

**Interfaces:**
- Produces: `JournalEntryMetaRow({required JournalMeta meta, required VoidCallback onEditDateTime, required VoidCallback onEditMood, ...})` — a row under the title: **date/time pill** (`📅 Tue, 17 Nov | 🕐 09:41`) + **mood pill** (empty `🙂 Add mood` dashed, or `<MoodFace> <Label>` accent-tinted).
- Consumes: `showJournalMoodSheet` (Task 5), `showJournalDateTimeSheet` (Task 6), `MoodFace` (Task 2).

- [ ] **Step 1: Failing test** — in journal mode, `NoteEditScreen` shows the meta row under the title (date/time pill + mood pill) and **not** the old top-bar `JournalDatePill` nor the toolbar `EditorMoodTool` nor the above-keyboard mood row. Plus: pick a mood + a date/time, save, reopen — the note keeps them (the `NoteContentCodec` round-trip) — pins Review Focus 5.
- [ ] **Step 2: Run, confirm fail.**
- [ ] **Step 3: Build `JournalEntryMetaRow`** (the two pills).
- [ ] **Step 4: Wire `note_edit_screen.dart`:** insert the meta row between the title `TextField` and `NoteTagRow` (journal mode only); set `NoteBar.leadingInset` to `null` for journal; set `EditorOverlay.editorMood` to `null`; remove the `JournalMoodPicker` `Positioned` block. Date pill tap → `showJournalDateTimeSheet` → update `_meta.entryAt` + `_draft.contentChanged()`; mood pill tap → `showJournalMoodSheet` → update `_meta.mood` + `_draft.contentChanged()`.
- [ ] **Step 5: Run, confirm pass; `rflutter analyze` clean; `rflutter test test/journal_editor_test.dart`.**
- [ ] **Step 6: Commit.** `git add -A && git commit -m "feat(journal): editor v2 metadata pills and picker sheets"`

## Phase 4 — Timeline v2

### Task 8: Stats row (conditional)

**Files:**
- Create: `mobile/lib/features/journal/presentation/widgets/journal_stats_row.dart`
- Modify: l10n (keys below)
- Test: `mobile/test/journal_stats_test.dart`

**Interfaces:**
- Produces: `JournalStatsRow({required List<JournalDay> days})` — three optional cards: **On this day** (≥1 entry on today's month-day in a prior year), **N-day streak** (≥2 consecutive days ending today/yesterday with ≥1 entry), **Throwback · <year>** (most recent prior year ≠ current with an entry on today's month-day). **Each card renders only when its data exists**; all absent → the row is empty (no `SizedBox`/spacer that breaks layout). Data source: `groupJournalDays(all notes)` (full history).
- Consumes: `JournalDay`/`JournalDayEntry` (`journal_day.dart`).

**l10n keys:** `journalStatOnThisDay`, `journalStatStreak(int)`, `journalStatThrowback(String)`.

- [ ] **Step 1: Add the l10n keys.**
- [ ] **Step 2: Failing test** — given days that produce a streak + an on-this-day, all three cards render; given days with no such data, the row is empty.
- [ ] **Step 3: Run, confirm fail; implement `JournalStatsRow` + the three trigger computations.**
- [ ] **Step 4: Run, confirm pass; `rflutter analyze` clean.**
- [ ] **Step 5: Commit.** `git add -A && git commit -m "feat(journal): conditional timeline stats row"`

### Task 9: Timeline meta row + typography

**Files:**
- Modify: `mobile/lib/features/journal/presentation/widgets/journal_timeline.dart`
- Test: `mobile/test/journal_timeline_test.dart`

**Interfaces:**
- Produces: the timeline entry shows a **horizontal meta row** `[time] • [MoodFace 20px] • [# tag]` (caption 11.5/500/tabular; the tag chip = the standard `TagChip`, identical to the Notes page).
- Consumes: `MoodFace` (Task 2), `journalMoodFromName`, the first non-journal tag (`_firstOtherTag` pattern from `journal_day_cards.dart`), `TagChip`.

**Typography targets (from the spec table):** day label **12/w700/appText**; day date-range **caption 11.5/500/tabular**; entry title **cardTitle w700**; meta time **caption 11.5/500**.

- [ ] **Step 1: Failing test** — the timeline row renders the meta row (time + mood face + tag chip); the day label is `appText` + `w700`; the title is `w700`.
- [ ] **Step 2: Run, confirm fail.**
- [ ] **Step 3: Implement:** add the horizontal meta row to `_EntryRow` (time + `MoodFace` + the first non-journal tag via the standard `TagChip` — identical to the Notes page, **no bespoke coloured variant**); apply the typography targets (day label `appText`+`w700`, date-range `caption`+`.tabular`, title `cardTitle.copyWith(fontWeight: w700)`, time `caption`).
- [ ] **Step 4: Run, confirm pass; `rflutter analyze` clean.**
- [ ] **Step 5: Commit.** `git add -A && git commit -m "feat(journal): timeline meta row and design typography"`

### Task 10: Timeline thumbnails (56, real back photo, no badge)

**Files:**
- Modify: `mobile/lib/features/journal/presentation/widgets/journal_timeline.dart` (`_EntryThumbnails`), `mobile/lib/core/theme/tokens/anchor_tokens.dart` (`sizeJournalThumb` → 56, verify on the layout scale)
- Test: `mobile/test/journal_timeline_test.dart`

**Interfaces:**
- Produces: `_EntryThumbnails` renders up to 3 stacked photos, **each loading its real file** (`attachmentFileProvider` per key, not just the front), size **56** (`sizeJournalThumb`), **no count badge**.

- [ ] **Step 1: Failing test** — a 3-photo entry renders 3 `Image.file`s (all real paths, no blank placeholder behind), no badge widget; size = 56.
- [ ] **Step 2: Run, confirm fail.**
- [ ] **Step 3: Implement:** load each stacked photo via `attachmentFileProvider`; remove the `_ThumbnailsBadge`; set `sizeJournalThumb = 56` (add `// off-scale:` if 56 is not on the scale, else it is).
- [ ] **Step 4: Run, confirm pass; `rflutter analyze` clean.**
- [ ] **Step 5: Commit.** `git add -A && git commit -m "feat(journal): stacked photo thumbnails load all, no badge"`

### Task 11: Timeline top-bar two-icon (calendar toggle + grid placeholder)

**Files:**
- Modify: `mobile/lib/features/journal/presentation/journal_screen.dart`
- Test: `mobile/test/journal_screen_test.dart`

**Interfaces:**
- Produces: the top bar shows **two** actions: a **calendar icon** (toggles `_calendar`; active-state when in calendar view, reusing the existing `JournalCalendar` + `journalEntryCountsProvider`) and a **grid (4-square) icon** (placeholder, no action yet). Replaces the current single combined `BarButton`.
- Consumes: existing `JournalCalendar`, `JournalTimeline`, `journalEntryCountsProvider` (calendar view already built on `fork/main`).

- [ ] **Step 1: Failing test** — the top bar has the calendar + grid icons; tapping the calendar icon switches to the calendar view; the grid icon has no effect.
- [ ] **Step 2: Run, confirm fail.**
- [ ] **Step 3: Implement:** two `BarButton`s (calendar = active-state via `_calendar`; grid = placeholder `onPressed: null` or a no-op).
- [ ] **Step 4: Run, confirm pass; `rflutter analyze` clean.**
- [ ] **Step 5: Commit.** `git add -A && git commit -m "feat(journal): timeline top-bar calendar toggle and grid placeholder"`

---

## Final: full suite + self-review

- [ ] `cd mobile && rflutter analyze` (clean) + `rflutter test` (all green).
- [ ] Plan self-review against the spec: every spec requirement maps to a task (see "File map"); type/signature names consistent across tasks; Review Focus items each have a test.
- [ ] Confirm off-scale escapes + l10n `@key.description` present; `test/theme/layout_scale_test.dart` + `test/l10n_test.dart` green.

## Execution

Worktree off `fork/main` @ `c33441d` (superpowers:using-git-worktrees). **Native** execution recommended: tasks are sequential and each builds on the previous task's interfaces (`MoodFace` → chips/rows; `JournalMonthGrid` → date/time sheet); a shipped mistake costs a UI rework, but there are no independent-parallel seams, so one Native pass + a final fresh review is cheapest.
