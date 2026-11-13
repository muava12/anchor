// lib/features/backup/data/backup_exporter.dart
import 'dart:io';

import 'package:path/path.dart' as path;

import '../../../core/database/app_database.dart';
import '../domain/backup_contents.dart';
import '../domain/backup_manifest.dart';
import 'backup_writer.dart';

/// Reads every note, tag and attachment out of the database and writes them
/// into one zip.
class BackupExporter {
  BackupExporter(this._db, this._attachmentsRoot);

  final AppDatabase _db;

  /// The `attachments` directory under the app documents directory.
  final Directory _attachmentsRoot;

  Future<BackupManifest> write(
    String zipPath, {
    required String appVersion,
  }) async {
    final writer = BackupWriter(zipPath);
    try {
      final tags = await _db.select(_db.tags).get();
      final notes = await _db.select(_db.notes).get();
      final attachments = await _db.select(_db.noteAttachments).get();
      final noteTags = await _db.select(_db.noteTags).get();

      final tagIdsByNote = <String, List<String>>{};
      for (final row in noteTags) {
        tagIdsByNote.putIfAbsent(row.noteId, () => []).add(row.tagId);
      }

      final backupNotes = <BackupNote>[];
      var attachmentCount = 0;

      for (final note in notes) {
        final backupAttachments = <BackupAttachment>[];
        for (final attachment in attachments.where(
          (row) => row.noteId == note.id,
        )) {
          final source = _sourceOf(attachment);
          if (source == null) continue;

          final name =
              'attachments/${attachment.id}${path.extension(source.path)}';
          await writer.addFile(source, name);
          attachmentCount++;
          backupAttachments.add(
            BackupAttachment(
              id: attachment.id,
              type: attachment.type,
              originalFilename: attachment.originalFilename,
              mimeType: attachment.mimeType,
              fileSize: attachment.fileSize,
              position: attachment.position,
              file: name,
            ),
          );
        }

        backupNotes.add(
          BackupNote(
            id: note.id,
            title: note.title,
            content: note.content,
            isPinned: note.isPinned,
            isArchived: note.isArchived,
            background: note.background,
            state: note.state,
            updatedAt: note.updatedAt,
            version: note.version,
            reminderAt: note.reminderAt,
            reminderRecurrence: note.reminderRecurrence,
            tagIds: tagIdsByNote[note.id] ?? const [],
            attachments: backupAttachments,
          ),
        );
      }

      final manifest = BackupManifest(
        format: BackupManifest.currentFormat,
        app: 'anchor',
        appVersion: appVersion,
        createdAt: DateTime.now().toUtc(),
        notes: backupNotes.length,
        attachments: attachmentCount,
      );

      await writer.addJson('manifest.json', manifest.toJson());
      await writer.addJson(
        'notes.json',
        BackupContents(
          tags: [
            for (final tag in tags)
              BackupTag(id: tag.id, name: tag.name, color: tag.color),
          ],
          notes: backupNotes,
        ).toJson(),
      );
      return manifest;
    } finally {
      await writer.close();
    }
  }

  /// Null when the row has no local file, or the file is gone.
  File? _sourceOf(AttachmentRow row) {
    final stored = row.localPath;
    if (stored == null) return null;
    // A stored path is absolute today. A relative one is read from the
    // attachments folder, so an older row still exports.
    final file = path.isAbsolute(stored)
        ? File(stored)
        : File(path.join(_attachmentsRoot.path, stored));
    return file.existsSync() ? file : null;
  }
}
