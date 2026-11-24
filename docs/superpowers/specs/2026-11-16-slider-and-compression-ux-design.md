# Design spec: slider UX + image-compression feedback (mobile)

Session: UI/UX improvements, `mobile/` only. Visual source of truth: Doop
canvas `Anchor — UI/UX` (https://doop.design/c/-IAXF4NORn), frames:

| Frame | id | Shows |
| --- | --- | --- |
| Settings: Text Size Slider (mobile) | `aQYM9UiQJ2` | Full settings screen; editor section with text-size slider + min/max labels |
| Backup: slider dialogs (redesigned) | `QHiJXx9KNO` | Period + keep-files dialogs: big accent value, unit, min/max ends, quick chips |
| Pictures: compression states | `5TU_sY7gzl` | 4 states: compressing, ready (savings), uploading, failed |

Canvas tokens mirror `anchor_tokens.dart` (accentStrong `#CC5F2D`/dark
`#EF8354`, appPage/Surface/Text/Muted, radii sm→2xl, spacing scale).
Components on the canvas: `Button`, `Section`, `ListTile`, `SliderRow`,
`AttachmentCard`.

## A. Text size slider (Settings → Editor): NO CHANGE (owner decision 2026-11-16)

Owner compared the redesign against the live screen and prefers the live
design. No theming, no min/max labels. The live baseline frame
`XL1xt_uBLV` is the source of truth for this screen.

## B. Backup number dialogs

`mobile/lib/features/backup/presentation/backup_section.dart`,
`_pickNumber` (~line 238) called by `_pickPeriod` (1–31) and
`_pickKeep` (1–10).

Current: bare `AlertDialog` + material `Slider`, value only in the
(untoggled) `label:` param.

Changes:
1. Dialog content: header row, left: fixed label ("Every" / "Keep");
   right: current value large (22px, w700, accentStrong) + unit
   ("days" / "files").
2. Slider: 6px track (active accent, inactive border), 24px thumb
   white with 2px accent ring + shadow. Divisions keep step = 1.
3. Ends row under track: min/max ("1 day" / "31 days"; "1" / "10"),
   11px muted.
4. Period dialog only: quick-select chip row, Daily (1), Weekly (7),
   Monthly (30); tapping a chip sets the slider value; active chip =
   accent fill. Keep dialog: no chips.
5. Actions unchanged: Cancel / Save.

l10n additions (en only, `app_en.arb` + `flutter gen-l10n`):
- `backupEvery`: "Every"
- `backupKeepWord`: "Keep"
- `backupDaysUnit`: "days", `backupFilesUnit`: "files"
- `backupDaily`: "Daily", `backupWeekly`: "Weekly", `backupMonthly`: "Monthly"

## C. Image compression feedback

Flow (unchanged): pick photo → `ImageCompressor.compress` in isolate →
JPEG q85, longest side ≤ 2048px, never upscale → file becomes the
attachment's `localPath`. Failure falls back to the original, silently.

Changes:
1. `add_sheet.dart::_pickPicture`: while compressing, show an inline
   status row at the top of the sheet body: spinner (accent) +
   "Compressing photo…" (`imageCompressing`); disable the pick
   buttons during that window. Remove the row when done.
2. Extend the `AddedFile` record with `int? originalBytes` and
   `int? compressedBytes` (null when no compression data).
3. `note_edit_screen.dart::_showAdd`: after a successful
   `addAttachment` for a picture with size data, append " · 4.2 MB →
   310 KB" to the success snackbar (new `attachmentCompressed`
   message with `{from}`/`{to}` placeholders). Show only when the
   compression actually shrank the file by ≥ 5%.
4. No new DB fields, no new provider, no tile changes. The upload
   spinner / failed overlay on `picture_tile.dart` already cover states
   3–4 of the frame.

Helper: `humanReadableBytes(int)` → "4.2 MB" / "310 KB" (KB/MB, one
decimal when ≥ 10 units, no decimal below), next to
`image_compressor_worker.dart` or in `core/utils`.

l10n additions:
- `imageCompressing`: "Compressing photo…"
- `attachmentCompressed`: "{from} → {to}"

## Motion & interaction (Apple fluid-design pass)

Applies to A and B. Existing app primitives carry it: `Spring`
system (`core/motion/springs.dart`, velocity-aware `simulation(from, to)`),
`Haptics`, and `MotionSpeed` (user's reduced-motion setting; `off` =
scale 0 → every new animation must collapse to instant).

1. **Chip → thumb handoff (backup dialog).** Tapping a quick chip sets the
   slider value; the thumb moves instantly (no glide), and the value text
   updates in the same frame. Rationale: an animated value
   (`ImplicitlyAnimatedSlider`) would lag the user's own drag and break the
   1:1 direct-manipulation feel, so the gesture always wins. Dragging the
   thumb is 1:1 and interruptible (plain material `Slider`).
2. **Zero-latency value text.** The big accent number updates in the
   same frame as `onChanged`: no debounce, no transition on the text.
3. **Haptics on commit only.** `Haptics.selection()` on chip tap
   (matches the segmented-control pattern in Settings). No haptics on
   slider release: the action is Save, not the gesture.
4. **Compression row (C).** Appears on the same frame compression
   starts, with no artificial delay. The spinner is continuous status, not
   an event: no haptic, no sound. The row is removed when the sheet
   pops; nothing animates out.
5. **Reduced motion.** Every new animation duration flows through
   `Spring.*.duration` / `context.motion(...)` so `MotionSpeed.off`
   makes them land instantly.

## Out of scope

- `server/` and `web/` untouched.
- WebP encoding.
- Per-attachment persisted compression status / savings on tiles.
- Other languages than en.
- Release: still via GitHub Runner tag (`v0.25.2` when merged).
