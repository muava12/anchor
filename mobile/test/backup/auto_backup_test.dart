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
