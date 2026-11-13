### Task 5: Restore into the database

**Files:**
- Create: `lib/features/backup/domain/restore_mode.dart`
- Create: `lib/features/backup/data/backup_restorer.dart`
- Test: `test/backup/backup_restorer_test.dart`

**Interfaces:**
- Consumes: `BackupReader` (Task 2), `BackupContents` (Task 1), `AppDatabase`, `newId()` from `lib/core/ids.dart`.
- Produces:
  - `enum RestoreMode { keepIds, newIds }`
  - `class BackupRestorer { BackupRestorer(this.db, this.attachmentsRoot); Future<int> restore(BackupReader reader, RestoreMode mode); }` — returns the number of notes written.

- [ ] **Step 1: Write the failing test**

```dart
// test/backup/backup_restorer_test.dart
import 'dart:io';

import 'package:anchor/core/database/app_database.dart';
import 'package:anchor/features/backup/data/backup_exporter.dart';
import 'package:anchor/features/backup/data/backup_reader.dart';
import 'package:anchor/features/backup/data/backup_restorer.dart';
import 'package:anchor/features/backup/domain/restore_mode.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase source;
  late AppDatabase target;
  late Directory folder;

  setUp(() {
    source = AppDatabase.forTesting(NativeDatabase.memory());
    target = AppDatabase.forTesting(NativeDatabase.memory());
    folder = Directory.systemTemp.createTempSync('backup_restore');
  });

  tearDown(() async {
    await source.close();
    await target.close();
    folder.deleteSync(recursive: true);
  });

  Future<BackupReader> exportOneNote() async {
    await source.into(source.notes).insert(
      NotesCompanion.insert(
        id: 'n1',
        title: 'Groceries',
        content: const Value('{"ops":[]}'),
        version: const Value(7),
      ),
    );
    final zipPath = '${folder.path}/out.zip';
    await BackupExporter(source, folder).write(zipPath, appVersion: '0.22.2');
    return BackupReader(File(zipPath).readAsBytesSync());
  }

  test('keepIds keeps the id and the version, and marks the note unsynced',
      () async {
    final reader = await exportOneNote();
    final written = await BackupRestorer(target, folder).restore(
      reader,
      RestoreMode.keepIds,
    );

    expect(written, 1);
    final row = await target.noteRow('n1');
    expect(row, isNotNull);
    expect(row!.title, 'Groceries');
    expect(row.version, 7);
    expect(row.isSynced, isFalse);
    expect(row.localRev, 0);
  });

  test('newIds gives a fresh id and clears the version', () async {
    final reader = await exportOneNote();
    await BackupRestorer(target, folder).restore(reader, RestoreMode.newIds);

    final rows = await target.select(target.notes).get();
    expect(rows, hasLength(1));
    expect(rows.single.id, isNot('n1'));
    expect(rows.single.version, isNull);
    expect(rows.single.isSynced, isFalse);
  });

  test('restore replaces what was there', () async {
    await target.into(target.notes).insert(
      NotesCompanion.insert(id: 'old', title: 'Old note'),
    );
    final reader = await exportOneNote();
    await BackupRestorer(target, folder).restore(reader, RestoreMode.keepIds);

    final rows = await target.select(target.notes).get();
    expect(rows.map((row) => row.id), ['n1']);
  });

  test('an attachment is written to disk and points at the new file',
      () async {
    await source.into(source.notes).insert(
      NotesCompanion.insert(id: 'n1', title: 'Groceries'),
    );
    final noteDir = Directory('${folder.path}/n1')..createSync(recursive: true);
    final photo = File('${noteDir.path}/a1-photo.jpg')
      ..writeAsBytesSync([5, 5, 5]);
    await source.into(source.noteAttachments).insert(
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
    await BackupExporter(source, folder).write(zipPath, appVersion: '0.22.2');

    final targetRoot = Directory('${folder.path}/target')..createSync();
    await BackupRestorer(
      target,
      targetRoot,
    ).restore(BackupReader(File(zipPath).readAsBytesSync()), RestoreMode.keepIds);

    final row = (await target.select(target.noteAttachments).get()).single;
    expect(row.serverAttachmentId, isNull);
    expect(row.syncStatus, 'pending_upload');
    expect(File(row.localPath!).readAsBytesSync(), [5, 5, 5]);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/backup/backup_restorer_test.dart`
Expected: FAIL — `Target of URI doesn't exist`

- [ ] **Step 3: Write the mode and the restorer**

```dart
// lib/features/backup/domain/restore_mode.dart
/// How a restore treats the ids in the backup.
enum RestoreMode {
  /// The same account: keep the ids and the server versions, so the server can
  /// tell an unchanged note from one edited after the backup.
  keepIds,

  /// Any account: fresh ids and no version, so the server creates every note.
  newIds,
}
```

```dart
// lib/features/backup/data/backup_restorer.dart
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

    await _db.transaction(() async {
      await _db.delete(_db.noteTags).go();
      await _db.delete(_db.noteAttachments).go();
      await _db.delete(_db.notes).go();
      await _db.delete(_db.tags).go();

      for (final tag in contents.tags) {
        await _db.into(_db.tags).insert(
          TagsCompanion.insert(
            id: tagIdMap[tag.id]!,
            name: tag.name,
            color: Value(tag.color),
            isSynced: const Value(false),
          ),
        );
      }

      for (final note in contents.notes) {
        final noteId = noteIdMap[note.id]!;
        await _db.into(_db.notes).insert(
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

        for (final tagId in note.tagIds) {
          final mapped = tagIdMap[tagId];
          if (mapped == null) continue;
          await _db.into(_db.noteTags).insert(
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

          await _db.into(_db.noteAttachments).insert(
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

    return contents.notes.length;
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd mobile && flutter test test/backup/backup_restorer_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/features/backup/domain/restore_mode.dart mobile/lib/features/backup/data/backup_restorer.dart mobile/test/backup/backup_restorer_test.dart
git commit -m "feat: restore a backup into the database, keeping or renewing ids"
```

---

