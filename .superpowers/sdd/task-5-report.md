# Task 5 report — restore into the database

Status: DONE_WITH_CONCERNS (one deviation: one extra import added to the brief's test file; see below).

## Files created

- `mobile/lib/features/backup/domain/restore_mode.dart`
- `mobile/lib/features/backup/data/backup_restorer.dart`
- `mobile/test/backup/backup_restorer_test.dart`

Nothing outside `mobile/lib/features/backup` and `mobile/test/backup` was touched. No commit made.
No `flutter` or `dart` command was run (this host has no Flutter toolchain).

## What the brief says, and what I did

Both library files are copied verbatim from the brief, character for character, including the
comment wording and the indentation of the `version:` argument spread over three lines.

The test file is copied verbatim, with **one added import**:

```dart
import 'package:anchor/features/notes/data/local/note_rows.dart';
```

Reason: the brief's first test calls `target.noteRow('n1')`. `noteRow` lives in the `NoteRows`
extension on `AppDatabase`, declared in `lib/features/notes/data/local/note_rows.dart`. The brief's
test imports do not include that file, so without the import the test fails to compile with
`The method 'noteRow' isn't defined for the type 'AppDatabase'` — that is a second, unrelated
failure in addition to the intended `Target of URI doesn't exist`. Every other line of the test,
including the import order, is unchanged. No file outside the allowed paths was modified to make
this work.

## Checks I ran on the code (static reading only, no compile)

- `drift: ^2.35.3`, `path: ^1.9.1`, `uuid: ^4.6.0` are already dependencies in `mobile/pubspec.yaml`.
- `NotesCompanion.insert` accepts every named argument used: `content`, `isPinned`, `isArchived`,
  `background`, `state`, `updatedAt` (`Value<DateTime?>`), `version` (`Value<int?>`), `reminderAt`,
  `reminderRecurrence`, `isSynced`, `localRev`.
- `NoteAttachmentsCompanion.insert` accepts `position`, `localPath`, `syncStatus`. `localPath` is
  `Value<String?>`, so `Value(target.path)` (non-nullable `String`) is assignable.
- `TagsCompanion.insert` requires `id` and `name`; `color` and `isSynced` are optional. `Value(tag.color)`
  is `Value<String?>` against `Value<String?>` — fine.
- `NoteTagsCompanion.insert(noteId:, tagId:)` — both required and final in the table, so both are
  required in `insert`. Fine.
- `fileSize` and `position` are non-nullable in `BackupAttachment`, matching `int` columns.
- `BackupAttachment.originalFilename` is non-null, so `path.basename(attachment.originalFilename)` needs
  no null guard.
- `BackupExporter` names attachment entries `attachments/<attachmentId><ext>`, so `reader.fileBytes(
  attachment.file)` resolves. The restorer writes to `<root>/<noteId>/<attachmentId>-<basename>`, which
  is a different layout on purpose (the brief's behaviour), and `localPath` holds that absolute path.
- `AppDatabase.delete(table)` and `AppDatabase.transaction(...)` are both Drift base-class members, so
  the `_db.transaction` / `_db.delete(_db.tags)` calls match the exporter's style.
- `directives_ordering` and `prefer_relative_imports` (mobile/analysis_options.yaml): library imports
  are relative and ordered; the test keeps `package:` imports like the sibling backup tests. The added
  import is in alphabetical position, so the ordering lint stays clean.
- `prefer_const_constructors` (flutter_lints): the two `Directory(...)` calls in the restorer get a
  non-const argument (`path.join(...)`), and `NotesCompanion.insert(...)` is not const, so no lint
  should fire.

## Doubts

1. **`newIds` mode and tags.** The restorer maps tag ids through `tagIdMap` for both modes, but never
   writes `version` to the tag row (`TagsCompanion.insert` gets no `version`), so even in `keepIds`
   mode the server version of every tag is dropped. The brief's code is what it is; I did not change
   it. If tag versions must survive a same-account restore, that is a Task 6 change — `BackupTag` does
   not even carry a version today, and this task may not edit `backup_contents.dart`.
2. **Restore is not atomic with the filesystem.** The database writes run in one transaction, but the
   attachment files are written inside it. A failure after some file writes leaves orphan files in the
   attachments folder, and a rollback leaves already-written files behind. The brief does not ask for
   cleanup; noting it because "replaces what was there" reads like an all-or-nothing promise.
3. **Old files are not deleted.** `restore replaces what was there` deletes the rows, not the files of
   the previous attachments. Old files under `<root>/<noteId>/` remain on disk. Again outside the
   brief's code.
4. **Duplicate tag per note.** If `note.tagIds` ever contains the same id twice, the `noteTags` insert
   throws a primary-key error and rolls back the whole restore. Not reachable from a backup written by
   `BackupExporter` (it lists each `noteTags` row once), so I left it.
5. **`version: Value(mode == keepIds ? note.version : null)`** — in `newIds` mode this writes an
   explicit `NULL`, not `absent`. The brief's second test asserts `isNull`, which passes either way, and
   `BACKUP` rows always supply a value when they come from the exporter, so the distinction is moot.
6. Not verified by execution: expected result is `PASS, 4 tests` on the remote host. If the first test
   still fails to compile there, check that the added `note_rows.dart` import is present; that is the
   only line I added to the brief's test.
