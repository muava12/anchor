# Journal

Status: proposed, 2026-11-17. Owner: Abang Ganteng. Scope: `mobile/` only.

## Intent

Anchor has no home for dated, daily writing. A journal entry is a note that
carries a mood, a day and a time, and the owner wants a dedicated Journal page:
a day-grouped timeline, a calendar, and an editor with a mood picker. This keeps
journaling in the same offline-first notes the app already syncs, instead of a
second data store.

The Doop canvas is a **layout reference only**. Colours, typography, spacing,
radii, and control behaviour come from the existing widgets and tokens in
`mobile/`, never from the frame's hardcoded values.

## Constraints from the owner

- Mobile only. Do not touch `server/`. Stop if the work needs a server change.
- Design frames give layout and structure. Detail styling reuses the live code:
  `AnchorTokens`, `AppTypography`, `NoteSurface`, `TagChip`, `EditorToolbar`,
  `NotesBottomBar`, `Pressable`, `FrostedGlass`, `AppScaffold`.
- Theme follows the app theme. No hardcoded dark palette.

## Goals

- A **Journal** entry in the sidebar, under Notes.
- **Timeline**: entries grouped by day, newest first, each row showing time,
  title or first body line, mood, and the first picture when present.
- **Calendar**: a month grid with a dot on days that have an entry; picking a
  day shows that day's entries.
- **Editor**: the existing note editor plus two journal controls: a date/time
  pill and a single mood button. The mood button shows one icon, opens four
  emoji choices, and takes the chosen emoji as its icon.
- Entries are ordinary notes tagged `journal`. No schema, server, or sync
  change.
- Everything works offline on first open.

## Non-goals

- No server table, endpoint, migration, or sync field.
- No new note content type or second database.
- No stories strip ("On this day", streak, throwback) in the first version.
- No backfill of notes written before this change.
- No change to the Notes, Archive, or Trash pages.
- No change to how a normal note editor behaves.

## Anti-goals

- A journal entity on the server, or a journal-only sync path.
- Metadata that the next sync silently drops.
- A note format the normal editor cannot open.
- The frame's dark palette forced over the app theme.

## Current state

- Notes are local drift rows synced by `NotesRepository`
  (`features/notes/data/repository/notes_repository.dart`). Content is a string
  of Quill-style ops: `decodeNoteOps` in `features/notes/domain/note_blocks.dart`
  accepts a bare list or a map with an `ops` list.
- Tags are local rows linked through `noteTags`. `watchNotes(tagId:)` returns
  the notes carrying a tag. The drawer
  (`features/notes/presentation/widgets/app_drawer.dart`) lists Notes, Archive,
  Trash, and tags, driven by `NoteFolder` and `selectedTagFilterProvider`.
- The list (`notes_list_screen.dart`, `notes_board.dart`) renders masonry, grid,
  or list cards grouped pinned/others/archived.
- The editor (`note_edit_screen.dart`) is `NoteEditorController` +
  `RichTextEditor` + `EditorToolbar` (`editor_toolbar.dart`,
  `editor_toolbar_mode.dart`). New notes take their tag from
  `selectedTagFilterProvider`.
- Date labels already exist in `note_labels.dart` (`shortDayLabel`,
  `editedDayLabel`, `dayTimeLabel`).

## Approaches

**A. Entries are notes tagged `journal`, metadata at the top of the content
(chosen).**
A note is already offline-first, searchable, backed up, and synced. The journal
adds a tag, a metadata block, and two pages. Trades: the metadata lives in the
content as lines, so the journal editor must hide it.

**B. A journal table on the server.**
Clean data model. Rejected: the owner's hard constraint is no server change, and
it would split journaling from the sync the app already has.

**C. A separate local-only store.**
No content parsing. Rejected: journal entries would leave the note list, the
backup, and search, and two stores would need their own conflict rules.

**Layout choice.** The owner picked the **timeline** over the card grid for the
list, and a **calendar** as the second view. Both are layout decisions only.

**Navigation choice.** `NoteFolder.journal` (chosen) keeps the existing drawer,
search, selection, and back behaviour. A standalone route would need its own
drawer and back stack for no gain.

