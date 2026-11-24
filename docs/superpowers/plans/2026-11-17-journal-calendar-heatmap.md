# Journal calendar v2: heat map and richer day cards

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Shade the journal calendar's month grid by per-day entry count
(GitHub-activity style), add a month footer + legend, a "TODAY" pill on the day
header, and a mood + tag chip on each day card.

**Architecture:** A pure heat-bucket helper and an unfiltered per-day count
provider feed the existing `JournalCalendar`; the footer, legend, TODAY pill and
the card's mood/tag meta are added to the existing calendar and day-card
widgets. No schema, server, or sync change.

**Tech Stack:** Flutter, Riverpod (manual providers), `AnchorTokens` /
`AppTypography`, `intl` DateFormat, single-locale `en` l10n.

**Spec:** `docs/superpowers/specs/2026-11-17-journal-calendar-heatmap-design.md`

## Global Constraints

- Mobile only. Do not touch `server/`.
- Styling from live tokens only (`AnchorTokens`, `AppTypography`); no hardcoded
  colours from the Doop frame. Day tints are alphas of
  `AnchorColors.accentStrong`: level 0 → 0.0, 1 → 0.14, 2 → 0.30, 3 → 0.55.
- Heat and the month count use **all** journal entries, independent of the
  active search query (search still filters the day cards below the calendar).
- l10n is English-only: add keys to `lib/l10n/app_en.arb` and hand-patch
  `app_localizations.dart` + `app_localizations_en.dart`. Do not run
  `gen-l10n`; those generated files are checked in by hand.
- The `ValueKey('journal-entry-dot')` marker is removed; the day tint is the
  "has entry" signal.

## Review Focus

- A day with 4+ entries shows the darkest bucket.
- A month with zero journal entries shows "0 entries this month" and no tints.
- The selected day stays a solid accent circle (white number), never a tint.
- An entry with only the `journal` tag shows no tag chip on its card.
- An entry with no mood shows its meta row as time only, with no blank gap.

Each is pinned to the owning task's test.

---

### Task 1: Heat buckets and unfiltered entry counts

**Files:**
- Modify: `mobile/lib/features/journal/domain/journal_day.dart`
- Modify: `mobile/lib/features/journal/presentation/journal_providers.dart`
- Test: `mobile/test/journal_day_test.dart`

**Interfaces:**
- Produces: `int heatLevelOf(int count)` (0 none · 1 · 2–3 · 4+);
  `Map<DateTime, int> journalEntryCounts(List<JournalDay> days)`;
  `final journalEntryCountsProvider = Provider<Map<DateTime, int>>` (unfiltered,
  from `journalNotesProvider`).

- [ ] **Step 1: Write the failing test** in `journal_day_test.dart`:
`heatLevelOf` returns 0 for 0, 1 for 1, 2 for 2 and 3, 3 for 4 and 10.
`journalEntryCounts` maps each day to its entry count from a `List<JournalDay>`.

- [ ] **Step 2: Run to confirm it fails**: `cd mobile && rflutter test test/journal_day_test.dart`.

- [ ] **Step 3: Implement** `heatLevelOf` and `journalEntryCounts` in
`journal_day.dart`; add `journalEntryCountsProvider` in `journal_providers.dart`
as `journalEntryCounts(groupJournalDays(ref.watch(journalNotesProvider).value ?? const <Note>()))`.

- [ ] **Step 4: Run to confirm it passes.**

- [ ] **Step 5: Commit**: `feat(journal): heat buckets and unfiltered entry counts`.

### Task 2: Footer and legend strings

**Files:**
- Modify: `mobile/lib/l10n/app_en.arb`
- Modify: `mobile/lib/l10n/app_localizations.dart`
- Modify: `mobile/lib/l10n/app_localizations_en.dart`

**Interfaces:**
- Produces: `String journalMonthEntries(int count)` (`=1{1 entry this month}`
  `other{{count} entries this month}`); `String get journalCalendarLess`
  ("Less"); `String get journalCalendarMore` ("More"). Each `@key` needs a
  `description` (checked by `test/l10n_test.dart`).

- [ ] **Step 1: Add** the three keys to `app_en.arb` (value + `@meta`), and the
method to `app_localizations.dart` and its implementation to
`app_localizations_en.dart` (plural via `intl.Intl.pluralLogic`, matching the
`notesCount` pattern).

- [ ] **Step 2: Run** `cd mobile && rflutter test test/l10n_test.dart` and
confirm the "every message tells translators where it shows" test still passes
(descriptions present).

- [ ] **Step 3: Commit**: `feat(journal): month-footer and legend strings`.

