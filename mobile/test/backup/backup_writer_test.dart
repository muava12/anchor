import 'dart:convert';
import 'dart:io';

import 'package:anchor/features/backup/data/backup_writer.dart';
import 'package:anchor/features/backup/domain/backup_contents.dart';
import 'package:anchor/features/backup/domain/backup_manifest.dart';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory folder;

  setUp(() => folder = Directory.systemTemp.createTempSync('backup_writer'));
  tearDown(() => folder.deleteSync(recursive: true));

  test('writes the manifest, the notes and an attachment', () async {
    final photo = File('${folder.path}/photo.jpg')
      ..writeAsBytesSync([1, 2, 3, 4]);
    final zipPath = '${folder.path}/out.zip';

    final writer = BackupWriter(zipPath);
    await writer.addJson('manifest.json', {
      'format': 1,
      'app': 'anchor',
      'appVersion': '0.22.2',
      'createdAt': '2026-11-14T05:30:00.000Z',
      'notes': 1,
      'attachments': 1,
    });
    await writer.addJson('notes.json', {
      'tags': [
        {'id': 't1', 'name': 'molagis', 'color': null},
      ],
      'notes': [
        {
          'id': 'n1',
          'title': 'Groceries',
          'content': null,
          'isPinned': false,
          'isArchived': false,
          'background': null,
          'state': 'active',
          'updatedAt': '2026-11-13T10:44:43.093Z',
          'version': 7,
          'reminderAt': null,
          'reminderRecurrence': null,
          'tagIds': ['t1'],
          'attachments': [
            {
              'id': 'a1',
              'type': 'image',
              'originalFilename': 'photo.jpg',
              'mimeType': 'image/jpeg',
              'fileSize': 4,
              'position': 0,
              'file': 'attachments/a1.jpg',
            },
          ],
        },
      ],
    });
    await writer.addFile(photo, 'attachments/a1.jpg');
    await writer.close();

    final archive = ZipDecoder().decodeBytes(File(zipPath).readAsBytesSync());
    expect(
      archive.files.map((file) => file.name),
      containsAll(['manifest.json', 'notes.json', 'attachments/a1.jpg']),
    );

    final notes = jsonDecode(
      utf8.decode(archive.findFile('notes.json')!.content as List<int>),
    ) as Map<String, dynamic>;
    expect((notes['notes'] as List).single['title'], 'Groceries');
    expect(archive.findFile('attachments/a1.jpg')!.content, [1, 2, 3, 4]);
  });

  test('a manifest round trips through json', () {
    final manifest = BackupManifest(
      format: 1,
      app: 'anchor',
      appVersion: '0.22.2',
      createdAt: DateTime.utc(2026, 11, 14, 5, 30),
      notes: 61,
      attachments: 6,
    );
    final back = BackupManifest.fromJson(manifest.toJson());
    expect(back.format, 1);
    expect(back.notes, 61);
    expect(back.createdAt, DateTime.utc(2026, 11, 14, 5, 30));
  });

  test('a note round trips through json', () {
    final note = BackupNote(
      id: 'n1',
      title: 'Groceries',
      content: '{"ops":[]}',
      isPinned: true,
      isArchived: false,
      background: null,
      state: 'active',
      updatedAt: DateTime.utc(2026, 11, 13, 10, 44, 43),
      version: 7,
      reminderAt: '2026-11-20T08:00',
      reminderRecurrence: 'daily',
      tagIds: const ['t1'],
      attachments: const [],
    );
    final back = BackupNote.fromJson(note.toJson());
    expect(back.id, 'n1');
    expect(back.isPinned, isTrue);
    expect(back.version, 7);
    expect(back.reminderAt, '2026-11-20T08:00');
    expect(back.tagIds, ['t1']);
  });
}
