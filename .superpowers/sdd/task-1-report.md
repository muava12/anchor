# Task 1 Report: Backup file model and writer

## Files created

- `mobile/lib/features/backup/domain/backup_manifest.dart` — `BackupManifest` with `currentFormat = 1`, `toJson`/`fromJson` (verbatim from brief).
- `mobile/lib/features/backup/domain/backup_contents.dart` — `BackupTag`, `BackupAttachment`, `BackupNote`, `BackupContents` with `toJson`/`fromJson` (verbatim from brief).
- `mobile/lib/features/backup/data/backup_writer.dart` — `BackupWriter` using `ZipFileEncoder` from `package:archive/archive_io.dart` (verbatim from brief).
- `mobile/test/backup/backup_writer_test.dart` — the 3-test spec (verbatim from brief).

## File modified

- `mobile/pubspec.yaml` — added `archive: ^4.5.2` under `dependencies:` in a new `# Backup` section, after `# Media` (`gal: ^2.3.3`). No other lines touched.

## Things not done, and why

- Did not run steps 2 and 6 (`flutter test` / `flutter pub get`): host has no Flutter toolchain and the task instructions forbid running flutter/dart here. Controller runs tests on the remote host.
- Did not run step 7 (commit): task instructions say the controller commits after tests pass.
- `mobile/pubspec.lock` was not regenerated, so it does not yet contain `archive` — the lock updates when the remote host runs `flutter pub get`. The brief's commit step stages `mobile/pubspec.lock`; the controller must have run pub get before committing, or the lock will be stale at commit time.

## Concerns / doubts

1. **`pubspec.lock` stale at commit time** — if the controller commits exactly as the brief's step 7 states, `pubspec.lock` will lack `archive` unless `pub get` ran first.
2. **API surface of `package:archive`** — the brief's code assumes `ZipFileEncoder.create(path)`, `addArchiveFile(ArchiveFile(...))`, `addFile(source, name)`, and `ArchiveFile(name, length, bytes)` constructor signatures for `archive: ^4.5.2` / `archive_io`. I could not verify these compile without a toolchain. `addFile(File, String)` in some archive versions streams the file; `addArchiveFile` with a pre-built `ArchiveFile` was added around 3.x and should exist in 4.5.2, but this is unverified.
3. **Test assertion on file content** — `expect(archive.findFile('attachments/a1.jpg')!.content, [1, 2, 3, 4])`: archive's `ZipDecoder` stores `content` as `List<int>`; the equality check against a `List` literal relies on list equality, which `flutter_test`'s `equals` handles. Low risk, noted for completeness.
4. Placed `archive` under a new `# Backup` comment group in pubspec.yaml; the brief only said "next to the other entries". Position is cosmetic.
