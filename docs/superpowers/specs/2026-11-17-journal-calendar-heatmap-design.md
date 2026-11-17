# Journal calendar v2 — activity heat map and richer day cards

Status: proposed, 2026-11-17. Owner: Abang Ganteng. Scope: `mobile/` only.
Builds on the `feat/journal` branch. Doop reference: frame `YesVmaWc4W`.

## Intent

The journal calendar is now a month card with day cards under it. The owner wants
it to read at a glance — how busy each day was — and to carry a little more of
the entry on the card. The Doop design shows a GitHub-style **heat map** on the
month grid: the more journal entries a day holds, the more strongly that day is
shaded. It also adds a month footer, a "TODAY" marker on the day header, and a
mood + tag chip on each entry card.

The **Less ◦ ◦ More** row in the design is a **legend for the shading, not a
control** (owner confirmed). It explains the light→dark scale.

The Doop frames are a **layout reference only**. Colours, type, spacing, radii
and control behaviour come from `AnchorTokens`, `AppTypography`, `TagChip`,
`Pressable` and the existing `JournalCalendar` / `JournalDayCards`.

## What already exists (on `feat/journal`)

- `JournalCalendar`: a month card — serif month, circular prev/next, a 6-week
  grid from the Monday, adjacent-month days muted, a dot on entry days, a
  filled circle on the selected day.
- `JournalDayCards`: the day header ("EEE, MMM d" + "N entries") and a card per
  entry (title, 2-line body, time).
- `_EntryThumbnails`: one / two / three stacked pictures with a count badge.
- `journalDaysProvider` already gives `List<JournalDay>` (each a day + its
  entries). `JournalMeta.mood` holds the mood.
- The entry **title and body** helpers live in `journal_entry_text.dart`.

So this work is a delta on the calendar card and the day cards, not a rewrite.

## Goals

1. **Heat-map the month grid.** Each in-month day cell is shaded in a tint of
   the accent, scaled by how many entries that day has. Selected day stays a
   solid accent circle with a white number. Adjacent-month days stay muted and
   unshaded. Today, when not selected, keeps its ring.
2. **Month footer.** A hairline divider under the grid, then "N entries this
   month" on the left and the **legend** (three accent-tint swatches with
   "Less" and "More" at the ends) on the right.
3. **TODAY marker.** When the selected day is today, the day header shows a
   small accent-tint "TODAY" pill next to the date.
4. **Richer entry card meta.** Under the body, the meta row shows the time, the
   mood emoji when a mood is set, and a `# tag` chip for the entry's first
   non-journal tag (via a tag-name lookup).

## Non-goals

- The Less/More row is display-only. It does not change zoom or filter.
- No change to the day-grouped **timeline** view (the rail) or to the editor.
- No schema, server, or sync change. Everything is derived from existing notes.

## Approach: the heat scale

The owner picked **fixed buckets** over a month-relative scale.

- **Fixed buckets (chosen).** Four states: 0 entries → no fill; 1 → light;
  2–3 → medium; 4+ → dark. Three fixed tints of the accent, matching the
  three squares in the design's legend. Predictable, matches the legend, easy
  to test.
- **Month-relative (rejected).** Darkest = the month's busiest day, all days
  scaled to it. More "live," but the legend has no fixed meaning and a quiet
  month never reaches the dark end.

The per-day count is derived from `journalDaysProvider` (already grouped by
day): a `Map<DateTime, int>` of day → entry count for the shown month. No new
provider.

## The owner's decisions

- Heat scale = **fixed buckets**: 0 / 1 / 2–3 / 4+ (this doc).
- The Less/More row is a **legend**, not an interactive control.
- Selected day keeps a **solid accent** fill with a white number, regardless of
  its bucket.

## Builder's calls (override if you disagree)

- **Tint colours.** No accent-tint token exists, so use three alphas of
  `AnchorColors.accentStrong` (≈ 0.14 / 0.30 / 0.55) on the day cell, in a
  rounded-rect (the existing cell circle). These are guesses; tune in review.
- **Month count.** "N entries this month" = the sum of `day.entries.length`
  over every `JournalDay` in the shown month (0 → "No entries this month").
- **Card tag chip.** Show the first tag whose id is not the journal tag's id,
  as one `TagChip`-style chip; none → no chip. The card becomes a
  `ConsumerWidget` and resolves names from `tagsControllerProvider` via
  `tagsByName`.
- **Mood in the card.** The mood emoji appears in the meta row only when a
  mood is set (same rule as the timeline).
- **Leading icon before the card title.** The design has a small orange marker
  before the title. Omit it for now — the mood already signals the day's tone;
  trivial to add back.
- **Legend swatches** reuse the three tint alphas above, as small rounded
  squares, labelled "Less" and "More".

## Resolved during the builder check

These came up reading the doc against the code; settled so the plan can proceed.

- **Search and the heat map.** The heat tints and "N entries this month" use
  **all** journal entries in the shown month, independent of the active search
  query. The day cards below the calendar still follow the query. Rationale:
  the map is a stable picture of the month's activity; it should not dim as
  you type. This needs an unfiltered day→count source (a small helper over the
  notes), since `journalDaysProvider` is already query-filtered.
- **Locale.** This project is English-only, so the new strings ("N entries
  this month", "No entries this month", "Less", "More") are added to
  `lib/l10n/app_en.arb` and hand-patched into `app_localizations.dart` and
  `app_localizations_en.dart` — no other locales, no gen step.
- **Entry dot removed.** The `ValueKey('journal-entry-dot')` marker is
  dropped; the day tint is now the "has entry" signal. `test/journal_calendar_test.dart`,
  which asserts that key, is updated to assert the tint instead.
- **Which tag is "first".** The card chip is the first tag in
  `note.tagIds` order, excluding the journal tag's id (not the name-sorted
  order `tagsByName` returns).
- **No reference image in the repo.** The Doop frame `YesVmaWc4W` is a live
  canvas, not a committed asset; the build is planned from the live tokens,
  using the frame as layout reference only (as the doc states).

## What's left to the builder

- Exact alpha values and the legend swatch size (tune visually against the
  live accent in light and dark themes).
- Bucket edge cases (a day with exactly 4+ entries, a month with zero entries).
- Tests: bucket mapping (0/1/2-3/4+), month count, legend presence, TODAY
  pill, and the card showing a mood + a non-journal tag chip.
