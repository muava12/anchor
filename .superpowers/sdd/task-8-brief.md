### Task 8: The backup job

**Files:**
- Create: `lib/features/backup/presentation/backup_controller.dart`
- Test: `test/backup/backup_controller_test.dart`

**Interfaces:**
- Consumes: `BackupExporter` (Task 4), `BackupCipher` (Task 3), `BackupFolder` (Task 6), `BackupSettingsController` (Task 7), `AppDatabase`.
- Produces:
  - `enum BackupOutcome { done, noFolder, failed }`
  - `class BackupResult { final BackupOutcome outcome; final String? fileName; final String? error; }`
  - `@Riverpod(keepAlive: true) class BackupController extends _$BackupController { bool build(); Future<BackupResult> run({required bool automatic}); }` — state is `true` while a backup runs.

- [ ] **Step 1: Write the failing test**

```dart
// test/backup/backup_controller_test.dart
import 'dart:io';

import 'package:anchor/core/database/app_database.dart';
import 'package:anchor/features/backup/data/backup_folder.dart';
import 'package:anchor/features/backup/presentation/backup_controller.dart';
import 'package:anchor/features/backup/presentation/backup_settings_controller.dart';
import 'package:anchor/features/backup/domain/backup_settings.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockBackupFolder extends Mock implements BackupFolder {}

class FakeSettings extends BackupSettingsController {
  FakeSettings(this.initial);

  final BackupSettings initial;

  @override
  Future<BackupSettings> build() async => initial;

  @override
  Future<void> markBackedUp(DateTime at) async {}
}

void main() {
  late AppDatabase db;
  late MockBackupFolder folder;
  late Directory root;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    folder = MockBackupFolder();
    root = Directory.systemTemp.createTempSync('backup_job');
  });

  tearDown(() async {
    await db.close();
    root.deleteSync(recursive: true);
  });

  ProviderContainer containerWith(BackupSettings settings) {
    return ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        backupFolderProvider.overrideWithValue(folder),
        backupSettingsControllerProvider.overrideWith(
          () => FakeSettings(settings),
        ),
      ],
    );
  }

  test('a backup with no folder chosen says so', () async {
    final container = containerWith(const BackupSettings());
    final result = await container
        .read(backupControllerProvider.notifier)
        .run(automatic: false);

    expect(result.outcome, BackupOutcome.noFolder);
    verifyNever(
      () => folder.write(any(), any(), any()),
    );
  });

  test('a backup writes one file and marks the time', () async {
    when(
      () => folder.write(any(), any(), any()),
    ).thenAnswer((_) async {});
    when(() => folder.list(any())).thenAnswer((_) async => <String>[]);

    final container = containerWith(
      const BackupSettings(folderUri: 'content://tree/backups'),
    );
    final result = await container
        .read(backupControllerProvider.notifier)
        .run(automatic: false);

    expect(result.outcome, BackupOutcome.done);
    expect(result.fileName, startsWith('anchor-'));
    verify(() => folder.write('content://tree/backups', any(), any())).called(1);
  });

  test('a write that throws is reported, not swallowed', () async {
    when(
      () => folder.write(any(), any(), any()),
    ).thenThrow(Exception('disk full'));

    final container = containerWith(
      const BackupSettings(folderUri: 'content://tree/backups'),
    );
    final result = await container
        .read(backupControllerProvider.notifier)
        .run(automatic: false);

    expect(result.outcome, BackupOutcome.failed);
    expect(result.error, contains('disk full'));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/backup/backup_controller_test.dart`
Expected: FAIL — `Target of URI doesn't exist`

- [ ] **Step 3: Write the controller**

