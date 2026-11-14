# Task 2 report — Backup reader

Status: DONE_WITH_CONCERNS (code written exactly as the brief; tests not run here)

## Files created

- `mobile/lib/features/backup/data/backup_reader.dart` — `BackupFormatException`, `BackupReader`
- `mobile/test/backup/backup_reader_test.dart` — 4 tests from the brief

Both files are the brief's code blocks, copied verbatim (including the leading
path comment lines `// lib/features/backup/data/backup_reader.dart` and
`// test/backup/backup_reader_test.dart`).

## What I could not do

- Step 2 (failing test run) and Step 4 (passing test run): not run. This host has
  no Flutter/Dart toolchain, and the brief's rules forbid running or installing one.
  The controller runs them on the remote host.
- Step 5 (commit): not done, as instructed.

## Checks I could do without a toolchain

- `BackupManifest.currentFormat == 1` exists; `BackupManifest.fromJson` reads
  `format`, `app`, `appVersion`, `createdAt`, `notes`, `attachments` — matches the
  JSON the test writes.
- `BackupContents.fromJson` needs `tags` and `notes` lists; `BackupNote` requires
  exactly the keys the test writes (`id`, `title`, `content`, `isPinned`,
  `isArchived`, `background`, `state`, `updatedAt`, `version`, `reminderAt`,
  `reminderRecurrence`, `tagIds`, `attachments`).
- `BackupWriter(path)` with `addJson` and `close` exists; `archive: ^4.5.2` is a
  direct dependency in `mobile/pubspec.yaml` (line 75).
- `git status`: only the two new files plus a pre-existing modification to
  `.superpowers/sdd/progress.md` (not touched by me).

## Doubts

1. `ArchiveFile.content` in archive 4.5.2: the brief casts it to `List<int>`
   (`file.content as List<int>`). If the resolved 4.5.2 build stores the entry as
   an `InputStream` after `ZipDecoder().decodeBytes`, the cast throws and every
   test fails. No package source is on this host, so I could not confirm the
   getter's return type. If the tests fail on a cast error, use
   `file.readBytes()!` or `Uint8List.fromList(file.content as List<int>)`.
2. `Archive.findFile(name)` is assumed to exist in 4.5.2 (brief's API). If it does
   not, `_archive.files` plus a name lookup is the fallback.
3. The two test lines written as
   `await writer.addJson('notes.json', {'tags': <Object>[], 'notes': <Object>[]});`
   exceed 80 columns, so `dart format --set-exit-if-changed` in CI would reformat
   them. They are verbatim from the brief, so I did not reflow them.
4. `BackupReader` decodes in the constructor initializer (`_decode`), so the
   `late final` fields are assigned in the body. `_decode` is a `static` method,
   which is required because an instance member cannot run before the initializer
   list completes — the brief already has this right.
