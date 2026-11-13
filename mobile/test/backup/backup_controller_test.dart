// test/backup/backup_controller_test.dart
import 'dart:io';

import 'package:anchor/core/database/app_database.dart';
import 'package:anchor/features/backup/data/backup_folder.dart';
import 'package:anchor/features/backup/presentation/backup_controller.dart';
import 'package:anchor/features/backup/presentation/backup_settings_controller.dart';
import 'package:anchor/features/backup/domain/backup_settings.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';

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
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late MockBackupFolder folder;
  late Directory root;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    folder = MockBackupFolder();
    root = Directory.systemTemp.createTempSync('backup_job');
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

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
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

  test('an automatic backup keeps the newest files and leaves manual ones',
      () async {
    when(
      () => folder.write(any(), any(), any()),
    ).thenAnswer((_) async {});
    when(() => folder.list(any())).thenAnswer(
      (_) async => [
        'anchor-auto-2026-01-01_000000.zip',
        'anchor-auto-2026-02-01_000000.zip',
        'anchor-auto-2026-03-01_000000.zip',
        'anchor-2026-04-01_000000.zip',
      ],
    );
    when(() => folder.delete(any(), any())).thenAnswer((_) async {});

    final container = containerWith(
      const BackupSettings(
        folderUri: 'content://tree/backups',
        keepFiles: 2,
      ),
    );
    final result = await container
        .read(backupControllerProvider.notifier)
        .run(automatic: true);

    expect(result.outcome, BackupOutcome.done);
    verify(
      () => folder.delete(
        'content://tree/backups',
        'anchor-auto-2026-01-01_000000.zip',
      ),
    ).called(1);
    verifyNever(
      () => folder.delete('content://tree/backups', 'anchor-2026-04-01_000000.zip'),
    );
  });
}
