### Task 4: Export the database into a backup

**Files:**
- Create: `lib/features/backup/data/backup_exporter.dart`
- Test: `test/backup/backup_exporter_test.dart`

**Interfaces:**
- Consumes: `BackupWriter` (Task 1), `BackupContents` (Task 1), `AppDatabase`.
- Produces:
  - `class BackupExporter { BackupExporter(this.db, this.attachmentsRoot); Future<BackupManifest> write(String zipPath, {required String appVersion}); }`
  - `attachmentsRoot` is the `attachments` directory under the app documents directory.

- [ ] **Step 1: Write the failing test**

```dart
// test/backup/backup_exporter_test.dart
import 'dart:io';

import 'package:anchor/core/database/app_database.dart';
import 'package:anchor/features/backup/data/backup_exporter.dart';
import 'package:anchor/features/backup/data/backup_reader.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late Directory folder;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    folder = Directory.systemTemp.createTempSync('backup_export');
  });

  tearDown(() async {
    await db.close();
    folder.deleteSync(recursive: true);
  });

  test('exports notes, tags and an attachment', () async {
    await db.into(db.tags).insert(
      TagsCompanion.insert(id: 't1', name: 'molagis'),
    );
    await db.into(db.notes).insert(
      NotesCompanion.insert(
        id: 'n1',
        title: 'Groceries',
        content: const Value('{"ops":[]}'),
        isPinned: const Value(true),
        version: const Value(7),
      ),
    );
    await db.into(db.noteTags).insert(
      NoteTagsCompanion.insert(noteId: 'n1', tagId: 't1'),
    );

    final noteDir = Directory('${folder.path}/n1')..createSync(recursive: true);
    final photo = File('${noteDir.path}/a1-photo.jpg')
      ..writeAsBytesSync([9, 9, 9]);
    await db.into(db.noteAttachments).insert(
      NoteAttachmentsCompanion.insert(
        id: 'a1',
        noteId: 'n1',
        type: 'image',
        originalFilename: 'photo.jpg',
        mimeType: 'image/jpeg',
        fileSize: 3,
        localPath: Value(photo.path),
      ),
    );

    final zipPath = '${folder.path}/out.zip';
    final manifest = await BackupExporter(db, folder).write(
      zipPath,
      appVersion: '0.22.2',
    );

    expect(manifest.notes, 1);
    expect(manifest.attachments, 1);

    final reader = BackupReader(File(zipPath).readAsBytesSync());
    final note = reader.contents.notes.single;
    expect(note.title, 'Groceries');
    expect(note.isPinned, isTrue);
    expect(note.version, 7);
    expect(note.tagIds, ['t1']);
    expect(reader.contents.tags.single.name, 'molagis');
    expect(reader.fileBytes(note.attachments.single.file), [9, 9, 9]);
  });

  test('an attachment whose file is gone is left out', () async {
    await db.into(db.notes).insert(
      NotesCompanion.insert(id: 'n1', title: 'Groceries'),
    );
    await db.into(db.noteAttachments).insert(
      NoteAttachmentsCompanion.insert(
        id: 'a1',
        noteId: 'n1',
        type: 'image',
        originalFilename: 'photo.jpg',
        mimeType: 'image/jpeg',
        fileSize: 3,
        localPath: const Value('/nowhere/photo.jpg'),
      ),
    );

    final zipPath = '${folder.path}/out.zip';
    final manifest = await BackupExporter(db, folder).write(
      zipPath,
      appVersion: '0.22.2',
    );

    expect(manifest.attachments, 0);
    expect(
      BackupReader(File(zipPath).readAsBytesSync()).contents.notes.single
          .attachments,
      isEmpty,
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/backup/backup_exporter_test.dart`
Expected: FAIL — `Target of URI doesn't exist`

- [ ] **Step 3: Write the exporter**

```dart
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

          final name = 'attachments/${attachment.id}${path.extension(source.path)}';
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
    final file = File(stored);
    return file.existsSync() ? file : null;
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd mobile && flutter test test/backup/backup_exporter_test.dart`
Expected: PASS, 2 tests.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/features/backup/data/backup_exporter.dart mobile/test/backup/backup_exporter_test.dart
git commit -m "feat: export every note, tag and attachment into a backup"
```

---