## Decided

1. **An entry is a note with a tag named `journal`.** The name is compared
   case-insensitively. If the tag does not exist, the Journal page is empty and
   the first entry creates the tag.
2. **Metadata is a header block at the top of the note content:**
   ```
   mood: good
   date: 2026-11-17
   time: 09:41
   ---
   <body>
   ```
   - One `key: value` per line; keys are case-insensitive; order is free.
   - `mood` is one of `amazing`, `good`, `neutral`, `rough`.
   - `date` is `YYYY-MM-DD`, `time` is `HH:mm` (24-hour, local wall clock).
   - A line that is exactly `---` ends the block; everything after is the body.
   - No `---` means the whole content is the body (a legacy note).
   - Missing `mood` means no mood. Missing `date` or `time` falls back to the
     note's `updatedAt`.
   - Unknown keys are ignored when reading and kept when rewriting.
3. **The block is one leading insert op,** so the content stays valid Quill ops
   and the normal editor can open it:
   `{"ops":[{"insert":"mood: good\ndate: …\ntime: …\n---\n"}, …bodyOps]}`.
4. **The journal editor hides the header.** It parses the header on open, gives
   the editor only the body, shows a date pill and the mood button, and writes
   the header back on save. If the header cannot be parsed, the note opens
   unchanged.
5. **The mood control is one `EditorTool.mood`**, placed right after
   `EditorTool.add` in the `typing` and `list` modes. Idle icon is a line face
   (`LucideIcons.smile`). A tap opens the four-emoji picker above the toolbar
   (layout reference: Doop frame `d2nuvirfk9`). Choosing sets the tool icon to
   that emoji and writes `mood:`.
6. **Navigation:** a new `NoteFolder.journal`, a "Journal" drawer item under
   Notes, and a `/journal` route that redirects to the folder, like `/archive`
   and `/trash`. Back returns to Notes.
7. **Journal page chrome:** the existing `AppScaffold` with the title "Journal",
   the drawer, a `NotesBottomBar` (search + pencil), and a top action that
   toggles timeline/calendar.
8. **Timeline:** group by entry day (metadata `date`, else `updatedAt.toLocal()`),
   newest day first, newest entry first inside a day. A day header
   (Today / Yesterday / short date) and a row: rail and dot, time, title or first
   body line, mood emoji, and the first picture thumbnail when present.
9. **Calendar:** a month grid; a dot under days with an entry; today and the
   selected day marked; the selected day's entries below the grid; previous and
   next month.
10. **Search:** the journal search matches the title and the body after `---`,
    never the header.
11. **Theme:** follow the app theme through the existing tokens.
12. **Offline-first:** every read and write is local. Sync is the existing note
    sync; nothing new is queued.

## Layout references

- Timeline: Doop frame `jnt2XBFVRD` (`Journal · 1 Timeline`).
- Calendar: Doop frame `Txka4a0QH7` (`Journal · 3 Calendar`).
- Editor: Doop frame `UP1VWzA3Gh` (`Journal · 0 Input / Editor`).
- Mood picker open: Doop frame `d2nuvirfk9` (`Journal · 0b Emoji picker`).

These fix structure and hierarchy only. Implementation uses the live widgets
and tokens named above.

## What is left to the builder

- Where the header split/join lives: inside `NoteEditorController` behind a
  journal flag, or a thin `JournalEditorScreen` around the existing editor.
- Whether the calendar is a full page or a header panel inside the journal list.
- Date and time editing: the first version sets them at creation. Making the
  pill open a date/time picker is a follow-up unless it is cheap.
- l10n keys: one locale, `app_en.arb`. Hand-patch `app_localizations.dart` and
  `app_localizations_en.dart` as before.
- Where the four mood emoji live: a small const map in the journal feature, no
  new asset.

## Known limitations

- Opening a journal note from Notes or its tag page shows the raw header lines.
- A hand-edited or broken header falls back to "no metadata".
- The journal tag is a normal tag: renaming or deleting it stops the Journal
  page from listing those notes.
- The stories strip in the reference frame is out of scope for this version.

## Checks

```
cd mobile && rflutter analyze && rflutter test
```
