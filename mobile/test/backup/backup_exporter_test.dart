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
    await db
        .into(db.tags)
        .insert(TagsCompanion.insert(id: 't1', name: 'molagis'));
    await db
        .into(db.notes)
        .insert(
          NotesCompanion.insert(
            id: 'n1',
            title: 'Groceries',
            content: const Value('{"ops":[]}'),
            isPinned: const Value(true),
            version: const Value(7),
          ),
        );
    await db
        .into(db.noteTags)
        .insert(NoteTagsCompanion.insert(noteId: 'n1', tagId: 't1'));

    final noteDir = Directory('${folder.path}/n1')..createSync(recursive: true);
    final photo = File('${noteDir.path}/a1-photo.jpg')
      ..writeAsBytesSync([9, 9, 9]);
    await db
        .into(db.noteAttachments)
        .insert(
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
    final manifest = await BackupExporter(
      db,
      folder,
    ).write(zipPath, appVersion: '0.22.2');

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
    await db
        .into(db.notes)
        .insert(NotesCompanion.insert(id: 'n1', title: 'Groceries'));
    await db
        .into(db.noteAttachments)
        .insert(
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
    final manifest = await BackupExporter(
      db,
      folder,
    ).write(zipPath, appVersion: '0.22.2');

    expect(manifest.attachments, 0);
    expect(
      BackupReader(
        File(zipPath).readAsBytesSync(),
      ).contents.notes.single.attachments,
      isEmpty,
    );
  });
}
