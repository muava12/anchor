// test/backup/backup_restorer_test.dart
import 'dart:io';

import 'package:anchor/core/database/app_database.dart';
import 'package:anchor/features/backup/data/backup_exporter.dart';
import 'package:anchor/features/backup/data/backup_reader.dart';
import 'package:anchor/features/backup/data/backup_restorer.dart';
import 'package:anchor/features/backup/domain/restore_mode.dart';
import 'package:anchor/features/notes/data/local/note_rows.dart';
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

  test('a tag keeps its version in keepIds mode and loses it in newIds mode',
      () async {
    await source.into(source.tags).insert(
      TagsCompanion.insert(
        id: 't1',
        name: 'molagis',
        version: const Value(4),
      ),
    );
    await source.into(source.notes).insert(
      NotesCompanion.insert(id: 'n1', title: 'Groceries'),
    );
    await source.into(source.noteTags).insert(
      NoteTagsCompanion.insert(noteId: 'n1', tagId: 't1'),
    );
    final zipPath = '${folder.path}/out.zip';
    await BackupExporter(source, folder).write(zipPath, appVersion: '0.22.2');
    final bytes = File(zipPath).readAsBytesSync();

    await BackupRestorer(target, folder).restore(
      BackupReader(bytes),
      RestoreMode.keepIds,
    );
    expect((await target.select(target.tags).get()).single.version, 4);

    await BackupRestorer(target, folder).restore(
      BackupReader(bytes),
      RestoreMode.newIds,
    );
    expect((await target.select(target.tags).get()).single.version, isNull);
  });

  test('the files of the replaced attachments are deleted', () async {
    final oldDir = Directory('${folder.path}/old')..createSync(recursive: true);
    final oldFile = File('${oldDir.path}/gone.jpg')..writeAsBytesSync([1]);
    await target.into(target.notes).insert(
      NotesCompanion.insert(id: 'old', title: 'Old note'),
    );
    await target.into(target.noteAttachments).insert(
      NoteAttachmentsCompanion.insert(
        id: 'a-old',
        noteId: 'old',
        type: 'image',
        originalFilename: 'gone.jpg',
        mimeType: 'image/jpeg',
        fileSize: 1,
        localPath: Value(oldFile.path),
      ),
    );

    final reader = await exportOneNote();
    await BackupRestorer(target, folder).restore(reader, RestoreMode.keepIds);

    expect(oldFile.existsSync(), isFalse);
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
