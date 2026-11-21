# Implementation Plan: Upstream Merge v0.19

## Overview

Cherry-pick 5 upstream commits into the fork, resolve conflicts, and ensure
all tests pass. Work in a dedicated worktree.

## Preconditions

- Fork `main` at `eb0bfe6` (2026-11-18).
- Upstream `main` at `2e66c80`.
- Worktree at `../anchorx-merge-v0.19` branched from `fork/main`.

## Step 1: Create worktree

```sh
cd /home/mimin/projects/anchorx
git fetch origin
git fetch fork
git worktree add ../anchorx-merge-v0.19 -b upstream-merge-v0.19 fork/main
cd ../anchorx-merge-v0.19
```

## Step 2: Cherry-pick commits (in order)

### 2a: b4ae4c4 — Delete account

```sh
git cherry-pick b4ae4c4
```

Expected conflicts: `mobile/lib/core/database/app_database.dart`

Resolution:
- Keep fork's `_closing` pattern (upstream adds it).
- Keep fork's `schemaVersion => 12` → change to `13`.
- Keep fork's `from < 12` block (attachment compression).
- Add upstream's `deleteUserDatabaseFiles` function.
- Add upstream's `_userDatabasePath` helper.

### 2b: 695b69a — Tag filter for new notes

```sh
git cherry-pick 695b69a
```

Expected conflicts: `note_editor_controller.dart`, `note_edit_screen.dart`

Resolution:
- Replace `newNoteTagId` with `newNoteTagIds` list.
- Keep fork's journal tag logic:
  `widget.journal ? journalTagProvider?.id : selectedTagFilterProvider`
- Keep fork's `codec` parameter (upstream removes it; fork needs it).

### 2c: c8ab5b7 — Web title bar

```sh
git cherry-pick c8ab5b7
```

Expected conflicts: none (web only).

### 2d: b230160 — Sort by created date

```sh
git cherry-pick b230160
```

Expected conflicts:
- `app_database.dart`: schema v12 → v13 migration.
- `app_database.g.dart`: regenerate with `dart run build_runner build`.
- `notes_table.dart`: add `createdAt` column.
- `note.dart`: add `createdAt` field.
- `notes_view_options.dart`: add `dateCreated` sort option.
- `sync_service.dart`: rename `_sharingOf` → `_alwaysAppliedOf`.
- `sync_changes.dart`: add `createdAt` to `SyncNoteChange`.
- Tests: update migration tests for v13.

### 2e: 16b05b9 — Editor fix

```sh
git cherry-pick 16b05b9
```

Expected conflicts:
- `note_edit_screen.dart`: merge title padding refactor with fork's journal/search.
- `rich_text_editor.dart`: merge backspace-at-start, long-press handlers.
- `editor_format.dart`: add `lineAttributesChange`, `handleBackspaceAtLineStart`.
- Tests: update `showsCaret`, add `document_lines.dart` import.

## Step 3: Resolve remaining conflicts

After each cherry-pick:
1. `git status` to see conflicts.
2. Edit conflicted files.
3. `git add` resolved files.
4. `git cherry-pick --continue`.

## Step 4: Regenerate code

```sh
cd mobile
dart run build_runner build --delete-conflicting-outputs
```

This regenerates:
- `app_database.g.dart`
- `note.freezed.dart`
- `auth_controller.g.dart`
- `app_router.g.dart`

## Step 5: Fix pubspec.yaml

Remove the accidental `flutter_cache_manager` addition (from merge artifacts).
Keep fork's dependencies intact.

## Step 6: Run checks

```sh
cd mobile && flutter analyze && flutter test
cd ../server && pnpm check && pnpm test
cd ../web && pnpm check && pnpm test
```

## Step 7: Create PR

```sh
git push fork upstream-merge-v0.19
gh pr create --repo muava12/anchor --base main --head upstream-merge-v0.19 \
  --title "Upstream merge v0.19" \
  --body "Cherry-pick 5 upstream commits: delete account, tag filter, web title bar, sort by created date, editor fix."
```

## Rollback

If anything goes wrong:
```sh
git cherry-pick --abort
# or
git reset --hard fork/main
```

## Checklist

- [ ] Worktree created
- [ ] b4ae4c4 cherry-picked
- [ ] 695b69a cherry-picked
- [ ] c8ab5b7 cherry-picked
- [ ] b230160 cherry-picked
- [ ] 16b05b9 cherry-picked
- [ ] `build_runner` run
- [ ] `flutter analyze` passes
- [ ] `flutter test` passes
- [ ] Server checks pass
- [ ] Web checks pass
- [ ] PR created