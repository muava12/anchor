# Design: Upstream Merge v0.19

## Status

Draft — 2026-11-18

## Context

The fork (`muava12/anchor`) is 113 commits ahead of upstream (`zhfahim/anchor`)
and 6 commits behind. This sync adopts 5 upstream commits that add account
deletion, tag filtering for new notes, web title bar theming, sort by created
date, and editor fixes for long-press selection and Backspace.

## Scope

| Commit | Area | Adopted |
| --- | --- | --- |
| `b4ae4c4` | Auth: delete account (mobile + server + web) | Yes |
| `695b69a` | Mobile: apply active tag filter to new notes | Yes |
| `c8ab5b7` | Web: theme installed app title bar, fit tall pictures | Yes |
| `b230160` | Mobile: sort notes by date created | Yes |
| `16b05b9` | Mobile: fix long-press, margin taps, Backspace at line start | Yes |
| `2e66c80` | Build: bump version to 0.18.1 | Skip — fork is 0.24.3+34 |

## Key Decisions

### D1: Schema version 13 for createdAt

The fork already has schema v12 (attachment compression columns). Upstream
adds `createdAt` in v12. The fork must use v13 to avoid conflict:

```dart
if (from < 13) {
  await migrator.addColumn(notes, notes.createdAt);
  await update(notes).write(NotesCompanion.custom(createdAt: notes.updatedAt));
  await (update(syncState)..where((tbl) => tbl.cursor.isNotNull()))
      .write(const SyncStateCompanion(cursor: Value(null)));
}
```

The `from < 12` block (attachment compression) stays unchanged.

### D2: Keep fork's newNoteTagId → newNoteTagIds migration

Upstream replaces `newNoteTagId` callback with `newNoteTagIds` list. The fork
must keep the journal tag injection (`widget.journal ? journalTagProvider?.id`).

### D3: Editor fix (16b05b9) requires careful merge

This commit touches `note_edit_screen.dart` (114 lines) and
`rich_text_editor.dart` (168 lines). The fork has journal mode, note search,
and other features in these files. The cherry-pick must:

1. Keep fork's journal mode imports and widgets.
2. Keep fork's note search imports and widgets.
3. Add upstream's `titlePadding` refactor.
4. Add upstream's `handleBackspaceAtLineStart` in editor_format.
5. Add upstream's `_onLongPressStart` / `_onLongPressMove` in rich_text_editor.
6. Update `showsCaret` helper to use `RenderEditableTextLine`.

### D4: Sync createdAt only for new notes

`createdAt` is sent to server only when `baseVersion == null` (new note):

```dart
if (baseVersion == null && createdAt != null)
  'createdAt': createdAt!.toUtc().toIso8601String(),
```

### D5: Version stays 0.24.3+34

Fork version is already higher than upstream 0.18.1. Do not downgrade.

## Risks

1. **Schema migration**: The `from < 13` migration must not conflict with
   the existing `from < 12` attachment compression migration.
2. **Editor merge**: The fork's journal and search features must survive
   the editor fix cherry-pick.
3. **Test compatibility**: Upstream tests reference `RenderEditableTextLine`
   and `document_lines.dart` which must exist in the fork.
4. **pubspec.yaml**: The fork has extra dependencies (`image`, `archive`,
   `cryptography`) that must not be removed.

## ADR Impact

- **ADR 0002** (upstream sync scope): This sync follows the same pattern.
  No new ADR needed.
- **ADR 0001** (visual check size): No impact — editor fix does not change
  checkbox sizing.