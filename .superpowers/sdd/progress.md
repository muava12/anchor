# Local backup — progress ledger

Plan: docs/superpowers/plans/2026-11-14-local-backup.md
Branch: feat/local-backup
Base: 5414c19

Note: this host has no Flutter. Tests are run on box-03 over SSH:
  tar czf /tmp/sync.tgz -C mobile lib test pubspec.yaml
  scp to box-03:/data/workspace/anchor-dev/
  flutter analyze && flutter test

Task 1: complete (commits 5414c19..9b86a2e, tests pass on box-03)
  - archive 4.5.2 addFile drops the entry; writer uses addArchiveFile with bytes.
Task 2: complete (tests pass on box-03)
  - Formatting: run `dart format` on box-03 once at the end for all backup files.
Task 3: complete (5 tests pass on box-03)
  - cryptography resolves to 2.9.0; pubspec.lock updated from box-03.
  - decrypt now refuses a truncated file with BackupFormatException.
Task 4: complete (14 backup tests pass, analyze clean on box-03)
  - _attachmentsRoot now resolves a relative localPath, so the field is used.
Task 5: complete (20 backup tests pass on box-03)
  - BackupTag gained version; keepIds keeps tag versions, newIds clears them.
  - Restore deletes replaced attachment files after commit, and written files on rollback.
  - Duplicate tag ids per note are de-duplicated.
Task 6: complete (4 tests pass on box-03)
  - Added androidx.documentfile:1.0.1 to android/app/build.gradle.kts.
  - Dart wrapper sends Uint8List so Kotlin receives a byte array.
  - Kotlin compile NOT verified: box-03 has no Android SDK. CI will verify.
Task 7: complete (3 tests pass on box-03; riverpod .g.dart generated on box-03 and copied back)
  - copyWith gained clearFolder, so setFolder(null) clears the in-memory state too.
Task 8: complete (4 tests pass on box-03; backup_controller.g.dart generated and copied back)
  - Test mocks path_provider and PackageInfo; added a retention test.
  - bytes is List<int> so the encrypted path compiles.
