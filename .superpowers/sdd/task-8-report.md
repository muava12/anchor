# Task 8 report — the backup job

Status: DONE_WITH_CONCERNS

## Files created / changed

- Created `mobile/lib/features/backup/presentation/backup_controller.dart` — verbatim from the brief.
- Created `mobile/test/backup/backup_controller_test.dart` — verbatim from the brief.
- Changed `mobile/lib/core/logging/log_tags.dart` — added `static const backup = 'Backup';` after `settings`.

Not created by me (generated on the remote host by the controller):
`mobile/lib/features/backup/presentation/backup_controller.g.dart` — step 5 of the brief.

No file outside `mobile/lib/features/backup`, `mobile/test/backup`,
`mobile/lib/core/logging` was touched. Nothing committed. No `flutter`, `dart`
or `build_runner` ran (no Flutter toolchain on this host).

## Brief steps

| Step | State |
| --- | --- |
| 1 write failing test | done |
| 2 run test (expect fail) | NOT run — no Flutter toolchain |
| 3 write controller | done |
| 4 add log tag | done |
| 5 `build_runner` | NOT run — controller runs it remotely |
| 6 run test (expect PASS 3) | NOT run |
| 7 commit | NOT run — controller commits |

## Interfaces checked against committed code

Verified by reading, not by compiling:

- `BackupExporter(db, attachmentsRoot).write(path, appVersion:)` returns
  `BackupManifest` with an int `notes` field — the log line uses it.
- `BackupCipher.encrypt(List<int>, String)` returns `Future<List<int>>`.
- `BackupFolder.write(folderUri, name, List<int>)`, `.list()`, `.delete()` match.
- `BackupSettings.hasFolder`, `folderUri`, `password`, `keepFiles` exist.
- `AppLogger.instance.info(tag, message)` and `.error(tag, message, error:, stackTrace:)` match.
- `AppDatabase.forTesting(NativeDatabase.memory())` and `appDatabaseProvider` exist.
- `package_info_plus`, `path_provider`, `path`, `mocktail`, `drift` are already in `pubspec.yaml`.
- `Ref` in a `@Riverpod` function provider matches the existing pattern in
  `lib/features/notes/presentation/notes_controller.dart`.

## Concern 1 (may block step 6): the brief test does not mock platform channels

The test mocks only `BackupFolder`, but the controller under test calls
`getApplicationDocumentsDirectory()`, `getTemporaryDirectory()` and
`PackageInfo.fromPlatform()` before `folder.write`.

No other test in this repo relies on a real plugin for those calls:

- `test/settings_editor_test.dart:81` calls `PackageInfo.setMockInitialValues(...)`.
- `test/note_attachments_upload_test.dart:70`, `test/add_sheet_test.dart:76`,
  `test/log_viewer_screen_test.dart:110` mock the `plugins.flutter.io/path_provider`
  method channel.

So on a host where those plugins are not registered for `flutter test`, tests 2
and 3 of the brief will get `MissingPluginException` instead of `done` / `disk
full`, and step 6 fails. Test 1 passes either way (it returns before the plugin
calls).

I did NOT change the test, because the brief says to write the files exactly.
Minimal fix if step 6 fails — add to `main()` in
`test/backup/backup_controller_test.dart`:

```dart
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // existing body...
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => root.path,
        );
    PackageInfo.setMockInitialValues(
      appName: 'Anchor',
      packageName: 'anchor',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });
```

plus imports `package:flutter/services.dart` and
`package:package_info_plus/package_info_plus.dart`. If the remote host does
register the Dart plugin implementations (Linux desktop path_provider), this fix
is harmless — the mock is simply unused.

## Concern 2: line length / `dart format`

The brief code has lines over 80 columns, e.g.

```dart
      if (automatic) await _applyRetention(folder, settings.folderUri!, settings.keepFiles);
```

and the mocktail `verify(...)` chain in the test. If CI runs
`dart format --set-exit-if-changed`, those lines will be reformatted. I kept the
brief text as written; run `dart format mobile/lib/features/backup mobile/test/backup`
on the remote host if the format check is part of CI.

## Concern 3: `run(automatic: true)` is untested

The brief has no test for the retention path (`_applyRetention`) or for the
"busy" guard. Behaviour is unverified: `keepFiles` older automatic files are
deleted, manual `anchor-*.zip` files are never counted. Not a defect, only a
gap in coverage that the brief did not ask me to close.

## Doubt

`_applyRetention` sorts names lexicographically. The stamp format
`YYYY-MM-DD_HHMMSS` sorts correctly, so the oldest go first — but this depends on
`folder.list()` returning plain names and on the prefix `anchor-auto-` being
unique. A folder holding files from another app with that prefix is not
distinguished.
