# Task 4 report — Export the database into a backup

Status: DONE_WITH_CONCERNS

## Files created

- `mobile/lib/features/backup/data/backup_exporter.dart`
- `mobile/test/backup/backup_exporter_test.dart`

Both written verbatim from the brief (Task 4, Steps 1 and 3). No file outside
`mobile/lib/features/backup` and `mobile/test/backup` was touched.
`git status --short` shows only these two new files.

## Checks I could run

No Flutter/Dart toolchain on this host, so I did not run `flutter test` or
`flutter analyze` (brief Steps 2 and 4). Instead I verified every symbol the
brief's code uses against the committed sources:

- `AttachmentRow` is the `@DataClassName` in `lib/features/notes/data/local/attachments_table.dart` ✓ (generated class at `app_database.g.dart:2568`).
- Getters `db.tags`, `db.notes`, `db.noteTags`, `db.noteAttachments` exist
  (`app_database.g.dart:4385-4386` and neighbours) ✓.
- Companion insert argument lists match the test calls:
  - `TagsCompanion.insert` requires `id`, `name` ✓.
  - `NotesCompanion.insert` requires `id`, `title`; `content`, `isPinned`,
    `version` are `Value.absent()` by default and accept `const Value(...)` ✓
    (`app_database.g.dart:1249-1261`).
  - `NoteTagsCompanion.insert` requires `noteId`, `tagId` ✓.
  - `NoteAttachmentsCompanion.insert` requires `id`, `noteId`, `type`,
    `originalFilename`, `mimeType`, `fileSize`; `position`, `localPath` are
    optional ✓.
- `AppDatabase.forTesting(super.e)` takes a `QueryExecutor`, and
  `NativeDatabase.memory()` is one ✓.
- `BackupNote`, `BackupTag`, `BackupAttachment`, `BackupContents`,
  `BackupManifest` constructor parameter names and types match the exporter
  call sites one for one ✓.
- `BackupWriter(path)`, `addJson(name, json)`, `addFile(File, name)`, `close()`
  match `lib/features/backup/data/backup_writer.dart` ✓.
- `BackupReader(bytes)`, `.manifest`, `.contents`, `.fileBytes(name)` match
  `lib/features/backup/data/backup_reader.dart` ✓.
- `package:path/path.dart` is already a dependency (`pubspec.yaml:92`) ✓.
- Brace/paren/bracket balance is zero on both files.
- `directives_ordering` and `prefer_relative_imports` (repo lints) are satisfied
  by the import block as written.

## What I could not follow, and why

Nothing in the brief was skipped or redesigned. One cosmetic deviation: the
brief's line

```dart
final name = 'attachments/${attachment.id}${path.extension(source.path)}';
```

is 84 characters, over the 80-column `dart format` width. I let it wrap the way
`dart format` would:

```dart
final name =
    'attachments/${attachment.id}${path.extension(source.path)}';
```

Semantics are identical. If the controller wants the literal one-line form,
run `dart format` and it will converge here.

## Concerns

1. `_attachmentsRoot` is stored but never read. `main()` in
   `note_attachments_repository.dart` writes an absolute path into
   `note_attachments.localPath` (e.g. line 645, `path.join(root.path,
   'attachments', noteId)`), so `_sourceOf` only needs `row.localPath` and the
   root parameter is dead data. The Dart analyzer will emit an `unused_field`
   warning on `_attachmentsRoot`. `flutter test` still passes; `flutter analyze`
   will not be clean. I kept the brief's code as written rather than dropping a
   constructor parameter that later tasks (restore/import) may need.
2. The exporter exports **every** note row, including `state == 'trashed'` and
   `'deleted'`, and every tag row including `isDeleted == true`. The brief's
   code has no filter and no test covers it, so I did not add one. If the
   restore task expects only live rows, that must be decided in that task.
3. Attachments are matched to notes by a nested scan over the full attachment
   list (`attachments.where(...)` inside the note loop). That is O(notes ×
   attachments). Correct, and fine for a phone-sized library, but it is a
   quadratic pattern if the library grows large.
4. `BackupWriter.addFile` reads each file fully into memory. A large photo is
   fine; a long audio attachment is bounded by the largest single file, which
   matches the writer's documented contract. Not a defect, just the limit in
   force.
5. Zip entry names use the attachment **id** plus the extension of the local
   path (`attachments/<id>.jpg`). If two rows for the same note somehow shared
   an id — the table primary key is `id`, so they cannot — the entry would
   collide. No action needed.
6. Untested here: Steps 2 and 4 (`flutter test test/backup/backup_exporter_test.dart`)
   and Step 5 (commit). The controller owns all three per the task rules.