```dart
// lib/features/backup/presentation/backup_controller.dart
import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/app_database.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/logging/log_tags.dart';
import '../data/backup_cipher.dart';
import '../data/backup_exporter.dart';
import '../data/backup_folder.dart';
import 'backup_settings_controller.dart';

part 'backup_controller.g.dart';

enum BackupOutcome { done, noFolder, failed }

class BackupResult {
  const BackupResult(this.outcome, {this.fileName, this.error});

  final BackupOutcome outcome;
  final String? fileName;
  final String? error;
}

@Riverpod(keepAlive: true)
BackupFolder backupFolder(Ref ref) => BackupFolder();

/// True while a backup runs. Kept alive so leaving Settings does not stop it.
@Riverpod(keepAlive: true)
class BackupController extends _$BackupController {
  @override
  bool build() => false;

  Future<BackupResult> run({required bool automatic}) async {
    if (state) return const BackupResult(BackupOutcome.failed, error: 'busy');
    state = true;
    try {
      return await _run(automatic: automatic);
    } finally {
      state = false;
    }
  }

  Future<BackupResult> _run({required bool automatic}) async {
    final settings = await ref.read(backupSettingsControllerProvider.future);
    if (!settings.hasFolder) {
      return const BackupResult(BackupOutcome.noFolder);
    }

    final folder = ref.read(backupFolderProvider);
    final documents = await getApplicationDocumentsDirectory();
    final attachmentsRoot = Directory(
      path.join(documents.path, 'attachments'),
    );
    final temp = await getTemporaryDirectory();
    final stamp = _stamp(DateTime.now());
    final prefix = automatic ? 'anchor-auto-' : 'anchor-';
    final fileName = '$prefix$stamp.zip';
    final zipPath = path.join(temp.path, fileName);

    try {
      final info = await PackageInfo.fromPlatform();
      final manifest = await BackupExporter(
        ref.read(appDatabaseProvider),
        attachmentsRoot,
      ).write(zipPath, appVersion: info.version);

      var bytes = await File(zipPath).readAsBytes();
      final password = settings.password;
      if (password != null && password.isNotEmpty) {
        bytes = await BackupCipher.encrypt(bytes, password);
      }

      await folder.write(settings.folderUri!, fileName, bytes);
      await ref
          .read(backupSettingsControllerProvider.notifier)
          .markBackedUp(DateTime.now());

      if (automatic) await _applyRetention(folder, settings.folderUri!, settings.keepFiles);

      AppLogger.instance.info(
        LogTags.backup,
        'Backup wrote $fileName with ${manifest.notes} notes',
      );
      return BackupResult(BackupOutcome.done, fileName: fileName);
    } catch (error, stack) {
      AppLogger.instance.error(
        LogTags.backup,
        'Backup failed',
        error: error,
        stackTrace: stack,
      );
      return BackupResult(BackupOutcome.failed, error: '$error');
    } finally {
      final leftover = File(zipPath);
      if (leftover.existsSync()) leftover.deleteSync();
    }
  }

  /// Only files this app wrote automatically are counted, so a manual backup is
  /// never deleted.
  Future<void> _applyRetention(
    BackupFolder folder,
    String folderUri,
    int keepFiles,
  ) async {
    final names =
        (await folder.list(folderUri))
            .where((name) => name.startsWith('anchor-auto-'))
            .toList()
          ..sort();
    final excess = names.length - keepFiles;
    if (excess <= 0) return;
    for (final name in names.take(excess)) {
      await folder.delete(folderUri, name);
    }
  }

  String _stamp(DateTime at) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${at.year}-${two(at.month)}-${two(at.day)}'
        '_${two(at.hour)}${two(at.minute)}${two(at.second)}';
  }
}
```

- [ ] **Step 4: Add the log tag**

In `lib/core/logging/log_tags.dart`, add `static const backup = 'Backup';` next to the other tags.

- [ ] **Step 5: Generate the riverpod code**

Run: `cd mobile && dart run build_runner build --delete-conflicting-outputs`
Expected: `Succeeded after ...`

- [ ] **Step 6: Run the test to verify it passes**

Run: `cd mobile && flutter test test/backup/backup_controller_test.dart`
Expected: PASS, 3 tests.

- [ ] **Step 7: Commit**

```bash
git add mobile/lib/core/logging mobile/lib/features/backup mobile/test/backup
git commit -m "feat: run a backup as a job that outlives the settings page"
```

---

