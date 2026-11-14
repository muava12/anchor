import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as path;

import '../../../core/database/app_database.dart';
import '../../../core/ids.dart';
import '../domain/restore_mode.dart';
import 'backup_reader.dart';

/// Replaces every local note, tag and attachment with the contents of a backup.
class BackupRestorer {
  BackupRestorer(this._db, this._attachmentsRoot);

  final AppDatabase _db;

  /// The `attachments` directory under the app documents directory.
  final Directory _attachmentsRoot;

  Future<int> restore(BackupReader reader, RestoreMode mode) async {
    final contents = reader.contents;
    final tagIdMap = <String, String>{};
    final noteIdMap = <String, String>{};

    for (final tag in contents.tags) {
      tagIdMap[tag.id] = mode == RestoreMode.keepIds ? tag.id : newId();
    }
    for (final note in contents.notes) {
      noteIdMap[note.id] = mode == RestoreMode.keepIds ? note.id : newId();
    }

    // Files the restore replaces. They are removed only after the transaction
    // commits, so a rollback leaves the old library readable.
    final replaced = <String>[
      for (final row in await _db.select(_db.noteAttachments).get())
        if (row.localPath != null) row.localPath!,
    ];
    final written = <String>[];

    try {
      await _db.transaction(() async {
        await _db.delete(_db.noteTags).go();
        await _db.delete(_db.noteAttachments).go();
        await _db.delete(_db.notes).go();
        await _db.delete(_db.tags).go();

        for (final tag in contents.tags) {
          await _db
              .into(_db.tags)
              .insert(
                TagsCompanion.insert(
                  id: tagIdMap[tag.id]!,
                  name: tag.name,
                  color: Value(tag.color),
                  version: Value(
                    mode == RestoreMode.keepIds ? tag.version : null,
                  ),
                  isSynced: const Value(false),
                ),
              );
        }

        for (final note in contents.notes) {
          final noteId = noteIdMap[note.id]!;
          await _db
              .into(_db.notes)
              .insert(
                NotesCompanion.insert(
                  id: noteId,
                  title: note.title,
                  content: Value(note.content),
                  isPinned: Value(note.isPinned),
                  isArchived: Value(note.isArchived),
                  background: Value(note.background),
                  state: Value(note.state),
                  updatedAt: Value(note.updatedAt),
                  version: Value(
                    mode == RestoreMode.keepIds ? note.version : null,
                  ),
                  reminderAt: Value(note.reminderAt),
                  reminderRecurrence: Value(note.reminderRecurrence),
                  isSynced: const Value(false),
                  localRev: const Value(0),
                ),
              );

          final linked = <String>{};
          for (final tagId in note.tagIds) {
            final mapped = tagIdMap[tagId];
            if (mapped == null || !linked.add(mapped)) continue;
            await _db
                .into(_db.noteTags)
                .insert(
                  NoteTagsCompanion.insert(noteId: noteId, tagId: mapped),
                );
          }

          for (final attachment in note.attachments) {
            final attachmentId = mode == RestoreMode.keepIds
                ? attachment.id
                : newId();
            final noteDir = Directory(path.join(_attachmentsRoot.path, noteId));
            if (!noteDir.existsSync()) noteDir.createSync(recursive: true);

            final target = File(
              path.join(
                noteDir.path,
                '$attachmentId-${path.basename(attachment.originalFilename)}',
              ),
            );
            await target.writeAsBytes(reader.fileBytes(attachment.file));
            written.add(target.path);

            await _db
                .into(_db.noteAttachments)
                .insert(
                  NoteAttachmentsCompanion.insert(
                    id: attachmentId,
                    noteId: noteId,
                    type: attachment.type,
                    originalFilename: attachment.originalFilename,
                    mimeType: attachment.mimeType,
                    fileSize: attachment.fileSize,
                    position: Value(attachment.position),
                    localPath: Value(target.path),
                    syncStatus: const Value('pending_upload'),
                  ),
                );
          }
        }
      });
    } catch (_) {
      // The database rolled back, so the files it would have pointed at are
      // orphans.
      for (final file in written) {
        final handle = File(file);
        if (handle.existsSync()) handle.deleteSync();
      }
      rethrow;
    }

    for (final file in replaced) {
      final handle = File(file);
      if (handle.existsSync()) handle.deleteSync();
    }

    return contents.notes.length;
  }
}