### Task 3: Heat-shaded cells, month footer, legend; drop the dot

**Files:**
- Modify: `mobile/lib/features/journal/presentation/widgets/journal_calendar.dart`
- Modify: `mobile/lib/features/journal/presentation/journal_screen.dart`
- Test: `mobile/test/journal_calendar_test.dart`

**Interfaces:**
- Consumes: `heatLevelOf`, `journalEntryCountsProvider` (Task 1);
  `journalMonthEntries`, `journalCalendarLess`, `journalCalendarMore` (Task 2).
- Produces: `JournalCalendar` gains `required Map<DateTime, int> entryCounts`.

- [ ] **Step 1: Update `journal_calendar_test.dart`:** drop the
`journal-entry-dot` assertion; pump with an `entryCounts` map that has one day at
4 and one at 1 and assert the "4 entries this month" footer plus the legend
("Less"/"More") present; and pump with an empty `entryCounts` and assert the
"0 entries this month" footer with no day tinted.

- [ ] **Step 2: Run to confirm it fails.**

- [ ] **Step 3: In `_DayCell`:** colour the in-month cell with
`colors.accentStrong.withValues(alpha: [0.0, 0.14, 0.30, 0.55][heatLevelOf(count)])`
instead of the dot; keep the solid accent + white number for the selected day and
the today-ring when not selected; keep adjacent months muted and unshaded. Remove
the `ValueKey('journal-entry-dot')` block.
Add the footer under the grid: a hairline, then `journalMonthEntries` (sum of
`entryCounts` for the shown month; 0 → "0 entries this month") on the left and
three `accentStrong` swatches (0.14 / 0.30 / 0.55) labelled with
`journalCalendarLess` / `journalCalendarMore` on the right.

- [ ] **Step 4: Wire** `entryCounts: ref.watch(journalEntryCountsProvider)` in
`journal_screen.dart`.

- [ ] **Step 5: Run to confirm it passes**, then **commit**:
`feat(journal): heat-shaded calendar cells, footer and legend`.

### Task 4: "TODAY" pill on the day header

**Files:**
- Modify: `mobile/lib/features/journal/presentation/widgets/journal_day_cards.dart`
- Test: `mobile/test/journal_day_cards_test.dart`

**Interfaces:**
- Consumes: `l10n.commonToday` (existing).
- Produces: a peach pill next to the day label when the day is today.

- [ ] **Step 1: Add a test:** pump `JournalDayCards` for a day equal to today and
assert `find.text(l10n.commonToday.toUpperCase(), ...)` (the "TODAY" pill) is
present; for a past day assert it is absent.
- [ ] **Step 2: Run to confirm it fails.**
- [ ] **Step 3: In `_DayHeader`,** when the day is today add a small
accent-tint pill (`l10n.commonToday`, uppercased, `accentStrong` text) between
the label and the entry count.
- [ ] **Step 4: Run to confirm it passes**, then **commit**:
`feat(journal): TODAY pill on the day header`.

### Task 5: Card mood and non-journal tag chip

**Files:**
- Modify: `mobile/lib/features/journal/presentation/widgets/journal_day_cards.dart`
- Test: `mobile/test/journal_day_cards_test.dart`

**Interfaces:**
- Consumes: `entry.meta.mood` + `JournalMoodX.emoji`; `tagsControllerProvider`,
  `journalTagProvider` (journal tag id), `tagsByName`.
- Produces: `JournalDayCards` as a `ConsumerWidget`; the card meta row shows the
  time, the mood emoji (only when a mood is set), and the first tag chip whose
  id is not the journal tag id (no chip when none).

- [ ] **Step 1: Add tests:** a card for a note with a mood + a topic tag shows
the emoji and that tag's name; a note with only the `journal` tag shows no chip;
a note with no mood shows the time with no gap.
- [ ] **Step 2: Run to confirm they fail.**
- [ ] **Step 3: Make `JournalDayCards` a `ConsumerWidget`;** build
`tagsById` from `tagsControllerProvider.value`, get the journal tag id from
`journalTagProvider`, and in `_EntryCard` resolve the first
`note.tagIds` entry that is not the journal tag (via `tagsByName`) and render
it as a small `TagChip`-style chip; show `mood.emoji` in the meta row when set.
- [ ] **Step 4: Run to confirm they pass** (with `tagsControllerProvider`
overridden in the test), then **commit**:
`feat(journal): mood and tag chip on the day card`.

---

## Execution note

Run after every task: `cd mobile && rflutter analyze` (clean) and the touched
test file. Before finishing: `cd mobile && rflutter test` (full suite green).
All work lands on the existing `feat/journal` branch.
