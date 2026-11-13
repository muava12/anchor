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

      List<int> bytes = await File(zipPath).readAsBytes();
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
