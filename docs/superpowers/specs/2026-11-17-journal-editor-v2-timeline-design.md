# Journal v2: editor, pickers, timeline & 12-mood model (design)

Design doc for the **remaining** journal frames on doop page `ymyXw6eqo_`
("Journal — list variations"): the **editor v2**, the two **picker sheets**,
the **timeline v2**, and the underlying **12-mood "Wangcai" model**.

Companion to `2026-11-17-journal-calendar-heatmap-design.md` (calendar v2,
already implemented and committed on `feat/journal`).

## Intent & why

The journal shipped with a v1 editor (date pill in the top bar, 4-mood
toolbar-row picker) and a basic timeline. The doop design has moved on to a
**v2 layout**: the entry metadata (date/time + mood) lives as **pills below
the title**, each opening a **bottom sheet**, and the mood set grew from 4 to
**12 "Wangcai" Shiba-inu faces**. The timeline gained a **stats row**,
**photo thumbnails**, and a **mood face on each row**. This work brings the
live app to match those frames 1:1.

## Execution venue

The implementation happens in a **git worktree off `feat/journal`** (which
holds the other session's calendar v2 commits `9ecbd4c`…`c5e0d68`), not
directly on the branch. Set it up before Phase 1.

## Scope split

- **This session (in the worktree)**: the 12-mood model + Wangcai SVG assets,
  the calendar **day-card mood chip** (the piece the calendar session skipped
  in `e890da7`), editor v2, both picker sheets, and timeline v2.
- **Other session (calendar v2, done)**: heat-map month grid, month footer +
  legend, TODAY pill, and the day-card **tag chip** (`e890da7`).

## Goals / non-goals / anti-goals

Goals
- Editor: date/time + mood as **pills under the title**; both open a **sheet**;
  tags under the pills; a **two-row** format toolbar.
- Mood: **12 Wangcai faces** as **local SVG** assets, tinted; picker is a
  **4×3 grid sheet** with **Clear mood** / **Done**.
- Timeline: **stats row** (per-card conditional), **photo** thumbnail with a
  count badge, **mood face** on the row (1:1), **day headers** with a
  left group label + right date range.

Non-goals
- The calendar view itself (other session).
- The **grid icon** behaviour in the top bar. It is a **placeholder**
  (rendered, no action). Its real behaviour ("like the Notes page menus") is a
  later feature.
- Any **server** change.

Anti-goals
- No new DB schema. Mood stays in the note **content metadata**.
- No hardcoded palette/size. Everything from live tokens (`AnchorTokens`,
  `AppTypography`, `AppButton`, `AnchorSheet`, `Pressable`).
- Do not hotlink assets at runtime (offline-first).

## Constraints

- Mobile only. No `server/` changes.
- Mood is stored **by name** inside content (`mood: <key>`), via
  `parseJournalContent` / `composeJournalContent` in
  `journal_meta.dart`. No sync/schema impact.
- Reuse `anchor_sheet.dart` (the `BottomSheet`: scrim + 26px handle + radius
  28 + `shadow.dialog`) and `app_buttons.dart` (`AppButton`: primary =
  **inverse slate**, secondary = text @8%). Follow the `anchor-shadow-motion`
  guideline for sheet motion.
- Icons stay **Lucide** (`lucide_icons_flutter`).
- `test/theme/layout_scale_test.dart` forbids off-scale sizes (escape with a
  `// off-scale:` comment). `test/l10n_test.dart` needs a
  `@key.description` on every `app_en.arb` message; l10n files are
  hand-patched (gen-l10n does not rewrite checked-in files).
- One locale: `app_en.arb`.

## Decisions (as the owner decided)

1. **Mood = 12 Wangcai faces, replacing the old 4.** "Pakai Wangcai, ganti."
   The 12 keys: `happy, calm, grateful, excited, okay, tired, anxious, sad,
   angry, lonely, stressed, sick`. Old entries that stored `amazing/
   good/neutral/rough` **fall back to no mood** (no face), with no mapping.
2. **Faces are SVG**, downloaded once from svgrepo into the repo as
   `mobile/assets/mood/<key>.svg` (local, offline). Monochrome
   (`fill: currentColor`) → **tinted `accent-strong`** (`#CC5F2D`), the warm
   tone seen in the frames. Key → source:
   `happy=539369, calm=539401, grateful=539407, excited=539393, okay=539368,
   tired=539410, anxious=539376, sad=539373, angry=539384, lonely=539367,
   stressed=539395, sick=539372` (svgrepo `/show/<id>/<name>.svg`).
3. **Editor v2**: move the date/time + mood to **pills below the title**
   (rework the v1 top-bar date pill + toolbar mood button). Date/time pill is
   a combined `📅 Tue, 17 Nov | 🕐 09:41`; the mood pill is `🙂 Add mood`
   (empty, dashed) or `🙂 <face> <Label>` (selected, accent tint). Tags sit
   under the pills. Toolbar is the **standard two-row** format toolbar.
4. **Date/time picker sheet** (frame `NZ_UENzgqV`): `AnchorSheet` + a
   month calendar (reuse the journal month grid, day-selection only, no
   heat/legend) + a **native** time wheel + `Cancel` (secondary) / `Save`
   (primary) footer.
5. **Mood picker sheet** (frames `d2_y9JDvvH` / `YB7mEERCyQ`): `AnchorSheet`
   + **4×3 grid** of the 12 Wangcai faces + selection ring + check badge +
   `Clear mood` (secondary) / `Done` (primary) footer.
6. **Timeline v2** (frame `jnt2XBFVRD`):
   - **Stats row** at top: "On this day", "N-day streak", "Throwback · <year>".
     Each card renders **only when its data exists** (owner: "hanya muncul
     saat data siap").
   - **Thumbnail = the photo** (rounded), with a **count badge** when
     multiple. **Not** the note-background colour.
   - **Mood face** (Shiba) on the row when the entry has a mood, 1:1.
   - **Day headers**: left group label (TODAY / YESTERDAY / THIS WEEK) +
     right date range.
   - **Top bar**: "Journal ▾" opens the **drawer** (same as other pages:
     already the `LargeBarTitle`); the **calendar icon** toggles timeline ↔
     calendar (active-state highlight); the **grid icon** is a
     **placeholder** (no action yet).

## Approaches (build alternatives considered; what was picked)

**Mood faces**
- *Local SVG + `flutter_svg`*: **picked.** Offline, tintable, matches
  "export as svg". Cost: adds the `flutter_svg` dependency (not currently in
  `pubspec.yaml`) and 12 asset files.
- Hotlink svgrepo at runtime: rejected (breaks offline-first).
- Rasterize to PNG: a fallback if `flutter_svg` is undesirable; but the owner
  asked for SVG.
- Emoji font (12 codepoints): rejected; the Wangcai set is the Shiba SVG
  series, not a font.

**Picker sheets**
- *Native Flutter widgets + reuse `AnchorSheet`/`AppButton` + `anchor-
  shadow-motion`*: **picked.** No new package; the canvas already ships the
  sheet/button components. Time wheel = `CupertinoDatePicker` (time mode,
  24h) or `ListWheelScrollView`.
- `omni_datetime_picker` package: rejected (adds a dependency; the dev-notes
  frame lists it as optional only).

## Phases (order)

1. **Mood model + assets (foundation).** `JournalMood` 4→12 in
   `journal_meta.dart`; `JournalMoodX` maps key → l10n label + SVG asset;
   download the 12 SVGs; add `flutter_svg` + the asset folder to
   `pubspec.yaml`; a shared `MoodFace` widget (SvgPicture, tinted).
2. **Editor v2 + 2 sheets.** Rework the journal editor to the under-title
   pills; the date/time sheet; the 12-mood sheet (replace the 4-card row
   picker `journal_mood_picker.dart`).
3. **Day-card mood chip** (calendar remainder): render the entry's `MoodFace`
   in the day-card meta row of `journal_day_cards.dart` (replacing the
   deferred TODO).
4. **Timeline v2.** Stats row (conditional), photo thumbnail + count badge,
   row mood face, day headers with ranges, top-bar two-icon layout
   (calendar active-state + grid placeholder).

## Day-card mood chip (the calendar session's skipped piece)

`journal_day_cards.dart` has a `// TODO: mood emoji row is deferred; only the
tag chip renders for now.` The tag chip shipped (`e890da7`), the mood chip
did not. This session adds it: in the day-card meta row, render the entry's
`MoodFace` (12-set) beside the time + tag chip, matching the design's day-card
frame (`YesVmaWc4W`). Old 4-mood entries show **no face** (fallback),
consistently in both the timeline row and this chip.

## Left to the builder (my calls: confirm in review)

- **Tint**: `accent-strong` for selected faces; a muted/neutral tone for
  unselected picker tiles.
- **Stats triggers**: "On this day" = ≥1 entry on today's month-day in a
  prior year; "N-day streak" = ≥2 consecutive days ending today/yesterday
  with ≥1 entry; "Throwback · <year>" = most recent prior year (≠ current)
  with an entry on today's month-day. Hide a card when its data is absent.
- **Old-mood fallback**: stored `amazing/good/neutral/rough` → `null` mood
  (no face), no crash, no migration.
- **`flutter_svg`** added as a dependency; 12 assets in `mobile/assets/mood/`.
- **Two-row toolbar** = the existing app format toolbar (line styles + text
  styles), not a journal-specific one.
