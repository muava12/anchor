# Task 9 report — Automatic backup when the app opens

Status: DONE

## Files created

- `mobile/lib/features/backup/data/auto_backup.dart`
- `mobile/test/backup/auto_backup_test.dart`

Both files are byte-for-byte the code in `.superpowers/sdd/task-9-brief.md`
(Steps 1 and 3). Nothing else was touched: `git status --short` shows only
these two new untracked files.

## Verification performed here

- Read `lib/features/backup/domain/backup_settings.dart`: `const BackupSettings({this.folderUri, this.automatic = true, this.periodDays = 7, ... this.lastBackupAt})` and `bool get hasFolder` exist as the brief assumes. `periodDays` default 7 matches the tests.
- Read `lib/features/backup/presentation/backup_controller.dart`: `enum BackupOutcome { done, noFolder, failed }` and `class BackupResult { const BackupResult(this.outcome, {this.fileName, this.error}); }` match the brief's `const BackupResult(BackupOutcome.done)`.
- `lib/features/backup/presentation/backup_controller.g.dart` is present, so importing the controller in the test resolves.
- `mobile/pubspec.yaml` has `name: anchor`, so the `package:anchor/...` imports are correct.
- `analysis_options.yaml` includes `package:flutter_lints/flutter.yaml`; no rule bans the file-header comment the brief keeps.

Not verified: Step 2 (fail) and Step 4 (pass). This host has no Flutter toolchain and the rules forbid installing it. Both steps must run on the remote test host.

## Brief items not followed

None. Step 5 (commit) was intentionally skipped: the controller commits after the tests pass.

## Doubts

- `BackupController._run` stamps the file name with `DateTime.now()` and calls `markBackedUp(DateTime.now())`, while `AutoBackup` compares with its injected `now`. The two clocks are unrelated. In production that is fine (real clock on both sides), but it means `AutoBackup` alone cannot be exercised against the controller's own time source. No test in the brief needs it.
- `AutoBackup.maybeRun` returns `true` even when `run()` yields `BackupResult(BackupOutcome.failed)`. The brief defines "returns true when it ran", so this is per spec, but a caller that shows a "backup done" toast on `true` would be wrong. No caller exists yet in this task.
- The `now` parameter is only compared to `lastBackupAt`. If the device clock moves backwards, `difference` is negative and the backup is skipped until the clock catches up. Per spec; noting it as an edge case only.
