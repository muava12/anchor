### Task 9: Automatic backup when the app opens

**Files:**
- Create: `lib/features/backup/data/auto_backup.dart`
- Test: `test/backup/auto_backup_test.dart`

**Interfaces:**
- Consumes: `BackupController` (Task 8), `BackupSettings` (Task 7).
- Produces:
  - `class AutoBackup { AutoBackup(this.run, this.now); final Future<BackupResult> Function() run; final DateTime Function() now; Future<bool> maybeRun(BackupSettings settings); }` — returns true when it ran.

- [ ] **Step 1: Write the failing test**

```dart
// test/backup/auto_backup_test.dart
import 'package:anchor/features/backup/data/auto_backup.dart';
import 'package:anchor/features/backup/domain/backup_settings.dart';
import 'package:anchor/features/backup/presentation/backup_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 11, 14, 12);

  test('runs when there has never been a backup', () async {
    var ran = 0;
    final auto = AutoBackup(() async {
      ran++;
      return const BackupResult(BackupOutcome.done);
    }, () => now);

    expect(
      await auto.maybeRun(
        const BackupSettings(folderUri: 'content://tree/backups'),
      ),
      isTrue,
    );
    expect(ran, 1);
  });

  test('does not run before the period is up', () async {
    var ran = 0;
    final auto = AutoBackup(() async {
      ran++;
      return const BackupResult(BackupOutcome.done);
    }, () => now);

    final settings = BackupSettings(
      folderUri: 'content://tree/backups',
      periodDays: 7,
      lastBackupAt: now.subtract(const Duration(days: 3)),
    );
    expect(await auto.maybeRun(settings), isFalse);
    expect(ran, 0);
  });

  test('runs once the period is up', () async {
    var ran = 0;
    final auto = AutoBackup(() async {
      ran++;
      return const BackupResult(BackupOutcome.done);
    }, () => now);

    final settings = BackupSettings(
      folderUri: 'content://tree/backups',
      periodDays: 7,
      lastBackupAt: now.subtract(const Duration(days: 8)),
    );
    expect(await auto.maybeRun(settings), isTrue);
    expect(ran, 1);
  });

  test('does nothing when automatic backup is off', () async {
    var ran = 0;
    final auto = AutoBackup(() async {
      ran++;
      return const BackupResult(BackupOutcome.done);
    }, () => now);

    expect(
      await auto.maybeRun(
        const BackupSettings(
          folderUri: 'content://tree/backups',
          automatic: false,
        ),
      ),
      isFalse,
    );
    expect(ran, 0);
  });

  test('does nothing when no folder is chosen', () async {
    var ran = 0;
    final auto = AutoBackup(() async {
      ran++;
      return const BackupResult(BackupOutcome.done);
    }, () => now);

    expect(await auto.maybeRun(const BackupSettings()), isFalse);
    expect(ran, 0);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/backup/auto_backup_test.dart`
Expected: FAIL — `Target of URI doesn't exist`

- [ ] **Step 3: Write the rule**

```dart
// lib/features/backup/data/auto_backup.dart
import '../domain/backup_settings.dart';
import '../presentation/backup_controller.dart';

/// Decides whether an automatic backup is due. It runs when the app opens
/// rather than on a schedule, so no background service is needed.
class AutoBackup {
  const AutoBackup(this.run, this.now);

  final Future<BackupResult> Function() run;
  final DateTime Function() now;

  Future<bool> maybeRun(BackupSettings settings) async {
    if (!settings.automatic || !settings.hasFolder) return false;

    final last = settings.lastBackupAt;
    if (last != null &&
        now().difference(last) < Duration(days: settings.periodDays)) {
      return false;
    }

    await run();
    return true;
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd mobile && flutter test test/backup/auto_backup_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/features/backup/data/auto_backup.dart mobile/test/backup/auto_backup_test.dart
git commit -m "feat: back up on app open when the period is up"
```

---

