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
